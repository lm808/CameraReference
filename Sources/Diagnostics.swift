import AppKit
import ApplicationServices

/// Owns report state, diagnostic windows and preview lifetime. All mutation stays
/// on main-thread call sites. Opt-in window-order recording owns a bounded timer;
/// routine report collection does not start it.
/// Coordination adapters retain cross-component guards and post-display scheduling;
/// the service owns report state, while readers/placement stay in their own modules.
final class DiagnosticsService {
    let windowOrdering=WindowOrderRecorder()
    var diagnosticsWindow:DiagnosticsController?
    var capturePreview:CapturePreviewController?
    var captureBaseline:CapturePreviewController?
    var captureBaselineGeometry:(CGWindowID,CGRect)?
    var captureBaselineSummary=""
    var lastLayout = "Automatic detection has not been tested."
    var lastResult = "No check yet."
    var lastTiming="No timing sample yet."
    var lastPlacementFailure="No placement failure recorded this session."
    var lastAXMapping="Not collected. Use Diagnostics → Refresh AX."
    var lastAXTrial="AX preview not run."
    var lastAXToolbar="Not collected. Use Diagnostics → Refresh AX."
    var lastViewDetection="Automatic view detection disabled."
    var lastGridStatus="Grid menu not sampled."
    var diagnosticGeneration=0
    var diagnosticPending=false
    var diagnosticRunningGeneration = -1
    var savingInvocation=false
    var diagnosticSaveStatus="Automatic report saving has not run."
    var axMappingInProgress=false
    var axTrialBorders:[NSPanel]=[]
    var axTrialGeneration=0

