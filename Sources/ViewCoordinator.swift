import AppKit
import ApplicationServices

// App-facing actions grouped by responsibility. Existing guard, callback and
// effect order is preserved; shared operation identities belong to composition.
extension AppDelegate {
    var screenshotAXDismissEnabled:Bool { screenshotDetectionEnabled && automaticViewEnabled }

    @objc func toggleAXLiveUpdate(_ item:NSMenuItem) {
        guard axPlacementEnabled else { return }
        CameraPreferences.shared.set(!axLiveUpdate,forKey:"axLiveUpdate")
        lightroomMonitor.liveViewGeneration += 1;lightroomMonitor.nextLiveViewCheck=0
        item.state=axLiveUpdate ? .on:.off
    }
    func dismissForGrid() {
        cancelScreenInspection();cancelRequest();hide()
        lastViewDetection="Grid View selected; overlay off. Returning to Loupe does not reopen it."
        report(lastViewDetection);saveInvocationDiagnostics()
    }
    @objc func selectLayout(_ sender:NSMenuItem) {
        guard let raw=sender.representedObject as? String,let mode=OverlayLayout(rawValue:raw),mode != overlayLayout else { return }
        if automaticViewEnabled && (mode.group==0 || mode.group != overlayLayout.group) { return }
        cancelScreenInspection();cancelRequest();calibration?.finish(nil)
        if OverlayBehaviourPolicy.dismissForExplicitSelection(screenshot:screenshotDetectionEnabled) { hide() }
        if automaticViewEnabled {
            CameraPreferences.shared.set(mode.rawValue,forKey:"axPreferredPane.\(currentModule() ?? "develop").\(mode.group)")
            lightroomMonitor.detectedLayout=mode
        } else { overlayLayout=mode }
        CameraPreferences.shared.set(true,forKey:regionKey("automaticBounds"))
        invalidateAutomaticGeometry();updateLayoutMenu()
        autoItem.state=CameraPreferences.shared.bool(forKey:regionKey("automaticBounds")) ? .on:.off
        report(mode == .full ? "Loupe View selected.":"\(mode.label) pane selected.")
        followLiveOverlayView(mode,module:currentModule(),requiresViewDetection:false)
    }
    func refreshAXSelection(_ image:CGImage,snapshot:ExportSnapshot?,epoch:String,panel existing:OverlayPanel,generation:Int) {
        let module=currentModule(),host=overlayController.overlayHost?.id,settings=reloadDetectionConfig()
        let height=CGDisplayBounds(CGMainDisplayID()).height
        startAXPlacement(epoch:epoch,full:false) { [weak self] ui in
            guard let self,self.panel === existing,self.axPlacementEnabled,self.axLiveUpdate,
                  self.lightroomMonitor.liveViewGeneration==generation,self.selectionEpoch()==epoch,
                  self.currentModule()==module,self.overlayController.overlayHost?.id==host,
                  self.isLightroom(),existing.isVisible,!self.overlayController.overlaySuspended,
                  CameraPreferences.shared.bool(forKey:self.regionKey("automaticBounds")),
                  let view=existing.contentView as? ReferenceView else { return }
            guard let ui,let placed=settings.placement(ui:appKitRect(ui,primaryHeight:height),image:CGSize(width:image.width,height:image.height)) else {
                self.report("Photo refresh placement unavailable; previous overlay retained.");return
            }
            let area=appKitRect(placed.region,primaryHeight:height),photo=appKitRect(placed.photo,primaryHeight:height)
            guard NSScreen.screens.contains(where:{$0.frame.intersects(area)}) else { return }
            existing.setFrame(area.insetBy(dx:-1,dy:-1),display:false)
            view.imageViewport=view.convert(existing.convertFromScreen(photo),from:nil)
            view.image=NSImage(cgImage:image,size:NSSize(width:image.width,height:image.height))
            view.exportSnapshot=snapshot
            self.overlayController.overlayEpoch=epoch;self.overlayController.livePanelSignature=self.pendingAXPanelSignature
            self.overlayController.displayedOverlayLayout=self.overlayLayout
            self.recordLifecycle("photo selection refreshed; Fit reset")
            self.clearAXTrialBorders();self.runAXTrial(after:existing);self.saveInvocationDiagnostics()
        }
    }
    @objc func toggleAutomaticView(_ item:NSMenuItem) {
        guard screenshotDetectionEnabled else { return }
        if !automaticViewEnabled && !FeaturePermission.accessibility.ensure() { return }
        cancelRequest();cancelScreenInspection()
        CameraPreferences.shared.set(!automaticViewEnabled,forKey:"experimentalAutomaticView")
        lightroomMonitor.liveViewGeneration += 1;lightroomMonitor.nextLiveViewCheck=0
        lightroomMonitor.detectedLayout=nil;lightroomMonitor.detectedLayoutModule=nil
        overlayController.livePanelSignature=nil;lightroomMonitor.invocationPanelHints=nil
        item.state=automaticViewEnabled ? .on:.off
        lastViewDetection=automaticViewEnabled ? "Enabled; AX view checked every 2 seconds while Lightroom is active.":"Disabled; using saved menu selection."
        invalidateAutomaticGeometry();updateLayoutMenu();report(lastViewDetection)
    }
    func followLiveOverlayView(_ mode:OverlayLayout,module:String?,requiresViewDetection:Bool=true,panelChange:Bool=false,panelSignature:String?=nil) {
        guard (axPlacementEnabled || screenshotAXDismissEnabled),(!requiresViewDetection || automaticViewEnabled),CameraPreferences.shared.bool(forKey:regionKey("automaticBounds")),
              let module,module==overlayController.displayedOverlayModule,(overlayController.displayedOverlayLayout != mode || panelChange),
              let existing=panel else { return }
        if OverlayBehaviourPolicy.geometryChange(accessibility:axPlacementEnabled,automatic:true,displayed:overlayController.displayedOverlayLayout,selected:mode,panelsChanged:panelChange,live:axLiveUpdate,screenshotAXDetection:screenshotAXDismissEnabled) == .dismiss {
            cancelScreenInspection();cancelRequest();hide()
            report("View, pane or panels changed; overlay dismissed.");return
        }
        guard existing.isVisible,!overlayController.overlaySuspended,
              let view=existing.contentView as? ReferenceView,let image=view.image,
              let host=overlayController.overlayHost else { return }
        let backend=automaticPlacementMode,epoch=selectionEpoch(),generation=lightroomMonitor.liveViewGeneration
        let settings=reloadDetectionConfig(),height=CGDisplayBounds(CGMainDisplayID()).height
        func stillCurrent()->Bool {
            self.panel === existing && existing.isVisible && !self.overlayController.overlaySuspended &&
            (!requiresViewDetection || self.automaticViewEnabled) && self.automaticPlacementMode==backend &&
            CameraPreferences.shared.bool(forKey:self.regionKey("automaticBounds")) &&
            self.currentModule()==module && self.overlayController.displayedOverlayModule==module &&
            self.overlayLayout==mode && self.lightroomMonitor.liveViewGeneration==generation &&
            self.selectionEpoch()==epoch && self.overlayController.overlayHost?.id==host.id && self.isLightroom() &&
            self.axLiveUpdate
        }
        func apply(_ area:CGRect,_ photo:CGRect,_ background:NSColor?) {
            guard stillCurrent(),NSScreen.screens.contains(where:{$0.frame.intersects(area)}) else { return }
            // Keep the same panel, image and export snapshot. No hide/order/reload.
            let frame=area.insetBy(dx:-1,dy:-1)
            if existing.frame != frame { existing.setFrame(frame,display:false) }
            view.imageViewport=view.convert(existing.convertFromScreen(photo),from:nil)
            if let background { view.backgroundColour=background }
            view.needsDisplay=true
            self.overlayController.displayedOverlayLayout=mode;self.lastImageSize=image.size
            self.overlayController.livePanelSignature=self.pendingAXPanelSignature ?? panelSignature
            self.lastLayout += "\nVisible overlay updated (panel change: \(panelChange)): \(mode.viewName), \(mode.label). Same image and zoom retained."
            self.recordLifecycle("view changed: \(mode.viewName), \(mode.label)")
            self.clearAXTrialBorders();self.runAXTrial(after:existing)
            self.saveInvocationDiagnostics()
        }
        if axPlacementEnabled {
            startAXPlacement(epoch:epoch,full:false) { ui in
                guard stillCurrent(),let ui,
                      let placed=settings.placement(ui:appKitRect(ui,primaryHeight:height),image:image.size) else { return }
                apply(appKitRect(placed.region,primaryHeight:height),appKitRect(placed.photo,primaryHeight:height),nil)
            }
        }
    }
    func detectInvocationView() {
        cancelRequest();cancelScreenInspection()
        let id=UUID(),module=currentModule(),axMode=axPlacementEnabled,started=ProcessInfo.processInfo.systemUptime
        viewProbeID=id;updateToggleTitle()
        report("Reading Lightroom view through Accessibility…")
        let settings=reloadDetectionConfig(),viewSettings=settings.viewClassificationSettings
        DispatchQueue.global(qos:.userInitiated).async {
            let grid=accessibilityGridReading(module:module)
            let toolbar=axMode ? nil:accessibilityToolbarReading(fallback:settings.toolbarUnknownFallback,module:module).shown
            var proposal:AXTrialProposal?,panelHints:AXPanelState?
            let mapping=accessibilityMappingReport { host,windows,fullScreen in
                // No fine adjustments: only classify the raw visible panel/label evidence.
                proposal=axTrialProposal(host:host,windows:windows,settings:viewSettings,fullScreen:fullScreen)
                if let toolbar { panelHints=AXPanelState(host:host,visibleFrames:windows.filter(\.visible).map(\.frame),toolbar:toolbar ? "shown":"hidden") }
            }
            DispatchQueue.main.async {
                guard self.viewProbeID==id else { return }
                self.viewProbeID=nil;self.updateToggleTitle()
                self.lastAXMapping=mapping
                self.lastGridStatus=grid.report
                if module==self.currentModule(),OverlayBehaviourPolicy.isGridSelected(grid.selected) { self.dismissForGrid();return }
                guard module==self.currentModule(),let proposal else {
                    self.lastViewDetection="AX view unavailable or module changed; no overlay requested. Disable automatic view detection to use the saved menu selection."
                    self.report(self.lastViewDetection);self.saveInvocationDiagnostics();return
                }
                let group=proposal.layout == "Side-by-side" ? 1:proposal.layout == "Above-and-below" ? 2:0
                let preferred=CameraPreferences.shared.string(forKey:"axPreferredPane.\(module ?? "develop").\(group)").flatMap(OverlayLayout.init(rawValue:))
                let mode:OverlayLayout=group==0 ? .full:(preferred?.group==group ? preferred!:(group==1 ? .left:.upper))
                self.lightroomMonitor.invocationPanelHints=panelHints
                self.lightroomMonitor.detectedLayout=mode;self.lightroomMonitor.detectedLayoutModule=module
                self.lastViewDetection="\(proposal.layout); selected pane: \(mode.label). No clear pair means single view.\nClassification took \(Int((ProcessInfo.processInfo.systemUptime-started)*1000)) ms (before bridge request)."
                self.updateLayoutMenu()
                self.request(.overlay,viewChecked:true)
            }
        }
    }
}
