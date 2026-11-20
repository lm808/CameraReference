import AppKit
import Carbon
import ImageIO
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation, NSMenuDelegate {
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
    var moduleTimer: Timer?
    var lastModuleSample: (String, Date)?
    var observedModule:String?
    var placementModule:String?
    var screenModule:String?
    var status: NSStatusItem!
    var workspaceOverview=false
    lazy var photoRequests=PhotoRequestPipeline(folder:folder)
    var assistedSignature:String?
    var assistedChecks=0,assistedAXChanges=0,assistedAXFailures=0,assistedPixelChanges=0,assistedPixelFailures=0
    var assistedCheckSeconds:Double=0,assistedAXSeconds:Double=0
    var assistedEvidence="No assisted comparison yet."
    static func screenHints(module:String?)->AXScreenHints? {
        let toolbar=accessibilityToolbarReading(module:module)
        var hints:AXScreenHints?
        _=accessibilityMappingReport { host,windows,_ in
            hints=AXScreenHints(host:host,visibleFrames:windows.filter(\.visible).map(\.frame),
                toolbar:toolbar.shown.map { $0 ? "shown":"hidden" } ?? "unknown")
        }
        return hints
    }
    var detectedLayout:OverlayLayout?
    var detectedLayoutModule:String?
    var viewProbeID:UUID?
    var liveViewBusy=false
    var nextLiveViewCheck:TimeInterval=0
    var liveViewGeneration=0
    var pendingAXPanelSignature:String?
    @objc func toggleAXLiveUpdate(_ item:NSMenuItem) {
        guard axPlacementEnabled else { return }
        CameraPreferences.shared.set(!axLiveUpdate,forKey:"axLiveUpdate")
        liveViewGeneration += 1;nextLiveViewCheck=0
        item.state=axLiveUpdate ? .on:.off
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
    var placementMemory:PlacementMemory?
    func regionKey(_ key:String,layout:OverlayLayout? = nil)->String {
        let base=regionPreferenceKey(key,layout:layout ?? (key == "automaticBounds" && automaticViewEnabled ? manualOverlayLayout:overlayLayout))
        return currentModule() == "library" ? "library."+base:base
    }
    var floatingHotKey: EventHotKeyRef?
    var floatingShortcut=(UInt32(kVK_ANSI_F),UInt32(controlKey | optionKey | cmdKey))
    var floatingKeyLabel="F"
    var hotKey: EventHotKeyRef?
    var handler: EventHandlerRef?
    var calibration: CalibrationController?
    var displayTimer: Timer?
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
    var panelCheckTask:Task<Void,Never>?
    var panelCheckID:UUID?
    var nextPanelCheck:TimeInterval=0
    var panelCheckStatus="Panel boundaries not yet checked in background."
    func cancelPanelCheck() { panelCheckTask?.cancel();panelCheckTask=nil;panelCheckID=nil }
    func checkPanelBoundariesIfDue() {
        guard !axPlacementEnabled else { cancelPanelCheck();panelCheckStatus="AX-only mode: background screenshot checks disabled; fresh AX geometry on invocation.";return }
        guard FeaturePermission.screenCapture.granted else { cancelPanelCheck();panelCheckStatus="Background capture paused: Screen Recording permission unavailable.";return }
        guard #available(macOS 14.0,*),ProcessInfo.processInfo.systemUptime>=nextPanelCheck,
              panelCheckTask==nil,screenTask==nil,pending==nil,calibration==nil,!recording,!regionResetting,
              !workspaceOverview,!overlaySuspended,isLightroom(),supportedLightroomModule(currentModule()),CameraPreferences.shared.bool(forKey:regionKey("automaticBounds")),
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
              placementMemory?.epoch==memory.epoch,selectionEpoch()==memory.epoch,
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
            if panel != nil { overlayVisibilityStatus="Overlay retained; cached placement invalidated: \(reason.lowercased())." }
        } else { panelCheckStatus="Background check: UI boundaries unchanged. Repeated toggle can skip capture." }
        panelCheckStatus += String(format:" 1280px check: %.0f ms elapsed.",elapsed*1000)
    }

    @objc func selectLayout(_ sender:NSMenuItem) {
        guard let raw=sender.representedObject as? String,let mode=OverlayLayout(rawValue:raw),mode != overlayLayout else { return }
        if automaticViewEnabled && (mode.group==0 || mode.group != overlayLayout.group) { return }
        cancelScreenInspection();cancelRequest();calibration?.finish(nil)
        if OverlayBehaviourPolicy.dismissForExplicitSelection(screenshot:screenshotDetectionEnabled) { hide() }
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
            if let memory=self.placementMemory,memory.epoch != epoch || !supportedLightroomModule(module) { self.placementMemory=nil }
            if OverlayBehaviourPolicy.moduleChanged(previous:self.observedModule,current:module) {
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
            self.checkOverlaySelection(epoch)
            // Module/heartbeat uncertainty invalidates reuse, not the user-visible image.
        }
        if let moduleTimer { RunLoop.main.add(moduleTimer,forMode:.common) }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(frontAppChanged), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(spaceChanged),name:NSWorkspace.activeSpaceDidChangeNotification,object:nil)
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
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
    func updateIcon() {
        let visible = panel != nil
        status?.button?.image = NSImage(systemSymbolName: visible ? "camera.fill" : "camera", accessibilityDescription: visible ? "Camera Reference overlay visible" : "Camera Reference")
        status?.button?.image?.isTemplate = true
        status?.button?.title = ""
        updateToggleTitle()
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


    func checkOverlaySelection(_ epoch:String?) {
        guard axPlacementEnabled,CameraPreferences.shared.bool(forKey:regionKey("automaticBounds")),
              let existing=panel,isLightroom(),supportedLightroomModule(currentModule()),
              displayedOverlayModule==currentModule(),let epoch else { return }
        guard let previous=overlayEpoch else { overlayEpoch=epoch;return }
        let action=OverlayBehaviourPolicy.photoSelectionChange(accessibility:true,automatic:true,overlayOpen:true,previous:previous,current:epoch,live:axLiveUpdate)
        if action == .dismiss {
            cancelScreenInspection();hide();report("Photo selection changed; overlay dismissed.");return
        }
        guard action == .adjust,attemptedSelectionRefresh != epoch,
              existing.isVisible,!overlaySuspended,!workspaceOverview,
              pending == nil,screenInspectionID == nil,viewProbeID == nil,calibration == nil,!liveViewBusy else { return }
        // One attempt per selection; failure keeps the old photo without retry storms.
        attemptedSelectionRefresh=epoch
        request(.overlay,viewChecked:true,refreshing:existing)
    }
    func refreshAXSelection(_ image:CGImage,snapshot:ExportSnapshot?,epoch:String,panel existing:OverlayPanel,generation:Int) {
        let module=currentModule(),host=overlayHost?.id,settings=reloadDetectionConfig()
        let height=CGDisplayBounds(CGMainDisplayID()).height
        startAXPlacement(epoch:epoch,full:false) { [weak self] ui in
            guard let self,self.panel === existing,self.axPlacementEnabled,self.axLiveUpdate,
                  self.liveViewGeneration==generation,self.selectionEpoch()==epoch,
                  self.currentModule()==module,self.overlayHost?.id==host,
                  self.isLightroom(),existing.isVisible,!self.overlaySuspended,
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
            self.overlayEpoch=epoch;self.livePanelSignature=self.pendingAXPanelSignature
            self.displayedOverlayLayout=self.overlayLayout
            self.recordLifecycle("photo selection refreshed; Fit reset")
            self.clearAXTrialBorders();self.runAXTrial(after:existing);self.saveInvocationDiagnostics()
        }
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
        let generation=liveViewGeneration,module=currentModule(),axMode=axPlacementEnabled,checkPanels=axPlacementEnabled && panel != nil
        let detectionSettings=reloadDetectionConfig()
        let fallback=detectionSettings.toolbarUnknownFallback
        let viewSettings=detectionSettings.viewClassificationSettings
        DispatchQueue.global(qos:.utility).async {
            let grid=axMode ? accessibilityGridReading(module:module):nil
            let toolbar=checkPanels ? accessibilityToolbarReading(fallback:fallback,module:module).effectiveState:"unknown"
            var proposal:AXTrialProposal?,hints:AXScreenHints?
            _=accessibilityMappingReport { host,windows,fullScreen in
                proposal=axTrialProposal(host:host,windows:windows,settings:viewSettings,fullScreen:fullScreen)
                if checkPanels { hints=AXScreenHints(host:host,visibleFrames:windows.filter(\.visible).map(\.frame),toolbar:toolbar) }
            }
            DispatchQueue.main.async {
                self.liveViewBusy=false
                guard self.automaticViewEnabled,self.liveViewGeneration==generation,module==self.currentModule(),
                      self.isLightroom(),self.pending == nil,self.viewProbeID == nil,self.screenInspectionID == nil,self.calibration == nil else { return }
                if let grid { self.lastGridStatus=grid.report }
                if OverlayBehaviourPolicy.isGridSelected(grid?.selected) {
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
                guard axMode,self.axPlacementEnabled else { return }
                let signature=hints?.signature
                let panelsChanged=signature != nil && self.livePanelSignature != nil && self.livePanelSignature != signature
                if self.livePanelSignature == nil { self.livePanelSignature=signature }
                self.followLiveOverlayView(mode,module:module,panelChange:panelsChanged,panelSignature:signature)
            }
        }
    }
    func followLiveOverlayView(_ mode:OverlayLayout,module:String?,requiresViewDetection:Bool=true,panelChange:Bool=false,panelSignature:String?=nil) {
        guard axPlacementEnabled,(!requiresViewDetection || automaticViewEnabled),CameraPreferences.shared.bool(forKey:regionKey("automaticBounds")),
              let module,module==displayedOverlayModule,(displayedOverlayLayout != mode || panelChange),
              let existing=panel else { return }
        if OverlayBehaviourPolicy.geometryChange(accessibility:true,automatic:true,displayed:displayedOverlayLayout,selected:mode,panelsChanged:panelChange,live:axLiveUpdate) == .dismiss {
            cancelScreenInspection();cancelRequest();hide()
            report("View, pane or panels changed; overlay dismissed.");return
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
            self.displayedOverlayLayout=mode;self.lastImageSize=image.size
            self.livePanelSignature=self.pendingAXPanelSignature ?? panelSignature
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
        let viewSettings=reloadDetectionConfig().viewClassificationSettings
        DispatchQueue.global(qos:.userInitiated).async {
            let grid=axMode ? accessibilityGridReading(module:module):nil
            var proposal:AXTrialProposal?
            let mapping=accessibilityMappingReport { host,windows,fullScreen in
                // No fine adjustments: only classify the raw visible panel/label evidence.
                proposal=axTrialProposal(host:host,windows:windows,settings:viewSettings,fullScreen:fullScreen)
            }
            DispatchQueue.main.async {
                guard self.viewProbeID==id else { return }
                self.viewProbeID=nil;self.updateToggleTitle()
                self.lastAXMapping=mapping
                if let grid { self.lastGridStatus=grid.report }
                if module==self.currentModule(),OverlayBehaviourPolicy.isGridSelected(grid?.selected) { self.dismissForGrid();return }
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
    var diagnosticSaveURL:URL { folder.deletingLastPathComponent().appendingPathComponent("Diagnostics/latest.txt") }
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
