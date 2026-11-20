import AppKit
import ApplicationServices

// Transitional app-facing coordination: all original guards, callbacks and action
// order are retained. State forwards to one concrete owner per display. Requests,
// placement and monitoring can be migrated independently without duplicate state.
extension AppDelegate {
    var panel:OverlayPanel? {
        get { overlayController.panel }
        set { overlayController.panel=newValue }
    }
    var overlayHost:HostWindowSnapshot? {
        get { overlayController.overlayHost }
        set { overlayController.overlayHost=newValue }
    }
    var displayedOverlayLayout:OverlayLayout? {
        get { overlayController.displayedOverlayLayout }
        set { overlayController.displayedOverlayLayout=newValue }
    }
    var displayedOverlayModule:String? {
        get { overlayController.displayedOverlayModule }
        set { overlayController.displayedOverlayModule=newValue }
    }
    var overlayGeometrySettler:OverlayGeometrySettler {
        get { overlayController.overlayGeometrySettler }
        set { overlayController.overlayGeometrySettler=newValue }
    }
    var overlayGeometrySource:String {
        get { overlayController.overlayGeometrySource }
        set { overlayController.overlayGeometrySource=newValue }
    }
    var overlayAccessibility:LightroomHostAccessibility? {
        get { overlayController.overlayAccessibility }
        set { overlayController.overlayAccessibility=newValue }
    }
    var nextAccessibilityBind:TimeInterval {
        get { overlayController.nextAccessibilityBind }
        set { overlayController.nextAccessibilityBind=newValue }
    }
    var accessibilityBindingStatus:String {
        get { overlayController.accessibilityBindingStatus }
        set { overlayController.accessibilityBindingStatus=newValue }
    }
    var lifecycleTrace:[String] {
        get { overlayController.lifecycleTrace }
        set { overlayController.lifecycleTrace=newValue }
    }
    var lastLifecycleEvent:String {
        get { overlayController.lastLifecycleEvent }
        set { overlayController.lastLifecycleEvent=newValue }
    }
    var overlayBaselineWindows:Set<CGWindowID> {
        get { overlayController.overlayBaselineWindows }
        set { overlayController.overlayBaselineWindows=newValue }
    }
    var overlayDialogVisible:Bool {
        get { overlayController.overlayDialogVisible }
        set { overlayController.overlayDialogVisible=newValue }
    }
    var overlayLifecycleStatus:String {
        get { overlayController.overlayLifecycleStatus }
        set { overlayController.overlayLifecycleStatus=newValue }
    }
    var attemptedSelectionRefresh:String? {
        get { overlayController.attemptedSelectionRefresh }
        set { overlayController.attemptedSelectionRefresh=newValue }
    }
    var overlayEpoch:String? {
        get { overlayController.overlayEpoch }
        set { overlayController.overlayEpoch=newValue }
    }
    var overlaySuspended:Bool {
        get { overlayController.overlaySuspended }
        set { overlayController.overlaySuspended=newValue }
    }
    var overlayResumeAfter:TimeInterval {
        get { overlayController.overlayResumeAfter }
        set { overlayController.overlayResumeAfter=newValue }
    }
    var overlayVisibilityStatus:String {
        get { overlayController.overlayVisibilityStatus }
        set { overlayController.overlayVisibilityStatus=newValue }
    }
    var overlayMoveCount:Int {
        get { overlayController.overlayMoveCount }
        set { overlayController.overlayMoveCount=newValue }
    }
    var overlayOrderCount:Int {
        get { overlayController.overlayOrderCount }
        set { overlayController.overlayOrderCount=newValue }
    }
    var overlayLevelChangeCount:Int {
        get { overlayController.overlayLevelChangeCount }
        set { overlayController.overlayLevelChangeCount=newValue }
    }
    var livePanelSignature:String? {
        get { overlayController.livePanelSignature }
        set { overlayController.livePanelSignature=newValue }
    }
    var floatingTitle:String {
        get { floatingController.floatingTitle }
        set { floatingController.floatingTitle=newValue }
    }
    var floatingZoom:Double {
        get { floatingController.floatingZoom }
        set { floatingController.floatingZoom=newValue }
    }
    var floating:NSPanel? {
        get { floatingController.floating }
        set { floatingController.floating=newValue }
    }
    var floatingView:ReferenceView? {
        get { floatingController.floatingView }
        set { floatingController.floatingView=newValue }
    }

