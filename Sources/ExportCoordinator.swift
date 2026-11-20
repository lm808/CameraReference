import AppKit
import ApplicationServices

// App-facing actions grouped by responsibility. Existing guard, callback and
// effect order is preserved; shared operation identities belong to composition.
extension AppDelegate {
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
}
