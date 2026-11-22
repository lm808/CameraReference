import AppKit
import Carbon

// Values and availability are independent of Carbon registration and menu rendering.
struct ViewShortcut {
    let layout:OverlayLayout
    let key:UInt32
    let label:String
    static let defaults:[ViewShortcut] = [
        .init(layout:.upper,key:UInt32(kVK_ANSI_8),label:"8"),
        .init(layout:.left,key:UInt32(kVK_ANSI_4),label:"4"),
        .init(layout:.right,key:UInt32(kVK_ANSI_6),label:"6"),
        .init(layout:.lower,key:UInt32(kVK_ANSI_2),label:"2"),
        .init(layout:.full,key:UInt32(kVK_ANSI_5),label:"5")]
    static func available(_ choice:OverlayLayout,automatic:Bool,inferred:OverlayLayout?,enabled:Bool)->Bool {
        enabled && (!automatic || (inferred != nil && choice.group != 0 && choice.group==inferred!.group))
    }
}

extension AppDelegate {
    func viewShortcut(_ choice:OverlayLayout)->(UInt32,UInt32,String) {
        let fallback=ViewShortcut.defaults.first{$0.layout==choice}!
        let prefix="viewShortcut.\(choice.rawValue).",prefs=CameraPreferences.shared
        guard prefs.object(forKey:prefix+"key") != nil else { return (fallback.key,UInt32(controlKey|optionKey|cmdKey),fallback.label) }
        return (UInt32(prefs.integer(forKey:prefix+"key")),UInt32(prefs.integer(forKey:prefix+"modifiers")),prefs.string(forKey:prefix+"label") ?? fallback.label)
    }
    func viewShortcutSuffix(_ choice:OverlayLayout)->String {
        let value=viewShortcut(choice)
        return value.1==0 ? "":"   "+shortcutText(key:value.2,modifiers:value.1)
    }
    func unregisterViewShortcuts() {
        for ref in viewHotKeys { UnregisterEventHotKey(ref) };viewHotKeys=[]
    }
    @discardableResult func registerViewShortcuts(values:[(UInt32,UInt32,String)]? = nil)->Bool {
        unregisterViewShortcuts()
        var success=true
        for (index,item) in ViewShortcut.defaults.enumerated() {
            let value=values?[index] ?? viewShortcut(item.layout)
            if value.1==0 { continue }
            var ref:EventHotKeyRef?
            if RegisterEventHotKey(value.0,value.1,EventHotKeyID(signature:0x43524546,id:UInt32(index+10)),GetApplicationEventTarget(),OptionBits(kEventHotKeyExclusive),&ref)==noErr,let ref { viewHotKeys.append(ref) }
            else { success=false }
        }
        return success
    }
    func handleViewShortcut(_ id:UInt32) {
        guard id>=10,Int(id-10)<ViewShortcut.defaults.count,!recording,calibration==nil,isLightroom() else { return }
        let mode=ViewShortcut.defaults[Int(id-10)].layout
        let inferred=lightroomMonitor.detectedLayoutModule==currentModule() ? lightroomMonitor.detectedLayout:nil
        guard ViewShortcut.available(mode,automatic:automaticViewEnabled,inferred:inferred,enabled:CameraPreferences.shared.bool(forKey:regionKey("automaticBounds"))) else { return }
        let item=NSMenuItem();item.representedObject=mode.rawValue
        selectLayout(item)
    }
}
