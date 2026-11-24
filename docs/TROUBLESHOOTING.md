# Troubleshooting and uninstalling

- **Bridge timeout:** confirm the enabled plugin points to its permanent installed location and bridge 0.5.3 is running. Restart through Lightroom’s Plug-in Extras; check the heartbeat in Developer tools → Diagnostics….
- **No camera JPEG:** check source preference and paired filenames. CR3/ARW extraction needs ExifTool; choose its executable in Settings. Sony embedded previews may be smaller than the RAW.
- **Wrong area:** first check automatic versus manual placement and Detection method. Use Lightroom Fit. Clear overlay region setting preserves the mode; in automatic mode it forces fresh placement. Screenshot without AX view inference uses your menu layout. Manual calibration is a fallback. Current fresh side-search default is 40; do not overwrite a working personal setting blindly.
- **Capture unavailable:** Screen Recording is optional for Accessibility placement. Explicit automatic Screenshot placement may request it; background checks and calibration snapping never prompt. Manual calibration still works without snapping, and Accessibility automatic placement does not need it. Screenshot features require macOS 14.
- **Off-screen failure:** if detection keeps failing with Lightroom partly off-screen, try restarting Lightroom Classic. Intermittent capture padding/scale errors remain unresolved. Capture / bridge actions → Preview captured Lightroom window… shows raw pixels even when placement rejects them; a plausible preview alone does not validate geometry.
- **Unexpected dismissal or unchanged image:** in automatic Accessibility mode, Update overlay with LrC view determines update versus dismissal on photo/view/pane/panel changes. Screenshot dismisses on confirmed photo-selection changes. With AX view detection enabled, confirmed view/pane/panel changes also dismiss; without it, panel pixel checks invalidate cached placement only. Explicit screenshot view/pane selection dismisses. Manual placement retains its existing behaviour. Confirmed module changes dismiss. Positive Library Grid evidence also dismisses in AX mode, but native mark reliability remains under test. Uncertainty alone should retain the current overlay.
- **Overview restoration:** return to the same Lightroom host. Suspension retains content for restoration; brief minimise linger is accepted. Report false suspension, failed restoration or detached overlays with diagnostics.
- **Config edits:** use Advanced settings or its Open config file button. config.conf is authoritative; unknown/duplicate settings are errors. Interval 0 disables periodic screenshot checks, not host tracking or AX view polling.
- **Permissions identity:** stable and purple testing apps have different identities but share settings/bridge. Run only one. Ad-hoc-signed updates can require renewed approval; do not reset system permissions routinely.

Enable **Developer tools → Save diagnostics after invocation** to write `~/Library/Application Support/CameraReference/Diagnostics/latest.txt`, or use **Diagnostics… → Copy all**. Include mode/pane, app/bridge and macOS/Lightroom versions, and what changed. If sharing a screenshot, keep the window/panels unchanged after failure and review private content first. See [privacy](../PRIVACY.md).

## Uninstall

1. Quit Camera Reference.
2. Disable/remove its bridge entry in Lightroom Plugin Manager and restart Lightroom if needed.
3. Move CameraReference.app from Applications to the Trash.
4. Optionally remove the installed plugin, backups and advanced configuration under `~/Library/Application Support/CameraReference/`, and bridge runtime files under `~/Library/Application Support/CameraReference/Bridge/`.
5. To reset GUI preferences/calibration, while the app is quit run `defaults delete org.local.CameraReference`. This is optional and removes your saved preferences.
6. Remove permissions for Camera Reference in macOS Privacy settings if desired.

None of these steps should delete photographs or exported JPEGs. Keep config/preferences if you intend to reinstall.

## Folder consolidation upgrade

Missing heartbeat after upgrade usually means Lightroom still runs an older bridge. Disable old copies and install/reload 0.5.3. App and bridge now use CameraReference/Bridge. A live old heartbeat defers consolidation; stop the old bridge. The app merges the spaced folder once inactive, preserves conflicting files with a .migrated suffix, and removes the empty old folder. If moving a loaded plugin, re-add its canonical path in Plug-in Manager.
