import AppKit
import Carbon
import ImageIO
import ApplicationServices

enum Destination: String { case overlay, window, check, detect }
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation, NSMenuDelegate {
    var diagnosticsWindow:DiagnosticsController?
    var capturePreview:CapturePreviewController?
    var captureBaseline:CapturePreviewController?
    var captureBaselineGeometry:(CGWindowID,CGRect)?
    var captureBaselineSummary=""
    var saving = false
    let saveToast=SaveToastController()
    var floatingTitle="Camera Reference"
    private var versionTitle: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        return "\(Bundle.main.object(forInfoDictionaryKey:"CFBundleDisplayName") as? String ?? "Camera Reference") \(version)"
    }
    var floatingZoom:Double=0
    var calibrationTask:Task<Void,Never>?
    var calibrationTimer:Timer?
    var regionResetting=false
    var screenTimeout:Timer?
    var detectionCompletion:((ScreenProbeResult)->Void)?
    var acceptedSplitKey:String?
    var lastProbe:ScreenProbeResult?
    var manualLayoutKey:String? {
        get { CameraPreferences.shared.string(forKey:regionKey("manualLayoutKey")) }
        set { CameraPreferences.shared.set(newValue,forKey:regionKey("manualLayoutKey")) }
    }
    func updateFloatingTitle() { floating?.title=floatingTitle + String(format:" — %.1f%%",floatingZoom) }
    let detectionSettings=DetectionConfigStore()
    var configEditor:ConfigEditorController?
    var observedWindowFrame:CGRect?
    var hasObservedWindow=false
    var lastImageSize: CGSize?
    var legacyBridgeConsolidated=false
    var nextLegacyCheck:TimeInterval=0
    var storageStatus=""
    func consolidateStorageIfDue() {
        guard !legacyBridgeConsolidated,ProcessInfo.processInfo.systemUptime>=nextLegacyCheck else { return }
        nextLegacyCheck=ProcessInfo.processInfo.systemUptime+5
        do {
            legacyBridgeConsolidated=try consolidateSupportDirectory(applicationSupport:folder.deletingLastPathComponent().deletingLastPathComponent())
            storageStatus=legacyBridgeConsolidated ? "Storage: consolidated under CameraReference." : "Storage migration waiting: stop the old bridge and reload bridge 0.5.3. The old bridge folder is still active."
        } catch { storageStatus="Storage migration deferred: \(error.localizedDescription)" }
    }
    let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/CameraReference/Bridge")
    var floating: NSPanel?
    var floatingView: ReferenceView?
    var preferItem: NSMenuItem!
    var autoItem: NSMenuItem!
    var cancellation: Cancellation?
    var destination: Destination?
    var pendingModule:String?
    var moduleTimer: Timer?
    var lastModuleSample: (String, Date)?
    var observedModule:String?
    var placementModule:String?
    var screenModule:String?
    var lastLayout = "Automatic detection has not been tested."
    var status: NSStatusItem!
    var detail: NSMenuItem!
    var shortcutItem: NSMenuItem!
    var panel: OverlayPanel?
    var overlayHost:HostWindowSnapshot?
    var displayedOverlayLayout:OverlayLayout?
    var displayedOverlayModule:String?
    var overlayGeometrySettler=OverlayGeometrySettler()
    var overlayGeometrySource="not sampled"
    var overlayAccessibility:LightroomHostAccessibility?
    var nextAccessibilityBind:TimeInterval=0
    var accessibilityBindingStatus="Host binding not attempted; show an overlay first."
    var lifecycleTrace:[String]=[]
    var lastLifecycleEvent=""
    func recordLifecycle(_ event:String) {
        guard event != lastLifecycleEvent else { return }
        lastLifecycleEvent=event
        lifecycleTrace.append(String(format:"%.3f ",ProcessInfo.processInfo.systemUptime)+event)
        lifecycleTrace=Array(lifecycleTrace.suffix(12))
    }
    func bindOverlayAccessibility(pid:pid_t,frame:CGRect) {
        guard overlayAccessibility == nil,ProcessInfo.processInfo.systemUptime>=nextAccessibilityBind else { return }
        nextAccessibilityBind=ProcessInfo.processInfo.systemUptime+1
        overlayAccessibility=LightroomHostAccessibility(pid:pid,hostFrame:frame,diagnostic:&accessibilityBindingStatus)
        overlayAccessibility?.onMinimized={ [weak self] in self?.suspendOverlay(reason:"Lightroom minimise notification") }
    }
    var overlayBaselineWindows=Set<CGWindowID>()
    var overlayDialogVisible=false
    var overlayLifecycleStatus="Window lifecycle not sampled."
    func updateOverlayLifecycle() {
        guard let saved=overlayHost,let owner=NSWorkspace.shared.runningApplications.first(where:isLightroomApp) else { return }
        bindOverlayAccessibility(pid:owner.processIdentifier,frame:saved.frame)
        let windows=lightroomWindowMetadata(pid:owner.processIdentifier)
        overlayDialogVisible=(overlayAccessibility?.hasDialog ?? false) || (windows.map { hasNewLightroomDialog(windows:$0,host:saved.id,baseline:overlayBaselineWindows) } ?? false)
        let minimized=overlayAccessibility?.minimized
        overlayLifecycleStatus="Lifecycle: minimise notifications \(overlayAccessibility?.watchesMinimize == true ? "active":"unavailable"); dialog \(overlayDialogVisible); minimised \(minimized.map(String.init) ?? "unavailable"); \(overlayAccessibility == nil ? "window-list fallback":"Accessibility + window list")."
        overlayLifecycleStatus += "\n" + accessibilityBindingStatus + "\n" + (overlayAccessibility?.diagnostic ?? "No AX observer; window-list fallback.")
    }
    var overlayEpoch:String?
    var overlaySuspended=false
    var overlayResumeAfter:TimeInterval=0
    var workspaceOverview=false
    var overlayVisibilityStatus="Overlay not shown."
    var overlayMoveCount=0
    var overlayOrderCount=0
    var overlayLevelChangeCount=0
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
        switch overlayHostAction(saved:saved.frame,current:current?.frame,onScreen:current?.onScreen ?? false,overview:workspaceOverview) {
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
    let imageCache=SelectionImageCache()
    var screenshotDetectionEnabled:Bool {
        (CameraPreferences.shared.object(forKey:"useScreenshotDetection") as? Bool) ?? (legacyPlacementMode != .accessibility)
    }
    var legacyPlacementMode:AutomaticPlacementMode {
        AutomaticPlacementMode.resolve(saved:CameraPreferences.shared.string(forKey:"automaticPlacementMode"),
            legacy:CameraPreferences.shared.object(forKey:"experimentalAXPlacement") as? Bool)
    }
    var screenshotAssistanceEnabled:Bool {
        (CameraPreferences.shared.object(forKey:"screenshotAXAssistance") as? Bool) ?? (legacyPlacementMode == .assisted)
    }
    var automaticPlacementMode:AutomaticPlacementMode {
        screenshotDetectionEnabled ? (screenshotAssistanceEnabled ? .assisted:.screenshot):.accessibility
    }
    var axPlacementEnabled:Bool { !screenshotDetectionEnabled }
    var assistedPlacementEnabled:Bool { screenshotDetectionEnabled && screenshotAssistanceEnabled }
    var screenshotToggleItem:NSMenuItem?,assistedToggleItem:NSMenuItem?,viewToggleItem:NSMenuItem?
    var detectionMethodItems=[NSMenuItem]()
    var assistedSignature:String?
    var assistedChecks=0,assistedAXChanges=0,assistedAXFailures=0,assistedPixelChanges=0,assistedPixelFailures=0
    var assistedCheckSeconds:Double=0,assistedAXSeconds:Double=0
    var assistedEvidence="No assisted comparison yet."
    static func screenHints(module:String?)->AXScreenHints? {
        let toolbar=accessibilityToolbarReading(module:module)
        var hints:AXScreenHints?
        _=accessibilityMappingReport { host,windows in
            hints=AXScreenHints(host:host,visibleFrames:windows.filter(\.visible).map(\.frame),
                toolbar:toolbar.shown.map { $0 ? "shown":"hidden" } ?? "unknown")
        }
        return hints
    }
    var automaticViewEnabled:Bool { automaticPlacementMode.usesAXViewDetection(screenshotOption:CameraPreferences.shared.bool(forKey:"experimentalAutomaticView")) }
    var detectedLayout:OverlayLayout?
    var detectedLayoutModule:String?
    var viewProbeID:UUID?
    var liveViewBusy=false
    var nextLiveViewCheck:TimeInterval=0
    var liveViewGeneration=0
    var diagnosticGeneration=0
    var diagnosticPending=false
    var diagnosticRunningGeneration = -1
    var lastViewDetection="Automatic view detection disabled."
    var lastGridStatus="Grid menu not sampled."
    var livePanelAdjustment:Bool { CameraPreferences.shared.bool(forKey:"adjustOverlayLiveWithPanels") }
    var livePanelSignature:String?
    var livePanelRefreshNeeded=false
    @objc func toggleLivePanels(_ item:NSMenuItem) {
        CameraPreferences.shared.set(!livePanelAdjustment,forKey:"adjustOverlayLiveWithPanels")
        item.state=livePanelAdjustment ? .on:.off
        livePanelSignature=nil;livePanelRefreshNeeded=livePanelAdjustment && screenshotDetectionEnabled && panel != nil;nextLiveViewCheck=0
    }
    var dismissOnViewChange:Bool { CameraPreferences.shared.bool(forKey:"dismissOverlayOnViewChange") }
    @objc func toggleDismissOnViewChange(_ item:NSMenuItem) {
        CameraPreferences.shared.set(!dismissOnViewChange,forKey:"dismissOverlayOnViewChange")
        item.state=dismissOnViewChange ? .on:.off
    }
    func dismissForGrid() {
        cancelScreenInspection();cancelRequest();hide()
        lastViewDetection="Grid View selected; overlay off. Returning to Loupe does not reopen it."
        report(lastViewDetection);saveInvocationDiagnostics()
    }
    var manualOverlayLayout:OverlayLayout { savedOverlayLayout(CameraPreferences.shared,module:currentModule() ?? observedModule) }
    var overlayLayout:OverlayLayout {
        get {
            if automaticViewEnabled,detectedLayoutModule == currentModule(),let mode=detectedLayout,
               CameraPreferences.shared.bool(forKey:regionKey("automaticBounds",layout:manualOverlayLayout)) { return mode }
            return manualOverlayLayout
        }
        set { CameraPreferences.shared.set(newValue.rawValue,forKey:overlayLayoutPreferenceKey(module:currentModule() ?? observedModule)) }
    }
    var layoutItems=[OverlayLayout:NSMenuItem]()
    var layoutGroups=[Int:NSMenuItem]()
    var layoutSeparator:NSMenuItem?
    var placementMemory:PlacementMemory?
    func regionKey(_ key:String,layout:OverlayLayout? = nil)->String {
        let base=regionPreferenceKey(key,layout:layout ?? (key == "automaticBounds" && automaticViewEnabled ? manualOverlayLayout:overlayLayout))
        return currentModule() == "library" ? "library."+base:base
    }
    var floatingHotKey: EventHotKeyRef?
    var floatingShortcut=(UInt32(kVK_ANSI_F),UInt32(controlKey | optionKey | cmdKey))
    var floatingKeyLabel="F"
    var floatingMenuItem:NSMenuItem!
    var hotKey: EventHotKeyRef?
    var handler: EventHandlerRef?
    var pending: String?
    var timer: Timer?
    var calibration: CalibrationController?
    var displayTimer: Timer?
    var screenTask: Task<Void, Never>?
    var screenInspectionID: UUID?
    var toggleItem: NSMenuItem!
    var keyLabel = "J"
    var recording = false
    var currentShortcut: (UInt32, UInt32) = (UInt32(kVK_ANSI_J), UInt32(controlKey | optionKey | cmdKey))
    var savedRegion: NSRect? {
        guard let text=CameraPreferences.shared.string(forKey:regionKey("region")) else { return nil }
        return NSRectFromString(text)
    }
    var region: NSRect? {
        get {
            guard let r=savedRegion else { return nil }
            let saved=CameraPreferences.shared.data(forKey:regionKey("regionDisplay")).flatMap { try? JSONDecoder().decode(DisplayGeometry.self,from:$0) }
            guard calibratedRegionIsUsable(r,savedDisplay:saved,current:currentDisplays()) else { return nil }
            if let text=CameraPreferences.shared.string(forKey:regionKey("regionWindow")),let current=lightroomWindowFrame() {
                return translatedCalibration(r,from:NSRectFromString(text),to:current)
            }
            return r
        }
        set {
            guard let newValue else { return } // Temporary display changes never erase calibration.
            CameraPreferences.shared.set(NSStringFromRect(newValue),forKey:regionKey("region"))
            if let frame=lightroomWindowFrame() { CameraPreferences.shared.set(NSStringFromRect(frame),forKey:regionKey("regionWindow")) }
            else { CameraPreferences.shared.removeObject(forKey:regionKey("regionWindow")) }
            if let screen=currentDisplays().first(where:{$0.frame.contains(newValue)}), let data=try? JSONEncoder().encode(screen) {
                CameraPreferences.shared.set(data,forKey:regionKey("regionDisplay"))
            }
        }
    }
    var panelCheckTask:Task<Void,Never>?
    var panelCheckID:UUID?
    var nextPanelCheck:TimeInterval=0
    var panelCheckStatus="Panel boundaries not yet checked in background."
    func cancelPanelCheck() { panelCheckTask?.cancel();panelCheckTask=nil;panelCheckID=nil }
    func checkPanelBoundariesIfDue() {
        guard !axPlacementEnabled else { cancelPanelCheck();panelCheckStatus="AX-only mode: background screenshot checks disabled; fresh AX geometry on invocation.";return }
        guard FeaturePermission.screenCapture.granted else { cancelPanelCheck();panelCheckStatus="Background capture paused: Screen Recording permission unavailable.";return }
        if livePanelAdjustment,livePanelRefreshNeeded,CameraPreferences.shared.bool(forKey:regionKey("automaticBounds")),ProcessInfo.processInfo.systemUptime>=nextPanelCheck,
           screenTask==nil,pending==nil,viewProbeID==nil,calibration==nil,!recording,!regionResetting,
           !workspaceOverview,!overlaySuspended,isLightroom() {
            let interval=reloadDetectionConfig().panelCheckIntervalSeconds
            if interval>0 {
                nextPanelCheck=ProcessInfo.processInfo.systemUptime+interval
                followLiveOverlayView(overlayLayout,module:currentModule(),requiresViewDetection:false,panelChange:true)
            }
            return
        }
        guard #available(macOS 14.0,*),ProcessInfo.processInfo.systemUptime>=nextPanelCheck,
              panelCheckTask==nil,screenTask==nil,pending==nil,calibration==nil,!recording,!regionResetting,
              !workspaceOverview,!overlaySuspended,isLightroom(),supportedLightroomModule(currentModule()),CameraPreferences.shared.bool(forKey:regionKey("automaticBounds")),
              let memory=placementMemory,memory.layout==overlayLayout,let imageSize=lastImageSize,
              (selectionEpoch()==memory.epoch || (livePanelAdjustment && panel != nil && displayedOverlayLayout==memory.layout)) else { return }
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
              placementMemory?.epoch==memory.epoch,
              (selectionEpoch()==memory.epoch || (livePanelAdjustment && panel != nil && displayedOverlayLayout==memory.layout)),
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
            if livePanelAdjustment,panel != nil {
                livePanelRefreshNeeded=true
                followLiveOverlayView(overlayLayout,module:currentModule(),requiresViewDetection:false,panelChange:true)
            }
            if panel != nil { overlayVisibilityStatus="Overlay retained; cached placement invalidated: \(reason.lowercased())." }
        } else { panelCheckStatus="Background check: UI boundaries unchanged. Repeated toggle can skip capture." }
        panelCheckStatus += String(format:" 1280px check: %.0f ms elapsed.",elapsed*1000)
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

    func buildLayoutMenu(_ menu:NSMenu) {
        layoutSeparator=NSMenuItem.separator();menu.addItem(layoutSeparator!)
        let full=add("▣  Loupe View",#selector(selectLayout(_:)),to:menu)
        full.representedObject=OverlayLayout.full.rawValue;full.image=layoutMenuIcon(.full);layoutItems[.full]=full
        for (title,modes) in [("◧  Reference View (Left/Right)",[OverlayLayout.left,.right]),("⬒  Reference View (Top/Bottom)",[OverlayLayout.upper,.lower])] {
            let parent=NSMenuItem(title:title,action:nil,keyEquivalent:"")
            parent.image=layoutMenuIcon(modes[0]);let child=NSMenu(title:title);parent.submenu=child;menu.addItem(parent)
            layoutGroups[modes[0].group]=parent
            for mode in modes {
                let item=add((mode == .left ? "◧":mode == .right ? "◨":mode == .upper ? "⬒":"⬓")+"  "+mode.label,#selector(selectLayout(_:)),to:child)
                item.representedObject=mode.rawValue;item.image=layoutMenuIcon(mode);layoutItems[mode]=item
            }
        }
        updateLayoutMenu()
    }
    func updateLayoutMenu() {
        let hidden = !CameraPreferences.shared.bool(forKey:regionKey("automaticBounds"))
        layoutSeparator?.isHidden=hidden
        layoutItems[.full]?.isHidden=hidden
        for item in layoutGroups.values { item.isHidden=hidden }
        let inferred=detectedLayoutModule == currentModule() ? detectedLayout:nil
        layoutItems[.full]?.action = automaticViewEnabled ? nil:#selector(selectLayout(_:))
        if automaticViewEnabled && !hidden {
            layoutItems[.full]?.title = inferred == nil ? "View detected on next invocation":"▣  Loupe View"
            layoutItems[.full]?.isEnabled=false
            layoutItems[.full]?.isHidden = inferred != nil && overlayLayout.group != 0
            for (group,item) in layoutGroups { item.isHidden = inferred == nil || group != overlayLayout.group }
        } else { layoutItems[.full]?.title="▣  Loupe View";layoutItems[.full]?.isEnabled=true }
        for (mode,item) in layoutItems { item.state=mode==overlayLayout ? .on:.off }
        for (group,item) in layoutGroups { item.state=group==overlayLayout.group ? .on:.off }
    }
    @objc func selectLayout(_ sender:NSMenuItem) {
        guard let raw=sender.representedObject as? String,let mode=OverlayLayout(rawValue:raw),mode != overlayLayout else { return }
        if automaticViewEnabled && (mode.group==0 || mode.group != overlayLayout.group) { return }
        cancelScreenInspection();cancelRequest();calibration?.finish(nil)
        if automaticViewEnabled {
            CameraPreferences.shared.set(mode.rawValue,forKey:"axPreferredPane.\(currentModule() ?? "develop").\(mode.group)")
            detectedLayout=mode
        } else { overlayLayout=mode }
        CameraPreferences.shared.set(true,forKey:regionKey("automaticBounds"))
        invalidateAutomaticGeometry();updateLayoutMenu()
        autoItem.state=CameraPreferences.shared.bool(forKey:regionKey("automaticBounds")) ? .on:.off
        report(mode == .full ? "Loupe View selected.":"\(mode.label) pane selected.")
        followLiveOverlayView(mode,module:currentModule(),requiresViewDetection:false)
    }
    func calibratedUI(_ mode:OverlayLayout)->CGRect? {
        guard let text=CameraPreferences.shared.string(forKey:regionKey("region",layout:mode)) else { return nil }
        let rect=NSRectFromString(text)
        let display=CameraPreferences.shared.data(forKey:regionKey("regionDisplay",layout:mode)).flatMap { try? JSONDecoder().decode(DisplayGeometry.self,from:$0) }
        guard calibratedRegionIsUsable(rect,savedDisplay:display,current:currentDisplays()),
              let saved=CameraPreferences.shared.string(forKey:regionKey("regionWindow",layout:mode)),let window=lightroomWindowFrame(),
              let translated=translatedCalibration(rect,from:NSRectFromString(saved),to:window),window.contains(translated),
              NSScreen.screens.contains(where:{$0.frame.contains(translated)}) else { return nil }
        return translated
    }
    func cachedUI(epoch:String?,settings:DetectionConfig,layout:OverlayLayout)->CGRect? {
        guard placementModule==currentModule(),let memory=placementMemory,let current=lightroomWindowFrame(),
              let cg=currentCaptureWindowFrame(memory.windowID),sameWindowGeometry(current,appKitRect(cg,primaryHeight:CGDisplayBounds(CGMainDisplayID()).height)),
              let ui=memory.translated(window:current,windowID:memory.windowID,epoch:epoch,settingsKey:settings.key,layout:layout),
              NSScreen.screens.contains(where:{$0.frame.intersects(ui)}) else { return nil }
        lastTiming += "; placement cache hit; capture skipped"
        lastLayout="Reused \(layout.label) UI bounds (AppKit): \(ui). Window size unchanged; position translated. Clear region setting after internal panel changes."
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
        guard supportedLightroomModule(currentModule()),#available(macOS 14.0,*),FeaturePermission.screenCapture.granted else { report("Screenshot sizing unavailable. Screen Recording permission and macOS 14 are required. Use AX placement or manual calibration.");return }
        startPhotoDetection(imageSize:imageSize,layout:.full) { [weak self] probe in
            guard let self else { return }
            if let epoch,self.selectionEpoch() != epoch { self.report("Selection changed during capture; invoke again.");return }
            guard let ui=probe.uiFrame else { self.askForCalibration(workingAreaTooNarrow:probe.workingAreaTooNarrow);return }
            self.rememberPlacement(probe,epoch:epoch,settings:settings,layout:.full)
            show(ui)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if NSWorkspace.shared.runningApplications.contains(where:{
            $0.processIdentifier != ProcessInfo.processInfo.processIdentifier &&
            ["org.local.CameraReference","org.local.CameraReference.testing"].contains($0.bundleIdentifier ?? "")
        }) {
            let alert=NSAlert();alert.messageText="Camera Reference is already running"
            alert.informativeText="Quit the other copy before opening this one. Stable and testing share the Lightroom bridge and settings."
            NSApp.activate(ignoringOtherApps:true);alert.runModal();NSApp.terminate(nil);return
        }
        if let url=Bundle.main.url(forResource:"AppIcon",withExtension:"icns") { NSApp.applicationIconImage=NSImage(contentsOf:url) }
        CameraPreferences.shared.register(defaults:Dictionary(uniqueKeysWithValues:OverlayLayout.allCases.map {
            ("library."+regionPreferenceKey("automaticBounds",layout:$0),true)
        }))
        // Carry only calibration and shortcut settings forward; no photo paths or images.
        if !CameraPreferences.shared.bool(forKey: "migrated03") {
            if let old = CameraPreferences.shared.persistentDomain(forName: "org.local.JPEGReference") {
                for key in ["region", "key", "modifiers"] {
                    if let value = old[key] { CameraPreferences.shared.set(value, forKey: key) }
                }
            }
            CameraPreferences.shared.set(true, forKey: "migrated03")
        }
        do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]) }
        catch { fatalError("Cannot create bridge directory: \(error)") }
        consolidateStorageIfDue()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()
        let menu = NSMenu(); menu.delegate=self
        menu.addItem(NSMenuItem(title: versionTitle, action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        detail = NSMenuItem(title: "Ready — first test: Check selected photo", action: nil, keyEquivalent: "")
        floatingMenuItem = add("Show floating display", #selector(openFloating), to: menu)
        toggleItem = add("Show overlay", #selector(menuToggle), to: menu)
        func submenu(_ title: String) -> NSMenu {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let child = NSMenu(title: title); item.submenu = child; menu.addItem(item); return child
        }
        buildLayoutMenu(menu)
        menu.addItem(.separator())
        let settings = submenu("Settings")
        shortcutItem = add("Keyboard shortcuts…", #selector(changeShortcut), to: settings)
        settings.addItem(.separator())
        preferItem = add("Prefer RAW-embedded JPEG", #selector(changePreference), to: settings)
        preferItem.state = CameraPreferences.shared.bool(forKey: "preferEmbedded") ? .on : .off
        add("Choose ExifTool…", #selector(chooseExifTool), to: settings)
        settings.addItem(.separator())
        let dismissView=add("Dismiss overlay when view changes",#selector(toggleDismissOnViewChange(_:)),to:settings)
        dismissView.state=dismissOnViewChange ? .on:.off
        let livePanels=add("Adjust overlay live with LrC panels",#selector(toggleLivePanels(_:)),to:settings)
        livePanels.state=livePanelAdjustment ? .on:.off
        settings.addItem(.separator())
        autoItem = add("Auto-detect viewing area", #selector(changeAutomatic), to: settings)
        autoItem.state = CameraPreferences.shared.bool(forKey: regionKey("automaticBounds")) ? .on : .off
        add("Set overlay region…", #selector(calibrate), to: settings)
        add("Clear overlay region setting", #selector(clearAllRegionData), to: settings)
        settings.addItem(.separator())
        let method=NSMenuItem(title:"Detection method",action:nil,keyEquivalent:"")
        let methods=NSMenu();method.submenu=methods;settings.addItem(method);screenshotToggleItem=method
        for (title,value) in [("Screenshot",true),("Accessibility",false)] {
            let item=add(title,#selector(selectDetectionMethod(_:)),to:methods)
            item.representedObject=value;detectionMethodItems.append(item)
        }
        viewToggleItem=add("AX view detection",#selector(toggleAutomaticView),to:settings)
        assistedToggleItem=add("AX-assisted placement",#selector(toggleScreenshotAssistance),to:settings)
        assistedToggleItem?.indentationLevel=1;viewToggleItem?.indentationLevel=1
        updateDetectionMenu()
        settings.addItem(.separator())
        add("Advanced settings…", #selector(editAdvancedSettings), to: settings)
        let developer = submenu("Developer tools")
        developer.addItem(detail); developer.addItem(.separator())
        add("Diagnostics…", #selector(showDiagnostics), to: developer)
        let copy=add("Save diagnostics after invocation", #selector(toggleAutoDiagnostics), to: developer)
        copy.state = autoDiagnostics ? .on:.off
        developer.addItem(.separator())
        let experimental=NSMenu();let experimentalItem=NSMenuItem(title:"Experimental features",action:nil,keyEquivalent:"")
        experimentalItem.submenu=experimental;developer.addItem(experimentalItem)
        let trial=add("Show AX placement preview",#selector(toggleAXTrial),to:experimental)
        trial.state=axTrialEnabled ? .on:.off
        let actions=NSMenu();let actionsItem=NSMenuItem(title:"Capture / bridge actions",action:nil,keyEquivalent:"")
        actionsItem.submenu=actions;developer.addItem(actionsItem)
        add("Check selected photo", #selector(checkPhoto), to: actions)
        add("Inspect Lightroom view state…", #selector(inspectViewState), to: actions)
        add("Keep on-screen capture baseline…", #selector(keepCaptureBaseline), to: actions)
        add("Preview captured Lightroom window…", #selector(previewCapture), to: actions)
        add("Find viewing area…", #selector(inspectScreen), to: actions)
        menu.addItem(.separator())
        add("Quit Camera Reference", #selector(quit), to: menu)
        status.menu = menu
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            var identifier=EventHotKeyID()
            guard let event, GetEventParameter(event,EventParamName(kEventParamDirectObject),EventParamType(typeEventHotKeyID),nil,MemoryLayout<EventHotKeyID>.size,nil,&identifier) == noErr else { return OSStatus(eventNotHandledErr) }
            let owner=Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            if identifier.id == 2 { owner.openFloating() } else { owner.toggle() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        let prefs = CameraPreferences.shared
        if prefs.object(forKey: "key") != nil {
            currentShortcut = (UInt32(prefs.integer(forKey: "key")), UInt32(prefs.integer(forKey: "modifiers")))
        }
        keyLabel=prefs.string(forKey:"keyLabel") ?? (currentShortcut.0 == UInt32(kVK_ANSI_J) ? "J" : "Key \(currentShortcut.0)")
        if prefs.data(forKey:regionKey("regionDisplay")) == nil, let previous=region { region=previous }
        updateToggleTitle()
        if !register(currentShortcut) { report("Shortcut unavailable. Choose Change shortcut.") }
        if prefs.object(forKey:"floatingKey") != nil {
            floatingShortcut=(UInt32(prefs.integer(forKey:"floatingKey")),UInt32(prefs.integer(forKey:"floatingModifiers")))
            floatingKeyLabel=prefs.string(forKey:"floatingKeyLabel") ?? "F"
        }
        if !register(floatingShortcut,floatingTarget:true) { report("Floating display shortcut unavailable.") }
        updateToggleTitle()
        moduleTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.consolidateStorageIfDue()
            let epoch=self.selectionEpoch()
            self.imageCache.observe(epoch)
            let module=self.currentModule()
            if let memory=self.placementMemory {
                // Retain old-epoch geometry only to monitor the still-open photo.
                // cachedUI continues to require the new invocation's exact epoch.
                let monitoring=self.livePanelAdjustment && self.panel != nil && self.displayedOverlayModule==module && self.displayedOverlayLayout==memory.layout
                if (memory.epoch != epoch && !monitoring) || !supportedLightroomModule(module) { self.placementMemory=nil }
            }
            if confirmedModuleChange(previous:self.observedModule,current:module) {
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
            // Module/heartbeat uncertainty invalidates reuse, not the user-visible image.
        }
        if let moduleTimer { RunLoop.main.add(moduleTimer,forMode:.common) }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(frontAppChanged), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(spaceChanged),name:NSWorkspace.activeSpaceDidChangeNotification,object:nil)
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }
    @discardableResult func add(_ title: String, _ action: Selector, to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item); return item
    }
    func register(_ shortcut: (UInt32, UInt32), floatingTarget:Bool=false) -> Bool {
        var replacement: EventHotKeyRef?
        let result = RegisterEventHotKey(shortcut.0, shortcut.1, EventHotKeyID(signature: 0x43524546, id: floatingTarget ? 2:1), GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &replacement)
        guard result == noErr else { return false }
        if floatingTarget {
            if let floatingHotKey { UnregisterEventHotKey(floatingHotKey) }
            floatingHotKey=replacement; floatingShortcut=shortcut
        } else {
            if let hotKey { UnregisterEventHotKey(hotKey) }
            hotKey = replacement; currentShortcut = shortcut
        }
        return true
    }
    func isLightroom() -> Bool {
        let app = NSWorkspace.shared.frontmostApplication
        return app?.bundleIdentifier?.hasPrefix("com.adobe.LightroomClassic") == true || app?.localizedName == "Adobe Lightroom Classic"
    }
    var lastResult = "No check yet."
    var lastTiming="No timing sample yet."
    var lastPlacementFailure="No placement failure recorded this session."
    var invocationStart:TimeInterval?
    func report(_ text: String) {
        lastResult = text; detail.title = String(text.prefix(100)); status.button?.toolTip = text
        DispatchQueue.main.async { [weak self] in
            guard let self,self.savingInvocation else { return }
            self.saveInvocationDiagnostics()
            if self.pending == nil && self.screenInspectionID == nil && self.panel == nil && self.viewProbeID == nil { self.savingInvocation=false;self.collectCompleteDiagnostics() }
        }
    }
    func updateIcon() {
        let visible = panel != nil
        status?.button?.image = NSImage(systemSymbolName: visible ? "camera.fill" : "camera", accessibilityDescription: visible ? "Camera Reference overlay visible" : "Camera Reference")
        status?.button?.image?.isTemplate = true
        status?.button?.title = ""
        updateToggleTitle()
    }
    func cancelRequest() {
        viewProbeID=nil
        cancellation?.cancel(); cancellation = nil; pending = nil; destination = nil
        timer?.invalidate(); timer = nil
        try? FileManager.default.removeItem(at: folder.appendingPathComponent("request.txt"))
        try? FileManager.default.removeItem(at: folder.appendingPathComponent("response.txt"))
        updateToggleTitle()
    }
    func hide() {
        clearAXTrialBorders()
        if destination == .overlay { cancelRequest() }
        (panel?.contentView as? ReferenceView)?.releaseContent()
        panel?.orderOut(nil); panel = nil;livePanelSignature=nil;livePanelRefreshNeeded=false;displayedOverlayLayout=nil;displayedOverlayModule=nil;overlayHost=nil;overlayGeometrySettler.reset();overlayAccessibility=nil;overlayBaselineWindows=[];overlayDialogVisible=false;overlayEpoch=nil;overlaySuspended=false;updateIcon()
    }
    func currentModule() -> String? {
        let url = folder.appendingPathComponent("heartbeat.txt")
        if let a = try? FileManager.default.attributesOfItem(atPath: url.path),
           let date = a[.modificationDate] as? Date, Date().timeIntervalSince(date) < 3,
           let text = try? String(contentsOf: url, encoding: .utf8) {
            let lines = text.components(separatedBy: "\n")
            if lines.count == 4, lines[2] == "END" { lastModuleSample = (lines[1], date) }
        }
        // A read can overlap a tiny heartbeat write. Keep the last complete sample until stale.
        guard let (module, date) = lastModuleSample, Date().timeIntervalSince(date) < 3 else { return nil }
        return module
    }
    @objc func frontAppChanged() {
        let own=NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier
        if !isLightroom() { cancelPanelCheck() }
        if !isLightroom() && !own { saveToast.close(); calibration?.finish(nil) }
        _ = orderOverlayAboveLightroom()
    }
    func invalidateAutomaticGeometry() {
        cancelPanelCheck()
        if livePanelAdjustment,panel != nil { livePanelRefreshNeeded=true }
        lastProbe=nil;placementMemory=nil
        Task { await ScreenGeometryCache.shared.reset() }
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
        displayTimer?.invalidate()
        displayTimer=Timer.scheduledTimer(withTimeInterval:0.6,repeats:false) { [weak self] _ in
            guard let self,self.savedRegion != nil else { return }
            self.report(self.region != nil ? "Display checked: saved calibration retained." : "Saved calibration retained, but this display layout differs. Restore the display layout or calibrate again.")
        }
    }
    func updateToggleTitle() {
        floatingMenuItem?.title=(floating?.isVisible == true ? "Hide floating display" : "Show floating display") + "   " + shortcutText(key:floatingKeyLabel,modifiers:floatingShortcut.1)
        let active=panel != nil || destination == .overlay || viewProbeID != nil || detectionCompletion != nil
        toggleItem?.title=(active ? "Hide overlay" : "Show overlay") + "   " + shortcutText(key:keyLabel,modifiers:currentShortcut.1)
    }
    func menuNeedsUpdate(_ menu:NSMenu) { updateToggleTitle();updateLayoutMenu();updateDetectionMenu() }
    @objc func menuToggle() { toggle() }
    func toggle() {
        if recording || calibration != nil { return }
        if destination == .overlay || viewProbeID != nil || panel != nil || detectionCompletion != nil { cancelScreenInspection(); cancelRequest(); hide(); report("Overlay cancelled."); return }
        guard isLightroom() || NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier else {
            report("Bring Lightroom to the front to show the overlay."); return
        }
        if !isLightroom() {
            guard let lr=NSWorkspace.shared.runningApplications.first(where:isLightroomApp) else { report("Lightroom is not running."); return }
            lr.activate(options:[])
        }
        request(.overlay)
    }
    @objc func checkPhoto() { request(.check) }
    func request(_ target: Destination, viewChecked:Bool=false) {
        diagnosticGeneration += 1
        savingInvocation = target == .overlay || target == .window
        guard !regionResetting,requireSupportedModule() else { return }
        if target == .overlay && automaticViewEnabled && !viewChecked && (currentModule()=="library" || detectedLayout == nil || detectedLayoutModule != currentModule()) && CameraPreferences.shared.bool(forKey:regionKey("automaticBounds")) {
            detectInvocationView();return
        }
        cancelPanelCheck();nextPanelCheck=ProcessInfo.processInfo.systemUptime+reloadDetectionConfig().panelCheckIntervalSeconds
        cancelScreenInspection(); cancelRequest()
        let token = UUID().uuidString, work = Cancellation()
        pending = token; destination = target; cancellation = work; pendingModule=currentModule()
        updateToggleTitle()
        let invoked = ProcessInfo.processInfo.systemUptime
        invocationStart=invoked
        do { try (token + "\n" + (target == .detect ? "check" : target.rawValue)).write(to: folder.appendingPathComponent("request.txt"), atomically: true, encoding: .utf8) }
        catch { cancelRequest(); report("Cannot write the bridge request."); return }
        let deadline = Date().addingTimeInterval(5)
        report("Waiting for Lightroom…")
        if target == .window { floating?.title = floatingTitle + " — refreshing…" }
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self, self.pending == token else { timer.invalidate(); return }
            if let text = try? String(contentsOf: self.folder.appendingPathComponent("response.txt"), encoding: .utf8),
               let response = BridgeResponse(text, expected: token) {
                timer.invalidate(); self.timer = nil
                try? FileManager.default.removeItem(at: self.folder.appendingPathComponent("response.txt"))
                try? FileManager.default.removeItem(at: self.folder.appendingPathComponent("request.txt"))
                guard response.success else { self.failed(response.value, target: target); return }
                self.load(response.value, token: token, target: target, work: work, invoked: invoked)
            } else if Date() >= deadline {
                self.failed("Plugin timed out. Reload the updated bridge 0.5.3 in Lightroom’s Plug-in Manager, then use File → Plug-in Extras → Start / restart Camera Reference bridge.", target: target)
            }
        }
    }
    func failed(_ text: String, target: Destination) {
        cancelRequest(); report(text)
        collectCompleteDiagnostics()
        if target == .window { floating?.title = floatingTitle + " — unchanged; refresh failed" }
    }
    func selectionEpoch()->String? {
        let url=folder.appendingPathComponent("selection.txt")
        guard let attrs=try? FileManager.default.attributesOfItem(atPath:url.path),let date=attrs[.modificationDate] as? Date,
              Date().timeIntervalSince(date)<3,let text=try? String(contentsOf:url,encoding:.utf8) else { return nil }
        let lines=text.components(separatedBy:"\n")
        return lines.count==3 && lines[1]=="END" && !lines[0].isEmpty ? lines[0]:nil
    }
    func responseEpoch(_ token:String)->String? {
        guard let text=try? String(contentsOf:folder.appendingPathComponent("response-selection.txt"),encoding:.utf8) else { return nil }
        let lines=text.components(separatedBy:"\n")
        return lines.count==4 && lines[0]==token && lines[2]=="END" ? lines[1]:nil
    }
    func load(_ path: String, token: String, target: Destination, work: Cancellation, invoked: TimeInterval) {
        let requestedModule=pendingModule
        let loadStarted=ProcessInfo.processInfo.systemUptime
        let bridgeMS=(loadStarted-invoked)*1000
        let prefer = CameraPreferences.shared.bool(forKey: "preferEmbedded")
        let executable = findExifTool(custom: CameraPreferences.shared.string(forKey: "exiftool"))
        let liveEpoch=selectionEpoch()
        imageCache.observe(liveEpoch)
        let epoch=responseEpoch(token).flatMap { $0 == liveEpoch ? $0:nil }
        let automatic = false // Screen detection runs after loading, outside the UI thread.
        report("Loading camera JPEG…")
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let result: Result<(LoadedReference, LayoutProbe?), Error> = Result {
                let raw=URL(fileURLWithPath:path)
                let started=ProcessInfo.processInfo.systemUptime
                let signature=epoch == nil ? nil:referenceFileSignature(raw:raw,preferEmbedded:prefer,executable:executable)
                var loaded:LoadedReference
                if let epoch,let signature,let cached=imageCache.value(key:signature,epoch:epoch),selectionEpoch()==epoch {
                    loaded=LoadedReference(image:cached.image,origin:cached.origin,elapsed:ProcessInfo.processInfo.systemUptime-started,extraction:nil,usedFallback:cached.usedFallback,embeddedBytes:cached.embeddedBytes,cameraOrientation:cached.cameraOrientation,sourceFilename:cached.sourceFilename,stages:"RAM cache hit; source files revalidated")
                } else {
                    loaded=try loadReference(raw:raw,preferEmbedded:prefer,executable:executable,cancellation:work)
                    loaded.stages += epoch == nil ? "; RAM cache unavailable: reload bridge 0.5.3 or check heartbeat":"; RAM cache miss"
                    if let epoch,let signature,selectionEpoch()==epoch,!work.isCancelled,
                       referenceFileSignature(raw:raw,preferEmbedded:prefer,executable:executable)==signature {
                        imageCache.insert(loaded,key:signature,epoch:epoch)
                    }
                }
                let layout = automatic && target != .check && target != .detect ? probeLightroom(imageSize: CGSize(width: loaded.image.width, height: loaded.image.height)) : nil
                try work.check()
                return (loaded, layout)
            }
            DispatchQueue.main.async {
                guard self.pending == token, !work.isCancelled else { return }
                guard supportedLightroomModule(self.currentModule()),self.currentModule()==requestedModule else {
                    self.cancelRequest();self.report("Module changed; invoke again in Library or Develop.");return
                }
                if let epoch, self.selectionEpoch() != epoch {
                    self.imageCache.observe(self.selectionEpoch());self.cancelRequest()
                    self.report("Selection changed while loading; invoke again for the current photo.");return
                }
                self.pending = nil; self.destination = nil; self.cancellation = nil
                self.updateToggleTitle()
                switch result {
                case .failure(let error):
                    self.report(error.localizedDescription)
                    if target == .window { self.floating?.title = self.floatingTitle + " — unchanged; refresh failed" }
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
                        self.resolveOverlay(loaded.image,snapshot:snapshot,selectionEpoch:epoch)
                    } else if target == .detect {
                        self.startPhotoDetection(imageSize:CGSize(width:loaded.image.width,height:loaded.image.height))
                    } else if target == .window {
                        self.resolveFloating(loaded, snapshot:snapshot, epoch:epoch)
                    }
                }
            }
        }
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
        p.contentView = view; panel = p;livePanelSignature=nil;livePanelRefreshNeeded=false;displayedOverlayLayout=overlayLayout;displayedOverlayModule=currentModule();overlayMoveCount=0;overlayOrderCount=0;overlayLevelChangeCount=0;
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
    func validateMenuItem(_ item:NSMenuItem) -> Bool {
        if item === assistedToggleItem || item === viewToggleItem {
            return screenshotDetectionEnabled && CameraPreferences.shared.bool(forKey:regionKey("automaticBounds"))
        }
        if detectionMethodItems.contains(where:{$0 === item}) { return CameraPreferences.shared.bool(forKey:regionKey("automaticBounds")) }
        return true
    }
    func saveExtracted(_ snapshot:ExportSnapshot, from view:ReferenceView) {
        guard !saving else { return }
        let url=snapshot.destination
        let overlayRegion=view.showIndicator ? view.window?.frame : nil
        do {
            let existing = try exportIdentity(url)
            if existing != nil {
                let alert = NSAlert();alert.icon=NSApp.applicationIconImage; alert.messageText = "Replace existing extracted JPEG?"
                alert.informativeText = "The _JpgFromRaw.jpg export beside this RAW already exists."
                alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Replace")
                NSApp.activate(ignoringOtherApps: true)
                guard alert.runModal() == .alertSecondButtonReturn else { return }
            }
            saving = true
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result { try writeExport(exportJPEG(snapshot.bytes, orientation: snapshot.orientation), to: url, replacing: existing) }
                DispatchQueue.main.async {
                    self.saving = false
                    switch result {
                    case .success:
                        self.report("Saved _JpgFromRaw.jpg beside the displayed RAW.")
                        let message="Saved " + url.lastPathComponent
                        if view.window?.isVisible == true, view.image != nil { view.showToast(message) }
                        else if let overlayRegion, self.isLightroom() { self.saveToast.show(message,in:overlayRegion) }
                    case .failure(let error): self.report(error.localizedDescription); self.showResult()
                    }
                }
            }
        } catch { report(error.localizedDescription); showResult() }
    }
    @objc func changePreference() {
        imageCache.clear()
        let enabled = !CameraPreferences.shared.bool(forKey: "preferEmbedded")
        CameraPreferences.shared.set(enabled, forKey: "preferEmbedded"); preferItem.state = enabled ? .on : .off
        report("Source priority changed; applies on the next load or double-click refresh.")
    }
    @objc func chooseExifTool() {
        imageCache.clear()
        let picker = NSOpenPanel(); picker.title = "Choose the ExifTool executable"; picker.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        if picker.runModal() == .OK, let url = picker.url, FileManager.default.isExecutableFile(atPath: url.path) {
            CameraPreferences.shared.set(url.path, forKey: "exiftool"); report("ExifTool location saved.")
        }
    }
    @objc func changeAutomatic() {
        let enabled = !CameraPreferences.shared.bool(forKey: regionKey("automaticBounds"))
        CameraPreferences.shared.set(enabled, forKey: regionKey("automaticBounds")); autoItem.state = enabled ? .on : .off
        cancelScreenInspection();cancelRequest();hide();invalidateAutomaticGeometry()
        if enabled { _ = axPlacementEnabled ? FeaturePermission.accessibility.ensure():FeaturePermission.screenCapture.granted }
        report(enabled ? "Automatic detection enabled. Manual calibration is the fallback." : "Using manual calibration.")
    }
    @objc func inspectViewState() {
        guard FeaturePermission.accessibility.ensure() else { return }
        report("Inspecting Lightroom menu state…")
        DispatchQueue.global(qos:.userInitiated).async { [weak self] in
            let result=probeLightroomViewState()
            DispatchQueue.main.async { self?.report(result);self?.showDiagnostics() }
        }
    }
    @objc func toggleAutomaticView(_ item:NSMenuItem) {
        guard screenshotDetectionEnabled else { return }
        if !automaticViewEnabled && !FeaturePermission.accessibility.ensure() { return }
        cancelRequest();cancelScreenInspection()
        CameraPreferences.shared.set(!automaticViewEnabled,forKey:"experimentalAutomaticView")
        liveViewGeneration += 1;nextLiveViewCheck=0
        detectedLayout=nil;detectedLayoutModule=nil
        item.state=automaticViewEnabled ? .on:.off
        lastViewDetection=automaticViewEnabled ? "Enabled; AX view checked every 2 seconds while Lightroom is active.":"Disabled; using saved menu selection."
        invalidateAutomaticGeometry();updateLayoutMenu();report(lastViewDetection)
    }
    func checkLiveAXViewIfDue() {
        let now=ProcessInfo.processInfo.systemUptime
        guard automaticViewEnabled,!liveViewBusy,!axMappingInProgress,now>=nextLiveViewCheck,
              isLightroom(),supportedLightroomModule(currentModule()),AXIsProcessTrusted(),
              pending == nil,viewProbeID == nil,screenInspectionID == nil,calibration == nil else { return }
        nextLiveViewCheck=now+2;liveViewBusy=true
        let generation=liveViewGeneration,module=currentModule(),checkPanels=livePanelAdjustment && panel != nil
        DispatchQueue.global(qos:.utility).async {
            let grid=accessibilityGridReading(module:module)
            let toolbar=checkPanels ? accessibilityToolbarReading(module:module).shown:nil
            var proposal:AXTrialProposal?,hints:AXScreenHints?
            _=accessibilityMappingReport { host,windows in
                proposal=axTrialProposal(host:host,windows:windows)
                if checkPanels { hints=AXScreenHints(host:host,visibleFrames:windows.filter(\.visible).map(\.frame),toolbar:toolbar.map { $0 ? "shown":"hidden" } ?? "unknown") }
            }
            DispatchQueue.main.async {
                self.liveViewBusy=false
                guard self.automaticViewEnabled,self.liveViewGeneration==generation,module==self.currentModule(),
                      self.isLightroom(),self.pending == nil,self.viewProbeID == nil,self.screenInspectionID == nil,self.calibration == nil else { return }
                self.lastGridStatus=grid.report
                if grid.selected == true {
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
                let signature=hints?.signature
                let panelsChanged=self.livePanelAdjustment && signature != nil && self.livePanelSignature != signature
                self.followLiveOverlayView(mode,module:module,panelChange:panelsChanged,panelSignature:signature)
            }
        }
    }
    func followLiveOverlayView(_ mode:OverlayLayout,module:String?,requiresViewDetection:Bool=true,panelChange:Bool=false,panelSignature:String?=nil) {
        guard (!requiresViewDetection || automaticViewEnabled),CameraPreferences.shared.bool(forKey:regionKey("automaticBounds")),
              let module,module==displayedOverlayModule,(displayedOverlayLayout != mode || (panelChange && livePanelAdjustment)),
              let existing=panel else { return }
        if shouldDismissForViewChange(enabled:dismissOnViewChange,displayed:displayedOverlayLayout,selected:mode) {
            cancelScreenInspection();cancelRequest();hide()
            report("View changed; overlay dismissed.");return
        }
        guard existing.isVisible,!overlaySuspended,
              let view=existing.contentView as? ReferenceView,let image=view.image,
              let host=overlayHost else { return }
        let backend=automaticPlacementMode,epoch=selectionEpoch(),generation=liveViewGeneration
        let settings=reloadDetectionConfig(),height=CGDisplayBounds(CGMainDisplayID()).height
        func stillCurrent()->Bool {
            self.panel === existing && existing.isVisible && !self.overlaySuspended &&
            (!requiresViewDetection || self.automaticViewEnabled) && self.automaticPlacementMode==backend &&
            CameraPreferences.shared.bool(forKey:self.regionKey("automaticBounds")) &&
            self.currentModule()==module && self.displayedOverlayModule==module &&
            self.overlayLayout==mode && self.liveViewGeneration==generation &&
            self.selectionEpoch()==epoch && self.overlayHost?.id==host.id && self.isLightroom() &&
            (!panelChange || self.livePanelAdjustment)
        }
        func apply(_ area:CGRect,_ photo:CGRect,_ background:NSColor?) {
            guard stillCurrent(),NSScreen.screens.contains(where:{$0.frame.intersects(area)}) else { return }
            // Keep the same panel, image and export snapshot. No hide/order/reload.
            let frame=area.insetBy(dx:-1,dy:-1)
            if existing.frame != frame { existing.setFrame(frame,display:false) }
            view.imageViewport=view.convert(existing.convertFromScreen(photo),from:nil)
            if let background { view.backgroundColour=background }
            view.needsDisplay=true
            self.displayedOverlayLayout=mode;self.lastImageSize=image.size
            if panelChange { self.livePanelSignature=panelSignature;self.livePanelRefreshNeeded=false }
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
        } else {
            guard #available(macOS 14.0,*),FeaturePermission.screenCapture.granted else { return }
            // Request fresh geometry through the selected, unchanged detector.
            // The existing overlay is excluded by the Lightroom-only capture filter.
            startPhotoDetection(imageSize:image.size,layout:mode) { result in
                guard stillCurrent(),result.windowID==host.id,let area=result.candidate else { return }
                self.rememberPlacement(result,epoch:epoch,settings:settings,layout:mode)
                let b=result.background
                apply(area,result.photoFrame ?? area,NSColor(srgbRed:b[0],green:b[1],blue:b[2],alpha:1))
            }
        }
    }
    func detectInvocationView() {
        cancelRequest();cancelScreenInspection()
        let id=UUID(),module=currentModule(),started=ProcessInfo.processInfo.systemUptime
        viewProbeID=id;updateToggleTitle()
        report("Reading Lightroom view through Accessibility…")
        DispatchQueue.global(qos:.userInitiated).async {
            let grid=accessibilityGridReading(module:module)
            var proposal:AXTrialProposal?
            let mapping=accessibilityMappingReport { host,windows in
                // No fine adjustments: only classify the raw visible panel/label evidence.
                proposal=axTrialProposal(host:host,windows:windows)
            }
            DispatchQueue.main.async {
                guard self.viewProbeID==id else { return }
                self.viewProbeID=nil;self.updateToggleTitle()
                self.lastAXMapping=mapping
                self.lastGridStatus=grid.report
                if module==self.currentModule(),grid.selected == true { self.dismissForGrid();return }
                guard module==self.currentModule(),let proposal else {
                    self.lastViewDetection="AX view unavailable or module changed; no overlay requested. Disable automatic view detection to use the saved menu selection."
                    self.report(self.lastViewDetection);self.saveInvocationDiagnostics();return
                }
                let group=proposal.layout == "Side-by-side" ? 1:proposal.layout == "Above-and-below" ? 2:0
                let preferred=CameraPreferences.shared.string(forKey:"axPreferredPane.\(module ?? "develop").\(group)").flatMap(OverlayLayout.init(rawValue:))
                let mode:OverlayLayout=group==0 ? .full:(preferred?.group==group ? preferred!:(group==1 ? .left:.upper))
                self.detectedLayout=mode;self.detectedLayoutModule=module
                self.lastViewDetection="\(proposal.layout); selected pane: \(mode.label). No clear pair means single view.\nClassification took \(Int((ProcessInfo.processInfo.systemUptime-started)*1000)) ms (before bridge request)."
                self.updateLayoutMenu()
                self.request(.overlay,viewChecked:true)
            }
        }
    }
    var lastAXMapping="Not collected. Use Diagnostics → Refresh AX."
    var savingInvocation=false
    var lastAXTrial="AX preview not run."
    var lastAXToolbar="Not collected. Use Diagnostics → Refresh AX."
    var axTrialBorders:[NSPanel]=[]
    var axTrialGeneration=0
    var axTrialEnabled:Bool { CameraPreferences.shared.bool(forKey:"developerAXTrial") }
    var autoDiagnostics:Bool {
        (CameraPreferences.shared.object(forKey:"developerAutoSaveDiagnostics") as? Bool) ?? CameraPreferences.shared.bool(forKey:"developerAutoCopyDiagnostics")
    }
    var diagnosticSaveStatus="Automatic report saving has not run."
    var diagnosticSaveURL:URL { folder.deletingLastPathComponent().appendingPathComponent("Diagnostics/latest.txt") }
    func updateDetectionMenu() {
        let automatic=CameraPreferences.shared.bool(forKey:regionKey("automaticBounds"))
        screenshotToggleItem?.title="Detection method: " + (screenshotDetectionEnabled ? "Screenshot":"Accessibility")
        screenshotToggleItem?.isEnabled=automatic
        for item in detectionMethodItems {
            item.state=(item.representedObject as? Bool)==screenshotDetectionEnabled ? .on:.off
            item.isEnabled=automatic
        }
        assistedToggleItem?.state=assistedPlacementEnabled ? .on:.off
        viewToggleItem?.state=automaticViewEnabled ? .on:.off
        assistedToggleItem?.isEnabled=automatic && screenshotDetectionEnabled
        viewToggleItem?.isEnabled=automatic && screenshotDetectionEnabled
    }
    func placementOptionsChanged() {
        cancelScreenInspection();cancelPanelCheck();cancelRequest()
        assistedSignature=nil;liveViewGeneration += 1;nextLiveViewCheck=0
        detectedLayout=nil;detectedLayoutModule=nil
        invalidateAutomaticGeometry();updateDetectionMenu();updateLayoutMenu()
        report("Placement: \(automaticPlacementMode.title). AX view detection \(automaticViewEnabled ? "on":"off"). Manual calibration takes precedence.")
    }
    @objc func selectDetectionMethod(_ item:NSMenuItem) {
        guard CameraPreferences.shared.bool(forKey:regionKey("automaticBounds")),
              let screenshot=item.representedObject as? Bool,screenshot != screenshotDetectionEnabled else { return }
        if !screenshot && !FeaturePermission.accessibility.ensure() { return }
        CameraPreferences.shared.set(screenshot,forKey:"useScreenshotDetection")
        placementOptionsChanged()
    }
    @objc func toggleScreenshotAssistance() {
        guard screenshotDetectionEnabled else { return }
        if !screenshotAssistanceEnabled && !FeaturePermission.accessibility.ensure() { return }
        CameraPreferences.shared.set(!screenshotAssistanceEnabled,forKey:"screenshotAXAssistance")
        placementOptionsChanged()
    }
    @objc func toggleAXTrial(_ item:NSMenuItem) {
        if !axTrialEnabled && !FeaturePermission.accessibility.ensure() { return }
        CameraPreferences.shared.set(!axTrialEnabled,forKey:"developerAXTrial")
        item.state=axTrialEnabled ? .on:.off
        if !axTrialEnabled { clearAXTrialBorders() }
    }
    @objc func toggleAutoDiagnostics(_ item:NSMenuItem) {
        CameraPreferences.shared.set(!autoDiagnostics,forKey:"developerAutoSaveDiagnostics")
        item.state=autoDiagnostics ? .on:.off
    }
    func saveInvocationDiagnostics() {
        guard autoDiagnostics else { return }
        do {
            try FileManager.default.createDirectory(at:diagnosticSaveURL.deletingLastPathComponent(),withIntermediateDirectories:true)
            diagnosticSaveStatus="Latest report: \(diagnosticSaveURL.path)\nSaved: \(Date())"
            try diagnosticReport(diagnosticSections()).write(to:diagnosticSaveURL,atomically:true,encoding:.utf8)
        } catch {
            diagnosticSaveStatus="Could not save diagnostics: \(error.localizedDescription)"
            detail.title=diagnosticSaveStatus
        }
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
            let mapping=accessibilityMappingReport { host,windows in proposal=axTrialProposal(host:host,windows:windows,settings:previewSettings,module:module) }
            DispatchQueue.main.async {
                guard self.axTrialGeneration==generation,self.panel === actual else { return }
                self.lastAXToolbar=toolbar.report
                self.lastAXMapping=displays+"\n\n"+mapping
                self.lastAXTrial=(proposal?.summary ?? "AX proposal unavailable. See Accessibility map; normal overlay unaffected.")+"\nToolbar evidence used for this preview:\n"+toolbar.report+String(format:"\nTrial elapsed: %.0f ms (after normal panel shown).",(ProcessInfo.processInfo.systemUptime-started)*1000)
                if !drawPreview { self.lastAXTrial += "\nDrawing disabled; collected for automatic diagnostics.";self.savingInvocation=false;self.collectCompleteDiagnostics();return }
                if let proposal,let current=self.overlayHost, axTrialHostMatches(proposedTopLeft:proposal.host,actualAppKit:current.frame,primaryHeight:CGDisplayBounds(CGMainDisplayID()).height) {
                    let displayHeight=CGDisplayBounds(CGMainDisplayID()).height
                    for (index,rect) in proposal.panes.enumerated() {
                        let frame=CGRect(x:rect.minX,y:displayHeight-rect.maxY,width:rect.width,height:rect.height)
                        let border=NSPanel(contentRect:frame,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
                        border.isOpaque=false;border.backgroundColor = .clear;border.hasShadow=false;border.ignoresMouseEvents=true
                        border.level=actual.level
                        border.animationBehavior = .none;border.isReleasedWhenClosed=false;border.hidesOnDeactivate=false
                        border.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle,.transient]
                        let name=proposal.panes.count==1 ? "AX single":(proposal.layout=="Side-by-side" ? (index==0 ? "AX left":"AX right"):(index==0 ? "AX top":"AX bottom"))
                        border.contentView=AXTrialBorder(size:frame.size,tint:index==0 ? .systemGreen:.systemPurple,label:name)
                        actual.addChildWindow(border,ordered:.above)
                        if !self.overlaySuspended && actual.isVisible {
                            border.orderFront(nil)
                        } else { border.orderOut(nil) }
                        self.axTrialBorders.append(border)
                        self.lastAXTrial += "\n\(name): requested AppKit \(frame); actual \(border.frame); visible \(border.isVisible); parent visible \(actual.isVisible); suspended \(self.overlaySuspended)."
                    }
                } else if proposal != nil { self.lastAXTrial += "\nPreview not drawn: host changed or does not match overlay host. AX top-left: \(proposal!.host); overlay AppKit: \(String(describing:self.overlayHost?.frame))." }
                self.savingInvocation=false;self.collectCompleteDiagnostics()
            }
        }
    }
    var axMappingInProgress=false
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
    @objc func editAdvancedSettings() {
        if let editor=configEditor,editor.window?.isVisible == true { editor.showWindow(nil);NSApp.activate(ignoringOtherApps:true);return }
        do {
            try detectionSettings.ensureFile()
            configEditor=try ConfigEditorController(url:detectionSettings.url,onSave:{ [weak self] in _ = self?.reloadDetectionConfig() },openFile:{ [weak self] in self?.openDetectionConfig() })
            configEditor?.showWindow(nil);NSApp.activate(ignoringOtherApps:true)
        } catch { report("Could not read config.conf: \(error.localizedDescription)");showResult() }
    }
    @objc func openDetectionConfig() {
        do {
            try detectionSettings.ensureFile()
            guard let editor=NSWorkspace.shared.urlForApplication(withBundleIdentifier:"com.apple.TextEdit") else {
                NSWorkspace.shared.activateFileViewerSelecting([detectionSettings.url]);return
            }
            NSWorkspace.shared.open([detectionSettings.url],withApplicationAt:editor,configuration:NSWorkspace.OpenConfiguration()) { [weak self] _,error in
                if error != nil { DispatchQueue.main.async { self?.report("Could not open TextEdit. Edit config.conf as plain text in Application Support/CameraReference.");self?.showResult() } }
            }
        }
        catch { report("Could not open config.conf: \(error.localizedDescription)");showResult() }
    }
    func reloadDetectionConfig()->DetectionConfig {
        do {
            let old=detectionSettings.current
            let next=try detectionSettings.reload()
            if old.key != next.key { invalidateAutomaticGeometry() }
            return next
        }
        catch {
            let alert=NSAlert();alert.icon=NSApp.applicationIconImage;alert.messageText="Detection configuration was not applied"
            alert.informativeText=error.localizedDescription+" The last valid settings will be used."
            alert.runModal();return detectionSettings.current
        }
    }
    @objc func calibrate() { beginCalibration() }
    func beginCalibration(proposal requestedProposal:CGRect? = nil, useManualOnAccept:Bool = false) {
        guard requireSupportedModule() else { return }
        guard !regionResetting else { return }
        cancelPanelCheck()
        cancelScreenInspection(); hide(); cancelRequest(); calibration?.finish(nil)
        let settings=reloadDetectionConfig()
        let proposal=requestedProposal == nil ? nil:lastProbe?.uiFrame
        let selectionKind="ui"
        let calibrationModule=currentModule()
        let controller=CalibrationController();controller.snapRadius=settings.snapDistancePoints; calibration=controller
        if overlayLayout != .full { controller.instruction="Select the entire \(overlayLayout.label.lowercased()) pane backdrop between panels and divider, including photo margins. Esc cancels." }
        controller.completed = { [weak self] result in
            guard let self else { return }
            self.calibrationTask?.cancel(); self.calibrationTask=nil
            self.calibrationTimer?.invalidate();self.calibrationTimer=nil
            self.calibration=nil
            if let result {
                guard self.currentModule()==calibrationModule else { self.report("Module changed; calibration was not saved.");return }
                guard let window=lightroomWindowFrame(),window.contains(result) else {
                    self.report("Select the UI backdrop inside the Lightroom window. Previous calibration retained.");return
                }
                // Accepting calibration makes this selected pane the manual region too.
                if self.automaticViewEnabled { let selected=self.overlayLayout;self.overlayLayout=selected }
                self.region=result; self.manualLayoutKey=self.lastProbe?.layoutKey
                CameraPreferences.shared.set(selectionKind,forKey:self.regionKey("regionKind"))
                CameraPreferences.shared.set(false,forKey:self.regionKey("automaticBounds")); self.autoItem.state = .off
                self.invalidateAutomaticGeometry()
                self.report("Image region saved. Shortcut toggles the reference.")
            }
            else { self.report("Calibration cancelled. Previous region retained.") }
        }
        guard #available(macOS 14.0,*),FeaturePermission.screenCapture.granted else {
            if calibration === controller { controller.start(proposal:proposal,snapAvailable:false,permissionUnavailable:!FeaturePermission.screenCapture.granted) }; return
        }
        guard calibration === controller else { return }
        report("Preparing calibration edges…")
        // Timeout enters free calibration; a late capture cannot replace it.
        calibrationTimer=Timer(timeInterval:3,repeats:false) { [weak self,weak controller] _ in
            guard let self,let controller,self.calibration === controller else { return }
            self.calibrationTask?.cancel();self.calibrationTask=nil;self.calibrationTimer=nil
            controller.start(proposal:proposal,snapAvailable:false)
        }
        RunLoop.main.add(calibrationTimer!,forMode:.common)
        calibrationTask=Task.detached(priority:.userInitiated) { [weak self,weak controller] in
            let result=await inspectScreenLayout(imageSize:.zero,forCalibration:true,settings:settings)
            guard !Task.isCancelled,let controller else { return }
            await self?.finishCalibrationPreparation(result,controller:controller,proposal:proposal)
        }
    }
    @MainActor func finishCalibrationPreparation(_ result:ScreenProbeResult,controller:CalibrationController,proposal:CGRect?) {
        guard calibration === controller,calibrationTimer != nil else { return }
        calibrationTimer?.invalidate();calibrationTimer=nil;calibrationTask=nil
        lastLayout=result.summary
        controller.start(proposal:proposal,edges:result.snapEdges,snapAvailable:!result.snapEdges.isEmpty,permissionUnavailable:result.summary.hasPrefix("Screen Recording permission unavailable"))
    }
    @objc func clearAllRegionData() {
        guard !regionResetting else { return };regionResetting=true
        calibration?.finish(nil);calibrationTask?.cancel();calibrationTask=nil
        calibrationTimer?.invalidate();calibrationTimer=nil
        cancelPanelCheck()
        cancelScreenInspection();cancelRequest();hide();saveToast.close();capturePreview?.close();capturePreview=nil
        clearRegionPreferences(CameraPreferences.shared,layout:overlayLayout,modulePrefix:currentModule() == "library" ? "library.":"")
        placementMemory=nil
        acceptedSplitKey=nil;lastProbe=nil;lastImageSize=nil
        lastLayout="No region data. Detection/calibration starts fresh."
        report("Clearing region data…")
        Task { @MainActor [weak self] in
            await ScreenGeometryCache.shared.reset()
            guard let self else { return };self.regionResetting=false
            self.report("Region cleared for this layout/pane. Automatic detection preference unchanged.")
        }
    }
    func requireSupportedModule()->Bool {
        guard !supportedLightroomModule(currentModule()) else { return true }
        let alert=NSAlert();alert.icon=NSApp.applicationIconImage
        alert.messageText="Switch Lightroom to Library or Develop"
        alert.informativeText="Camera Reference supports Library and Develop only. Switch to either module, then try again. In Library, use Loupe for single-photo placement."
        NSApp.activate(ignoringOtherApps:true);alert.runModal();return false
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
        guard #available(macOS 14.0,*), FeaturePermission.screenCapture.granted else {
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
    func askForCalibration(workingAreaTooNarrow:Bool = false,reason:String? = nil) {
        let alert=NSAlert();alert.icon=NSApp.applicationIconImage
        alert.messageText="Cannot reliably identify viewing area."
        let automatic=CameraPreferences.shared.bool(forKey:regionKey("automaticBounds"))
        alert.informativeText=(reason.map { $0 + "\n\n" } ?? "") + (workingAreaTooNarrow ? "Working area too narrow—enlarge it or calibrate manually.\n\n":"") + calibrationInstructions(layout:overlayLayout,automatic:automatic)
        if automatic { alert.informativeText += "\n\nIf detection keeps failing with Lightroom partly off-screen, try restarting Lightroom Classic." }
        lastPlacementFailure="Recorded: \(Date()). Module: \(currentModule() ?? "unknown"); view: \(overlayLayout.viewName); pane: \(overlayLayout.label); method: \(automaticPlacementMode.title); automatic: \(automatic).\n" + alert.informativeText + "\n\nCalculation at failure:\n" + (automatic ? lastLayout:"Manual region missing or no longer valid; automatic detection was not attempted.") + "\n\nTiming at failure: " + lastTiming
        lastResult="Placement unavailable; manual calibration offered."
        // Save synchronously before entering the modal loop. Keep this failure
        // snapshot separate from subsequent successful placements and AX refreshes.
        saveInvocationDiagnostics()
        alert.addButton(withTitle:"Calibrate manually…"); alert.addButton(withTitle:"Cancel")
        NSApp.activate(ignoringOtherApps:true)
        if alert.runModal() == .alertFirstButtonReturn {
            beginCalibration(useManualOnAccept:true)
        } else { report("Overlay cancelled; calibration was not changed.") }
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
            var proposal:AXTrialProposal?
            let mapping=accessibilityMappingReport { host,windows in proposal=axTrialProposal(host:host,windows:windows,settings:adjusted,module:module) }
            guard !Task.isCancelled,let owner=self else { return }
            let resultProposal=proposal
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
                    if owner.detectedLayout != selected || owner.detectedLayoutModule != module {
                        owner.detectedLayout=selected;owner.detectedLayoutModule=module;owner.updateLayoutMenu()
                    }
                }
                guard let area=axSelectedArea(proposal,layout:full ? .full:selected) else {
                    owner.lastLayout += "\nSelected layout does not match AX labels.";completion(nil);return
                }
                owner.lastLayout += "\nSelected AX UI (top-left): \(area)."
                completion(appKitRect(area,primaryHeight:height))
            }
        }
    }
    func startPhotoDetection(imageSize:CGSize,previewCapture:Bool=false,layout requestedLayout:OverlayLayout? = nil,completion:((ScreenProbeResult)->Void)? = nil) {
        guard #available(macOS 14.0, *), supportedLightroomModule(currentModule()) else { report("Detection cancelled: Library or Develop is no longer active."); return }
        cancelPanelCheck()
        if previewCapture { lastTiming="" }
        let settings=reloadDetectionConfig()
        let mode=requestedLayout ?? overlayLayout
        let seed=mode == overlayLayout && mode != .full ? region:nil
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
        let assisted=assistedPlacementEnabled && !previewCapture
        let module=currentModule()
        screenTask=Task.detached(priority:.userInitiated) { [weak self] in
            let hints=assisted ? Self.screenHints(module:module):nil
            let result=await inspectScreenLayout(imageSize:imageSize,previewCapture:previewCapture,settings:settings,layout:mode,seed:seed,axHints:hints)
            if assisted { await self?.recordAssistedInvocation(hints,id:inspectionID) }
            guard !Task.isCancelled else { return }
            await self?.finishScreenInspection(result,id:inspectionID,elapsed:ProcessInfo.processInfo.systemUptime-inspectionStarted)
        }
    }
    @MainActor func recordAssistedInvocation(_ hints:AXScreenHints?,id:UUID) {
        guard screenInspectionID==id else { return }
        assistedSignature=hints?.signature
        assistedEvidence=hints == nil ? "AX read unavailable; original screenshot path used.":"Fresh raw AX hints; no calibrated AX offsets used."
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
    func diagnosticSections()->[DiagnosticSection] {
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
            DiagnosticSection(title:"Grid view & view-change policy",body:lastGridStatus+"\nDismiss on view change: \(dismissOnViewChange). Pane changes count as view changes. Live panel adjustment: \(livePanelAdjustment)."),
            DiagnosticSection(title:"Last result",body:lastResult),
            DiagnosticSection(title:"Last placement failure (retained snapshot)",body:lastPlacementFailure),
            DiagnosticSection(title:"Lightroom bridge",body:"Heartbeat: \(age)\nPlugin status: \(state.trimmingCharacters(in:.whitespacesAndNewlines))"),
            DiagnosticSection(title:"Overlay visibility & minimisation",body:"\(overlayVisibilityStatus)\nGeometry source: \(overlayGeometrySource)\n\(overlayLifecycleStatus)\nMoves: \(overlayMoveCount); ordering changes: \(overlayOrderCount); level changes: \(overlayLevelChangeCount).\n\nEvent history (uptime seconds):\n" + lifecycleTrace.joined(separator:"\n")),
            DiagnosticSection(title:"Placement & capture",body:lastLayout),
            DiagnosticSection(title:"Cache & background checks",body:"Last completed background check (may precede the current invocation):\n"+panelCheckStatus),
            DiagnosticSection(title:"Performance",body:lastTiming)
        ]
    }
    @objc func showDiagnostics() {
        let sections=diagnosticSections()
        diagnosticsWindow?.close()
        diagnosticsWindow=DiagnosticsController(sections:sections,refresh: { [weak self] in self?.inspectLayout() })
    }
    @objc func showResult() {
        hide(); NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert();alert.icon=NSApp.applicationIconImage; alert.messageText = "Camera Reference"; alert.informativeText = lastResult + "\n\n" + lastTiming; alert.runModal()
    }
    @objc func changeShortcut() {
        hide();calibration?.finish(nil);recording=true
        let oldOverlay=currentShortcut,oldFloating=floatingShortcut
        if let hotKey { UnregisterEventHotKey(hotKey);self.hotKey=nil }
        if let floatingHotKey { UnregisterEventHotKey(floatingHotKey);self.floatingHotKey=nil }
        defer { recording=false;updateToggleTitle() }
        let overlay=ShortcutRecorder(shortcut:oldOverlay,label:keyLabel)
        let floating=ShortcutRecorder(shortcut:oldFloating,label:floatingKeyLabel)
        floating.defaultShortcut=(UInt32(kVK_ANSI_F),UInt32(controlKey|optionKey|cmdKey));floating.defaultLabel="F"
        overlay.setAccessibilityLabel("Overlay shortcut");floating.setAccessibilityLabel("Floating display shortcut")
        let help=NSTextField(wrappingLabelWithString:"Click either shortcut to record it. Both shortcuts must be different.")
        overlay.help=help;floating.help=help
        let grid=NSGridView(views:[
            [NSTextField(labelWithString:"Overlay"),overlay,NSButton(title:"Use Default",target:overlay,action:#selector(ShortcutRecorder.useDefault))],
            [NSTextField(labelWithString:"Floating display"),floating,NSButton(title:"Use Default",target:floating,action:#selector(ShortcutRecorder.useDefault))]])
        grid.columnSpacing=14;grid.rowSpacing=8;grid.yPlacement = .center
        grid.column(at:0).width=110;grid.column(at:1).width=125;grid.column(at:2).width=105
        overlay.font = .systemFont(ofSize:14);floating.font = .systemFont(ofSize:14)
        overlay.widthAnchor.constraint(equalToConstant:125).isActive=true
        floating.widthAnchor.constraint(equalToConstant:125).isActive=true
        overlay.heightAnchor.constraint(equalToConstant:28).isActive=true
        floating.heightAnchor.constraint(equalToConstant:28).isActive=true
        let stack=NSStackView(views:[grid,help]);stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=12
        stack.frame=CGRect(x:0,y:0,width:370,height:105)
        help.widthAnchor.constraint(equalToConstant:370).isActive=true
        let alert=NSAlert();alert.icon=NSApp.applicationIconImage;alert.messageText="Keyboard shortcuts";alert.accessoryView=stack
        alert.addButton(withTitle:"Save");alert.addButton(withTitle:"Cancel")
        NSApp.activate(ignoringOtherApps:true)
        while true {
            guard alert.runModal() == .alertFirstButtonReturn else {
                let a=register(oldOverlay),b=register(oldFloating,floatingTarget:true)
                if !a || !b { report("A previous shortcut is unavailable; reopen Keyboard shortcuts.") };return
            }
            guard overlay.candidate != floating.candidate else { help.stringValue="Choose two different shortcuts.";continue }
            let a=register(overlay.candidate)
            let b=a && register(floating.candidate,floatingTarget:true)
            if a && b {
                keyLabel=overlay.keyLabel;floatingKeyLabel=floating.keyLabel
                let prefs=CameraPreferences.shared
                prefs.set(currentShortcut.0,forKey:"key");prefs.set(currentShortcut.1,forKey:"modifiers");prefs.set(keyLabel,forKey:"keyLabel")
                prefs.set(floatingShortcut.0,forKey:"floatingKey");prefs.set(floatingShortcut.1,forKey:"floatingModifiers");prefs.set(floatingKeyLabel,forKey:"floatingKeyLabel")
                report("Shortcuts saved.");return
            }
            if let hotKey { UnregisterEventHotKey(hotKey);self.hotKey=nil }
            if let floatingHotKey { UnregisterEventHotKey(floatingHotKey);self.floatingHotKey=nil }
            help.stringValue="A shortcut is unavailable. Choose another combination or Cancel."
        }
    }
    @objc func cancel() { calibration?.finish(nil); hide(); report("Ready.") }
    @objc func quit() { cancelPanelCheck();imageCache.clear(); calibration?.finish(nil); cancelScreenInspection(); hide(); cancelRequest(); diagnosticsWindow?.close(); captureBaseline?.close(); capturePreview?.close(); floating?.close(); NSApp.terminate(nil) }

}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