    func sections(app:AppDelegate)->[DiagnosticSection] {
        let folder=app.folder
        let versionTitle=app.versionTitle
        let storageStatus=app.storageStatus
        let automaticPlacementMode=app.automaticPlacementMode
        let automaticViewEnabled=app.automaticViewEnabled
        let assistedChecks=app.assistedChecks
        let assistedAXSeconds=app.assistedAXSeconds
        let assistedCheckSeconds=app.assistedCheckSeconds
        let assistedAXChanges=app.assistedAXChanges
        let assistedAXFailures=app.assistedAXFailures
        let assistedPixelChanges=app.assistedPixelChanges
        let assistedPixelFailures=app.assistedPixelFailures
        let assistedEvidence=app.assistedEvidence
        let axLiveUpdate=app.axLiveUpdate
        let overlayVisibilityStatus=app.overlayController.overlayVisibilityStatus + "\nTitle-bar clip: \(app.overlayController.titlebarClipStatus); top=\(app.panel?.titlebarClipHeight ?? 0) pt"
        let overlayGeometrySource=app.overlayController.overlayGeometrySource
        let overlayLifecycleStatus=app.overlayController.overlayLifecycleStatus
        let overlayMoveCount=app.overlayController.overlayMoveCount
        let overlayOrderCount=app.overlayController.overlayOrderCount
        let overlayLevelChangeCount=app.overlayController.overlayLevelChangeCount
        let lifecycleTrace=app.overlayController.lifecycleTrace
        let panelCheckStatus=app.lightroomMonitor.panelCheckStatus
        let heartbeat=folder.appendingPathComponent("heartbeat.txt")
        let attributes=try? FileManager.default.attributesOfItem(atPath:heartbeat.path)
        let date=attributes?[.modificationDate] as? Date
        let age=date.map { "\(max(0,Int(Date().timeIntervalSince($0)))) seconds ago" } ?? "not received"
        let state=(try? String(contentsOf:folder.appendingPathComponent("status.txt"),encoding:.utf8)) ?? "No plugin status received."
        return [
            DiagnosticSection(title:"App & permissions",body:"\(versionTitle)\nAccessibility: \(AXIsProcessTrusted() ? "granted":"not granted — request through Inspect Accessibility layout")\nScreen Recording: \(CGPreflightScreenCaptureAccess() ? "granted":"not granted")\nExifTool: \(findExifTool(custom:CameraPreferences.shared.string(forKey:"exiftool")) == nil ? "not found":"available")\nApp: \(Bundle.main.bundleURL.path)\nBundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")\n\(storageStatus)"),
            DiagnosticSection(title:"Accessibility & display map",body:lastAXMapping),
            DiagnosticSection(title:"Saved diagnostics",body:diagnosticSaveStatus),
            DiagnosticSection(title:"Automatic view experiment",body:lastViewDetection),
            DiagnosticSection(title:"Placement method & assisted evidence",body:"Method: \(automaticPlacementMode.title). View detection: \(automaticViewEnabled ? "automatic AX":"menu selection").\nRetained screenshot checks: \(assistedChecks); AX time: \(Int(assistedAXSeconds*1000)) ms; retained capture/check time: \(Int((assistedCheckSeconds-assistedAXSeconds)*1000)) ms.\nAX changes: \(assistedAXChanges); AX unavailable/stale: \(assistedAXFailures).\nPixel boundary changes after unchanged AX: \(assistedPixelChanges); pixel validation failures: \(assistedPixelFailures).\n\(assistedEvidence)\nAll periodic screenshot checks retained for this measurement trial; counters are session-only."),
            DiagnosticSection(title:"AX placement trial",body:lastAXTrial),
            DiagnosticSection(title:"AX toolbar visibility",body:lastAXToolbar),
            DiagnosticSection(title:"Grid view & view-change policy",body:lastGridStatus+"\nAX-only update overlay with LrC view: \(axLiveUpdate). Screenshot with AX view detection dismisses on confirmed photo/view/pane/panel changes and Grid. Without AX view detection, existing cache-invalidation behaviour is retained."),
            DiagnosticSection(title:"Last result",body:lastResult),
            DiagnosticSection(title:"Last placement failure (retained snapshot)",body:lastPlacementFailure),
            DiagnosticSection(title:"Lightroom bridge",body:"Heartbeat: \(age)\nPlugin status: \(state.trimmingCharacters(in:.whitespacesAndNewlines))"),
            DiagnosticSection(title:"Overlay visibility & minimisation",body:"\(overlayVisibilityStatus)\nGeometry source: \(overlayGeometrySource)\n\(overlayLifecycleStatus)\nMoves: \(overlayMoveCount); ordering changes: \(overlayOrderCount); level changes: \(overlayLevelChangeCount).\n\nEvent history (uptime seconds):\n" + lifecycleTrace.joined(separator:"\n")),
            DiagnosticSection(title:"Placement & capture",body:lastLayout),
            DiagnosticSection(title:"Cache & background checks",body:"Last completed background check (may precede the current invocation):\n"+panelCheckStatus),
            DiagnosticSection(title:"Performance",body:lastTiming)
        ]
    }

    func save(enabled:Bool,url:URL,sections:()->[DiagnosticSection],failure:(String)->Void) {
        guard enabled else { return }
        do {
            try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
            diagnosticSaveStatus="Latest report: \(url.path)\nSaved: \(Date())"
            try diagnosticReport(sections()).write(to:url,atomically:true,encoding:.utf8)
        } catch {
            diagnosticSaveStatus="Could not save diagnostics: \(error.localizedDescription)"
            failure(diagnosticSaveStatus)
        }
    }
    func show(sections:[DiagnosticSection],refresh:@escaping ()->Void) {
        diagnosticsWindow?.close()
        diagnosticsWindow=DiagnosticsController(sections:sections,refresh:refresh)
    }
}

