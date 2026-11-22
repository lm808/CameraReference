import AppKit
import Carbon

// Recording UI gathers bindings; this coordinator applies them transactionally.
extension AppDelegate {
    @objc func changeShortcut() {
        hide();calibration?.finish(nil);recording=true
        let oldOverlay=currentShortcut,oldFloating=floatingShortcut
        let oldViews=ViewShortcut.defaults.map { viewShortcut($0.layout) }
        if let hotKey { UnregisterEventHotKey(hotKey);self.hotKey=nil }
        if let floatingHotKey { UnregisterEventHotKey(floatingHotKey);self.floatingHotKey=nil }
        unregisterViewShortcuts()
        defer { recording=false;updateToggleTitle();updateLayoutMenu() }
        let overlay=ShortcutRecorder(shortcut:oldOverlay,label:keyLabel)
        let floating=ShortcutRecorder(shortcut:oldFloating,label:floatingKeyLabel)
        floating.defaultShortcut=(UInt32(kVK_ANSI_F),UInt32(controlKey|optionKey|cmdKey));floating.defaultLabel="F"
        let views=zip(ViewShortcut.defaults,oldViews).map { entry,value -> ShortcutRecorder in
            let recorder=ShortcutRecorder(shortcut:(value.0,value.1),label:value.2)
            recorder.defaultShortcut=(entry.key,UInt32(controlKey|optionKey|cmdKey));recorder.defaultLabel=entry.label
            return recorder
        }
        let recorders=[overlay,floating]+views
        let names=["Overlay","Floating display"]+ViewShortcut.defaults.map {
            $0.layout == .full ? "Loupe View":"Reference View (\($0.layout.label))"
        }
        let help=NSTextField(wrappingLabelWithString:"Click a binding to record it. Save while waiting for a key clears that binding; untouched bindings stay unchanged. Clear also removes a binding. Escape stops recording. View shortcuts follow the available menu choices.")
        let rows=zip(names,recorders).map { name,recorder -> [NSView] in
            recorder.help=help;recorder.setAccessibilityLabel(name+" shortcut");recorder.font = .systemFont(ofSize:14)
            return [NSTextField(labelWithString:name),recorder,NSButton(title:"Default",target:recorder,action:#selector(ShortcutRecorder.useDefault)),NSButton(title:"Clear",target:recorder,action:#selector(ShortcutRecorder.clearShortcut))]
        }
        let grid=NSGridView(views:rows);grid.columnSpacing=12;grid.rowSpacing=8;grid.yPlacement = .center
        grid.column(at:0).width=175;grid.column(at:1).width=145
        let stack=NSStackView(views:[grid,help]);stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=12
        stack.frame=CGRect(x:0,y:0,width:540,height:330);help.widthAnchor.constraint(equalToConstant:540).isActive=true
        let alert=NSAlert();alert.icon=NSApp.applicationIconImage;alert.messageText="Keyboard shortcuts";alert.accessoryView=stack
        alert.addButton(withTitle:"Save");alert.addButton(withTitle:"Cancel")
        NSApp.activate(ignoringOtherApps:true)
        func clearRegistrations() {
            if let hotKey { UnregisterEventHotKey(hotKey);self.hotKey=nil }
            if let floatingHotKey { UnregisterEventHotKey(floatingHotKey);self.floatingHotKey=nil }
            unregisterViewShortcuts()
        }
        while true {
            guard alert.runModal() == .alertFirstButtonReturn else {
                clearRegistrations()
                let a=register(oldOverlay),b=register(oldFloating,floatingTarget:true),c=registerViewShortcuts(values:oldViews)
                if !a || !b || !c { report("A previous shortcut is unavailable; reopen Keyboard shortcuts.") };return
            }
            recorders.forEach{$0.finishRecording()}
            let assigned=recorders.filter{$0.candidate.1 != 0}.map{"\($0.candidate.0):\($0.candidate.1)"}
            guard Set(assigned).count==assigned.count else { help.stringValue="Each assigned shortcut must be different.";continue }
            clearRegistrations()
            let values=views.map{($0.candidate.0,$0.candidate.1,$0.keyLabel)}
            let a=register(overlay.candidate),b=register(floating.candidate,floatingTarget:true),c=registerViewShortcuts(values:values)
            if a && b && c {
                keyLabel=overlay.keyLabel;floatingKeyLabel=floating.keyLabel
                let prefs=CameraPreferences.shared
                prefs.set(currentShortcut.0,forKey:"key");prefs.set(currentShortcut.1,forKey:"modifiers");prefs.set(keyLabel,forKey:"keyLabel")
                prefs.set(floatingShortcut.0,forKey:"floatingKey");prefs.set(floatingShortcut.1,forKey:"floatingModifiers");prefs.set(floatingKeyLabel,forKey:"floatingKeyLabel")
                for (entry,value) in zip(ViewShortcut.defaults,values) {
                    let prefix="viewShortcut.\(entry.layout.rawValue)."
                    prefs.set(value.0,forKey:prefix+"key");prefs.set(value.1,forKey:prefix+"modifiers");prefs.set(value.2,forKey:prefix+"label")
                }
                report("Shortcuts saved.");return
            }
            clearRegistrations();help.stringValue="A shortcut is unavailable. Choose another combination or Cancel."
        }
    }
}
