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
        get { UserDefaults.standard.string(forKey:"manualLayoutKey") }
        set { UserDefaults.standard.set(newValue,forKey:"manualLayoutKey") }
    }
    func updateFloatingTitle() { floating?.title=floatingTitle + String(format:" — %.1f%%",floatingZoom) }
    let detectionSettings=DetectionConfigStore()
    var observedWindowFrame:CGRect?
    var hasObservedWindow=false
    var lastImageSize: CGSize?
    let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/CameraReference")
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
        guard let text=UserDefaults.standard.string(forKey:"region") else { return nil }
        return NSRectFromString(text)
    }
    var region: NSRect? {
        get {
            guard let r=savedRegion else { return nil }
            let saved=UserDefaults.standard.data(forKey:"regionDisplay").flatMap { try? JSONDecoder().decode(DisplayGeometry.self,from:$0) }
            guard calibratedRegionIsUsable(r,savedDisplay:saved,current:currentDisplays()) else { return nil }
            if let text=UserDefaults.standard.string(forKey:"regionWindow"),let current=lightroomWindowFrame() {
                return translatedCalibration(r,from:NSRectFromString(text),to:current)
            }
            return r
        }
        set {
            guard let newValue else { return } // Temporary display changes never erase calibration.
            UserDefaults.standard.set(NSStringFromRect(newValue),forKey:"region")
            if let frame=lightroomWindowFrame() { UserDefaults.standard.set(NSStringFromRect(frame),forKey:"regionWindow") }
            else { UserDefaults.standard.removeObject(forKey:"regionWindow") }
            if let screen=currentDisplays().first(where:{$0.frame.contains(newValue)}), let data=try? JSONEncoder().encode(screen) {
                UserDefaults.standard.set(data,forKey:"regionDisplay")
            }
        }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
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
        menu.addItem(.separator())
        let settings = submenu("Settings")
        preferItem = add("Prefer RAW-embedded JPEG", #selector(changePreference), to: settings)
        preferItem.state = UserDefaults.standard.bool(forKey: "preferEmbedded") ? .on : .off
        autoItem = add("Automatic viewing area", #selector(changeAutomatic), to: settings)
        autoItem.state = UserDefaults.standard.bool(forKey: "automaticBounds") ? .on : .off
        add("Set image region…", #selector(calibrate), to: settings)
        settings.addItem(.separator())
        shortcutItem = add("Overlay shortcut…", #selector(changeShortcut), to: settings)
        add("Floating display shortcut…", #selector(changeFloatingShortcut), to: settings)
        settings.addItem(.separator())
        add("Edit config file", #selector(openDetectionConfig), to: settings)
        add("Choose ExifTool…", #selector(chooseExifTool), to: settings)
        add("Clear all region data", #selector(clearAllRegionData), to: settings)
        let developer = submenu("Developer tools")
        developer.addItem(detail); developer.addItem(.separator())
        add("Check selected photo", #selector(checkPhoto), to: developer)
        add("Show last result / timing…", #selector(showResult), to: developer)
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
        if prefs.data(forKey:"regionDisplay") == nil, let previous=region { region=previous }
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
            self.observeWindowGeometry()
            guard self.panel != nil || self.destination == .overlay else { return }
            if let module = self.currentModule(), module != "develop" { self.hide(); self.report("Overlay dismissed: Lightroom left Develop.") }
            else if self.panel != nil && self.currentModule() == nil { self.hide(); self.report("Overlay dismissed: bridge status is unavailable.") }
        }
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
        panel?.orderOut(nil); panel = nil; updateIcon()
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
        if !isLightroom() && !own { saveToast.close(); hide(); calibration?.finish(nil) }
    }
    func invalidateAutomaticGeometry() {
        lastProbe=nil
        Task { await ScreenGeometryCache.shared.reset() }
    }
    func observeWindowGeometry() {
        let current=lightroomWindowFrame()
        defer { observedWindowFrame=current;hasObservedWindow=true }
        guard hasObservedWindow else { return }
        if current == nil && observedWindowFrame == nil { return }
        if !sameWindowGeometry(current,observedWindowFrame) {
            hide();invalidateAutomaticGeometry()
        }
    }
    @objc func spaceChanged() {
        hide();cancelScreenInspection();invalidateAutomaticGeometry()
        hasObservedWindow=false
    }
    @objc func displaysChanged() {
        invalidateAutomaticGeometry()
        hide(); calibration?.finish(nil)
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
    func menuNeedsUpdate(_ menu:NSMenu) { updateToggleTitle() }
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
                self.failed("Plugin timed out. Use Lightroom’s File → Plug-in Extras → Start / restart Camera Reference bridge.", target: target)
            }
        }
    }
    func failed(_ text: String, target: Destination) {
        cancelRequest(); report(text)
        if target == .window { floating?.title = floatingTitle + " — unchanged; refresh failed" }
    }
    func load(_ path: String, token: String, target: Destination, work: Cancellation, invoked: TimeInterval) {
        let loadStarted=ProcessInfo.processInfo.systemUptime
        let bridgeMS=(loadStarted-invoked)*1000
        let prefer = UserDefaults.standard.bool(forKey: "preferEmbedded")
        let executable = findExifTool(custom: UserDefaults.standard.string(forKey: "exiftool"))
        let automatic = false // Screen detection runs after loading, outside the UI thread.
        report("Loading camera JPEG…")
        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result<(LoadedReference, LayoutProbe?), Error> = Result {
                let loaded = try loadReference(raw: URL(fileURLWithPath: path), preferEmbedded: prefer, executable: executable, cancellation: work)
                let layout = automatic && target != .check && target != .detect ? probeLightroom(imageSize: CGSize(width: loaded.image.width, height: loaded.image.height)) : nil
                try work.check()
                return (loaded, layout)
            }
            DispatchQueue.main.async {
                guard self.pending == token, !work.isCancelled else { return }
                self.pending = nil; self.destination = nil; self.cancellation = nil
                self.updateToggleTitle()
                switch result {
                case .failure(let error):
                    self.report(error.localizedDescription)
                    if target == .window { self.floating?.title = self.floatingTitle + " — unchanged; refresh failed" }
                case .success(let (loaded, layout)):
                    self.lastTiming=String(format:"Bridge %.0f ms; JPEG load/decode %.0f ms",bridgeMS,loaded.elapsed*1000) + (loaded.extraction.map { String(format:" (extraction %.0f ms, included)",$0*1000) } ?? "")
                    self.lastImageSize = CGSize(width: loaded.image.width, height: loaded.image.height)
                    if let layout { self.lastLayout = layout.summary }
                    let elapsed = ProcessInfo.processInfo.systemUptime - invoked
                    let extraction = loaded.extraction.map { String(format: "; extraction %.0f ms", $0 * 1000) } ?? ""
                    self.report(loaded.origin.rawValue + (loaded.usedFallback ? " (fallback)" : "") + String(format: " · ready in %.0f ms", elapsed * 1000) + extraction)
                    let snapshot=loaded.embeddedBytes.map { ExportSnapshot(raw:URL(fileURLWithPath:path),bytes:$0,orientation:loaded.cameraOrientation) }
                    let detected = layout?.imageBounds
                    let recentArea: CGRect? = {
                        guard let probe=self.lastProbe, let frame=probe.windowFrame,let current=lightroomWindowFrame() else { return nil }
                        let previous=CGRect(x:frame.minX,y:CGDisplayBounds(CGMainDisplayID()).height-frame.maxY,width:frame.width,height:frame.height)
                        return probe.candidate.flatMap { translatedCalibration($0,from:previous,to:current) }
                    }()
                    let area = detected ?? recentArea ?? self.region
                    if target == .overlay {
                        guard self.isLightroom(), self.currentModule() == "develop" else { self.report("Overlay cancelled: Develop is no longer active."); return }
                        self.resolveOverlay(loaded.image,snapshot:snapshot)
                    } else if target == .detect {
                        self.startPhotoDetection(imageSize:CGSize(width:loaded.image.width,height:loaded.image.height))
                    } else if target == .window {
                        self.displayFloating(loaded.image, origin: loaded.origin, filename: loaded.sourceFilename, area: area)
                        self.floatingView?.exportSnapshot=snapshot
                    }
                }
            }
        }
    }
    func display(_ image: CGImage, in region: NSRect, photoFrame: NSRect? = nil) -> ReferenceView? {
        guard NSScreen.screens.contains(where: { $0.frame.contains(region) }) else {
            lastLayout += "\nOverlay rejected: region \(region) is outside current displays \(NSScreen.screens.map { $0.frame })."
            report("Set image region again for this display layout."); return nil
        }
        let p = OverlayPanel(contentRect: region.insetBy(dx: -1, dy: -1), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.level = .floating; p.isOpaque = true; p.backgroundColor = .black
        p.hasShadow = false; p.hidesOnDeactivate = false; p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = ReferenceView(frame: NSRect(origin: .zero, size: p.frame.size))
        view.showIndicator = true
        view.autoresizingMask = [.width, .height]
        configureImageView(view)
        view.refresh = { [weak self] in self?.reloadOverlay() }
        view.image = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        p.contentView = view; panel = p; p.orderFrontRegardless()
        let requested=region.insetBy(dx:-1,dy:-1)
        p.setFrame(requested,display:true)
        lastLayout += "\nOverlay panel requested (AppKit): \(requested). Actual: \(p.frame)."
        guard overlayPlacementIsAcceptable(requested:requested,actual:p.frame) else {
            hide();report("macOS moved the overlay panel. No offset overlay displayed; see geometry diagnostics.");return nil
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
            if floating.isVisible { floating.orderOut(nil) } else { floating.orderFrontRegardless() }
            updateToggleTitle(); return
        }
        request(.window)
    }
    func displayFloating(_ image: CGImage, origin: ImageOrigin, filename:String, area: NSRect?) {
        let ratio = NSSize(width: image.width, height: image.height)
        if floating == nil {
            let screen = NSScreen.screens.first(where: { area.map($0.frame.intersects) ?? false }) ?? NSScreen.main ?? NSScreen.screens[0]
            let base = area ?? screen.visibleFrame
            let photo = fittedSize(image: ratio, inside: (ratio.height > ratio.width ? base : screen.visibleFrame).size)
            let requested = ratio.height > ratio.width ? photo : CGSize(width: photo.width/2, height: photo.height/2)
            let size = fittedSize(image: requested, inside: CGSize(width: min(requested.width,screen.visibleFrame.width), height: min(requested.height,screen.visibleFrame.height-28)))
            let frame = NSRect(x: min(max(base.minX, screen.visibleFrame.minX), screen.visibleFrame.maxX-size.width),
                               y: min(max(base.midY-size.height/2, screen.visibleFrame.minY), screen.visibleFrame.maxY-size.height-28), width: size.width, height: size.height)
            let p = OverlayPanel(contentRect: frame, styleMask: [.titled, .closable, .resizable, .nonactivatingPanel], backing: .buffered, defer: false)
            p.level = .floating; p.isFloatingPanel = true; p.hidesOnDeactivate = false
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.isReleasedWhenClosed = false; p.backgroundColor = .black; p.delegate = self
            p.appearance = NSAppearance(named: .darkAqua)
            let view = ReferenceView(frame: NSRect(origin: .zero, size: size))
            configureImageView(view)
            view.zoomChanged = { [weak self] percentage in
                self?.floatingZoom=percentage
                if self?.destination != .window { self?.updateFloatingTitle() }
            }
            view.autoresizingMask = [.width, .height]
            view.refresh = { [weak self] in self?.request(.window) }
            p.contentView = view; floating = p; floatingView = view
        } else if let floating {
            // Keep the user's position and approximate size, while adapting to portrait/landscape changes.
            let box = floating.contentLayoutRect.size
            let area = box.width * box.height, aspect = ratio.width / ratio.height
            let desired = CGSize(width: sqrt(area * aspect), height: sqrt(area / aspect))
            let available = floating.screen?.visibleFrame.size ?? CGSize(width: 1200, height: 800)
            let limit = CGSize(width: min(desired.width, available.width * 0.9), height: min(desired.height, available.height * 0.85))
            floating.setContentSize(fittedSize(image: ratio, inside: limit))
        }
        floating?.contentAspectRatio = ratio
        floating?.contentMinSize = fittedSize(image: ratio, inside: CGSize(width: 180, height: 180))
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
        view.toolTip="Pinch: zoom. Two-finger scroll: pan. Command-scroll: zoom. Drag: pan. Double-click: reload and Fit. Right-click: Fit / 100% / Save."
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
                let alert = NSAlert(); alert.messageText = "Replace existing extracted JPEG?"
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
        let enabled = !UserDefaults.standard.bool(forKey: "preferEmbedded")
        UserDefaults.standard.set(enabled, forKey: "preferEmbedded"); preferItem.state = enabled ? .on : .off
        report("Source priority changed; applies on the next load or double-click refresh.")
    }
    @objc func chooseExifTool() {
        let picker = NSOpenPanel(); picker.title = "Choose the ExifTool executable"; picker.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        if picker.runModal() == .OK, let url = picker.url, FileManager.default.isExecutableFile(atPath: url.path) {
            UserDefaults.standard.set(url.path, forKey: "exiftool"); report("ExifTool location saved.")
        }
    }
    @objc func changeAutomatic() {
        let enabled = !UserDefaults.standard.bool(forKey: "automaticBounds")
        UserDefaults.standard.set(enabled, forKey: "automaticBounds"); autoItem.state = enabled ? .on : .off
        if enabled { hide(); _ = FeaturePermission.screenCapture.ensure() }
        report(enabled ? "Automatic detection enabled. Manual calibration is the fallback." : "Using manual calibration.")
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
                if error != nil { DispatchQueue.main.async { self?.report("Could not open TextEdit. Edit detection.conf as plain text in Application Support/Camera Reference.");self?.showResult() } }
            }
        }
        catch { report("Could not open detection.conf: \(error.localizedDescription)");showResult() }
    }
    func reloadDetectionConfig()->DetectionConfig {
        do { return try detectionSettings.reload() }
        catch {
            let alert=NSAlert();alert.messageText="Detection configuration was not applied"
            alert.informativeText=error.localizedDescription+" The last valid settings will be used."
            alert.runModal();return detectionSettings.current
        }
    }
    @objc func calibrate() { beginCalibration() }
    func beginCalibration(proposal:CGRect? = nil, useManualOnAccept:Bool = false) {
        guard !regionResetting else { return }
        cancelScreenInspection(); hide(); cancelRequest(); calibration?.finish(nil)
        let settings=reloadDetectionConfig()
        let controller=CalibrationController();controller.snapRadius=settings.snapDistancePoints; calibration=controller
        controller.completed = { [weak self] result in
            guard let self else { return }
            self.calibrationTask?.cancel(); self.calibrationTask=nil
            self.calibrationTimer?.invalidate();self.calibrationTimer=nil
            self.calibration=nil
            if let result {
                self.region=result; self.manualLayoutKey=self.lastProbe?.layoutKey
                if useManualOnAccept {
                    UserDefaults.standard.set(false,forKey:"automaticBounds"); self.autoItem.state = .off
                }
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
        cancelScreenInspection();cancelRequest();hide();saveToast.close();capturePreview?.close();capturePreview=nil
        clearRegionPreferences(UserDefaults.standard)
        acceptedSplitKey=nil;lastProbe=nil;lastImageSize=nil
        lastLayout="No region data. Detection/calibration starts fresh."
        report("Clearing region data…")
        Task { @MainActor [weak self] in
            await ScreenGeometryCache.shared.reset()
            guard let self else { return };self.regionResetting=false
            self.report("All region data cleared. Shortcut and JPEG preferences retained.")
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
    func resolveOverlay(_ image:CGImage,snapshot:ExportSnapshot?) {
        guard UserDefaults.standard.bool(forKey:"automaticBounds") else {
            if let area=region { display(image,in:area)?.exportSnapshot=snapshot }
            else { askForCalibration() }; return
        }
        guard #available(macOS 14.0,*), FeaturePermission.screenCapture.ensure() else {
            report("Automatic detection needs Screen Recording permission. Turn it off to use manual calibration."); return
        }
        startPhotoDetection(imageSize:CGSize(width:image.width,height:image.height)) { [weak self] result in
            guard let self, self.isLightroom(), self.currentModule()=="develop" else { return }
            if let key=result.layoutKey,key==self.manualLayoutKey,let area=self.region {
                self.display(image,in:area)?.exportSnapshot=snapshot; return
            }
            guard let area=result.candidate else { self.askForCalibration(workingAreaTooNarrow:result.workingAreaTooNarrow); return }
            if result.split && self.acceptedSplitKey != result.layoutKey {
                let alert=NSAlert(); alert.messageText="Use the left or upper reference pane?"
                alert.informativeText="A split layout was found. Confirm this is Reference view; Before/After can have similar dividers."
                alert.addButton(withTitle:"Use reference pane"); alert.addButton(withTitle:"Calibrate manually…"); alert.addButton(withTitle:"Cancel")
                NSApp.activate(ignoringOtherApps:true)
                let choice=alert.runModal()
                if choice == .alertSecondButtonReturn { self.beginCalibration(); return }
                guard choice == .alertFirstButtonReturn else { self.report("Overlay cancelled."); return }
                self.acceptedSplitKey=result.layoutKey
                NSWorkspace.shared.runningApplications.first(where:isLightroomApp)?.activate(options:[])
            }
            guard let view=self.display(image,in:area,photoFrame:result.photoFrame) else { return }
            view.exportSnapshot=snapshot
            view.backgroundColour=NSColor(srgbRed:result.background[0],green:result.background[1],blue:result.background[2],alpha:1)
            self.report("Reference shown using UI viewing-area bounds.")
        }
    }
    func askForCalibration(workingAreaTooNarrow:Bool = false) {
        let alert=NSAlert(); alert.messageText=workingAreaTooNarrow ? "Working area too narrow for automatic placement—enlarge it or calibrate manually." : "Select the reference viewing area"
        alert.informativeText="The viewing area could not be identified reliably. Drag around the area for the JPEG, then invoke the overlay again. Accepting a region switches to manual mode. Cancelling keeps your current mode and region."
        alert.addButton(withTitle:"Calibrate manually…"); alert.addButton(withTitle:"Cancel")
        NSApp.activate(ignoringOtherApps:true)
        if alert.runModal() == .alertFirstButtonReturn {
            beginCalibration(useManualOnAccept:true)
        } else { report("Overlay cancelled; calibration was not changed.") }
    }
    func startPhotoDetection(imageSize:CGSize,previewCapture:Bool=false,completion:((ScreenProbeResult)->Void)? = nil) {
        guard #available(macOS 14.0, *), currentModule()=="develop" else { report("Detection cancelled: Develop is no longer active."); return }
        let settings=reloadDetectionConfig()
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
            let result=await inspectScreenLayout(imageSize:imageSize,previewCapture:previewCapture,settings:settings)
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
        let alert=NSAlert(); alert.messageText="Viewing area detection"; alert.informativeText=result.summary
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
        return "\(versionTitle)\nHeartbeat: \(age)\nPlugin status: \(state)\nExifTool: \(findExifTool(custom: UserDefaults.standard.string(forKey: "exiftool")) == nil ? "not found" : "available")\n\n" + lastLayout + "\n\nTiming: " + lastTiming
    }
    @objc func showDiagnostics() {
        let saved = lastResult
        report(bridgeDiagnostics())
        showResult()
        report(saved)
    }
    @objc func showResult() {
        hide(); NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert(); alert.messageText = "Camera Reference"; alert.informativeText = lastResult + "\n\n" + lastTiming; alert.runModal()
    }
    @objc func changeShortcut() { editShortcut(floatingTarget:false) }
    @objc func changeFloatingShortcut() { editShortcut(floatingTarget:true) }
    func editShortcut(floatingTarget:Bool) {
        hide(); calibration?.finish(nil); recording=true
        let original=floatingTarget ? floatingShortcut:currentShortcut
        // Suspend the global shortcut while recording so its keystroke reaches the recorder.
        if floatingTarget {
            if let floatingHotKey { UnregisterEventHotKey(floatingHotKey); self.floatingHotKey=nil }
        } else if let hotKey { UnregisterEventHotKey(hotKey); self.hotKey=nil }
        defer { recording=false; updateToggleTitle() }
        NSApp.activate(ignoringOtherApps:true)
        let alert=NSAlert(); alert.messageText=floatingTarget ? "Floating Display Shortcut":"Overlay Shortcut"
        alert.informativeText=floatingTarget ? "Show or hide the independent floating display. Click the shortcut to change it." : "Show or hide the camera reference over Lightroom. Click the shortcut to change it."
        let recorder=ShortcutRecorder(shortcut:original,label:floatingTarget ? floatingKeyLabel:keyLabel)
        recorder.defaultShortcut=floatingTarget ? (UInt32(kVK_ANSI_F),UInt32(controlKey|optionKey|cmdKey)): (UInt32(kVK_ANSI_J),UInt32(controlKey|optionKey|cmdKey))
        recorder.defaultLabel=floatingTarget ? "F":"J"
        recorder.setAccessibilityLabel(alert.messageText)
        let help=NSTextField(wrappingLabelWithString:"Click the shortcut field, then press a new combination.")
        recorder.help=help
        let reset=NSButton(title:"Use Default",target:recorder,action:#selector(ShortcutRecorder.useDefault))
        let stack=NSStackView(views:[recorder,reset,help]); stack.orientation = .vertical; stack.alignment = .centerX; stack.spacing=12
        stack.frame=CGRect(x:0,y:0,width:340,height:120)
        recorder.widthAnchor.constraint(equalToConstant:240).isActive=true
        help.widthAnchor.constraint(equalToConstant:330).isActive=true
        alert.accessoryView=stack; alert.addButton(withTitle:"Save"); alert.addButton(withTitle:"Cancel")
        while true {
            if alert.runModal() != .alertFirstButtonReturn {
                if !register(original,floatingTarget:floatingTarget) { report("Previous shortcut is unavailable. Choose another shortcut.") }; break
            }
            if register(recorder.candidate,floatingTarget:floatingTarget) {
                let prefs=UserDefaults.standard
                if floatingTarget {
                    floatingKeyLabel=recorder.keyLabel
                    prefs.set(floatingShortcut.0,forKey:"floatingKey");prefs.set(floatingShortcut.1,forKey:"floatingModifiers");prefs.set(floatingKeyLabel,forKey:"floatingKeyLabel")
                } else {
                    keyLabel=recorder.keyLabel
                    prefs.set(currentShortcut.0,forKey:"key");prefs.set(currentShortcut.1,forKey:"modifiers");prefs.set(keyLabel,forKey:"keyLabel")
                }
                report("Shortcut saved."); break
            }
            help.stringValue="That shortcut is unavailable. Choose another, or Cancel."
        }
    }
    @objc func cancel() { calibration?.finish(nil); hide(); report("Ready.") }
    @objc func quit() { calibration?.finish(nil); cancelScreenInspection(); hide(); cancelRequest(); floating?.close(); NSApp.terminate(nil) }

}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
