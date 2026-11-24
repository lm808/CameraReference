import AppKit

// Coordinator keeps UI/policy qualification and completion order. Request-handle
// aliases retain existing bindings; other state is addressed on PhotoRequestPipeline.
extension AppDelegate {
    var cancellation:Cancellation? {
        get { photoRequests.cancellation }
        set { photoRequests.cancellation=newValue }
    }
    var destination:Destination? {
        get { photoRequests.destination }
        set { photoRequests.destination=newValue }
    }
    var pending:String? {
        get { photoRequests.pending }
        set { photoRequests.pending=newValue }
    }
    var imageCache:SelectionImageCache { photoRequests.imageCache }
    func cancelRequest() {
        viewProbeID=nil
        photoRequests.cancel()
        updateToggleTitle()
    }
    func request(_ target: Destination, viewChecked:Bool=false,refreshing existing:OverlayPanel?=nil) {
        diagnosticGeneration += 1
        savingInvocation = target == .overlay || target == .window
        guard !regionResetting,requireSupportedModule() else { return }
        if target == .overlay && automaticViewEnabled && !viewChecked && (screenshotAXDismissEnabled || (axPlacementEnabled && currentModule()=="library") || lightroomMonitor.detectedLayout == nil || lightroomMonitor.detectedLayoutModule != currentModule()) && CameraPreferences.shared.bool(forKey:regionKey("automaticBounds")) {
            detectInvocationView();return
        }
        cancelPanelCheck();lightroomMonitor.nextPanelCheck=ProcessInfo.processInfo.systemUptime+reloadDetectionConfig().panelCheckIntervalSeconds
        cancelScreenInspection(); cancelRequest()
        let token = UUID().uuidString, work = Cancellation()
        pending = token; destination = target; cancellation = work; photoRequests.pendingModule=currentModule();photoRequests.selectionRefreshPanel=existing
        updateToggleTitle()
        let invoked = ProcessInfo.processInfo.systemUptime
        photoRequests.invocationStart=invoked
        do { try photoRequests.writeRequest(token:token,target:target) }
        catch { cancelRequest(); report("Cannot write the bridge request."); return }
        let deadline = Date().addingTimeInterval(5)
        report("Waiting for Lightroom…")
        if target == .window { floating?.title = floatingController.floatingTitle + " — refreshing…" }
        photoRequests.poll(token:token,deadline:deadline,onResponse:{ [weak self] response in
            guard let self else { return }
            guard response.success else { self.failed(response.value, target: target); return }
            self.load(response.value, token: token, target: target, work: work, invoked: invoked)
        },onTimeout:{ [weak self] in
            self?.failed("Plugin timed out. Reload the updated bridge 0.5.3 in Lightroom’s Plug-in Manager, then use File → Plug-in Extras → Start / restart Camera Reference bridge.", target: target)
        })
    }
    func failed(_ text: String, target: Destination) {
        cancelRequest(); report(text)
        collectCompleteDiagnostics()
        if target == .window { floating?.title = floatingController.floatingTitle + " — unchanged; refresh failed" }
    }
    func selectionEpoch()->String? { photoRequests.selectionEpoch() }
    func responseEpoch(_ token:String)->String? { photoRequests.responseEpoch(token) }
    func load(_ path: String, token: String, target: Destination, work: Cancellation, invoked: TimeInterval) {
        let requestedModule=photoRequests.pendingModule,refreshingPanel=photoRequests.selectionRefreshPanel,refreshGeneration=lightroomMonitor.liveViewGeneration
        let loadStarted=ProcessInfo.processInfo.systemUptime
        let bridgeMS=(loadStarted-invoked)*1000
        let prefer = CameraPreferences.shared.bool(forKey: "preferEmbedded")
        let executable = findExifTool(custom: CameraPreferences.shared.string(forKey: "exiftool"))
        let liveEpoch=selectionEpoch()
        imageCache.observe(liveEpoch)
        let epoch=responseEpoch(token).flatMap { $0 == liveEpoch ? $0:nil }
        let automatic = false // Screen detection runs after loading, outside the UI thread.
        report("Loading camera JPEG…")
        let context=PhotoLoadContext(token:token,target:target,cancellation:work,invoked:invoked,module:requestedModule,refreshingPanel:refreshingPanel,refreshGeneration:refreshGeneration,epoch:epoch)
        photoRequests.load(path,context:context,prefer:prefer,executable:executable,automatic:automatic) { [self] result in
            let token=context.token,work=context.cancellation,target=context.target,invoked=context.invoked
            let requestedModule=context.module,refreshingPanel=context.refreshingPanel,refreshGeneration=context.refreshGeneration,epoch=context.epoch
            guard self.pending == token, !work.isCancelled else { return }
            guard supportedLightroomModule(self.currentModule()),self.currentModule()==requestedModule else {
                self.cancelRequest();self.report("Module changed; invoke again in Library or Develop.");return
            }
            if let epoch, self.selectionEpoch() != epoch {
                self.imageCache.observe(self.selectionEpoch());self.cancelRequest()
                self.report("Selection changed while loading; invoke again for the current photo.");return
            }
            if let refreshingPanel {
                guard let epoch,self.panel === refreshingPanel,self.axPlacementEnabled,self.axLiveUpdate,
                      self.lightroomMonitor.liveViewGeneration==refreshGeneration,
                      CameraPreferences.shared.bool(forKey:self.regionKey("automaticBounds")) else { self.cancelRequest();return }
                guard self.selectionEpoch()==epoch else { self.cancelRequest();return }
            }
            self.pending = nil; self.destination = nil; self.cancellation = nil;self.photoRequests.selectionRefreshPanel=nil
            self.updateToggleTitle()
            switch result {
            case .failure(let error):
                self.report(error.localizedDescription)
                if target == .window { self.floating?.title = self.floatingController.floatingTitle + " — unchanged; refresh failed" }
            case .success(let (loaded, layout)):
                self.lastTiming=String(format:"Bridge %.0f ms; JPEG load/decode %.0f ms",bridgeMS,loaded.elapsed*1000) + (loaded.extraction.map { String(format:" (extraction %.0f ms, included)",$0*1000) } ?? "")
                self.lastTiming += "; " + loaded.stages
                self.lastImageSize = CGSize(width: loaded.image.width, height: loaded.image.height)
                if let layout { self.lastLayout = layout.summary }
                let elapsed = ProcessInfo.processInfo.systemUptime - invoked
                let extraction = loaded.extraction.map { String(format: "; extraction %.0f ms", $0 * 1000) } ?? ""
                self.report(loaded.origin.rawValue + (loaded.usedFallback ? " (fallback)" : "") + String(format: " · ready in %.0f ms", elapsed * 1000) + extraction)
                let snapshot=loaded.embeddedBytes.map { ExportSnapshot(raw:URL(fileURLWithPath:path),bytes:$0,orientation:loaded.cameraOrientation) }
                if target == .overlay {
                    guard self.isLightroom(), supportedLightroomModule(self.currentModule()) else { self.report("Overlay cancelled: Library or Develop is no longer active."); return }
                    if let refreshingPanel,let epoch {
                        self.refreshAXSelection(loaded.image,snapshot:snapshot,epoch:epoch,panel:refreshingPanel,generation:refreshGeneration,pictureStyle:loaded.pictureStyle)
                    } else { self.resolveOverlay(loaded.image,snapshot:snapshot,selectionEpoch:epoch,pictureStyle:loaded.pictureStyle) }
                } else if target == .detect {
                    self.startPhotoDetection(imageSize:CGSize(width:loaded.image.width,height:loaded.image.height))
                } else if target == .window {
                    self.resolveFloating(loaded, snapshot:snapshot, epoch:epoch)
                }
            }
        }
    }
}
