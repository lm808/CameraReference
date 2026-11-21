import AppKit
import ApplicationServices

// App-facing presentation coordination preserves guard, callback and effect order.
// Panel aliases support local optional bindings; lifecycle/identity state is
// addressed directly on its owner. This extension is not a second state store.
extension AppDelegate {
    var panel:OverlayPanel? {
        get { overlayController.panel }
        set { overlayController.panel=newValue }
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
        guard overlayController.overlayAccessibility == nil,ProcessInfo.processInfo.systemUptime>=overlayController.nextAccessibilityBind else { return }
        overlayController.nextAccessibilityBind=ProcessInfo.processInfo.systemUptime+1
        overlayController.overlayAccessibility=LightroomHostAccessibility(pid:pid,hostFrame:frame,diagnostic:&overlayController.accessibilityBindingStatus)
        overlayController.overlayAccessibility?.onMinimized={ [weak self] in self?.suspendOverlay(reason:"Lightroom minimise notification") }
    }
    func updateOverlayLifecycle() {
        guard let saved=overlayController.overlayHost,let owner=NSWorkspace.shared.runningApplications.first(where:isLightroomApp) else { return }
        bindOverlayAccessibility(pid:owner.processIdentifier,frame:saved.frame)
        let windows=lightroomWindowMetadata(pid:owner.processIdentifier)
        overlayController.overlayDialogVisible=(overlayController.overlayAccessibility?.hasDialog ?? false) || (windows.map { hasNewLightroomDialog(windows:$0,host:saved.id,baseline:overlayController.overlayBaselineWindows) } ?? false)
        let minimized=overlayController.overlayAccessibility?.minimized
        overlayController.overlayLifecycleStatus="Lifecycle: minimise notifications \(overlayController.overlayAccessibility?.watchesMinimize == true ? "active":"unavailable"); dialog \(overlayController.overlayDialogVisible); minimised \(minimized.map(String.init) ?? "unavailable"); \(overlayController.overlayAccessibility == nil ? "window-list fallback":"Accessibility + window list")."
        overlayController.overlayLifecycleStatus += "\n" + overlayController.accessibilityBindingStatus + "\n" + (overlayController.overlayAccessibility?.diagnostic ?? "No AX observer; window-list fallback.")
    }
    func suspendOverlay(reason:String="Space transition") {
        guard let panel else { return }
        overlayController.overlayVisibilityStatus="Overlay suspended: \(reason)."
        recordLifecycle("suspend: \(reason)")
        if !overlayController.overlaySuspended { overlayController.overlayGeometrySettler.reset() }
        cancelPanelCheck();overlayController.overlaySuspended=true
        overlayController.overlayResumeAfter=ProcessInfo.processInfo.systemUptime+0.4
        for border in axTrialBorders { border.orderOut(nil) }
        panel.orderOut(nil)
        diagnostics.windowOrdering.event("overlay orderOut: suspend")
    }
    func reconcileOverlayHost() {
        guard let panel,let saved=overlayController.overlayHost else { return }
        let reported=hostWindowSnapshot(saved.id)
        // AX describes logical layout; CG window positions may follow Dock
        // animation. Keep CG visibility, but prefer AX coordinates for movement.
        let logical=overlayController.overlayAccessibility?.layoutFrame
        let current=reported.map { HostWindowSnapshot(id:$0.id,frame:logical ?? $0.frame,onScreen:$0.onScreen) }
        overlayController.overlayGeometrySource=logical == nil ? "window list":"Accessibility logical frame"
        if let logical,let reported,hostPresentationIsShrinking(reported:reported.frame,logical:logical,saved:saved.frame) {
            suspendOverlay(reason:"host presentation shrinking during minimise");return
        }
        if overlayController.overlayAccessibility?.minimized == true || (current.map { hostIsPresentationThumbnail($0.frame) } ?? false) {
            suspendOverlay(reason:"Lightroom minimised or thumbnail transition");return
        }
        if !lightroomMonitor.workspaceOverview,current == nil,hostWindowIsClosed(saved.id) {
            overlayController.overlayVisibilityStatus="Overlay dismissed: Lightroom host closed.";hide();invalidateAutomaticGeometry();return
        }
        if let current,abs(current.frame.width-saved.frame.width)>=0.5 || abs(current.frame.height-saved.frame.height)>=0.5 {
            invalidateAutomaticGeometry() // Next invocation; keep the displayed image.
        }
        if let current,!NSScreen.screens.contains(where:{$0.frame.contains(current.frame)}) { cancelPanelCheck() }
        switch OverlayBehaviourPolicy.hostChange(saved:saved.frame,current:current?.frame,onScreen:current?.onScreen ?? false,overview:lightroomMonitor.workspaceOverview) {
        case .retain:overlayController.overlayVisibilityStatus="Overlay retained: host metadata temporarily unavailable."
        case .suspend:suspendOverlay(reason:lightroomMonitor.workspaceOverview ? "Dock overview active":"host is off-screen or on another Space")
        case .translate(let delta):
            guard let current,overlayController.overlayGeometrySettler.accepts(current.frame,saved:saved.frame,restoring:overlayController.overlaySuspended,now:ProcessInfo.processInfo.systemUptime) else {
                overlayController.overlayVisibilityStatus="Overlay geometry held while host resize/restoration settles.";return
            }
            if overlayController.overlaySuspended {
                guard ProcessInfo.processInfo.systemUptime>=overlayController.overlayResumeAfter else { return }
            }
            if delta != .zero {
                panel.setFrameOrigin(CGPoint(x:panel.frame.minX+delta.x,y:panel.frame.minY+delta.y))
                overlayController.overlayMoveCount += 1
            }
            overlayController.overlayGeometrySettler.reset();overlayController.overlayHost=current
            if overlayController.overlaySuspended {
                recordLifecycle("restore: host visible and settled")
                overlayController.overlaySuspended=false;_ = orderOverlayAboveLightroom(initial:true)
                for border in axTrialBorders { orderReferencePanelFront(border) }
            }
        }
    }
    func orderReferencePanelFront(_ overlay:NSPanel) {
        diagnostics.windowOrdering.event("orderReferencePanelFront id=\(overlay.windowNumber) level=\(overlay.level.rawValue)")
        if let panel,overlay !== panel,panel.isVisible,overlayController.overlayAccessibility?.fullScreen == true {
            overlay.order(.above,relativeTo:panel.windowNumber)
            return
        }
        if let floating,floating.isVisible,floating.level == overlay.level {
            overlay.order(.below,relativeTo:floating.windowNumber)
        } else { overlay.orderFront(nil) }
    }
    @discardableResult func orderOverlayAboveLightroom(initial:Bool=false)->Bool {
        guard let panel else { return false }
        updateOverlayLifecycle()
        let fullScreen=overlayController.overlayAccessibility?.fullScreen
        let floating=OverlayBehaviourPolicy.useFloatingOverlayLevel(lightroomActive:isLightroom(),overview:lightroomMonitor.workspaceOverview,dialog:overlayController.overlayDialogVisible,fullScreen:fullScreen)
        if fullScreen == false { overlayController.revealedTitlebar=nil;overlayController.titlebarClipStatus="windowed; no clip";applyTitlebarClip() }
        let desiredLevel:NSWindow.Level=floating ? .floating:.normal
        let levelChanged=panel.level != desiredLevel
        // Lower immediately on app deactivation, even if host metadata is
        // temporarily unavailable. Never leave a globally floating overlay.
        if levelChanged { panel.level=desiredLevel;overlayController.overlayLevelChangeCount += 1
            diagnostics.windowOrdering.event("overlay level set=\(desiredLevel.rawValue) actual=\(panel.level.rawValue)")
            for border in axTrialBorders { border.level=desiredLevel }
        }
        guard !lightroomMonitor.workspaceOverview,!overlayController.overlaySuspended else { return false }
        if floating,!initial,overlayController.overlayHost != nil {
            // Lightroom clicks cannot cover this level. No 5Hz reordering.
            // Do not reinsert a window suppressed by native overview handling.
            if levelChanged,panel.isVisible { orderReferencePanelFront(panel);overlayController.overlayOrderCount += 1 }
            overlayController.overlayVisibilityStatus="Overlay floating while Lightroom is active.";return true
        }
        guard let owner=NSWorkspace.shared.runningApplications.first(where:isLightroomApp),
              let rows=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] else { return false }
        updateTitlebarClip(fullScreen:fullScreen,pid:owner.processIdentifier)
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
        if initial && overlayController.overlayHost == nil {
            overlayController.overlayHost=hostWindowSnapshot(CGWindowID(number));overlayController.overlayEpoch=selectionEpoch()
            overlayController.overlayBaselineWindows=Set(lightroomWindowMetadata(pid:owner.processIdentifier)?.map(\.id) ?? [])
            if let host=overlayController.overlayHost { bindOverlayAccessibility(pid:owner.processIdentifier,frame:host.frame) }
            // The first pass had no AX host yet; apply its confirmed full-screen
            // level before showing the overlay. The bound host prevents recursion.
            if overlayController.overlayAccessibility?.fullScreen == true { return orderOverlayAboveLightroom(initial:true) }
        }
        guard overlayController.overlayHost?.id==CGWindowID(number) else { return false }
        if floating {
            orderReferencePanelFront(panel);overlayController.overlayOrderCount += 1
            overlayController.overlayVisibilityStatus="Overlay floating while Lightroom is active.";return true
        }
        let order=windows.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.intValue }
        if !initial && !levelChanged && !order.contains(panel.windowNumber) {
            overlayController.overlayVisibilityStatus="Overlay retained: native visibility managed by macOS.";return true
        }
        let lightroomWindows=Set(windows.filter {
            ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value==owner.processIdentifier
        }.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.intValue })
        if levelChanged || overlayNeedsOrdering(order:order,overlay:panel.windowNumber,lightroom:number,lightroomWindows:lightroomWindows) {
            panel.order(.above,relativeTo:number);overlayController.overlayOrderCount += 1
            diagnostics.windowOrdering.event("overlay order above host=\(number) level=\(panel.level.rawValue)")
        }
        overlayController.overlayVisibilityStatus=overlayController.overlayDialogVisible ? "Overlay lowered for a Lightroom dialog.":(fullScreen == true ? "Overlay at normal level; revealed title bar clips the overlay content.":"Overlay at normal level while another app is active.")
        return true
    }
    func updateTitlebarClip(fullScreen:Bool?,pid:pid_t) {
        guard fullScreen == true else { return }
        switch overlayController.overlayAccessibility?.revealedTitlebar(pid:pid) ?? .unknown {
        case .unknown: break // Retain the last mask through transient/animation read failures.
        case .hidden: overlayController.revealedTitlebar=nil
        case .visible(let frame): overlayController.revealedTitlebar=frame
        }
        overlayController.titlebarClipStatus=overlayController.overlayAccessibility?.titlebarStatus ?? "AX unavailable; retaining previous clip"
        applyTitlebarClip()
    }
    func applyTitlebarClip() {
        let windows=([panel].compactMap { $0 }) + axTrialBorders.compactMap { $0 as? OverlayPanel }
        for window in windows {
            let depth=OverlayBehaviourPolicy.titlebarClipHeight(overlay:window.frame,titlebar:overlayController.revealedTitlebar)
            if depth != window.titlebarClipHeight { diagnostics.windowOrdering.event("title-bar clip id=\(window.windowNumber) top=\(depth); frame unchanged") }
            window.clipTop(depth)
        }
    }
    func hide() {
        overlayController.revealedTitlebar=nil;overlayController.titlebarClipStatus="overlay not shown"
        diagnostics.windowOrdering.event("overlay hide requested")
        clearAXTrialBorders()
        if destination == .overlay { cancelRequest() }
        (panel?.contentView as? ReferenceView)?.releaseContent()
        panel?.orderOut(nil); panel = nil;overlayController.attemptedSelectionRefresh=nil;overlayController.livePanelSignature=nil;overlayController.displayedOverlayLayout=nil;overlayController.displayedOverlayModule=nil;overlayController.overlayHost=nil;overlayController.overlayGeometrySettler.reset();overlayController.overlayAccessibility=nil;overlayController.overlayBaselineWindows=[];overlayController.overlayDialogVisible=false;overlayController.overlayEpoch=nil;overlayController.overlaySuspended=false;updateIcon()
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
        p.contentView = view; panel = p;overlayController.livePanelSignature=axPlacementEnabled ? pendingAXPanelSignature:nil;overlayController.displayedOverlayLayout=overlayLayout;overlayController.displayedOverlayModule=currentModule();overlayController.overlayMoveCount=0;overlayController.overlayOrderCount=0;overlayController.overlayLevelChangeCount=0;
        overlayController.overlayGeometrySettler.reset()
        overlayController.lifecycleTrace=[];overlayController.lastLifecycleEvent="";recordLifecycle("overlay created")
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
        applyTitlebarClip()
        lastLayout += "\nOverlay content bounds: \(view.bounds). Photo viewport (view): \(view.imageViewport!). Panel visible: \(p.isVisible). Display scale: \(p.backingScaleFactor)."
        guard p.isVisible else { hide();report("Overlay panel did not become visible; see geometry diagnostics.");return nil }
        if screenshotAXDismissEnabled,let hints=lightroomMonitor.invocationPanelHints,let host=overlayController.overlayHost,
           axTrialHostMatches(proposedTopLeft:hints.host,actualAppKit:host.frame,primaryHeight:CGDisplayBounds(CGMainDisplayID()).height) {
            overlayController.livePanelSignature=hints.signature
        }
        updateIcon()
        if let started=photoRequests.invocationStart { lastTiming += String(format:"; total to panel shown %.0f ms",(ProcessInfo.processInfo.systemUptime-started)*1000) }
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
            p.isFloatingPanel = true; p.hidesOnDeactivate = false
            // isFloatingPanel can reset the level; apply the final level afterward.
            p.level = FloatingPanel.presentationLevel
            p.collectionBehavior = FloatingPanel.presentationCollection
            p.isReleasedWhenClosed = false; p.backgroundColor = .black; p.delegate = self
            p.appearance = NSAppearance(named: .darkAqua)
            let view = ReferenceView(frame: NSRect(origin: .zero, size: size))
            configureImageView(view)
            view.movesWindowAtFit=true
            view.toolTip=referenceInteractionHint(floating:true)
            p.acceptsMouseMovedEvents=true
            view.zoomChanged = { [weak self] percentage in
                self?.floatingController.floatingZoom=percentage
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
        floatingController.floatingTitle=filename + " — " + origin.rawValue + " · Camera Reference"
        updateFloatingTitle()
        floating?.orderFrontRegardless()
        diagnostics.windowOrdering.event("floating orderFrontRegardless level=\(floating?.level.rawValue.description ?? "none")")
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
        view.toolTip=referenceInteractionHint(floating:false)
    }
    func reloadOverlay() {
        guard panel != nil, supportedLightroomModule(currentModule()) else { return }
        hide(); request(.overlay)
    }
}
