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
    var assistedToggleItem:NSMenuItem?
    var viewToggleItem:NSMenuItem?
    var detectionMethodItems=[NSMenuItem]()
    var liveUpdateItem:NSMenuItem?
    var layoutItems=[OverlayLayout:NSMenuItem]()
    var layoutGroups=[Int:NSMenuItem]()
    var layoutSeparator:NSMenuItem?
    var floatingMenuItem:NSMenuItem!
    var toggleItem: NSMenuItem!
    var versionTitle:String { owner.versionTitle }
    var axPlacementEnabled:Bool { owner.axPlacementEnabled }
    var screenshotDetectionEnabled:Bool { owner.screenshotDetectionEnabled }
    var axLiveUpdate:Bool { owner.axLiveUpdate }
    var assistedPlacementEnabled:Bool { owner.assistedPlacementEnabled }
    var automaticViewEnabled:Bool { owner.automaticViewEnabled }
    var autoDiagnostics:Bool { owner.autoDiagnostics }
    var axTrialEnabled:Bool { owner.axTrialEnabled }
    var detectedLayoutModule:String? { owner.detectedLayoutModule }
    var detectedLayout:OverlayLayout? { owner.detectedLayout }
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
        menu.addItem(NSMenuItem(title: versionTitle, action: nil, keyEquivalent: ""))
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
        assistedToggleItem=add("AX-assisted placement",#selector(AppDelegate.toggleScreenshotAssistance),to:settings)
        assistedToggleItem?.indentationLevel=1;viewToggleItem?.indentationLevel=1
        liveUpdateItem=add("Update overlay with LrC view",#selector(AppDelegate.toggleAXLiveUpdate(_:)),to:settings)
        liveUpdateItem?.indentationLevel=1
        updateDetectionMenu()
        settings.addItem(.separator())
        add("Advanced settings…", #selector(AppDelegate.editAdvancedSettings), to: settings)
        let developer = submenu("Developer tools")
        developer.addItem(detail); developer.addItem(.separator())
        add("Diagnostics…", #selector(AppDelegate.showDiagnostics), to: developer)
        let copy=add("Save diagnostics after invocation", #selector(AppDelegate.toggleAutoDiagnostics), to: developer)
        copy.state = autoDiagnostics ? .on:.off
        developer.addItem(.separator())
        let experimental=NSMenu();let experimentalItem=NSMenuItem(title:"Experimental features",action:nil,keyEquivalent:"")
        experimentalItem.submenu=experimental;developer.addItem(experimentalItem)
        let trial=add("Show AX placement preview",#selector(AppDelegate.toggleAXTrial),to:experimental)
        trial.state=axTrialEnabled ? .on:.off
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
    func buildLayoutMenu(_ menu:NSMenu) {
        layoutSeparator=NSMenuItem.separator();menu.addItem(layoutSeparator!)
        let full=add("▣  Loupe View",#selector(AppDelegate.selectLayout(_:)),to:menu)
        full.representedObject=OverlayLayout.full.rawValue;full.image=layoutMenuIcon(.full);layoutItems[.full]=full
        for (title,modes) in [("◧  Reference View (Left/Right)",[OverlayLayout.left,.right]),("⬒  Reference View (Top/Bottom)",[OverlayLayout.upper,.lower])] {
            let parent=NSMenuItem(title:title,action:nil,keyEquivalent:"")
            parent.image=layoutMenuIcon(modes[0]);let child=NSMenu(title:title);parent.submenu=child;menu.addItem(parent)
            layoutGroups[modes[0].group]=parent
            for mode in modes {
                let item=add((mode == .left ? "◧":mode == .right ? "◨":mode == .upper ? "⬒":"⬓")+"  "+mode.label,#selector(AppDelegate.selectLayout(_:)),to:child)
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
        layoutItems[.full]?.action = automaticViewEnabled ? nil:#selector(AppDelegate.selectLayout(_:))
        if automaticViewEnabled && !hidden {
            layoutItems[.full]?.title = inferred == nil ? "View detected on next invocation":"▣  Loupe View"
            layoutItems[.full]?.isEnabled=false
            layoutItems[.full]?.isHidden = inferred != nil && overlayLayout.group != 0
            for (group,item) in layoutGroups { item.isHidden = inferred == nil || group != overlayLayout.group }
        } else { layoutItems[.full]?.title="▣  Loupe View";layoutItems[.full]?.isEnabled=true }
        for (mode,item) in layoutItems { item.state=mode==overlayLayout ? .on:.off }
        for (group,item) in layoutGroups { item.state=group==overlayLayout.group ? .on:.off }
    }
    func updateDetectionMenu() {
        let automatic=CameraPreferences.shared.bool(forKey:regionKey("automaticBounds"))
        screenshotToggleItem?.title="Detection method: " + (screenshotDetectionEnabled ? "Screenshot":"Accessibility")
        screenshotToggleItem?.isEnabled=automatic
        for item in detectionMethodItems {
            item.state=(item.representedObject as? Bool)==screenshotDetectionEnabled ? .on:.off
            item.isEnabled=automatic
        }
        liveUpdateItem?.isHidden=screenshotDetectionEnabled
        liveUpdateItem?.isEnabled=automatic && axPlacementEnabled
        liveUpdateItem?.state=axLiveUpdate ? .on:.off
        assistedToggleItem?.isHidden=axPlacementEnabled
        viewToggleItem?.isHidden=axPlacementEnabled
        assistedToggleItem?.state=assistedPlacementEnabled ? .on:.off
        viewToggleItem?.state=automaticViewEnabled ? .on:.off
        assistedToggleItem?.isEnabled=automatic && screenshotDetectionEnabled
        viewToggleItem?.isEnabled=automatic && screenshotDetectionEnabled
    }
    func updateToggleTitle() {
        floatingMenuItem?.title=(floating?.isVisible == true ? "Hide floating display" : "Show floating display") + "   " + shortcutText(key:floatingKeyLabel,modifiers:floatingShortcut.1)
        let active=panel != nil || destination == .overlay || viewProbeID != nil || detectionCompletion != nil
        toggleItem?.title=(active ? "Hide overlay" : "Show overlay") + "   " + shortcutText(key:keyLabel,modifiers:currentShortcut.1)
    }
    func validateMenuItem(_ item:NSMenuItem) -> Bool {
        if item === liveUpdateItem { return axPlacementEnabled && CameraPreferences.shared.bool(forKey:regionKey("automaticBounds")) }
        if item === assistedToggleItem || item === viewToggleItem {
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
    var legacyPlacementMode:AutomaticPlacementMode { settings.legacyPlacementMode }
    var screenshotAssistanceEnabled:Bool { settings.screenshotAssistanceEnabled }
    var automaticPlacementMode:AutomaticPlacementMode { settings.automaticPlacementMode }
    var axPlacementEnabled:Bool { settings.axPlacementEnabled }
    var assistedPlacementEnabled:Bool { settings.assistedPlacementEnabled }
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
    var assistedToggleItem:NSMenuItem? {
        get { menus.assistedToggleItem }
        set { menus.assistedToggleItem=newValue }
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
    var layoutGroups:[Int:NSMenuItem] {
        get { menus.layoutGroups }
        set { menus.layoutGroups=newValue }
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
