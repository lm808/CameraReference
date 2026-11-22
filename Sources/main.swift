import AppKit
import Carbon
import ImageIO
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation, NSMenuDelegate {
    // MARK: - Composition and shared operation state
    lazy var lightroomMonitor=LightroomMonitor(folder:folder)
    let overlayController=OverlayController()
    let floatingController=FloatingDisplayController()
    let diagnostics=DiagnosticsService()
    let settings=AppSettings()
    lazy var menus=SettingsMenuController(owner:self)
    var saving = false
    let saveToast=SaveToastController()
    var versionTitle: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        return "\(Bundle.main.object(forInfoDictionaryKey:"CFBundleDisplayName") as? String ?? "Camera Reference") \(version)"
    }
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
    let detectionSettings=DetectionConfigStore()
    var configEditor:ConfigEditorController?
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
    var placementModule:String?
    var screenModule:String?
    var status: NSStatusItem!
    lazy var photoRequests=PhotoRequestPipeline(folder:folder)
    var viewProbeID:UUID?
    var pendingAXPanelSignature:String?
    var manualOverlayLayout:OverlayLayout { savedOverlayLayout(CameraPreferences.shared,module:currentModule() ?? lightroomMonitor.observedModule) }
    var overlayLayout:OverlayLayout {
        get {
            if automaticViewEnabled,lightroomMonitor.detectedLayoutModule == currentModule(),let mode=lightroomMonitor.detectedLayout,
               CameraPreferences.shared.bool(forKey:regionKey("automaticBounds",layout:manualOverlayLayout)) { return mode }
            return manualOverlayLayout
        }
        set { CameraPreferences.shared.set(newValue.rawValue,forKey:overlayLayoutPreferenceKey(module:currentModule() ?? lightroomMonitor.observedModule)) }
    }
    var placementMemory:PlacementMemory?
    func regionKey(_ key:String,layout:OverlayLayout? = nil)->String {
        let base=regionPreferenceKey(key,layout:layout ?? (key == "automaticBounds" && automaticViewEnabled ? manualOverlayLayout:overlayLayout))
        return currentModule() == "library" ? "library."+base:base
    }
    var floatingHotKey: EventHotKeyRef?
    var floatingShortcut=(UInt32(kVK_ANSI_F),UInt32(controlKey | optionKey | cmdKey))
    var floatingKeyLabel="F"
    var hotKey: EventHotKeyRef?
    var viewHotKeys=[EventHotKeyRef]()
    var handler: EventHandlerRef?
    var calibration: CalibrationController?
    var screenTask: Task<Void, Never>?
    var screenInspectionID: UUID?
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

    // MARK: - Startup and native action wiring
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
        settings.registerAndMigrate()
        do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]) }
        catch { fatalError("Cannot create bridge directory: \(error)") }
        consolidateStorageIfDue()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()
        status.menu = menus.build()
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            var identifier=EventHotKeyID()
            guard let event, GetEventParameter(event,EventParamName(kEventParamDirectObject),EventParamType(typeEventHotKeyID),nil,MemoryLayout<EventHotKeyID>.size,nil,&identifier) == noErr else { return OSStatus(eventNotHandledErr) }
            let owner=Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            if identifier.id >= 10 { owner.handleViewShortcut(identifier.id) } else if identifier.id == 2 { owner.openFloating() } else { owner.toggle() }
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
        if !registerViewShortcuts() { report("A view shortcut is unavailable. Check Keyboard shortcuts.") }
        updateToggleTitle()
        lightroomMonitor.start(workspaceCenter:NSWorkspace.shared.notificationCenter) { [weak self] event in
            self?.handleLightroomEvent(event)
        }
    }
    func register(_ shortcut: (UInt32, UInt32), floatingTarget:Bool=false) -> Bool {
        if shortcut.1==0 {
            if floatingTarget { if let floatingHotKey { UnregisterEventHotKey(floatingHotKey) };floatingHotKey=nil;floatingShortcut=shortcut }
            else { if let hotKey { UnregisterEventHotKey(hotKey) };hotKey=nil;currentShortcut=shortcut }
            return true
        }
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
    func updateIcon() {
        let visible = panel != nil
        status?.button?.image = NSImage(systemSymbolName: visible ? "camera.fill" : "camera", accessibilityDescription: visible ? "Camera Reference overlay visible" : "Camera Reference")
        status?.button?.image?.isTemplate = true
        status?.button?.title = ""
        updateToggleTitle()
    }

    // MARK: - Shared geometry invalidation and invocation entry points
    func invalidateAutomaticGeometry() {
        cancelPanelCheck()
        lastProbe=nil;placementMemory=nil
        Task { await ScreenGeometryCache.shared.reset() }
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

    var diagnosticSaveURL:URL { folder.deletingLastPathComponent().appendingPathComponent("Diagnostics/latest.txt") }
    func requireSupportedModule()->Bool {
        guard !supportedLightroomModule(currentModule()) else { return true }
        let alert=NSAlert();alert.icon=NSApp.applicationIconImage
        alert.messageText="Switch Lightroom to Library or Develop"
        alert.informativeText="Camera Reference supports Library and Develop only. Switch to either module, then try again. In Library, use Loupe for single-photo placement."
        NSApp.activate(ignoringOtherApps:true);alert.runModal();return false
    }

    @objc func showResult() {
        hide(); NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert();alert.icon=NSApp.applicationIconImage; alert.messageText = "Camera Reference"; alert.informativeText = lastResult + "\n\n" + lastTiming; alert.runModal()
    }
    // MARK: - Shortcut recording
    // MARK: - Cancellation and shutdown
    @objc func cancel() { calibration?.finish(nil); hide(); report("Ready.") }
    @objc func quit() { cancelPanelCheck();imageCache.clear(); calibration?.finish(nil); cancelScreenInspection(); hide(); cancelRequest(); diagnosticsWindow?.close(); captureBaseline?.close(); capturePreview?.close(); floating?.close(); NSApp.terminate(nil) }

}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
