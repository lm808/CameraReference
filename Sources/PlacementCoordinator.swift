import AppKit
import ApplicationServices

// Placement orchestration shares composition-owned operation/cancellation state.
// Request and presentation state have independent owners; no second event queue.
// Manual precedence, cache eligibility, permissions and completion guards stay
// here; concrete implementations below own only their calculation/read boundary.
extension AppDelegate {
    func calibratedUI(_ mode:OverlayLayout)->CGRect? {
        guard let text=CameraPreferences.shared.string(forKey:regionKey("region",layout:mode)) else { return nil }
        let rect=NSRectFromString(text)
        let display=CameraPreferences.shared.data(forKey:regionKey("regionDisplay",layout:mode)).flatMap { try? JSONDecoder().decode(DisplayGeometry.self,from:$0) }
        guard calibratedRegionIsUsable(rect,savedDisplay:display,current:currentDisplays()),
              let saved=CameraPreferences.shared.string(forKey:regionKey("regionWindow",layout:mode)),let window=lightroomWindowFrame(),
              let translated=ManualPlacement.translate(rect,from:NSRectFromString(saved),to:window)?.areaAppKit,window.contains(translated),
              NSScreen.screens.contains(where:{$0.frame.contains(translated)}) else { return nil }
        return translated
    }
    func cachedUI(epoch:String?,settings:DetectionConfig,layout:OverlayLayout)->CGRect? {
        guard placementModule==currentModule(),let memory=placementMemory,let current=lightroomWindowFrame(),
              let cg=currentCaptureWindowFrame(memory.windowID),sameWindowGeometry(current,appKitRect(cg,primaryHeight:CGDisplayBounds(CGMainDisplayID()).height)),
              let ui=memory.translated(window:current,windowID:memory.windowID,epoch:epoch,settingsKey:settings.key,layout:layout,expandedReuse:expandedScreenshotReuse,module:currentModule()),
              NSScreen.screens.contains(where:{$0.frame.intersects(ui)}) else { return nil }
        lastTiming += "; placement cache hit; capture skipped"
        lastLayout="Reused \(layout.label) UI bounds (AppKit): \(ui). Window size unchanged; position translated. Expanded working-area reuse: \(expandedScreenshotReuse). Clear overlay region setting forces fresh detection."
        return ui
    }
    func rememberPlacement(_ result:ScreenProbeResult,epoch:String?,settings:DetectionConfig,layout:OverlayLayout) {
        guard let ui=result.uiFrame,let window=result.windowFrame,let id=result.windowID,let epoch else { return }
        placementModule=currentModule()
        placementMemory=PlacementMemory(ui:ui,window:appKitRect(window,primaryHeight:CGDisplayBounds(CGMainDisplayID()).height),windowID:id,epoch:epoch,settingsKey:settings.key,layout:layout,background:result.background)
    }
    func showUI(_ image:CGImage,ui:CGRect,snapshot:ExportSnapshot?,settings:DetectionConfig) {
        let height=CGDisplayBounds(CGMainDisplayID()).height
        guard let placed=settings.placement(ui:appKitRect(ui,primaryHeight:height),image:CGSize(width:image.width,height:image.height)) else { return }
        if let view=display(image,in:appKitRect(placed.region,primaryHeight:height),photoFrame:appKitRect(placed.photo,primaryHeight:height)) {
            view.exportSnapshot=snapshot
            if let b=placementMemory?.background { view.backgroundColour=NSColor(srgbRed:b[0],green:b[1],blue:b[2],alpha:1) }
        }
    }
    func resolveFloating(_ loaded:LoadedReference,snapshot:ExportSnapshot?,epoch:String?) {
        let settings=reloadDetectionConfig()
        let imageSize=CGSize(width:loaded.image.width,height:loaded.image.height)
        func show(_ ui:CGRect) {
            guard let size=floatingPhotoSize(viewport:ui.size,image:imageSize,settings:settings),size.width>0,size.height>0 else { report("UI working area is too small for floating placement.");return }
            displayFloating(loaded.image,origin:loaded.origin,filename:loaded.sourceFilename,area:ui,photoSize:size)
            floatingView?.exportSnapshot=snapshot
        }
        if !CameraPreferences.shared.bool(forKey:regionKey("automaticBounds")) {
            if let full=calibratedUI(.full) { show(full);return }
            if let pane=region,overlayLayout != .full {
                // A calibrated split pane supplies an approximate full working area.
                let full=overlayLayout.group==1 ? CGRect(x:pane.minX,y:pane.minY,width:pane.width*2,height:pane.height):CGRect(x:pane.minX,y:pane.minY,width:pane.width,height:pane.height*2)
                show(full);return
            }
            askForCalibration();return
        }
        if placementBackend(automatic:true,axOnly:axPlacementEnabled) == .accessibility {
            startAXPlacement(epoch:epoch,full:true) { [weak self] ui in
                guard let self else { return }
                if let ui { show(ui) } else { self.askForCalibration(reason:"AX placement unavailable. No screenshot fallback was used.") }
            };return
        }
        if let ui=cachedUI(epoch:epoch,settings:settings,layout:.full) { show(ui);return }
        guard supportedLightroomModule(currentModule()),#available(macOS 14.0,*),FeaturePermission.screenCapture.ensure() else { report("Screenshot sizing unavailable. Screen Recording permission and macOS 14 are required. Use AX placement or manual calibration.");return }
        startPhotoDetection(imageSize:imageSize,layout:.full) { [weak self] probe in
            guard let self else { return }
            if let epoch,self.selectionEpoch() != epoch { self.report("Selection changed during capture; invoke again.");return }
            guard let placement=UIPlacement(probe:probe) else { self.askForCalibration(workingAreaTooNarrow:probe.workingAreaTooNarrow);return }
            self.rememberPlacement(probe,epoch:epoch,settings:settings,layout:.full)
            show(placement.areaAppKit)
        }
    }
    func displayManual(_ image:CGImage,in area:CGRect,snapshot:ExportSnapshot?) {
        if CameraPreferences.shared.string(forKey:regionKey("regionKind")) == "ui" {
            let settings=reloadDetectionConfig()
            // placement uses top-left coordinates, even though calibration is AppKit.
            let topLeft=appKitRect(area,primaryHeight:CGDisplayBounds(CGMainDisplayID()).height)
            guard let placed=settings.placement(ui:topLeft,image:CGSize(width:image.width,height:image.height)) else { report("Calibration is too small for the configured Fit inset.");return }
            let region=appKitRect(placed.region,primaryHeight:CGDisplayBounds(CGMainDisplayID()).height)
            let photo=appKitRect(placed.photo,primaryHeight:CGDisplayBounds(CGMainDisplayID()).height)
            display(image,in:region,photoFrame:photo)?.exportSnapshot=snapshot
        } else {
            report("Please recalibrate: select the entire UI working area between the panels.")
            beginCalibration(useManualOnAccept:true)
        }
    }
    func resolveOverlay(_ image:CGImage,snapshot:ExportSnapshot?,selectionEpoch expectedEpoch:String? = nil) {
        let settings=reloadDetectionConfig()
        guard CameraPreferences.shared.bool(forKey:regionKey("automaticBounds")) else {
            if let area=region { displayManual(image,in:area,snapshot:snapshot) }
            else { askForCalibration() }; return
        }
        if placementBackend(automatic:true,axOnly:axPlacementEnabled) == .accessibility {
            startAXPlacement(epoch:expectedEpoch,full:false) { [weak self] ui in
                guard let self else { return }
                guard let ui else { self.askForCalibration(reason:"AX placement unavailable. No screenshot fallback was used.");return }
                self.showUI(image,ui:ui,snapshot:snapshot,settings:settings)
            };return
        }
        if let ui=cachedUI(epoch:expectedEpoch,settings:settings,layout:overlayLayout) {
            showUI(image,ui:ui,snapshot:snapshot,settings:settings)
            return
        }
        guard #available(macOS 14.0,*), FeaturePermission.screenCapture.ensure() else {
            report("Screenshot detection unavailable: Screen Recording permission and macOS 14 are required. Use AX placement or manual calibration."); return
        }
        startPhotoDetection(imageSize:CGSize(width:image.width,height:image.height)) { [weak self] result in
            guard let self, self.isLightroom(), supportedLightroomModule(self.currentModule()) else { return }
            if let expectedEpoch,self.selectionEpoch() != expectedEpoch { self.imageCache.observe(self.selectionEpoch());self.report("Selection changed during capture; invoke again.");return }
            guard let area=result.candidate else { self.askForCalibration(workingAreaTooNarrow:result.workingAreaTooNarrow,reason:result.placementUnavailableReason); return }
            self.rememberPlacement(result,epoch:expectedEpoch,settings:settings,layout:self.overlayLayout)
            guard let view=self.display(image,in:area,photoFrame:result.photoFrame) else { return }
            view.exportSnapshot=snapshot
            view.backgroundColour=NSColor(srgbRed:result.background[0],green:result.background[1],blue:result.background[2],alpha:1)
            self.report("Reference shown using UI viewing-area bounds.")
        }
    }
    func startAXPlacement(epoch:String?,full:Bool,completion:@escaping(CGRect?)->Void) {
        guard axPlacementEnabled, supportedLightroomModule(currentModule()),FeaturePermission.accessibility.ensure() else { completion(nil);return }
        cancelScreenInspection();cancelPanelCheck()
        let id=UUID(),module=currentModule(),settings=reloadDetectionConfig(),mode=overlayLayout
        let autoView=automaticViewEnabled,height=CGDisplayBounds(CGMainDisplayID()).height
        let started=ProcessInfo.processInfo.systemUptime
        screenInspectionID=id;screenModule=module;detectionCompletion={ _ in };updateToggleTitle()
        screenTask=Task.detached(priority:.userInitiated) { [weak self] in
            let toolbar=accessibilityToolbarReading(fallback:settings.toolbarUnknownFallback,module:module)
            var adjusted=settings;adjusted.axToolbarState=toolbar.effectiveState
            var proposal:AXTrialProposal?,signature:String?
            let mapping=accessibilityMappingReport { host,windows,fullScreen in
                proposal=axTrialProposal(host:host,windows:windows,settings:adjusted,module:module,fullScreen:fullScreen)
                signature=AXPanelState(host:host,visibleFrames:windows.filter(\.visible).map(\.frame),toolbar:toolbar.effectiveState)?.signature
            }
            guard !Task.isCancelled,let owner=self else { return }
            let resultProposal=proposal,resultSignature=signature
            await MainActor.run {
                let proposal=resultProposal
                guard owner.screenInspectionID==id else { return }
                owner.screenInspectionID=nil;owner.screenTask=nil;owner.detectionCompletion=nil;owner.updateToggleTitle()
                guard owner.axPlacementEnabled,owner.currentModule()==module,owner.isLightroom(),
                      CameraPreferences.shared.bool(forKey:owner.regionKey("automaticBounds")),epoch==owner.selectionEpoch() else {
                    owner.report("AX placement cancelled: selection, module or mode changed.");return
                }
                owner.lastAXMapping=displayMappingReport()+"\n\n"+mapping;owner.lastAXToolbar=toolbar.report
                owner.lastAXTrial=proposal?.summary ?? "AX geometry unavailable."
                owner.lastLayout="AX-only placement; no screen capture; no placement cache.\n"+owner.lastAXTrial+"\n"+toolbar.report
                owner.lastTiming += String(format:"; AX placement %.0f ms; capture skipped",(ProcessInfo.processInfo.systemUptime-started)*1000)
                guard let proposal,let current=lightroomWindowFrame(),axTrialHostMatches(proposedTopLeft:proposal.host,actualAppKit:current,primaryHeight:height) else {
                    owner.lastLayout += "\nHost unavailable or changed during AX read.";completion(nil);return
                }
                var selected=mode
                if autoView && !full {
                    let group=proposal.layout == "Side-by-side" ? 1:proposal.layout == "Above-and-below" ? 2:0
                    let preference=CameraPreferences.shared.string(forKey:"axPreferredPane.\(module ?? "develop").\(group)").flatMap(OverlayLayout.init(rawValue:))
                    selected=group==0 ? .full:(preference?.group==group ? preference!:(group==1 ? .left:.upper))
                    if owner.lightroomMonitor.detectedLayout != selected || owner.lightroomMonitor.detectedLayoutModule != module {
                        owner.lightroomMonitor.detectedLayout=selected;owner.lightroomMonitor.detectedLayoutModule=module;owner.updateLayoutMenu()
                    }
                }
                guard let placement=AXPlacement.selectedArea(proposal,layout:full ? .full:selected,primaryHeight:height) else {
                    owner.lastLayout += "\nSelected layout does not match AX labels.";completion(nil);return
                }
                owner.lastLayout += "\nSelected AX UI (top-left): \(placement.topLeft)."
                if !full { owner.pendingAXPanelSignature=resultSignature }
                completion(placement.placement.areaAppKit)
            }
        }
    }
    func startPhotoDetection(imageSize:CGSize,previewCapture:Bool=false,layout requestedLayout:OverlayLayout? = nil,completion:((ScreenProbeResult)->Void)? = nil) {
        guard #available(macOS 14.0, *), supportedLightroomModule(currentModule()) else { report("Detection cancelled: Library or Develop is no longer active."); return }
        cancelPanelCheck()
        if previewCapture { lastTiming="" }
        let settings=reloadDetectionConfig()
        let mode=requestedLayout ?? overlayLayout
        cancelScreenInspection()
        report("Finding the Lightroom viewing area…")
        detectionCompletion=completion
        let inspectionID=UUID(); screenInspectionID=inspectionID;screenModule=currentModule()
        let inspectionStarted=ProcessInfo.processInfo.systemUptime
        lastLayout="Current inspection started \(Date()); awaiting capture result."
        updateToggleTitle()
        screenTimeout=Timer(timeInterval:12,repeats:false) { [weak self] _ in
            guard let self,self.screenInspectionID==inspectionID else { return }
            let callback=self.detectionCompletion
            self.cancelScreenInspection()
            let result=ScreenProbeResult(candidate:nil,summary:"Screen capture timed out. Retry Find viewing area, or use manual calibration.")
            self.lastLayout=result.summary;self.report(result.summary); callback?(result)
        }
        RunLoop.main.add(screenTimeout!,forMode:.common)
        let expandedReuse=expandedScreenshotReuse
        screenTask=Task.detached(priority:.userInitiated) { [weak self] in
            let result=await ScreenshotPlacement.inspect(imageSize:imageSize,previewCapture:previewCapture,settings:settings,layout:mode,reuseOuterBoundsForSplits:expandedReuse)
            guard !Task.isCancelled else { return }
            await self?.finishScreenInspection(result,id:inspectionID,elapsed:ProcessInfo.processInfo.systemUptime-inspectionStarted)
        }
    }
    func cancelScreenInspection() {
        let wasRunning=screenInspectionID != nil
        screenTask?.cancel(); screenTask=nil; screenInspectionID=nil
        screenTimeout?.invalidate(); screenTimeout=nil; detectionCompletion=nil
        updateToggleTitle()
        if wasRunning { report("Screen inspection cancelled.") }
    }
    @MainActor func finishScreenInspection(_ result:ScreenProbeResult,id:UUID,elapsed:TimeInterval) {
        guard screenInspectionID==id else { return }
        lastTiming += (lastTiming.isEmpty ? "":"; ") + String(format:"capture and detection %.0f ms",elapsed*1000)
        let callback=detectionCompletion
        screenInspectionID=nil; screenTask=nil; screenTimeout?.invalidate(); screenTimeout=nil; detectionCompletion=nil
        updateToggleTitle()
        guard supportedLightroomModule(currentModule()),screenModule==currentModule() else { report("Module changed; detection cancelled. Invoke again in Library or Develop."); return }
        if result.geometryChanged { report(result.summary);lastLayout=result.summary;return }
        if result.previewImage == nil,let windowID=result.windowID, !sameWindowGeometry(result.windowFrame,currentCaptureWindowFrame(windowID)) {
            invalidateAutomaticGeometry();lastLayout=result.summary+"\nRejected before display: Lightroom window geometry changed.";report(lastLayout);return
        }
        if result.previewImage == nil { lastProbe=result }; lastLayout=result.summary; report(result.summary)
        if let callback { callback(result); return }
        let alert=NSAlert();alert.icon=NSApp.applicationIconImage; alert.messageText="Viewing area detection"; alert.informativeText=result.summary
        if result.candidate != nil { alert.addButton(withTitle:"Preview region…") }
        alert.addButton(withTitle:"Close")
        NSApp.activate(ignoringOtherApps:true)
        let response=alert.runModal()
        if let candidate=result.candidate, response == .alertFirstButtonReturn { beginCalibration(proposal:candidate) }
    }
}