// App-facing adapters preserve the existing call graph, weak captures,
// generations, foreground gating and post-display scheduling verbatim.
extension AppDelegate {
    var diagnosticsWindow:DiagnosticsController? {
        get { diagnostics.diagnosticsWindow }
        set { diagnostics.diagnosticsWindow=newValue }
    }
    var capturePreview:CapturePreviewController? {
        get { diagnostics.capturePreview }
        set { diagnostics.capturePreview=newValue }
    }
    var captureBaseline:CapturePreviewController? {
        get { diagnostics.captureBaseline }
        set { diagnostics.captureBaseline=newValue }
    }
    var captureBaselineGeometry:(CGWindowID,CGRect)? {
        get { diagnostics.captureBaselineGeometry }
        set { diagnostics.captureBaselineGeometry=newValue }
    }
    var captureBaselineSummary:String {
        get { diagnostics.captureBaselineSummary }
        set { diagnostics.captureBaselineSummary=newValue }
    }
    var lastLayout:String {
        get { diagnostics.lastLayout }
        set { diagnostics.lastLayout=newValue }
    }
    var lastResult:String {
        get { diagnostics.lastResult }
        set { diagnostics.lastResult=newValue }
    }
    var lastTiming:String {
        get { diagnostics.lastTiming }
        set { diagnostics.lastTiming=newValue }
    }
    var lastPlacementFailure:String {
        get { diagnostics.lastPlacementFailure }
        set { diagnostics.lastPlacementFailure=newValue }
    }
    var lastAXMapping:String {
        get { diagnostics.lastAXMapping }
        set { diagnostics.lastAXMapping=newValue }
    }
    var lastAXTrial:String {
        get { diagnostics.lastAXTrial }
        set { diagnostics.lastAXTrial=newValue }
    }
    var lastAXToolbar:String {
        get { diagnostics.lastAXToolbar }
        set { diagnostics.lastAXToolbar=newValue }
    }
    var lastViewDetection:String {
        get { diagnostics.lastViewDetection }
        set { diagnostics.lastViewDetection=newValue }
    }
    var lastGridStatus:String {
        get { diagnostics.lastGridStatus }
        set { diagnostics.lastGridStatus=newValue }
    }
    var diagnosticGeneration:Int {
        get { diagnostics.diagnosticGeneration }
        set { diagnostics.diagnosticGeneration=newValue }
    }
    var diagnosticPending:Bool {
        get { diagnostics.diagnosticPending }
        set { diagnostics.diagnosticPending=newValue }
    }
    var diagnosticRunningGeneration:Int {
        get { diagnostics.diagnosticRunningGeneration }
        set { diagnostics.diagnosticRunningGeneration=newValue }
    }
    var savingInvocation:Bool {
        get { diagnostics.savingInvocation }
        set { diagnostics.savingInvocation=newValue }
    }
    var diagnosticSaveStatus:String {
        get { diagnostics.diagnosticSaveStatus }
        set { diagnostics.diagnosticSaveStatus=newValue }
    }
    var axMappingInProgress:Bool {
        get { diagnostics.axMappingInProgress }
        set { diagnostics.axMappingInProgress=newValue }
    }
    var axTrialBorders:[NSPanel] {
        get { diagnostics.axTrialBorders }
        set { diagnostics.axTrialBorders=newValue }
    }
    var axTrialGeneration:Int {
        get { diagnostics.axTrialGeneration }
        set { diagnostics.axTrialGeneration=newValue }
    }
    func report(_ text: String) {
        lastResult = text; detail.title = String(text.prefix(100)); status.button?.toolTip = text
        DispatchQueue.main.async { [weak self] in
            guard let self,self.savingInvocation else { return }
            self.saveInvocationDiagnostics()
            if self.pending == nil && self.screenInspectionID == nil && self.panel == nil && self.viewProbeID == nil { self.savingInvocation=false;self.collectCompleteDiagnostics() }
        }
    }

    func saveInvocationDiagnostics() {
        diagnostics.save(enabled:autoDiagnostics,url:diagnosticSaveURL,sections:{ self.diagnosticSections() },failure:{ self.detail.title=$0 })
    }

    func clearAXTrialBorders() {
        axTrialGeneration += 1
        for border in axTrialBorders { border.parent?.removeChildWindow(border);border.orderOut(nil) }
        axTrialBorders=[]
    }

