import AppKit
import ApplicationServices

// App-facing actions grouped by responsibility. Existing guard, callback and
// effect order is preserved; shared operation identities belong to composition.
extension AppDelegate {
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
    func placementOptionsChanged() {
        cancelScreenInspection();cancelPanelCheck();cancelRequest()
        assistedSignature=nil;lightroomMonitor.liveViewGeneration += 1;lightroomMonitor.nextLiveViewCheck=0
        lightroomMonitor.detectedLayout=nil;lightroomMonitor.detectedLayoutModule=nil
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
}