    func updateFloatingTitle() { floatingController.updateFloatingTitle() }
    func recordLifecycle(_ event:String) { overlayController.recordLifecycle(event) }
    func bindOverlayAccessibility(pid:pid_t,frame:CGRect) {
        guard overlayAccessibility == nil,ProcessInfo.processInfo.systemUptime>=nextAccessibilityBind else { return }
        nextAccessibilityBind=ProcessInfo.processInfo.systemUptime+1
        overlayAccessibility=LightroomHostAccessibility(pid:pid,hostFrame:frame,diagnostic:&accessibilityBindingStatus)
        overlayAccessibility?.onMinimized={ [weak self] in self?.suspendOverlay(reason:"Lightroom minimise notification") }
    }
    func updateOverlayLifecycle() {
        guard let saved=overlayHost,let owner=NSWorkspace.shared.runningApplications.first(where:isLightroomApp) else { return }
        bindOverlayAccessibility(pid:owner.processIdentifier,frame:saved.frame)
        let windows=lightroomWindowMetadata(pid:owner.processIdentifier)
        overlayDialogVisible=(overlayAccessibility?.hasDialog ?? false) || (windows.map { hasNewLightroomDialog(windows:$0,host:saved.id,baseline:overlayBaselineWindows) } ?? false)
        let minimized=overlayAccessibility?.minimized
        overlayLifecycleStatus="Lifecycle: minimise notifications \(overlayAccessibility?.watchesMinimize == true ? "active":"unavailable"); dialog \(overlayDialogVisible); minimised \(minimized.map(String.init) ?? "unavailable"); \(overlayAccessibility == nil ? "window-list fallback":"Accessibility + window list")."
        overlayLifecycleStatus += "\n" + accessibilityBindingStatus + "\n" + (overlayAccessibility?.diagnostic ?? "No AX observer; window-list fallback.")
    }
    func suspendOverlay(reason:String="Space transition") {
        guard let panel else { return }
        overlayVisibilityStatus="Overlay suspended: \(reason)."
        recordLifecycle("suspend: \(reason)")
        if !overlaySuspended { overlayGeometrySettler.reset() }
        cancelPanelCheck();overlaySuspended=true
        overlayResumeAfter=ProcessInfo.processInfo.systemUptime+0.4
        for border in axTrialBorders { border.orderOut(nil) }
        panel.orderOut(nil)
    }
    func reconcileOverlayHost() {
        guard let panel,let saved=overlayHost else { return }
        let reported=hostWindowSnapshot(saved.id)
        // AX describes logical layout; CG window positions may follow Dock
        // animation. Keep CG visibility, but prefer AX coordinates for movement.
        let logical=overlayAccessibility?.layoutFrame
        let current=reported.map { HostWindowSnapshot(id:$0.id,frame:logical ?? $0.frame,onScreen:$0.onScreen) }
        overlayGeometrySource=logical == nil ? "window list":"Accessibility logical frame"
        if let logical,let reported,hostPresentationIsShrinking(reported:reported.frame,logical:logical,saved:saved.frame) {
            suspendOverlay(reason:"host presentation shrinking during minimise");return
        }
        if overlayAccessibility?.minimized == true || (current.map { hostIsPresentationThumbnail($0.frame) } ?? false) {
            suspendOverlay(reason:"Lightroom minimised or thumbnail transition");return
        }
        if !workspaceOverview,current == nil,hostWindowIsClosed(saved.id) {
            overlayVisibilityStatus="Overlay dismissed: Lightroom host closed.";hide();invalidateAutomaticGeometry();return
        }
        if let current,abs(current.frame.width-saved.frame.width)>=0.5 || abs(current.frame.height-saved.frame.height)>=0.5 {
            invalidateAutomaticGeometry() // Next invocation; keep the displayed image.
        }
        if let current,!NSScreen.screens.contains(where:{$0.frame.contains(current.frame)}) { cancelPanelCheck() }
        switch OverlayBehaviourPolicy.hostChange(saved:saved.frame,current:current?.frame,onScreen:current?.onScreen ?? false,overview:workspaceOverview) {
        case .retain:overlayVisibilityStatus="Overlay retained: host metadata temporarily unavailable."
        case .suspend:suspendOverlay(reason:workspaceOverview ? "Dock overview active":"host is off-screen or on another Space")
        case .translate(let delta):
            guard let current,overlayGeometrySettler.accepts(current.frame,saved:saved.frame,restoring:overlaySuspended,now:ProcessInfo.processInfo.systemUptime) else {
                overlayVisibilityStatus="Overlay geometry held while host resize/restoration settles.";return
            }
            if overlaySuspended {
                guard ProcessInfo.processInfo.systemUptime>=overlayResumeAfter else { return }
            }
            if delta != .zero {
                panel.setFrameOrigin(CGPoint(x:panel.frame.minX+delta.x,y:panel.frame.minY+delta.y))
                overlayMoveCount += 1
            }
            overlayGeometrySettler.reset();overlayHost=current
            if overlaySuspended {
                recordLifecycle("restore: host visible and settled")
                overlaySuspended=false;_ = orderOverlayAboveLightroom(initial:true)
                for border in axTrialBorders { border.orderFront(nil) }
            }
        }
    }
    @discardableResult func orderOverlayAboveLightroom(initial:Bool=false)->Bool {
        guard let panel else { return false }
        updateOverlayLifecycle()
        let floating=isLightroom() && !workspaceOverview && !overlayDialogVisible
        let desiredLevel:NSWindow.Level=floating ? .floating:.normal
        let levelChanged=panel.level != desiredLevel
        // Lower immediately on app deactivation, even if host metadata is
        // temporarily unavailable. Never leave a globally floating overlay.
        if levelChanged { panel.level=desiredLevel;overlayLevelChangeCount += 1
            for border in axTrialBorders { border.level=desiredLevel }
        }
        guard !workspaceOverview,!overlaySuspended else { return false }
        if floating,!initial,overlayHost != nil {
            // Lightroom clicks cannot cover this level. No 5Hz reordering.
            // Do not reinsert a window suppressed by native overview handling.
            if levelChanged,panel.isVisible { panel.orderFront(nil);overlayOrderCount += 1 }
            overlayVisibilityStatus="Overlay floating while Lightroom is active.";return true
        }
        guard let owner=NSWorkspace.shared.runningApplications.first(where:isLightroomApp),
              let rows=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] else { return false }
        let windows=rows.filter { ($0[kCGWindowLayer as String] as? NSNumber)?.intValue==0 }
        let lightroom=windows.filter {
            guard ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value==owner.processIdentifier,
                  let dict=$0[kCGWindowBounds as String] as? [String:Any],let frame=CGRect(dictionaryRepresentation:dict as CFDictionary) else { return false }
            return frame.width>600 && frame.height>400
        }.max { a,b in
            func area(_ item:[String:Any])->CGFloat {
                guard let d=item[kCGWindowBounds as String] as? [String:Any],let f=CGRect(dictionaryRepresentation:d as CFDictionary) else { return 0 };return f.width*f.height
            }
            return area(a)<area(b)
        }
        guard let number=(lightroom?[kCGWindowNumber as String] as? NSNumber)?.intValue else { return false }
        if initial && overlayHost == nil {
            overlayHost=hostWindowSnapshot(CGWindowID(number));overlayEpoch=selectionEpoch()
            overlayBaselineWindows=Set(lightroomWindowMetadata(pid:owner.processIdentifier)?.map(\.id) ?? [])
            if let host=overlayHost { bindOverlayAccessibility(pid:owner.processIdentifier,frame:host.frame) }
        }
        guard overlayHost?.id==CGWindowID(number) else { return false }
        if floating {
            panel.orderFront(nil);overlayOrderCount += 1
            overlayVisibilityStatus="Overlay floating while Lightroom is active.";return true
        }
        let order=windows.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.intValue }
        if !initial && !levelChanged && !order.contains(panel.windowNumber) {
            overlayVisibilityStatus="Overlay retained: native visibility managed by macOS.";return true
        }
        let lightroomWindows=Set(windows.filter {
            ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value==owner.processIdentifier
        }.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.intValue })
        if levelChanged || overlayNeedsOrdering(order:order,overlay:panel.windowNumber,lightroom:number,lightroomWindows:lightroomWindows) {
            panel.order(.above,relativeTo:number);overlayOrderCount += 1
        }
        overlayVisibilityStatus=overlayDialogVisible ? "Overlay lowered for a Lightroom dialog.":"Overlay at normal level while another app is active."
        return true
    }
    func hide() {
        clearAXTrialBorders()
        if destination == .overlay { cancelRequest() }
        (panel?.contentView as? ReferenceView)?.releaseContent()
        panel?.orderOut(nil); panel = nil;attemptedSelectionRefresh=nil;livePanelSignature=nil;displayedOverlayLayout=nil;displayedOverlayModule=nil;overlayHost=nil;overlayGeometrySettler.reset();overlayAccessibility=nil;overlayBaselineWindows=[];overlayDialogVisible=false;overlayEpoch=nil;overlaySuspended=false;updateIcon()
    }
    func display(_ image: CGImage, in region: NSRect, photoFrame: NSRect? = nil) -> ReferenceView? {
        guard NSScreen.screens.contains(where: { $0.frame.intersects(region) }) else {
            lastLayout += "\nOverlay rejected: region \(region) is outside current displays \(NSScreen.screens.map { $0.frame })."
            report("Set image region again for this display layout."); return nil
        }
        let p = OverlayPanel(contentRect: region.insetBy(dx: -1, dy: -1), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.animationBehavior = .none
        p.level = .normal; p.isOpaque = true; p.backgroundColor = .black
        p.hasShadow = false; p.hidesOnDeactivate = false; p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        let view = ReferenceView(frame: NSRect(origin: .zero, size: p.frame.size))
        view.showIndicator = true
        view.autoresizingMask = [.width, .height]
        configureImageView(view)
        view.refresh = { [weak self] in self?.reloadOverlay() }
        view.image = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        p.contentView = view; panel = p;livePanelSignature=axPlacementEnabled ? pendingAXPanelSignature:nil;displayedOverlayLayout=overlayLayout;displayedOverlayModule=currentModule();overlayMoveCount=0;overlayOrderCount=0;overlayLevelChangeCount=0;
        overlayGeometrySettler.reset()
        lifecycleTrace=[];lastLifecycleEvent="";recordLifecycle("overlay created")
        guard orderOverlayAboveLightroom(initial:true) else { hide();report("Lightroom window unavailable; invoke again when it is visible.");return nil }
        let requested=region.insetBy(dx:-1,dy:-1)
        p.setFrame(requested,display:true)
        lastLayout += "\nOverlay panel requested (AppKit): \(requested). Actual: \(p.frame)."
        if !overlayPlacementIsAcceptable(requested:requested,actual:p.frame) {
            invalidateAutomaticGeometry()
            lastLayout += "\nmacOS adjusted placement; overlay retained for manual dismissal."
        }
        // Convert through the actual native window and content view after AppKit rounding.
        view.imageViewport = view.convert(p.convertFromScreen(photoFrame ?? region), from:nil)
        view.needsDisplay = true
        lastLayout += "\nOverlay content bounds: \(view.bounds). Photo viewport (view): \(view.imageViewport!). Panel visible: \(p.isVisible). Display scale: \(p.backingScaleFactor)."
        guard p.isVisible else { hide();report("Overlay panel did not become visible; see geometry diagnostics.");return nil }
        updateIcon()
        if let started=invocationStart { lastTiming += String(format:"; total to panel shown %.0f ms",(ProcessInfo.processInfo.systemUptime-started)*1000) }
        runAXTrial(after:p)
        return view
    }
    @objc func openFloating() {
        guard !recording, calibration == nil else { return }
        if destination == .window { cancelRequest(); return }
        if let floating {
            if floating.isVisible { floating.close() } else { floating.orderFrontRegardless() }
            updateToggleTitle(); return
        }
        request(.window)
    }
    func displayFloating(_ image: CGImage, origin: ImageOrigin, filename:String, area: NSRect?, photoSize:CGSize? = nil) {
        let ratio = NSSize(width: image.width, height: image.height)
        if floating == nil {
            let screen = NSScreen.screens.first(where: { area.map($0.frame.intersects) ?? false }) ?? NSScreen.main ?? NSScreen.screens[0]
            let base = area ?? screen.visibleFrame
            let photo = photoSize ?? fittedSize(image: ratio, inside: base.size)
            let requested = photo
            let size = fittedSize(image: requested, inside: CGSize(width: min(requested.width,screen.visibleFrame.width), height: min(requested.height,screen.visibleFrame.height-28)))
            let frame = NSRect(x: min(max(base.minX, screen.visibleFrame.minX), screen.visibleFrame.maxX-size.width),
                               y: min(max(base.midY-size.height/2, screen.visibleFrame.minY), screen.visibleFrame.maxY-size.height-28), width: size.width, height: size.height)
            let p = FloatingPanel(contentRect: frame, styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
            p.level = .floating; p.isFloatingPanel = true; p.hidesOnDeactivate = false
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.isReleasedWhenClosed = false; p.backgroundColor = .black; p.delegate = self
            p.appearance = NSAppearance(named: .darkAqua)
            let view = ReferenceView(frame: NSRect(origin: .zero, size: size))
            configureImageView(view)
            view.movesWindowAtFit=true
            p.acceptsMouseMovedEvents=true
            view.zoomChanged = { [weak self] percentage in
                self?.floatingZoom=percentage
                if self?.destination != .window { self?.updateFloatingTitle() }
            }
            view.autoresizingMask = [.width, .height]
            view.refresh = { [weak self] in self?.request(.window) }
            p.contentView = view
            p.setFrame(frame,display:false) // Full-size content: chrome overlays, never resizes the photo.
            p.installChrome()
            lastLayout += "\nFloating requested photo size: \(size); actual content: \(view.bounds.size); outer frame: \(p.frame.size)."
            floating = p; floatingView = view
        } else if let floating {
            // Keep the user's position and approximate size, while adapting to portrait/landscape changes.
            let box = floating.contentView?.bounds.size ?? floating.frame.size
            let area = box.width * box.height, aspect = ratio.width / ratio.height
            let desired = CGSize(width: sqrt(area * aspect), height: sqrt(area / aspect))
            let available = floating.screen?.visibleFrame.size ?? CGSize(width: 1200, height: 800)
            let limit = CGSize(width: min(desired.width, available.width * 0.9), height: min(desired.height, available.height * 0.85))
            floating.setFrame(CGRect(origin:floating.frame.origin,size:fittedSize(image:ratio,inside:limit)),display:true)
        }
        floating?.aspectRatio = ratio
        floating?.minSize = fittedSize(image: ratio, inside: CGSize(width: 180, height: 180))
        floatingView?.image = NSImage(cgImage: image, size: ratio)
        floatingTitle=filename + " — " + origin.rawValue + " · Camera Reference"
        updateFloatingTitle()
        floating?.orderFrontRegardless()
        collectCompleteDiagnostics()
    }
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === floating else { return }
        if destination == .window { cancelRequest() }
        floatingView?.releaseContent(); floatingView = nil; floating = nil
    }
    func configureImageView(_ view:ReferenceView) {
        view.save = { [weak self, weak view] snapshot in
            guard let view else { return }; self?.saveExtracted(snapshot, from:view)
        }
        view.canSave = { [weak self] in self?.saving == false }
        view.toolTip="Two-finger scroll: pan. Command-scroll: zoom. Drag: pan (floating at Fit: move window). Double-click: reload and Fit. Right-click: Fit / 100% / Save."
    }
    func reloadOverlay() {
        guard panel != nil, supportedLightroomModule(currentModule()) else { return }
        hide(); request(.overlay)
    }
}
