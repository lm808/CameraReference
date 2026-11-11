import AppKit
import Carbon
import ImageIO
import ApplicationServices

enum Destination: String { case overlay, window, check, detect }
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation, NSMenuDelegate {
    var capturePreview:CapturePreviewController?
    var saving = false
    let saveToast=SaveToastController()
    var floatingTitle="Camera Reference"
    private var versionTitle: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        return "Camera Reference \(version)"
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
        get { UserDefaults.standard.string(forKey:regionKey("manualLayoutKey")) }
        set { UserDefaults.standard.set(newValue,forKey:regionKey("manualLayoutKey")) }
    }
    func updateFloatingTitle() { floating?.title=floatingTitle + String(format:" — %.1f%%",floatingZoom) }
    let detectionSettings=DetectionConfigStore()
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
            storageStatus=legacyBridgeConsolidated ? "Storage: consolidated under CameraReference." : "Storage migration waiting: stop the old bridge and reload bridge 0.5.2. The old bridge folder is still active."
        } catch { storageStatus="Storage migration deferred: \(error.localizedDescription)" }
    }
    let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/CameraReference/Bridge")
    var floating: NSPanel?
    var floatingView: ReferenceView?
    var preferItem: NSMenuItem!
    var autoItem: NSMenuItem!
    var cancellation: Cancellation?
    var destination: Destination?
    var moduleTimer: Timer?
    var lastModuleSample: (String, Date)?
    var lastLayout = "Automatic detection has not been tested."
    var status: NSStatusItem!
    var detail: NSMenuItem!
    var shortcutItem: NSMenuItem!
    var panel: OverlayPanel?
    var overlayHost:HostWindowSnapshot?
    var overlayAccessibility:LightroomHostAccessibility?
    var nextAccessibilityBind:TimeInterval=0
    func bindOverlayAccessibility(pid:pid_t,frame:CGRect) {
        guard overlayAccessibility == nil,ProcessInfo.processInfo.systemUptime>=nextAccessibilityBind else { return }
        nextAccessibilityBind=ProcessInfo.processInfo.systemUptime+1
        overlayAccessibility=LightroomHostAccessibility(pid:pid,hostFrame:frame)
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
        overlayLifecycleStatus="Lifecycle: minimise notifications \(overlayAccessibility?.watchesMinimize == true ? "active":"unavailable"); dialog \(overlayDialogVisible); minimised \(overlayAccessibility?.minimized.map(String.init) ?? "unavailable"); \(overlayAccessibility == nil ? "window-list fallback":"Accessibility + window list")."
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
        cancelPanelCheck();overlaySuspended=true
        overlayResumeAfter=ProcessInfo.processInfo.systemUptime+0.4
        panel.orderOut(nil)
    }
    func reconcileOverlayHost() {
        guard let panel,let saved=overlayHost else { return }
        let current=hostWindowSnapshot(saved.id)
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
            if overlaySuspended {
                guard ProcessInfo.processInfo.systemUptime>=overlayResumeAfter else { return }
            }
            if delta != .zero {
                panel.setFrameOrigin(CGPoint(x:panel.frame.minX+delta.x,y:panel.frame.minY+delta.y))
                overlayMoveCount += 1
            }
            overlayHost=current
            if overlaySuspended { overlaySuspended=false;_ = orderOverlayAboveLightroom(initial:true) }
        }
    }
    let imageCache=SelectionImageCache()
    var overlayLayout:OverlayLayout = OverlayLayout(rawValue:UserDefaults.standard.string(forKey:"overlayLayout") ?? "full") ?? .full
    var layoutItems=[OverlayLayout:NSMenuItem]()
    var layoutGroups=[Int:NSMenuItem]()
    var layoutSeparator:NSMenuItem?
    var placementMemory:PlacementMemory?
    func regionKey(_ key:String,layout:OverlayLayout? = nil)->String {
        regionPreferenceKey(key,layout:layout ?? overlayLayout)
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
        guard let text=UserDefaults.standard.string(forKey:regionKey("region")) else { return nil }
        return NSRectFromString(text)
    }
    var region: NSRect? {
        get {
            guard let r=savedRegion else { return nil }
            let saved=UserDefaults.standard.data(forKey:regionKey("regionDisplay")).flatMap { try? JSONDecoder().decode(DisplayGeometry.self,from:$0) }
            guard calibratedRegionIsUsable(r,savedDisplay:saved,current:currentDisplays()) else { return nil }
            if let text=UserDefaults.standard.string(forKey:regionKey("regionWindow")),let current=lightroomWindowFrame() {
                return translatedCalibration(r,from:NSRectFromString(text),to:current)
            }
            return r
        }
        set {
            guard let newValue else { return } // Temporary display changes never erase calibration.
            UserDefaults.standard.set(NSStringFromRect(newValue),forKey:regionKey("region"))
            if let frame=lightroomWindowFrame() { UserDefaults.standard.set(NSStringFromRect(frame),forKey:regionKey("regionWindow")) }
            else { UserDefaults.standard.removeObject(forKey:regionKey("regionWindow")) }
            if let screen=currentDisplays().first(where:{$0.frame.contains(newValue)}), let data=try? JSONEncoder().encode(screen) {
                UserDefaults.standard.set(data,forKey:regionKey("regionDisplay"))
            }
        }
    }
    var panelCheckTask:Task<Void,Never>?
    var panelCheckID:UUID?
    var nextPanelCheck:TimeInterval=0
    var panelCheckStatus="Panel boundaries not yet checked in background."
    func cancelPanelCheck() { panelCheckTask?.cancel();panelCheckTask=nil;panelCheckID=nil }
    func checkPanelBoundariesIfDue() {
        guard #available(macOS 14.0,*),ProcessInfo.processInfo.systemUptime>=nextPanelCheck,
              panelCheckTask==nil,screenTask==nil,pending==nil,calibration==nil,!recording,!regionResetting,
              !workspaceOverview,!overlaySuspended,isLightroom(),currentModule()=="develop",UserDefaults.standard.bool(forKey:regionKey("automaticBounds")),
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
        panelCheckTask=Task.detached(priority:.utility) { [weak self] in
            let result=await inspectScreenLayout(imageSize:imageSize,settings:settings,layout:memory.layout,seed:seed,maxPixelWidth:1280)
            guard !Task.isCancelled else { return }
            await self?.finishPanelCheck(result,id:id,memory:memory,elapsed:ProcessInfo.processInfo.systemUptime-started)
        }
    }
    @MainActor func finishPanelCheck(_ result:ScreenProbeResult,id:UUID,memory:PlacementMemory,elapsed:TimeInterval) {
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
        if panelBoundsChanged(previous:expected,current:result.uiFrame,tolerance:4) {
            let reason=result.uiFrame == nil ? "UI boundaries could not be validated":"UI boundaries changed"
            panelCheckStatus="Background check invalidated cached placement (visible overlay retained): \(reason).\nPrevious UI: \(String(describing:expected)); checked UI: \(String(describing:result.uiFrame)).\n"+result.summary
            invalidateAutomaticGeometry()
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
        if levelChanged { panel.level=desiredLevel;overlayLevelChangeCount += 1 }
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
        let full=add("▣  Full",#selector(selectLayout(_:)),to:menu)
        full.representedObject=OverlayLayout.full.rawValue;full.image=layoutMenuIcon(.full);layoutItems[.full]=full
        for (title,modes) in [("◧  Side-by-side",[OverlayLayout.left,.right]),("⬒  Above-and-below",[OverlayLayout.upper,.lower])] {
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
        let hidden = !UserDefaults.standard.bool(forKey:regionKey("automaticBounds"))
        layoutSeparator?.isHidden=hidden
        layoutItems[.full]?.isHidden=hidden
        for item in layoutGroups.values { item.isHidden=hidden }
        for (mode,item) in layoutItems { item.state=mode==overlayLayout ? .on:.off }
        for (group,item) in layoutGroups { item.state=group==overlayLayout.group ? .on:.off }
    }
    @objc func selectLayout(_ sender:NSMenuItem) {
        guard let raw=sender.representedObject as? String,let mode=OverlayLayout(rawValue:raw),mode != overlayLayout else { return }
        cancelScreenInspection();cancelRequest();hide();calibration?.finish(nil)
        overlayLayout=mode;UserDefaults.standard.set(mode.rawValue,forKey:"overlayLayout")
        UserDefaults.standard.set(true,forKey:regionKey("automaticBounds"))
        invalidateAutomaticGeometry();updateLayoutMenu()
        autoItem.state=UserDefaults.standard.bool(forKey:regionKey("automaticBounds")) ? .on:.off
        report(mode == .full ? "Full layout selected.":"\(mode.label) pane selected. Calibrate its entire UI backdrop, including photo margins.")
    }
    func calibratedUI(_ mode:OverlayLayout)->CGRect? {
        guard let text=UserDefaults.standard.string(forKey:regionKey("region",layout:mode)) else { return nil }
        let rect=NSRectFromString(text)
        let display=UserDefaults.standard.data(forKey:regionKey("regionDisplay",layout:mode)).flatMap { try? JSONDecoder().decode(DisplayGeometry.self,from:$0) }
        guard calibratedRegionIsUsable(rect,savedDisplay:display,current:currentDisplays()),
              let saved=UserDefaults.standard.string(forKey:regionKey("regionWindow",layout:mode)),let window=lightroomWindowFrame(),
              let translated=translatedCalibration(rect,from:NSRectFromString(saved),to:window),window.contains(translated),
              NSScreen.screens.contains(where:{$0.frame.contains(translated)}) else { return nil }
        return translated
    }
    func cachedUI(epoch:String?,settings:DetectionConfig,layout:OverlayLayout)->CGRect? {
        guard let memory=placementMemory,let current=lightroomWindowFrame(),
              let cg=currentCaptureWindowFrame(memory.windowID),sameWindowGeometry(current,appKitRect(cg,primaryHeight:CGDisplayBounds(CGMainDisplayID()).height)),
              let ui=memory.translated(window:current,windowID:memory.windowID,epoch:epoch,settingsKey:settings.key,layout:layout),
              NSScreen.screens.contains(where:{$0.frame.intersects(ui)}) else { return nil }
        lastTiming += "; placement cache hit; capture skipped"
        lastLayout="Reused \(layout.label) UI bounds (AppKit): \(ui). Window size unchanged; position translated. Clear region setting after internal panel changes."
        return ui
    }
    func rememberPlacement(_ result:ScreenProbeResult,epoch:String?,settings:DetectionConfig,layout:OverlayLayout) {
        guard let ui=result.uiFrame,let window=result.windowFrame,let id=result.windowID,let epoch else { return }
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
        if !UserDefaults.standard.bool(forKey:regionKey("automaticBounds")) {
            if let full=calibratedUI(.full) { show(full);return }
            if let pane=region,overlayLayout != .full {
                // A calibrated split pane supplies an approximate full working area.
                let full=overlayLayout.group==1 ? CGRect(x:pane.minX,y:pane.minY,width:pane.width*2,height:pane.height):CGRect(x:pane.minX,y:pane.minY,width:pane.width,height:pane.height*2)
                show(full);return
            }
            askForCalibration();return
        }
        if let ui=cachedUI(epoch:epoch,settings:settings,layout:.full) { show(ui);return }
        guard currentModule()=="develop",#available(macOS 14.0,*),FeaturePermission.screenCapture.ensure() else { report("Calibrate a UI working area, or open Develop to size the floating photo.");return }
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
        if let url=Bundle.main.url(forResource:"AppIcon",withExtension:"icns") { NSApp.applicationIconImage=NSImage(contentsOf:url) }
        // Carry only calibration and shortcut settings forward; no photo paths or images.
        if !UserDefaults.standard.bool(forKey: "migrated03") {
            if let old = UserDefaults.standard.persistentDomain(forName: "org.local.JPEGReference") {
                for key in ["region", "key", "modifiers"] {
                    if let value = old[key] { UserDefaults.standard.set(value, forKey: key) }
                }
            }
            UserDefaults.standard.set(true, forKey: "migrated03")
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
        preferItem = add("Prefer RAW-embedded JPEG", #selector(changePreference), to: settings)
        preferItem.state = UserDefaults.standard.bool(forKey: "preferEmbedded") ? .on : .off
        autoItem = add("Automatic viewing area", #selector(changeAutomatic), to: settings)
        autoItem.state = UserDefaults.standard.bool(forKey: regionKey("automaticBounds")) ? .on : .off
        add("Set image region…", #selector(calibrate), to: settings)
        settings.addItem(.separator())
        shortcutItem = add("Keyboard shortcuts…", #selector(changeShortcut), to: settings)

        settings.addItem(.separator())
        add("Edit config file", #selector(openDetectionConfig), to: settings)
        add("Choose ExifTool…", #selector(chooseExifTool), to: settings)
        add("Clear region setting", #selector(clearAllRegionData), to: settings)
        let developer = submenu("Developer tools")
        developer.addItem(detail); developer.addItem(.separator())
        add("Check selected photo", #selector(checkPhoto), to: developer)
        add("Show last result / timing…", #selector(showResult), to: developer)
        add("Inspect Lightroom view state…", #selector(inspectViewState), to: developer)
        add("Inspect Accessibility layout…", #selector(inspectLayout), to: developer)
        add("Preview captured Lightroom window…", #selector(previewCapture), to: developer)
        add("Find viewing area…", #selector(inspectScreen), to: developer)
        add("Bridge diagnostics…", #selector(showDiagnostics), to: developer)
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
        let prefs = UserDefaults.standard
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
            if let memory=self.placementMemory,memory.epoch != epoch || module != "develop" { self.placementMemory=nil }
            // A confirmed Library switch dismisses even a suspended overlay and
            // cancels an in-flight overlay request. Missing/stale heartbeats do neither.
            if module == "library" {
                if self.panel != nil || self.destination == .overlay { self.hide() }
                // Detection also requires Develop; discard its callback so a
                // quick return cannot resurrect an overlay from the old request.
                if self.screenInspectionID != nil { self.cancelScreenInspection() }
            }
            self.workspaceOverview=(self.panel != nil || self.placementMemory != nil) && workspaceOverviewIsVisible()
            self.observeWindowGeometry()
            if self.panel != nil { _ = self.orderOverlayAboveLightroom() }
            self.checkPanelBoundariesIfDue()
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
    var invocationStart:TimeInterval?
    func report(_ text: String) {
        lastResult = text; detail.title = String(text.prefix(100)); status.button?.toolTip = text
    }
    func updateIcon() {
        let visible = panel != nil
        status?.button?.image = NSImage(systemSymbolName: visible ? "camera.fill" : "camera", accessibilityDescription: visible ? "Camera Reference overlay visible" : "Camera Reference")
        status?.button?.image?.isTemplate = true
        status?.button?.title = ""
        updateToggleTitle()
    }
    func cancelRequest() {
        cancellation?.cancel(); cancellation = nil; pending = nil; destination = nil
        timer?.invalidate(); timer = nil
        try? FileManager.default.removeItem(at: folder.appendingPathComponent("request.txt"))
        try? FileManager.default.removeItem(at: folder.appendingPathComponent("response.txt"))
        updateToggleTitle()
    }
    func hide() {
        if destination == .overlay { cancelRequest() }
        (panel?.contentView as? ReferenceView)?.releaseContent()
        panel?.orderOut(nil); panel = nil;overlayHost=nil;overlayAccessibility=nil;overlayBaselineWindows=[];overlayDialogVisible=false;overlayEpoch=nil;overlaySuspended=false;updateIcon()
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
        let active=panel != nil || destination == .overlay || detectionCompletion != nil
        toggleItem?.title=(active ? "Hide overlay" : "Show overlay") + "   " + shortcutText(key:keyLabel,modifiers:currentShortcut.1)
    }
    func menuNeedsUpdate(_ menu:NSMenu) { updateToggleTitle();updateLayoutMenu() }
    @objc func menuToggle() { toggle() }
    func toggle() {
        if recording || calibration != nil { return }
        if destination == .overlay || panel != nil || detectionCompletion != nil { cancelScreenInspection(); hide(); report("Overlay cancelled."); return }
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
    func request(_ target: Destination) {
        guard !regionResetting else { return }
        cancelPanelCheck();nextPanelCheck=ProcessInfo.processInfo.systemUptime+reloadDetectionConfig().panelCheckIntervalSeconds
        cancelScreenInspection(); cancelRequest()
        let token = UUID().uuidString, work = Cancellation()
        pending = token; destination = target; cancellation = work
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
                self.failed("Plugin timed out. Reload the updated bridge 0.5.2 in Lightroom’s Plug-in Manager, then use File → Plug-in Extras → Start / restart Camera Reference bridge.", target: target)
            }
        }
    }
    func failed(_ text: String, target: Destination) {
        cancelRequest(); report(text)
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
        let loadStarted=ProcessInfo.processInfo.systemUptime
        let bridgeMS=(loadStarted-invoked)*1000
        let prefer = UserDefaults.standard.bool(forKey: "preferEmbedded")
        let executable = findExifTool(custom: UserDefaults.standard.string(forKey: "exiftool"))
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
                    loaded.stages += epoch == nil ? "; RAM cache unavailable: reload bridge 0.5.2 or check heartbeat":"; RAM cache miss"
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
                        guard self.isLightroom(), self.currentModule() == "develop" else { self.report("Overlay cancelled: Develop is no longer active."); return }
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
        p.contentView = view; panel = p;overlayMoveCount=0;overlayOrderCount=0;overlayLevelChangeCount=0;
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
        guard panel != nil, currentModule()=="develop" else { return }
        hide(); request(.overlay)
    }
    func validateMenuItem(_ item:NSMenuItem) -> Bool { true }
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
        let enabled = !UserDefaults.standard.bool(forKey: "preferEmbedded")
        UserDefaults.standard.set(enabled, forKey: "preferEmbedded"); preferItem.state = enabled ? .on : .off
        report("Source priority changed; applies on the next load or double-click refresh.")
    }
    @objc func chooseExifTool() {
        imageCache.clear()
        let picker = NSOpenPanel(); picker.title = "Choose the ExifTool executable"; picker.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        if picker.runModal() == .OK, let url = picker.url, FileManager.default.isExecutableFile(atPath: url.path) {
            UserDefaults.standard.set(url.path, forKey: "exiftool"); report("ExifTool location saved.")
        }
    }
    @objc func changeAutomatic() {
        let enabled = !UserDefaults.standard.bool(forKey: regionKey("automaticBounds"))
        UserDefaults.standard.set(enabled, forKey: regionKey("automaticBounds")); autoItem.state = enabled ? .on : .off
        cancelScreenInspection();cancelRequest();hide();invalidateAutomaticGeometry()
        if enabled { _ = FeaturePermission.screenCapture.ensure() }
        report(enabled ? "Automatic detection enabled. Manual calibration is the fallback." : "Using manual calibration.")
    }
    @objc func inspectViewState() {
        guard FeaturePermission.accessibility.ensure() else { return }
        report("Inspecting Lightroom menu state…")
        DispatchQueue.global(qos:.userInitiated).async { [weak self] in
            let result=probeLightroomViewState()
            DispatchQueue.main.async { self?.report(result);self?.showResult() }
        }
    }
    @objc func inspectLayout() {
        hide(); guard FeaturePermission.accessibility.ensure() else { return }
        report("Inspecting Lightroom’s accessible layout…")
        let size = lastImageSize
        DispatchQueue.global(qos: .userInitiated).async {
            let result = probeLightroom(imageSize: size)
            DispatchQueue.main.async {
                self.lastLayout = result.summary; self.report(result.summary); self.showResult()
            }
        }
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
        guard !regionResetting else { return }
        cancelPanelCheck()
        cancelScreenInspection(); hide(); cancelRequest(); calibration?.finish(nil)
        let settings=reloadDetectionConfig()
        let proposal=requestedProposal == nil ? nil:lastProbe?.uiFrame
        let selectionKind="ui"
        let controller=CalibrationController();controller.snapRadius=settings.snapDistancePoints; calibration=controller
        if overlayLayout != .full { controller.instruction="Select the entire \(overlayLayout.label.lowercased()) pane backdrop between panels and divider, including photo margins. ⌥ snaps; Esc cancels." }
        controller.completed = { [weak self] result in
            guard let self else { return }
            self.calibrationTask?.cancel(); self.calibrationTask=nil
            self.calibrationTimer?.invalidate();self.calibrationTimer=nil
            self.calibration=nil
            if let result {
                guard let window=lightroomWindowFrame(),window.contains(result) else {
                    self.report("Select the UI backdrop inside the Lightroom window. Previous calibration retained.");return
                }
                self.region=result; self.manualLayoutKey=self.lastProbe?.layoutKey
                UserDefaults.standard.set(selectionKind,forKey:self.regionKey("regionKind"))
                UserDefaults.standard.set(false,forKey:self.regionKey("automaticBounds")); self.autoItem.state = .off
                self.invalidateAutomaticGeometry()
                self.report("Image region saved. Shortcut toggles the reference.")
            }
            else { self.report("Calibration cancelled. Previous region retained.") }
        }
        guard #available(macOS 14.0,*),FeaturePermission.screenCapture.ensure() else {
            if calibration === controller { controller.start(proposal:proposal,snapAvailable:false) }; return
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
        controller.start(proposal:proposal,edges:result.snapEdges,snapAvailable:!result.snapEdges.isEmpty)
    }
    @objc func clearAllRegionData() {
        guard !regionResetting else { return };regionResetting=true
        calibration?.finish(nil);calibrationTask?.cancel();calibrationTask=nil
        calibrationTimer?.invalidate();calibrationTimer=nil
        cancelPanelCheck()
        cancelScreenInspection();cancelRequest();hide();saveToast.close();capturePreview?.close();capturePreview=nil
        clearRegionPreferences(UserDefaults.standard,layout:overlayLayout)
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
    @objc func previewCapture() {
        guard !regionResetting else { return }
        hide();calibration?.finish(nil);capturePreview?.close();capturePreview=nil
        guard #available(macOS 14.0,*),FeaturePermission.screenCapture.ensure() else { return }
        startPhotoDetection(imageSize:.zero,previewCapture:true) { [weak self] result in
            guard let self else { return }
            if let image=result.previewImage { self.capturePreview=CapturePreviewController(image:image) }
            else { self.report(result.summary);self.showResult() }
        }
    }
    @objc func inspectScreen() {
        guard !regionResetting else { return }
        guard screenTask == nil else { report("Screen inspection is already running."); return }
        guard #available(macOS 14.0, *) else { report("Screen-based inspection requires macOS 14 or newer. Manual calibration remains available."); showResult(); return }
        hide(); calibration?.finish(nil)
        guard currentModule()=="develop" else { report("Select a photograph in Lightroom Develop before screen inspection."); return }
        guard FeaturePermission.screenCapture.ensure() else { return }
        request(.detect) // Obtain the current JPEG aspect ratio, never a previous photo's.
    }
    func displayManual(_ image:CGImage,in area:CGRect,snapshot:ExportSnapshot?) {
        if UserDefaults.standard.string(forKey:regionKey("regionKind")) == "ui" {
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
        guard UserDefaults.standard.bool(forKey:regionKey("automaticBounds")) else {
            if let area=region { displayManual(image,in:area,snapshot:snapshot) }
            else { askForCalibration() }; return
        }
        if let ui=cachedUI(epoch:expectedEpoch,settings:settings,layout:overlayLayout) {
            showUI(image,ui:ui,snapshot:snapshot,settings:settings)
            return
        }
        guard #available(macOS 14.0,*), FeaturePermission.screenCapture.ensure() else {
            report("Automatic detection needs Screen Recording permission. Turn it off to use manual calibration."); return
        }
        startPhotoDetection(imageSize:CGSize(width:image.width,height:image.height)) { [weak self] result in
            guard let self, self.isLightroom(), self.currentModule()=="develop" else { return }
            if let expectedEpoch,self.selectionEpoch() != expectedEpoch { self.imageCache.observe(self.selectionEpoch());self.report("Selection changed during capture; invoke again.");return }
            guard let area=result.candidate else { self.askForCalibration(workingAreaTooNarrow:result.workingAreaTooNarrow); return }
            self.rememberPlacement(result,epoch:expectedEpoch,settings:settings,layout:self.overlayLayout)
            guard let view=self.display(image,in:area,photoFrame:result.photoFrame) else { return }
            view.exportSnapshot=snapshot
            view.backgroundColour=NSColor(srgbRed:result.background[0],green:result.background[1],blue:result.background[2],alpha:1)
            self.report("Reference shown using UI viewing-area bounds.")
        }
    }
    func askForCalibration(workingAreaTooNarrow:Bool = false) {
        let alert=NSAlert();alert.icon=NSApp.applicationIconImage
        alert.messageText="Cannot reliably identify viewing area."
        let automatic=UserDefaults.standard.bool(forKey:regionKey("automaticBounds"))
        alert.informativeText=(workingAreaTooNarrow ? "Working area too narrow—enlarge it or calibrate manually.\n\n":"") + calibrationInstructions(layout:overlayLayout,automatic:automatic)
        alert.addButton(withTitle:"Calibrate manually…"); alert.addButton(withTitle:"Cancel")
        NSApp.activate(ignoringOtherApps:true)
        if alert.runModal() == .alertFirstButtonReturn {
            beginCalibration(useManualOnAccept:true)
        } else { report("Overlay cancelled; calibration was not changed.") }
    }
    func startPhotoDetection(imageSize:CGSize,previewCapture:Bool=false,layout requestedLayout:OverlayLayout? = nil,completion:((ScreenProbeResult)->Void)? = nil) {
        guard #available(macOS 14.0, *), currentModule()=="develop" else { report("Detection cancelled: Develop is no longer active."); return }
        cancelPanelCheck()
        let settings=reloadDetectionConfig()
        let mode=requestedLayout ?? overlayLayout
        let seed=mode == overlayLayout && mode != .full ? region:nil
        cancelScreenInspection()
        report("Finding the Lightroom viewing area…")
        detectionCompletion=completion
        let inspectionID=UUID(); screenInspectionID=inspectionID
        let inspectionStarted=ProcessInfo.processInfo.systemUptime
        updateToggleTitle()
        screenTimeout=Timer(timeInterval:12,repeats:false) { [weak self] _ in
            guard let self,self.screenInspectionID==inspectionID else { return }
            let callback=self.detectionCompletion
            self.cancelScreenInspection()
            let result=ScreenProbeResult(candidate:nil,summary:"Screen capture timed out. Retry Find viewing area, or use manual calibration.")
            self.report(result.summary); callback?(result)
        }
        RunLoop.main.add(screenTimeout!,forMode:.common)
        screenTask=Task.detached(priority:.userInitiated) { [weak self] in
            let result=await inspectScreenLayout(imageSize:imageSize,previewCapture:previewCapture,settings:settings,layout:mode,seed:seed)
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
        lastTiming += String(format:"; capture and detection %.0f ms",elapsed*1000)
        let callback=detectionCompletion
        screenInspectionID=nil; screenTask=nil; screenTimeout?.invalidate(); screenTimeout=nil; detectionCompletion=nil
        updateToggleTitle()
        guard currentModule()=="develop" else { report("Detection cancelled: Develop is no longer active."); return }
        if result.geometryChanged { report(result.summary);lastLayout=result.summary;return }
        if let windowID=result.windowID, !sameWindowGeometry(result.windowFrame,currentCaptureWindowFrame(windowID)) {
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
    func bridgeDiagnostics() -> String {
        let heartbeat = folder.appendingPathComponent("heartbeat.txt")
        let attributes = try? FileManager.default.attributesOfItem(atPath: heartbeat.path)
        let date = attributes?[.modificationDate] as? Date
        let age = date.map { "\(max(0, Int(Date().timeIntervalSince($0)))) seconds ago" } ?? "not received"
        let state = (try? String(contentsOf: folder.appendingPathComponent("status.txt"), encoding: .utf8)) ?? "No plugin status. The bridge may not have started."
        return "\(versionTitle)\nHeartbeat: \(age)\nPlugin status: \(state)\nExifTool: \(findExifTool(custom: UserDefaults.standard.string(forKey: "exiftool")) == nil ? "not found" : "available")\n\n" + storageStatus + "\n" + overlayVisibilityStatus + "\n" + overlayLifecycleStatus + "\nWindow maintenance since show: moves \(overlayMoveCount); ordering changes \(overlayOrderCount); level changes \(overlayLevelChangeCount).\n" + lastLayout + "\n" + panelCheckStatus + "\n\nTiming: " + lastTiming
    }
    @objc func showDiagnostics() {
        let saved = lastResult
        report(bridgeDiagnostics())
        showResult()
        report(saved)
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
                let prefs=UserDefaults.standard
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
    @objc func quit() { cancelPanelCheck();imageCache.clear(); calibration?.finish(nil); cancelScreenInspection(); hide(); cancelRequest(); floating?.close(); NSApp.terminate(nil) }

}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
