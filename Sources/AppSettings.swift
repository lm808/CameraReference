import Foundation

/// Access to the existing shared preference domain. No duplicate store/cache.
/// Context-dependent calibration keys still belong to their current coordinator.
final class AppSettings {
    let preferences:UserDefaults
    init(preferences:UserDefaults = CameraPreferences.shared) { self.preferences=preferences }
    var screenshotDetectionEnabled:Bool {
        (preferences.object(forKey:"useScreenshotDetection") as? Bool) ?? (legacyPlacementMode != .accessibility)
    }
    var legacyPlacementMode:AutomaticPlacementMode {
        AutomaticPlacementMode.resolve(saved:preferences.string(forKey:"automaticPlacementMode"),
            legacy:preferences.object(forKey:"experimentalAXPlacement") as? Bool)
    }
    var automaticPlacementMode:AutomaticPlacementMode {
        screenshotDetectionEnabled ? .screenshot:.accessibility
    }
    var axPlacementEnabled:Bool { !screenshotDetectionEnabled }
    var automaticViewEnabled:Bool { automaticPlacementMode.usesAXViewDetection(screenshotOption:preferences.bool(forKey:"experimentalAutomaticView")) }
    var axLiveUpdate:Bool { (preferences.object(forKey:"axLiveUpdate") as? Bool) ?? true }
    var reuseScreenshotWorkingArea:Bool { (preferences.object(forKey:"developerReuseScreenshotWorkingArea") as? Bool) ?? true }
    var expandedScreenshotReuse:Bool { screenshotDetectionEnabled && reuseScreenshotWorkingArea }
    var axTrialEnabled:Bool { preferences.bool(forKey:"developerAXTrial") }
    var autoDiagnostics:Bool {
        (preferences.object(forKey:"developerAutoSaveDiagnostics") as? Bool) ?? preferences.bool(forKey:"developerAutoCopyDiagnostics")
    }
    func registerAndMigrate() {
        preferences.register(defaults:Dictionary(uniqueKeysWithValues:OverlayLayout.allCases.map {
            ("library."+regionPreferenceKey("automaticBounds",layout:$0),true)
        }))
        // Carry only calibration and shortcut settings forward; no photo paths or images.
        if !preferences.bool(forKey: "migrated03") {
            if let old = preferences.persistentDomain(forName: "org.local.JPEGReference") {
                for key in ["region", "key", "modifiers"] {
                    if let value = old[key] { preferences.set(value, forKey: key) }
                }
            }
            preferences.set(true, forKey: "migrated03")
        }
    }
}
