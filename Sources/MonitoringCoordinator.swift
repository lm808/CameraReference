import AppKit
import ApplicationServices

// Applies existing policy/actions to synchronous monitor signals and asynchronous
// evidence. Guard/read/effect order is intentional; do not eagerly snapshot reads.
extension AppDelegate {
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
            if let memory=self.placementMemory,(!self.expandedScreenshotReuse && memory.epoch != epoch) || !supportedLightroomModule(module) { self.placementMemory=nil }
            if OverlayBehaviourPolicy.moduleChanged(previous:self.lightroomMonitor.observedModule,current:module) {
                self.hide();self.cancelRequest();self.cancelScreenInspection()
                self.calibration?.finish(nil);self.calibrationTask?.cancel()
                self.invalidateAutomaticGeometry()
                self.updateLayoutMenu()
                self.autoItem?.state=CameraPreferences.shared.bool(forKey:self.regionKey("automaticBounds")) ? .on:.off
            }
            if let module {
                if self.lightroomMonitor.observedModule == nil {
                    self.updateLayoutMenu()
                    self.autoItem?.state=CameraPreferences.shared.bool(forKey:self.regionKey("automaticBounds")) ? .on:.off
                }
                self.lightroomMonitor.observedModule=module
            }
            self.lightroomMonitor.workspaceOverview=(self.panel != nil || self.placementMemory != nil) && workspaceOverviewIsVisible()
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
        defer { lightroomMonitor.observedWindowFrame=current;lightroomMonitor.hasObservedWindow=true }
        if panel != nil { reconcileOverlayHost();return }
        guard lightroomMonitor.hasObservedWindow else { return }
        if current == nil && lightroomMonitor.observedWindowFrame == nil { return }
        if expandedScreenshotReuse,let current,let previous=lightroomMonitor.observedWindowFrame,
           abs(current.width-previous.width)<0.5,abs(current.height-previous.height)<0.5 { return }
        if !sameWindowGeometry(current,lightroomMonitor.observedWindowFrame) { invalidateAutomaticGeometry() }
    }
    @objc func spaceChanged() {
        suspendOverlay();cancelScreenInspection();lastProbe=nil
        Task { await ScreenGeometryCache.shared.reset() }
        lightroomMonitor.hasObservedWindow=false
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
    func cancelPanelCheck() { lightroomMonitor.panelCheckTask?.cancel();lightroomMonitor.panelCheckTask=nil;lightroomMonitor.panelCheckID=nil }
    func checkPanelBoundariesIfDue() {
        guard !axPlacementEnabled else { cancelPanelCheck();lightroomMonitor.panelCheckStatus="AX-only mode: background screenshot checks disabled; fresh AX geometry on invocation.";return }
        guard FeaturePermission.screenCapture.granted else { cancelPanelCheck();lightroomMonitor.panelCheckStatus="Background capture paused: Screen Recording permission unavailable.";return }
        guard #available(macOS 14.0,*),ProcessInfo.processInfo.systemUptime>=lightroomMonitor.nextPanelCheck,
              lightroomMonitor.panelCheckTask==nil,screenTask==nil,pending==nil,calibration==nil,!recording,!regionResetting,
              !lightroomMonitor.workspaceOverview,!overlayController.overlaySuspended,isLightroom(),supportedLightroomModule(currentModule()),CameraPreferences.shared.bool(forKey:regionKey("automaticBounds")),
              let memory=placementMemory,memory.supportsLayout(overlayLayout,module:currentModule(),expandedReuse:expandedScreenshotReuse),let imageSize=lastImageSize,
              let observedEpoch=selectionEpoch(),(expandedScreenshotReuse || observedEpoch==memory.epoch) else { return }
        guard let host=hostWindowSnapshot(memory.windowID),host.onScreen,
              NSScreen.screens.contains(where:{$0.frame.contains(host.frame)}) else {
            cancelPanelCheck();lightroomMonitor.panelCheckStatus="Background check paused: Lightroom is off-screen or spans displays.";return
        }
        let old=detectionSettings.current
        if let updated=try? detectionSettings.reload(),updated.key != old.key { invalidateAutomaticGeometry();return }
        let interval=detectionSettings.current.panelCheckIntervalSeconds
        guard interval>0 else { lightroomMonitor.nextPanelCheck=ProcessInfo.processInfo.systemUptime+1;lightroomMonitor.panelCheckStatus="Background panel checks disabled (interval 0).";return }
        lightroomMonitor.nextPanelCheck=ProcessInfo.processInfo.systemUptime+interval
        let id=UUID();lightroomMonitor.panelCheckID=id
        let settings=detectionSettings.current
        let started=ProcessInfo.processInfo.systemUptime
        let expandedReuse=expandedScreenshotReuse
        lightroomMonitor.panelCheckTask=Task.detached(priority:.utility) { [weak self] in
            let result=await inspectScreenLayout(imageSize:imageSize,settings:settings,layout:memory.layout,maxPixelWidth:1280,reuseOuterBoundsForSplits:expandedReuse)
            guard !Task.isCancelled else { return }
            await self?.finishPanelCheck(result,id:id,memory:memory,observedEpoch:observedEpoch,expandedReuse:expandedReuse,elapsed:ProcessInfo.processInfo.systemUptime-started)
        }
    }
    @MainActor func finishPanelCheck(_ result:ScreenProbeResult,id:UUID,memory:PlacementMemory,observedEpoch:String,expandedReuse:Bool,elapsed:TimeInterval) {
        guard lightroomMonitor.panelCheckID==id else { return };lightroomMonitor.panelCheckID=nil;lightroomMonitor.panelCheckTask=nil
        guard !lightroomMonitor.workspaceOverview,!overlayController.overlaySuspended,isLightroom(),pending==nil,screenTask==nil,calibration==nil,
              placementMemory==memory,selectionEpoch()==observedEpoch,expandedScreenshotReuse==expandedReuse,
              memory.supportsLayout(overlayLayout,module:currentModule(),expandedReuse:expandedReuse),detectionSettings.current.key==memory.settingsKey,
              let current=currentCaptureWindowFrame(memory.windowID),sameWindowGeometry(current,result.windowFrame) else { return }
        let window=appKitRect(current,primaryHeight:CGDisplayBounds(CGMainDisplayID()).height)
        guard NSScreen.screens.contains(where:{$0.frame.contains(window)}) else {
            lightroomMonitor.panelCheckStatus="Background check paused: Lightroom is off-screen or spans displays.";return
        }
        let expected=memory.translated(window:window,windowID:memory.windowID,epoch:memory.epoch,settingsKey:memory.settingsKey,layout:memory.layout)
        if panelBoundsChanged(previous:expected,current:result.uiFrame,tolerance:4) {
            let reason=result.uiFrame == nil ? "UI boundaries could not be validated":"UI boundaries changed"
            lightroomMonitor.panelCheckStatus="Background check invalidated cached placement (visible overlay retained): \(reason).\nPrevious UI: \(String(describing:expected)); checked UI: \(String(describing:result.uiFrame)).\n"+result.summary
            invalidateAutomaticGeometry()
            if panel != nil { overlayController.overlayVisibilityStatus="Overlay retained; cached placement invalidated: \(reason.lowercased())." }
        } else { lightroomMonitor.panelCheckStatus="Background check: UI boundaries unchanged. Repeated toggle can skip capture." }
        lightroomMonitor.panelCheckStatus += String(format:" 1280px check: %.0f ms elapsed.",elapsed*1000)
    }
    func checkLiveAXViewIfDue() {
        let now=ProcessInfo.processInfo.systemUptime
        guard automaticViewEnabled,!lightroomMonitor.liveViewBusy,!axMappingInProgress,now>=lightroomMonitor.nextLiveViewCheck,
              isLightroom(),supportedLightroomModule(currentModule()),AXIsProcessTrusted(),
              pending == nil,viewProbeID == nil,screenInspectionID == nil,calibration == nil else { return }
        lightroomMonitor.nextLiveViewCheck=now+2;lightroomMonitor.liveViewBusy=true
        let screenshotPolicy=screenshotAXDismissEnabled && CameraPreferences.shared.bool(forKey:regionKey("automaticBounds"))
        let observedPanel=panel,observedHost=overlayController.overlayHost?.id,backend=automaticPlacementMode
        let generation=lightroomMonitor.liveViewGeneration,module=currentModule(),axMode=axPlacementEnabled,checkPanels=(axPlacementEnabled || screenshotPolicy) && panel != nil
        let detectionSettings=reloadDetectionConfig()
        let fallback=detectionSettings.toolbarUnknownFallback
        let viewSettings=detectionSettings.viewClassificationSettings
        lightroomMonitor.readLiveAX(module:module,axMode:axMode,checkPanels:checkPanels,checkGrid:screenshotPolicy,fallback:fallback,viewSettings:viewSettings) { evidence in
                let grid=evidence.grid,proposal=evidence.proposal,hints=evidence.hints
                self.lightroomMonitor.liveViewBusy=false
                guard self.automaticViewEnabled,self.lightroomMonitor.liveViewGeneration==generation,module==self.currentModule(),
                      self.isLightroom(),self.pending == nil,self.viewProbeID == nil,self.screenInspectionID == nil,self.calibration == nil else { return }
                // A read started for an old overlay must not dismiss a replacement.
                let currentScreenshotObservation=screenshotPolicy && self.screenshotAXDismissEnabled &&
                    self.automaticPlacementMode==backend && observedPanel != nil && self.panel === observedPanel &&
                    self.overlayController.overlayHost?.id==observedHost &&
                    CameraPreferences.shared.bool(forKey:self.regionKey("automaticBounds"))
                if let grid { self.lastGridStatus=grid.report }
                if OverlayBehaviourPolicy.isGridSelected(grid?.selected) {
                    if self.panel != nil && (axMode || currentScreenshotObservation) { self.dismissForGrid() }
                    return
                }
                guard let proposal else { self.lastViewDetection="Live AX read unavailable; retaining previous inferred view.";return }
                let group=proposal.layout == "Side-by-side" ? 1:proposal.layout == "Above-and-below" ? 2:0
                let preferred=CameraPreferences.shared.string(forKey:"axPreferredPane.\(module ?? "develop").\(group)").flatMap(OverlayLayout.init(rawValue:))
                let mode:OverlayLayout=group==0 ? .full:(preferred?.group==group ? preferred!:(group==1 ? .left:.upper))
                if self.lightroomMonitor.detectedLayout != mode || self.lightroomMonitor.detectedLayoutModule != module {
                    self.lightroomMonitor.detectedLayout=mode;self.lightroomMonitor.detectedLayoutModule=module
                    self.lastViewDetection="Live AX: \(proposal.layout); pane: \(mode.label). Updated \(Date()). Poll interval 2 seconds."
                    self.updateLayoutMenu()
                }
                // Compare with displayed geometry as well as the menu. A failed or
                // suspended update can retry on the next poll without rebuilding menus.
                if !axMode {
                    guard currentScreenshotObservation,
                          let host=self.overlayController.overlayHost,
                          axTrialHostMatches(proposedTopLeft:proposal.host,actualAppKit:host.frame,primaryHeight:CGDisplayBounds(CGMainDisplayID()).height) else { return }
                } else { guard self.axPlacementEnabled else { return } }
                let signature=hints?.signature
                let panelsChanged=signature != nil && self.overlayController.livePanelSignature != nil && self.overlayController.livePanelSignature != signature
                if self.overlayController.livePanelSignature == nil { self.overlayController.livePanelSignature=signature }
                self.followLiveOverlayView(mode,module:module,panelChange:panelsChanged,panelSignature:signature)
        }
    }
    func checkOverlaySelection(_ epoch:String?) {
        guard (axPlacementEnabled || screenshotDetectionEnabled),CameraPreferences.shared.bool(forKey:regionKey("automaticBounds")),
              let existing=panel,isLightroom(),supportedLightroomModule(currentModule()),
              overlayController.displayedOverlayModule==currentModule(),let epoch else { return }
        guard let previous=overlayController.overlayEpoch else { overlayController.overlayEpoch=epoch;return }
        let action=OverlayBehaviourPolicy.photoSelectionChange(accessibility:axPlacementEnabled,automatic:true,overlayOpen:true,previous:previous,current:epoch,live:axLiveUpdate,screenshot:screenshotDetectionEnabled)
        if action == .dismiss {
            cancelScreenInspection();hide();report("Photo selection changed; overlay dismissed.");return
        }
        guard action == .adjust,overlayController.attemptedSelectionRefresh != epoch,
              existing.isVisible,!overlayController.overlaySuspended,!lightroomMonitor.workspaceOverview,
              pending == nil,screenInspectionID == nil,viewProbeID == nil,calibration == nil,!lightroomMonitor.liveViewBusy else { return }
        // One attempt per selection; failure keeps the old photo without retry storms.
        overlayController.attemptedSelectionRefresh=epoch
        request(.overlay,viewChecked:true,refreshing:existing)
    }
}
