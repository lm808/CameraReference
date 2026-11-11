# Troubleshooting and uninstalling

- **Bridge timeout:** confirm the enabled plugin points to its permanent installed location. Restart the bridge from Lightroom’s Plug-in Extras and check the heartbeat in Developer tools → Bridge diagnostics.
- **No camera JPEG:** check source preference and standalone filename pairing. Embedded extraction supports CR3 and needs ExifTool; choose its executable in Settings if necessary.
- **Wrong area:** use Lightroom Fit and matching Full/split selection. Clear region while keeping auto enabled. The current verified setup uses `sideSearchPercent = 30`; wider ranges may select unintended edges. If Full is wrong, split will inherit its wrong outer bounds. Use manual calibration when uncertain.
- **Capture unavailable:** grant the requested Screen Recording permission. New automatic capture needs the Lightroom window wholly on one display. Existing placement/manual calibration may still follow partial off-screen movement.
- **Unexpected disappearance:** copy Bridge diagnostics before another invocation. It includes background rejection reasons. Resize, changed panels, selection or heartbeat uncertainty must retain the visible reference; only explicit dismissal or confirmed host closure releases it. Background checks should pause during overview transitions.
- **Overview restoration:** return to the same Lightroom window in Develop without resizing it. This alpha uses native transient behaviour plus a public window-list heuristic for Dock overview surfaces; native macOS versions/setups still require testing. A false suspension is a bug to report.
- **Config edits:** edit `config.conf`, not the retained `detection.conf` backup. Unknown/duplicate settings are errors. Interval 0 disables periodic image checks, not the lightweight window geometry tracker.
- **Privacy icon stale:** quit the app/System Settings, reopen the installed app and then System Settings. Do not reset permissions as a routine troubleshooting step.

Report app/bridge versions, macOS/Lightroom versions, mode/pane, whether Full works, and Bridge diagnostics. If comfortable, include an overlay-free screenshot without changing window/panels after failure. See PRIVACY.md before sharing.

## Uninstall

1. Quit Camera Reference.
2. Disable/remove its bridge entry in Lightroom Plugin Manager and restart Lightroom if needed.
3. Move CameraReference.app from Applications to the Trash.
4. Optionally remove the installed plugin, backups and advanced configuration under `~/Library/Application Support/CameraReference/`, and bridge runtime files under `~/Library/Application Support/CameraReference/Bridge/`.
5. To reset GUI preferences/calibration, while the app is quit run `defaults delete org.local.CameraReference`. This is optional and removes your saved preferences.
6. Remove permissions for Camera Reference in macOS Privacy settings if desired.

None of these steps should delete photographs or exported JPEGs. Keep config/preferences if you intend to reinstall.

## Folder consolidation upgrade

Missing heartbeat after upgrade usually means Lightroom still runs an older bridge. Disable old copies and install/reload 0.5.2. App and bridge now use CameraReference/Bridge. A live old heartbeat defers consolidation; stop the old bridge. The app merges the spaced folder once inactive, preserves conflicting files with a .migrated suffix, and removes the empty old folder. If moving a loaded plugin, re-add its canonical path in Plug-in Manager.