    func runAXTrial(after actual:NSPanel) {
        clearAXTrialBorders()
        guard axTrialEnabled || autoDiagnostics else { lastAXTrial="AX preview disabled.";return }
        let drawPreview=axTrialEnabled,settings=reloadDetectionConfig(),module=currentModule()
        let generation=axTrialGeneration, displays=displayMappingReport(), started=ProcessInfo.processInfo.systemUptime
        lastAXTrial="AX preview collecting…"
        DispatchQueue.global(qos:.utility).async {
            var proposal:AXTrialProposal?
            let toolbar=accessibilityToolbarReading(fallback:settings.toolbarUnknownFallback,module:module)
            var previewSettings=settings;previewSettings.axToolbarState=toolbar.effectiveState
            let mapping=accessibilityMappingReport { host,windows,fullScreen in proposal=axTrialProposal(host:host,windows:windows,settings:previewSettings,module:module,fullScreen:fullScreen) }
            DispatchQueue.main.async {
                guard self.axTrialGeneration==generation,self.panel === actual else { return }
                self.lastAXToolbar=toolbar.report
                self.lastAXMapping=displays+"\n\n"+mapping
                self.lastAXTrial=(proposal?.summary ?? "AX proposal unavailable. See Accessibility map; normal overlay unaffected.")+"\nToolbar evidence used for this preview:\n"+toolbar.report+String(format:"\nTrial elapsed: %.0f ms (after normal panel shown).",(ProcessInfo.processInfo.systemUptime-started)*1000)
                if !drawPreview { self.lastAXTrial += "\nDrawing disabled; collected for automatic diagnostics.";self.savingInvocation=false;self.collectCompleteDiagnostics();return }
                if let proposal,let current=self.overlayController.overlayHost, axTrialHostMatches(proposedTopLeft:proposal.host,actualAppKit:current.frame,primaryHeight:CGDisplayBounds(CGMainDisplayID()).height) {
                    let displayHeight=CGDisplayBounds(CGMainDisplayID()).height
                    for (index,rect) in proposal.panes.enumerated() {
                        let frame=CGRect(x:rect.minX,y:displayHeight-rect.maxY,width:rect.width,height:rect.height)
                        let border=AXTrialPanel(contentRect:frame,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
                        border.isOpaque=false;border.backgroundColor = .clear;border.hasShadow=false;border.ignoresMouseEvents=true
                        border.level=actual.level
                        border.animationBehavior = .none;border.isReleasedWhenClosed=false;border.hidesOnDeactivate=false
                        border.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle,.transient]
                        let name=proposal.panes.count==1 ? "AX single":(proposal.layout=="Side-by-side" ? (index==0 ? "AX left":"AX right"):(index==0 ? "AX top":"AX bottom"))
                        border.contentView=AXTrialBorder(size:frame.size,tint:index==0 ? .systemGreen:.systemPurple,label:name)
                        actual.addChildWindow(border,ordered:.above)
                        if !self.overlayController.overlaySuspended && actual.isVisible {
                            self.orderReferencePanelFront(border)
                        } else { border.orderOut(nil) }
                        self.axTrialBorders.append(border)
                        self.applyTitlebarClip()
                        self.lastAXTrial += "\n\(name): requested AppKit \(frame); actual \(border.frame); visible \(border.isVisible); parent visible \(actual.isVisible); suspended \(self.overlayController.overlaySuspended)."
                    }
                } else if proposal != nil { self.lastAXTrial += "\nPreview not drawn: host changed or does not match overlay host. AX top-left: \(proposal!.host); overlay AppKit: \(String(describing:self.overlayController.overlayHost?.frame))." }
                self.savingInvocation=false;self.collectCompleteDiagnostics()
            }
        }
    }

    @objc func inspectLayout() {
        guard FeaturePermission.accessibility.ensure() else { return }
        collectCompleteDiagnostics(openWindow:true)
    }

    func collectCompleteDiagnostics(openWindow:Bool=false) {
        guard openWindow || autoDiagnostics else { return }
        if axMappingInProgress { if diagnosticRunningGeneration != diagnosticGeneration { diagnosticPending=true };return }
        let generation=diagnosticGeneration,displays=displayMappingReport(),module=currentModule(),settings=reloadDetectionConfig()
        axMappingInProgress=true;diagnosticRunningGeneration=generation
        lastAXToolbar="Collecting toolbar visibility…"
        saveInvocationDiagnostics()
        DispatchQueue.global(qos:.utility).async {
            let mapping="Module: \(module ?? "unknown")\n\n"+displays+"\n\n"+accessibilityMappingReport()
            let toolbar=accessibilityToolbarReading(fallback:settings.toolbarUnknownFallback,module:module)
            DispatchQueue.main.async {
                self.axMappingInProgress=false
                if generation==self.diagnosticGeneration && module==self.currentModule() {
                    self.lastAXMapping=mapping;self.lastAXToolbar=toolbar.report
                    self.saveInvocationDiagnostics()
                    if openWindow { self.showDiagnostics() }
                }
                if self.diagnosticPending {
                    self.diagnosticPending=false;self.collectCompleteDiagnostics()
                }
            }
        }
    }

