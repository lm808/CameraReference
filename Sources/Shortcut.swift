import AppKit
import Carbon

func shortcutText(key: String, modifiers: UInt32) -> String {
    var text=""
    for (flag,symbol) in [(controlKey,"⌃"),(optionKey,"⌥"),(shiftKey,"⇧"),(cmdKey,"⌘")] {
        if modifiers & UInt32(flag) != 0 { text += symbol }
    }
    return text+key
}
final class ShortcutRecorder: NSButton {
    var candidate: (UInt32,UInt32)
    var keyLabel: String
    var defaultShortcut=(UInt32(kVK_ANSI_J),UInt32(controlKey|optionKey|cmdKey))
    var defaultLabel="J"
    var capturing=false
    var help: NSTextField?
    init(shortcut: (UInt32,UInt32), label:String) {
        candidate=shortcut; keyLabel=label
        super.init(frame:CGRect(x:0,y:0,width:240,height:36))
        bezelStyle = .rounded; setButtonType(.momentaryPushIn)
        font = .systemFont(ofSize:18); target=self; action=#selector(beginCapture)
        updateTitle()
        setAccessibilityLabel("Overlay keyboard shortcut")
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var acceptsFirstResponder: Bool { true }
    func updateTitle() { title=capturing ? "Press shortcut…" : shortcutText(key:keyLabel,modifiers:candidate.1) }
    @objc func beginCapture() {
        capturing=true; window?.makeFirstResponder(self); updateTitle()
        help?.stringValue="Press Command or Control plus a key. Escape stops recording."
    }
    @objc func useDefault() {
        candidate=defaultShortcut; keyLabel=defaultLabel; capturing=false; updateTitle()
        help?.stringValue="Choose Save to apply this shortcut."
    }
    override func performKeyEquivalent(with event:NSEvent) -> Bool {
        if capturing { keyDown(with:event); return true }; return super.performKeyEquivalent(with:event)
    }
    override func keyDown(with event:NSEvent) {
        guard capturing else { super.keyDown(with:event); return }
        if event.keyCode == 53 { capturing=false; updateTitle(); help?.stringValue="Recording cancelled. Current choice retained."; return }
        let flags=event.modifierFlags
        guard flags.contains(.command) || flags.contains(.control) else {
            help?.stringValue="Include Command (⌘) or Control (⌃)."; return
        }
        var modifiers:UInt32=0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        let names:[UInt16:String]=[36:"↩",48:"⇥",49:"Space",51:"⌫",117:"⌦",123:"←",124:"→",125:"↓",126:"↑"]
        keyLabel=names[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
        candidate=(UInt32(event.keyCode),modifiers); capturing=false; updateTitle()
        help?.stringValue="Choose Save to apply this shortcut."
    }
}
