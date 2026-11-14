import AppKit
import ApplicationServices

// Permission prompts are tied to explicit feature use, never a startup loop.
enum FeaturePermission:Hashable {
    private static var requested=Set<FeaturePermission>()
    case accessibility, screenCapture
    var granted: Bool { self == .accessibility ? AXIsProcessTrusted() : CGPreflightScreenCaptureAccess() }
    var name: String { self == .accessibility ? "Accessibility" : "Screen Recording" }
    @discardableResult func ensure() -> Bool {
        if granted { return true }
        // Screen Recording is optional and must never prompt, even on explicit
        // capture actions. Callers explain unavailability or use free calibration.
        if self == .screenCapture { return false }
        // Request once per launch. A stale TCC grant cannot be repaired by
        // repeatedly triggering the native request. Never report it as granted.
        if Self.requested.insert(self).inserted {
            if self == .accessibility {
                _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary)
            }
            if granted { return true }
        }
        let appName=Bundle.main.object(forInfoDictionaryKey:"CFBundleDisplayName") as? String ?? "Camera Reference"
        let alert=NSAlert();alert.icon=NSApp.applicationIconImage; alert.messageText="Allow \(name) for \(appName)"
        alert.informativeText=self == .accessibility
            ? "Read-only Lightroom window monitoring and layout inspection need Accessibility access. Enable \(appName) in Privacy & Security → Accessibility, then try again. Manual calibration does not need this permission."
            : "Screen-based detection needs Screen Recording access to inspect Lightroom’s window in memory. No screenshot is saved. Enable \(appName) in Privacy & Security → Screen Recording (or Screen & System Audio Recording), then try again. macOS may ask you to quit and reopen the app."
        alert.informativeText += "\n\nThis copy: \(Bundle.main.bundleURL.path)\n\nIf this exact app is already enabled, quit and reopen it before retrying. A checked entry for another copy/build does not establish permission for this one. Leave the stable app’s entry unchanged."
        alert.addButton(withTitle:"Open System Settings"); alert.addButton(withTitle:"Not Now")
        NSApp.activate(ignoringOtherApps:true)
        if alert.runModal() == .alertFirstButtonReturn {
            let pane=self == .accessibility ? "Privacy_Accessibility" : "Privacy_ScreenCapture"
            if let url=URL(string:"x-apple.systempreferences:com.apple.preference.security?"+pane) { NSWorkspace.shared.open(url) }
        }
        return false
    }
}