    @objc func inspectViewState() {
        guard FeaturePermission.accessibility.ensure() else { return }
        report("Inspecting Lightroom menu state…")
        DispatchQueue.global(qos:.userInitiated).async { [weak self] in
            let result=probeLightroomViewState()
            DispatchQueue.main.async { self?.report(result);self?.showDiagnostics() }
        }
    }

    @objc func keepCaptureBaseline() { showCapturePreview(keepBaseline:true) }

    @objc func previewCapture() { showCapturePreview(keepBaseline:false) }

    func showCapturePreview(keepBaseline:Bool) {
        guard !regionResetting,requireSupportedModule() else { return }
        guard #available(macOS 14.0,*),FeaturePermission.screenCapture.granted else {
            report("Capture preview unavailable: Screen Recording permission is not available (macOS 14 or newer required). No capture taken.");showResult();return
        }
        hide();calibration?.finish(nil)
        if !keepBaseline { capturePreview?.close();capturePreview=nil }
        startPhotoDetection(imageSize:.zero,previewCapture:true) { [weak self] result in
            guard let self else { return }
            guard let image=result.previewImage,let frame=result.windowFrame,let id=result.windowID else {
                self.report(result.summary);self.showResult();return
            }
            if keepBaseline {
                guard result.displayContainedCapture else {
                    self.report("Move Lightroom fully onto one display, then keep the baseline. No baseline was replaced.");self.showResult();return
                }
                self.captureBaseline?.close()
                self.captureBaselineGeometry=(id,frame);self.captureBaselineSummary=result.summary
                self.captureBaseline=CapturePreviewController(image:image,title:"On-screen baseline") { [weak self] in
                    self?.captureBaselineGeometry=nil;self?.captureBaselineSummary=""
                }
            } else {
                if let (baselineID,baselineFrame)=self.captureBaselineGeometry {
                    let sameSize=abs(frame.width-baselineFrame.width)<0.5 && abs(frame.height-baselineFrame.height)<0.5
                    let comparison=baselineID==id && sameSize
                        ? "Same window and point size as baseline. Compare panel edges and full window corners; no alignment correction inferred."
                        : "Baseline window or size differs: capture a new on-screen baseline before comparing."
                    self.lastLayout += "\nComparison: " + comparison + "\nOn-screen baseline:\n" + self.captureBaselineSummary
                }
                self.capturePreview=CapturePreviewController(image:image,title:"Raw capture — unvalidated")
            }
        }
    }

    @objc func inspectScreen() {
        guard !regionResetting,requireSupportedModule() else { return }
        guard screenTask == nil else { report("Screen inspection is already running."); return }
        guard #available(macOS 14.0, *) else { report("Screen-based inspection requires macOS 14 or newer. Manual calibration remains available."); showResult(); return }
        guard FeaturePermission.screenCapture.granted else {
            report("Screen inspection unavailable: no Screen Recording permission. AX placement and manual calibration remain available.");showResult();return
        }
        hide(); calibration?.finish(nil)
        guard supportedLightroomModule(currentModule()) else { report("Select a photograph in Lightroom Library or Develop before screen inspection."); return }
        request(.detect) // Obtain the current JPEG aspect ratio, never a previous photo's.
    }

    func diagnosticSections()->[DiagnosticSection] { diagnostics.sections(app:self) }

    @objc func showDiagnostics() {
        diagnostics.show(sections:diagnosticSections(),refresh:{ [weak self] in self?.inspectLayout() })
    }
}
