import AppKit
import ApplicationServices

// Applies existing policy/actions to synchronous monitor signals and asynchronous
// evidence. Guard/read/effect order is intentional; do not eagerly snapshot reads.
extension AppDelegate {
    var observedWindowFrame:CGRect? {
        get { lightroomMonitor.observedWindowFrame }
        set { lightroomMonitor.observedWindowFrame=newValue }
    }
    var hasObservedWindow:Bool {
        get { lightroomMonitor.hasObservedWindow }
        set { lightroomMonitor.hasObservedWindow=newValue }
    }
    var lastModuleSample:(String, Date)? {
        get { lightroomMonitor.lastModuleSample }
        set { lightroomMonitor.lastModuleSample=newValue }
    }
    var observedModule:String? {
        get { lightroomMonitor.observedModule }
        set { lightroomMonitor.observedModule=newValue }
    }
    var workspaceOverview:Bool {
        get { lightroomMonitor.workspaceOverview }
        set { lightroomMonitor.workspaceOverview=newValue }
    }
    var detectedLayout:OverlayLayout? {
        get { lightroomMonitor.detectedLayout }
        set { lightroomMonitor.detectedLayout=newValue }
    }
    var detectedLayoutModule:String? {
        get { lightroomMonitor.detectedLayoutModule }
        set { lightroomMonitor.detectedLayoutModule=newValue }
    }
    var liveViewBusy:Bool {
        get { lightroomMonitor.liveViewBusy }
        set { lightroomMonitor.liveViewBusy=newValue }
    }
    var nextLiveViewCheck:TimeInterval {
        get { lightroomMonitor.nextLiveViewCheck }
        set { lightroomMonitor.nextLiveViewCheck=newValue }
    }
    var liveViewGeneration:Int {
        get { lightroomMonitor.liveViewGeneration }
        set { lightroomMonitor.liveViewGeneration=newValue }
    }
    var panelCheckTask:Task<Void,Never>? {
        get { lightroomMonitor.panelCheckTask }
        set { lightroomMonitor.panelCheckTask=newValue }
    }
    var panelCheckID:UUID? {
        get { lightroomMonitor.panelCheckID }
        set { lightroomMonitor.panelCheckID=newValue }
    }
    var nextPanelCheck:TimeInterval {
        get { lightroomMonitor.nextPanelCheck }
        set { lightroomMonitor.nextPanelCheck=newValue }
    }
    var panelCheckStatus:String {
        get { lightroomMonitor.panelCheckStatus }
        set { lightroomMonitor.panelCheckStatus=newValue }
    }
    func currentModule()->String? { lightroomMonitor.currentModule() }
    func isLightroom()->Bool { lightroomMonitor.isLightroom() }
    func handleLightroomEvent(_ event:LightroomMonitor.Event) {
        switch event {
        case .tick:monitorTick()
        case .foregroundChanged:frontAppChanged()
        case .spaceChanged:spaceChanged()
        case .displaysChanged:displaysChanged()
        case .displayCheckSettled:displayCheckSettled()
        }
    }
    func monitorTick() {
            self.consolidateStorageIfDue()
            let epoch=self.selectionEpoch()
            self.imageCache.observe(epoch)
            let module=self.currentModule()
            if let memory=self.placementMemory,memory.epoch != epoch || !supportedLightroomModule(module) { self.placementMemory=nil }
            if OverlayBehaviourPolicy.moduleChanged(previous:self.observedModule,current:module) {
                self.hide();self.cancelRequest();self.cancelScreenInspection()
                self.calibration?.finish(nil);self.calibrationTask?.cancel()
                self.invalidateAutomaticGeometry()
                self.updateLayoutMenu()
                self.autoItem?.state=CameraPreferences.shared.bool(forKey:self.regionKey("automaticBounds")) ? .on:.off
            }
            if let module {
                if self.observedModule == nil {
                    self.updateLayoutMenu()
                    self.autoItem?.state=CameraPreferences.shared.bool(forKey:self.regionKey("automaticBounds")) ? .on:.off
                }
                self.observedModule=module
            }
            self.workspaceOverview=(self.panel != nil || self.placementMemory != nil) && workspaceOverviewIsVisible()
            self.observeWindowGeometry()
            if self.panel != nil { _ = self.orderOverlayAboveLightroom() }
            self.checkPanelBoundariesIfDue()
            self.checkLiveAXViewIfDue()
            self.checkOverlaySelection(epoch)
            // Module/heartbeat uncertainty invalidates reuse, not the user-visible image.
    }
    @objc func frontAppChanged() {
        let own=NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier
        if !isLightroom() { cancelPanelCheck() }
        if !isLightroom() && !own { saveToast.close(); calibration?.finish(nil) }
        _ = orderOverlayAboveLightroom()
    }
    func observeWindowGeometry() {
        let current=lightroomWindowFrame()
        defer { observedWindowFrame=current;hasObservedWindow=true }
        if panel != nil { reconcileOverlayHost();return }
        guard hasObservedWindow else { return }
        if current == nil && observedWindowFrame == nil { return }
        if !sameWindowGeometry(current,observedWindowFrame) { invalidateAutomaticGeometry() }
    }
    @objc func spaceChanged() {
        suspendOverlay();cancelScreenInspection();lastProbe=nil
        Task { await ScreenGeometryCache.shared.reset() }
        hasObservedWindow=false
    }
    @objc func displaysChanged() {
        invalidateAutomaticGeometry()
        calibration?.finish(nil)
        lightroomMonitor.scheduleDisplayCheck()
    }
    func displayCheckSettled() {
        guard self.savedRegion != nil else { return }
        self.report(self.region != nil ? "Display checked: saved calibration retained." : "Saved calibration retained, but this display layout differs. Restore the display layout or calibrate again.")
    }
    func cancelPanelCheck() { panelCheckTask?.cancel();panelCheckTask=nil;panelCheckID=nil }
    func checkPanelBoundariesIfDue() {
        guard !axPlacementEnabled else { cancelPanelCheck();panelCheckStatus="AX-only mode: background screenshot checks disabled; fresh AX geometry on invocation.";return }
        guard FeaturePermission.screenCapture.granted else { cancelPanelCheck();panelCheckStatus="Background capture paused: Screen Recording permission unavailable.";return }
        guard #available(macOS 14.0,*),ProcessInfo.processInfo.systemUptime>=nextPanelCheck,
              panelCheckTask==nil,screenTask==nil,pending==nil,calibration==nil,!recording,!regionResetting,
              !workspaceOverview,!overlaySuspended,isLightroom(),supportedLightroomModule(currentModule()),CameraPreferences.shared.bool(forKey:regionKey("automaticBounds")),
              let memory=placementMemory,memory.layout==overlayLayout,let imageSize=lastImageSize,
              selectionEpoch()==memory.epoch else { return }
        guard let host=hostWindowSnapshot(memory.windowID),host.onScreen,
              NSScreen.screens.contains(where:{$0.frame.contains(host.frame)}) else {
            cancelPanelCheck();panelCheckStatus="Background check paused: Lightroom is off-screen or spans displays.";return
        }
        let old=detectionSettings.current
        if let updated=try? detectionSettings.reload(),updated.key != old.key { invalidateAutomaticGeometry();return }
        let interval=detectionSettings.current.panelCheckIntervalSeconds
        guard interval>0 else { nextPanelCheck=ProcessInfo.processInfo.systemUptime+1;panelCheckStatus="Background panel checks disabled (interval 0).";return }
        nextPanelCheck=ProcessInfo.processInfo.systemUptime+interval
        let id=UUID();panelCheckID=id
        let settings=detectionSettings.current
        let started=ProcessInfo.processInfo.systemUptime
        let seed=overlayLayout == .full ? nil:region
        let assisted=assistedPlacementEnabled,module=currentModule()
        panelCheckTask=Task.detached(priority:.utility) { [weak self] in
            let hints=assisted ? Self.screenHints(module:module):nil
            let axElapsed=ProcessInfo.processInfo.systemUptime-started
            let result=await inspectScreenLayout(imageSize:imageSize,settings:settings,layout:memory.layout,seed:seed,maxPixelWidth:1280,axHints:hints)
            guard !Task.isCancelled else { return }
            await self?.finishPanelCheck(result,id:id,memory:memory,elapsed:ProcessInfo.processInfo.systemUptime-started,assisted:assisted,hints:hints,axElapsed:axElapsed)
        }
    }
    @MainActor func finishPanelCheck(_ result:ScreenProbeResult,id:UUID,memory:PlacementMemory,elapsed:TimeInterval,assisted:Bool=false,hints:AXScreenHints?=nil,axElapsed:TimeInterval=0) {
        guard panelCheckID==id else { return };panelCheckID=nil;panelCheckTask=nil
        guard !workspaceOverview,!overlaySuspended,isLightroom(),pending==nil,screenTask==nil,calibration==nil,
              placementMemory?.epoch==memory.epoch,selectionEpoch()==memory.epoch,
              overlayLayout==memory.layout,detectionSettings.current.key==memory.settingsKey,
              let current=currentCaptureWindowFrame(memory.windowID),sameWindowGeometry(current,result.windowFrame) else { return }
        let window=appKitRect(current,primaryHeight:CGDisplayBounds(CGMainDisplayID()).height)
        guard NSScreen.screens.contains(where:{$0.frame.contains(window)}) else {
            panelCheckStatus="Background check paused: Lightroom is off-screen or spans displays.";return
        }
        let expected=memory.translated(window:window,windowID:memory.windowID,epoch:memory.epoch,settingsKey:memory.settingsKey,layout:memory.layout)
        var axChanged=false
        if assisted {
            assistedChecks += 1;assistedCheckSeconds += elapsed;assistedAXSeconds += axElapsed
            if let hints,sameWindowGeometry(hints.host,current) {
                axChanged=assistedSignature != nil && assistedSignature != hints.signature
                if axChanged { assistedAXChanges += 1 }
                if result.uiFrame == nil { assistedPixelFailures += 1 }
                else if assistedSignature == hints.signature && panelBoundsChanged(previous:expected,current:result.uiFrame,tolerance:4) { assistedPixelChanges += 1 }
                assistedSignature=hints.signature
            } else { assistedAXFailures += 1 }
            assistedEvidence="Last comparison: AX changed=\(axChanged); prior=\(String(describing:expected)); screenshot=\(String(describing:result.uiFrame))."
        }
        if axChanged || panelBoundsChanged(previous:expected,current:result.uiFrame,tolerance:4) {
            let reason=result.uiFrame == nil ? "UI boundaries could not be validated":"UI boundaries changed"
            panelCheckStatus="Background check invalidated cached placement (visible overlay retained): \(reason).\nPrevious UI: \(String(describing:expected)); checked UI: \(String(describing:result.uiFrame)).\n"+result.summary
            invalidateAutomaticGeometry()
            if panel != nil { overlayVisibilityStatus="Overlay retained; cached placement invalidated: \(reason.lowercased())." }
        } else { panelCheckStatus="Background check: UI boundaries unchanged. Repeated toggle can skip capture." }
        panelCheckStatus += String(format:" 1280px check: %.0f ms elapsed.",elapsed*1000)
    }
    func checkLiveAXViewIfDue() {
        let now=ProcessInfo.processInfo.systemUptime
        guard automaticViewEnabled,!liveViewBusy,!axMappingInProgress,now>=nextLiveViewCheck,
              isLightroom(),supportedLightroomModule(currentModule()),AXIsProcessTrusted(),
              pending == nil,viewProbeID == nil,screenInspectionID == nil,calibration == nil else { return }
        nextLiveViewCheck=now+2;liveViewBusy=true
        let generation=liveViewGeneration,module=currentModule(),axMode=axPlacementEnabled,checkPanels=axPlacementEnabled && panel != nil
        let detectionSettings=reloadDetectionConfig()
        let fallback=detectionSettings.toolbarUnknownFallback
        let viewSettings=detectionSettings.viewClassificationSettings
        lightroomMonitor.readLiveAX(module:module,axMode:axMode,checkPanels:checkPanels,fallback:fallback,viewSettings:viewSettings) { evidence in
                let grid=evidence.grid,proposal=evidence.proposal,hints=evidence.hints
                self.liveViewBusy=false
                guard self.automaticViewEnabled,self.liveViewGeneration==generation,module==self.currentModule(),
                      self.isLightroom(),self.pending == nil,self.viewProbeID == nil,self.screenInspectionID == nil,self.calibration == nil else { return }
                if let grid { self.lastGridStatus=grid.report }
                if OverlayBehaviourPolicy.isGridSelected(grid?.selected) {
                    if self.panel != nil { self.dismissForGrid() }
                    return
                }
                guard let proposal else { self.lastViewDetection="Live AX read unavailable; retaining previous inferred view.";return }
                let group=proposal.layout == "Side-by-side" ? 1:proposal.layout == "Above-and-below" ? 2:0
                let preferred=CameraPreferences.shared.string(forKey:"axPreferredPane.\(module ?? "develop").\(group)").flatMap(OverlayLayout.init(rawValue:))
                let mode:OverlayLayout=group==0 ? .full:(preferred?.group==group ? preferred!:(group==1 ? .left:.upper))
                if self.detectedLayout != mode || self.detectedLayoutModule != module {
                    self.detectedLayout=mode;self.detectedLayoutModule=module
                    self.lastViewDetection="Live AX: \(proposal.layout); pane: \(mode.label). Updated \(Date()). Poll interval 2 seconds."
                    self.updateLayoutMenu()
                }
                // Compare with displayed geometry as well as the menu. A failed or
                // suspended update can retry on the next poll without rebuilding menus.
                guard axMode,self.axPlacementEnabled else { return }
                let signature=hints?.signature
                let panelsChanged=signature != nil && self.livePanelSignature != nil && self.livePanelSignature != signature
                if self.livePanelSignature == nil { self.livePanelSignature=signature }
                self.followLiveOverlayView(mode,module:module,panelChange:panelsChanged,panelSignature:signature)
        }
    }
    func checkOverlaySelection(_ epoch:String?) {
        guard axPlacementEnabled,CameraPreferences.shared.bool(forKey:regionKey("automaticBounds")),
              let existing=panel,isLightroom(),supportedLightroomModule(currentModule()),
              displayedOverlayModule==currentModule(),let epoch else { return }
        guard let previous=overlayEpoch else { overlayEpoch=epoch;return }
        let action=OverlayBehaviourPolicy.photoSelectionChange(accessibility:true,automatic:true,overlayOpen:true,previous:previous,current:epoch,live:axLiveUpdate)
        if action == .dismiss {
            cancelScreenInspection();hide();report("Photo selection changed; overlay dismissed.");return
        }
        guard action == .adjust,attemptedSelectionRefresh != epoch,
              existing.isVisible,!overlaySuspended,!workspaceOverview,
              pending == nil,screenInspectionID == nil,viewProbeID == nil,calibration == nil,!liveViewBusy else { return }
        // One attempt per selection; failure keeps the old photo without retry storms.
        attemptedSelectionRefresh=epoch
        request(.overlay,viewChecked:true,refreshing:existing)
    }
}
