import AppKit

/// Builds and refreshes menus at the original call sites. Actions continue to
/// target AppDelegate; owning menu references does not change action policy.
final class SettingsMenuController {
    unowned let owner:AppDelegate
    init(owner:AppDelegate) { self.owner=owner }
    var preferItem: NSMenuItem!
    var autoItem: NSMenuItem!
    var detail: NSMenuItem!
    var shortcutItem: NSMenuItem!
    var screenshotToggleItem:NSMenuItem?
    var viewToggleItem:NSMenuItem?
    var screenshotReuseItem:NSMenuItem?
    var detectionMethodItems=[NSMenuItem]()
    var liveUpdateItem:NSMenuItem?
    var layoutItems=[OverlayLayout:NSMenuItem]()
    var layoutRoot:NSMenuItem?
    let layoutChoices=NSMenu()
    var layoutSeparator:NSMenuItem?
    var floatingMenuItem:NSMenuItem!
    var toggleItem: NSMenuItem!
    var versionTitle:String { owner.versionTitle }
    var axPlacementEnabled:Bool { owner.axPlacementEnabled }
    var screenshotDetectionEnabled:Bool { owner.screenshotDetectionEnabled }
    var axLiveUpdate:Bool { owner.axLiveUpdate }
    var automaticViewEnabled:Bool { owner.automaticViewEnabled }
    var autoDiagnostics:Bool { owner.autoDiagnostics }
    var axTrialEnabled:Bool { owner.axTrialEnabled }
    var detectedLayoutModule:String? { owner.lightroomMonitor.detectedLayoutModule }
    var detectedLayout:OverlayLayout? { owner.lightroomMonitor.detectedLayout }
    var overlayLayout:OverlayLayout { owner.overlayLayout }
    var floating:NSPanel? { owner.floating }
    var floatingKeyLabel:String { owner.floatingKeyLabel }
    var floatingShortcut:(UInt32,UInt32) { owner.floatingShortcut }
    var panel:OverlayPanel? { owner.panel }
    var destination:Destination? { owner.destination }
    var viewProbeID:UUID? { owner.viewProbeID }
    var detectionCompletion:((ScreenProbeResult)->Void)? { owner.detectionCompletion }
    var keyLabel:String { owner.keyLabel }
    var currentShortcut:(UInt32,UInt32) { owner.currentShortcut }
    func currentModule()->String? { owner.currentModule() }
    func regionKey(_ key:String)->String { owner.regionKey(key) }
    func build()->NSMenu {
        let menu = NSMenu(); menu.delegate=owner
        // The root Loupe row is informational, enabled but deliberately actionless.
        // Top-level commands always validated true; child menus retain validation.
        menu.autoenablesItems=false
        let versionItem=NSMenuItem(title: versionTitle, action: nil, keyEquivalent: "")
        versionItem.isEnabled=false;menu.addItem(versionItem)
        menu.addItem(.separator())
        detail = NSMenuItem(title: "Ready — first test: Check selected photo", action: nil, keyEquivalent: "")
        floatingMenuItem = add("Show floating display", #selector(AppDelegate.openFloating), to: menu)
        toggleItem = add("Show overlay", #selector(AppDelegate.menuToggle), to: menu)
        func submenu(_ title: String) -> NSMenu {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let child = NSMenu(title: title); item.submenu = child; menu.addItem(item); return child
        }
        buildLayoutMenu(menu)
        menu.addItem(.separator())
        let settings = submenu("Settings")
        shortcutItem = add("Keyboard shortcuts…", #selector(AppDelegate.changeShortcut), to: settings)
        settings.addItem(.separator())
        preferItem = add("Prefer RAW-embedded JPEG", #selector(AppDelegate.changePreference), to: settings)
        preferItem.state = CameraPreferences.shared.bool(forKey: "preferEmbedded") ? .on : .off
        add("Choose ExifTool…", #selector(AppDelegate.chooseExifTool), to: settings)
        settings.addItem(.separator())
        autoItem = add("Auto-detect viewing area", #selector(AppDelegate.changeAutomatic), to: settings)
        autoItem.state = CameraPreferences.shared.bool(forKey: regionKey("automaticBounds")) ? .on : .off
        add("Set overlay region…", #selector(AppDelegate.calibrate), to: settings)
        add("Clear overlay region setting", #selector(AppDelegate.clearAllRegionData), to: settings)
        settings.addItem(.separator())
        let method=NSMenuItem(title:"Detection method",action:nil,keyEquivalent:"")
        let methods=NSMenu();method.submenu=methods;settings.addItem(method);screenshotToggleItem=method
        for (title,value) in [("Screenshot",true),("Accessibility",false)] {
            let item=add(title,#selector(AppDelegate.selectDetectionMethod(_:)),to:methods)
            item.representedObject=value;detectionMethodItems.append(item)
        }
        viewToggleItem=add("AX view detection",#selector(AppDelegate.toggleAutomaticView),to:settings)
        viewToggleItem?.indentationLevel=1
        liveUpdateItem=add("Update overlay with LrC view",#selector(AppDelegate.toggleAXLiveUpdate(_:)),to:settings)
        liveUpdateItem?.indentationLevel=1
        updateDetectionMenu()
        settings.addItem(.separator())
        add("Advanced settings…", #selector(AppDelegate.editAdvancedSettings), to: settings)
        let developer = submenu("Developer tools")
        developer.addItem(detail); developer.addItem(.separator())
        add("Diagnostics…", #selector(AppDelegate.showDiagnostics), to: developer)
        add("Record window ordering (5-second delay)…", #selector(AppDelegate.recordWindowOrdering), to: developer)
        let copy=add("Save diagnostics after invocation", #selector(AppDelegate.toggleAutoDiagnostics), to: developer)
        copy.state = autoDiagnostics ? .on:.off
        developer.addItem(.separator())
        screenshotReuseItem=add("Reuse screenshot working area",#selector(AppDelegate.toggleScreenshotWorkingAreaReuse(_:)),to:developer)
        updateDetectionMenu()
        let trial=add("Show AX placement preview",#selector(AppDelegate.toggleAXTrial),to:developer)
        trial.state=axTrialEnabled ? .on:.off
        add("Guided AX calibration…",#selector(AppDelegate.guidedAXCalibration),to:developer)
        let actions=NSMenu();let actionsItem=NSMenuItem(title:"Capture / bridge actions",action:nil,keyEquivalent:"")
        actionsItem.submenu=actions;developer.addItem(actionsItem)
        add("Check selected photo", #selector(AppDelegate.checkPhoto), to: actions)
        add("Inspect Lightroom view state…", #selector(AppDelegate.inspectViewState), to: actions)
        add("Keep on-screen capture baseline…", #selector(AppDelegate.keepCaptureBaseline), to: actions)
        add("Preview captured Lightroom window…", #selector(AppDelegate.previewCapture), to: actions)
        add("Find viewing area…", #selector(AppDelegate.inspectScreen), to: actions)
        menu.addItem(.separator())
        add("Quit Camera Reference", #selector(AppDelegate.quit), to: menu)
        return menu
    }
    private func layoutSymbol(_ mode:OverlayLayout)->String {
        switch mode {
        case .full: return "▣"
        case .left: return "◧"
        case .right: return "◨"
        case .upper: return "⬒"
        case .lower: return "⬓"
        }
    }
    private func paneTitle(_ mode:OverlayLayout)->String {
        switch mode {
        case .full: return "Loupe View"
        case .left: return "Left"
        case .right: return "Right"
        case .upper: return "Top"
        case .lower: return "Bottom"
        }
    }
    private func layoutTitle(_ mode:OverlayLayout)->String {
        switch mode {
        case .full: return "Loupe View"
        case .left: return "Reference View (Left)"
        case .right: return "Reference View (Right)"
        case .upper: return "Reference View (Top)"
        case .lower: return "Reference View (Bottom)"
        }
    }
    func buildLayoutMenu(_ menu:NSMenu) {
        layoutSeparator=NSMenuItem.separator();menu.addItem(layoutSeparator!)
        let root=NSMenuItem(title:"",action:nil,keyEquivalent:"")
        menu.addItem(root);layoutRoot=root
        for mode in OverlayLayout.allCases {
            let item=add(layoutTitle(mode),#selector(AppDelegate.selectLayout(_:)),to:layoutChoices)
            item.representedObject=mode.rawValue;item.image=layoutMenuIcon(mode);layoutItems[mode]=item
        }
        updateLayoutMenu()
    }
    func updateLayoutMenu() {
        let hidden = !CameraPreferences.shared.bool(forKey:regionKey("automaticBounds"))
        layoutSeparator?.isHidden=hidden
        guard let root=layoutRoot else { return }
        root.isHidden=hidden;root.state = .off
        let inferred=detectedLayoutModule == currentModule() ? detectedLayout:nil
        let mode=overlayLayout
        let unknown=automaticViewEnabled && inferred == nil
        root.title=unknown ? "View detected on next invocation":layoutSymbol(mode)+"  "+layoutTitle(mode)+owner.viewShortcutSuffix(mode)
        styleShortcut(root,suffix:unknown ? "":owner.viewShortcutSuffix(mode))
        root.image=unknown ? nil:layoutItems[mode]?.image
        let hasChoices = !unknown && (!automaticViewEnabled || mode != .full)
        if hasChoices {
            if root.submenu !== layoutChoices { root.submenu=layoutChoices }
        } else {
            root.submenu=nil;root.action=nil;root.target=nil
        }
        root.isEnabled = !unknown
        for (choice,item) in layoutItems {
            item.title=layoutSymbol(choice)+"  "+(automaticViewEnabled ? paneTitle(choice):layoutTitle(choice))+owner.viewShortcutSuffix(choice)
            styleShortcut(item,suffix:owner.viewShortcutSuffix(choice))
            item.isHidden=automaticViewEnabled && (unknown || choice.group != mode.group)
            item.state=choice==mode ? .on:.off
        }
    }
    func updateDetectionMenu() {
        let automatic=CameraPreferences.shared.bool(forKey:regionKey("automaticBounds"))
        screenshotReuseItem?.state=owner.settings.reuseScreenshotWorkingArea ? .on:.off
        screenshotReuseItem?.isEnabled=screenshotDetectionEnabled
        screenshotToggleItem?.title="Detection method: " + (screenshotDetectionEnabled ? "Screenshot":"Accessibility")
        screenshotToggleItem?.isEnabled=automatic
        for item in detectionMethodItems {
            item.state=(item.representedObject as? Bool)==screenshotDetectionEnabled ? .on:.off
            item.isEnabled=automatic
        }
        liveUpdateItem?.isHidden=screenshotDetectionEnabled
        liveUpdateItem?.isEnabled=automatic && axPlacementEnabled
        liveUpdateItem?.state=axLiveUpdate ? .on:.off
        viewToggleItem?.isHidden=axPlacementEnabled
        viewToggleItem?.state=automaticViewEnabled ? .on:.off
        viewToggleItem?.isEnabled=automatic && screenshotDetectionEnabled
    }
    func updateToggleTitle() {
        floatingMenuItem?.title=(floating?.isVisible == true ? "Hide floating display" : "Show floating display") + "   " + shortcutText(key:floatingKeyLabel,modifiers:floatingShortcut.1)
        styleShortcut(floatingMenuItem,suffix:shortcutText(key:floatingKeyLabel,modifiers:floatingShortcut.1))
        let active=panel != nil || destination == .overlay || viewProbeID != nil || detectionCompletion != nil
        toggleItem?.title=(active ? "Hide overlay" : "Show overlay") + "   " + shortcutText(key:keyLabel,modifiers:currentShortcut.1)
        styleShortcut(toggleItem,suffix:shortcutText(key:keyLabel,modifiers:currentShortcut.1))
    }
    // Presentation only: keep plain titles and native actions/bindings intact.
    private func styleShortcut(_ item:NSMenuItem?,suffix:String) {
        guard let item else { return }
        guard !suffix.isEmpty,item.title.hasSuffix(suffix) else { item.attributedTitle=nil;return }
        let title=NSMutableAttributedString(string:item.title)
        let length=(suffix as NSString).length
        title.addAttribute(.foregroundColor,value:NSColor.secondaryLabelColor,
                           range:NSRange(location:title.length-length,length:length))
        item.attributedTitle=title
    }
    func validateMenuItem(_ item:NSMenuItem) -> Bool {
        if item === screenshotReuseItem { return screenshotDetectionEnabled }
        if item === liveUpdateItem { return axPlacementEnabled && CameraPreferences.shared.bool(forKey:regionKey("automaticBounds")) }
        if item === viewToggleItem {
            return screenshotDetectionEnabled && CameraPreferences.shared.bool(forKey:regionKey("automaticBounds"))
        }
        if detectionMethodItems.contains(where:{$0 === item}) { return CameraPreferences.shared.bool(forKey:regionKey("automaticBounds")) }
        return true
    }
    @discardableResult func add(_ title: String, _ action: Selector, to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = owner; menu.addItem(item); return item
    }
}

extension AppDelegate {
    var screenshotDetectionEnabled:Bool { settings.screenshotDetectionEnabled }
    var expandedScreenshotReuse:Bool { settings.expandedScreenshotReuse }
    var legacyPlacementMode:AutomaticPlacementMode { settings.legacyPlacementMode }
    var automaticPlacementMode:AutomaticPlacementMode { settings.automaticPlacementMode }
    var axPlacementEnabled:Bool { settings.axPlacementEnabled }
    var automaticViewEnabled:Bool { settings.automaticViewEnabled }
    var axLiveUpdate:Bool { settings.axLiveUpdate }
    var axTrialEnabled:Bool { settings.axTrialEnabled }
    var autoDiagnostics:Bool { settings.autoDiagnostics }
    var preferItem:NSMenuItem! {
        get { menus.preferItem }
        set { menus.preferItem=newValue }
    }
    var autoItem:NSMenuItem! {
        get { menus.autoItem }
        set { menus.autoItem=newValue }
    }
    var detail:NSMenuItem! {
        get { menus.detail }
        set { menus.detail=newValue }
    }
    var shortcutItem:NSMenuItem! {
        get { menus.shortcutItem }
        set { menus.shortcutItem=newValue }
    }
    var screenshotToggleItem:NSMenuItem? {
        get { menus.screenshotToggleItem }
        set { menus.screenshotToggleItem=newValue }
    }
    var viewToggleItem:NSMenuItem? {
        get { menus.viewToggleItem }
        set { menus.viewToggleItem=newValue }
    }
    var detectionMethodItems:[NSMenuItem] {
        get { menus.detectionMethodItems }
        set { menus.detectionMethodItems=newValue }
    }
    var liveUpdateItem:NSMenuItem? {
        get { menus.liveUpdateItem }
        set { menus.liveUpdateItem=newValue }
    }
    var layoutItems:[OverlayLayout:NSMenuItem] {
        get { menus.layoutItems }
        set { menus.layoutItems=newValue }
    }
    var layoutSeparator:NSMenuItem? {
        get { menus.layoutSeparator }
        set { menus.layoutSeparator=newValue }
    }
    var floatingMenuItem:NSMenuItem! {
        get { menus.floatingMenuItem }
        set { menus.floatingMenuItem=newValue }
    }
    var toggleItem:NSMenuItem! {
        get { menus.toggleItem }
        set { menus.toggleItem=newValue }
    }
    func buildLayoutMenu(_ menu:NSMenu) { menus.buildLayoutMenu(menu) }
    func updateLayoutMenu() { menus.updateLayoutMenu() }
    func updateDetectionMenu() { menus.updateDetectionMenu() }
    func updateToggleTitle() { menus.updateToggleTitle() }
    func validateMenuItem(_ item:NSMenuItem) -> Bool { menus.validateMenuItem(item) }
    @discardableResult func add(_ title:String,_ action:Selector,to menu:NSMenu) -> NSMenuItem { menus.add(title,action,to:menu) }
}
