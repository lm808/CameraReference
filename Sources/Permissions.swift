import AppKit
import ApplicationServices

// Permission prompts are tied to explicit feature use, never a startup loop.
enum FeaturePermission {
    case accessibility, screenCapture
    var granted: Bool { self == .accessibility ? AXIsProcessTrusted() : CGPreflightScreenCaptureAccess() }
    var name: String { self == .accessibility ? "Accessibility" : "Screen Recording" }
    @discardableResult func ensure() -> Bool {
        if granted { return true }
        let key="requestedPermission."+name
        if !UserDefaults.standard.bool(forKey:key) {
            UserDefaults.standard.set(true,forKey:key)
            if self == .accessibility {
                _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary)
            } else { _ = CGRequestScreenCaptureAccess() }
            if granted { return true }
        }
        let alert=NSAlert(); alert.messageText="Allow \(name) for Camera Reference"
        alert.informativeText=self == .accessibility
            ? "Read-only layout inspection needs Accessibility access. Enable Camera Reference in Privacy & Security → Accessibility, then try again. Manual calibration does not need this permission."
            : "Screen-based detection needs Screen Recording access to inspect Lightroom’s window in memory. No screenshot is saved. Enable Camera Reference in Privacy & Security → Screen Recording (or Screen & System Audio Recording), then try again. macOS may ask you to quit and reopen the app."
        alert.addButton(withTitle:"Open System Settings"); alert.addButton(withTitle:"Not Now")
        NSApp.activate(ignoringOtherApps:true)
        if alert.runModal() == .alertFirstButtonReturn {
            let pane=self == .accessibility ? "Privacy_Accessibility" : "Privacy_ScreenCapture"
            if let url=URL(string:"x-apple.systempreferences:com.apple.preference.security?"+pane) { NSWorkspace.shared.open(url) }
        }
        return false
    }
}
