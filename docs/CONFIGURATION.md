# Configuration and state

## GUI settings

The app uses macOS `UserDefaults` under `org.local.CameraReference`, normally stored in `~/Library/Preferences/org.local.CameraReference.plist`. Change these through the GUI, not by editing the plist while the app runs:

- Overlay/floating shortcuts, key labels and modifiers.
- JPEG source preference and custom ExifTool path.
- Selected layout/pane and auto/manual preference for each layout/pane.
- Internal saved calibration geometry, display/window association and migration metadata.

Each setting has one authoritative storage location. Calibration remains internal app state; it is not duplicated in the advanced file.

## Advanced configuration

`~/Library/Application Support/Camera Reference/config.conf`

Settings → Edit config file opens this plain-text file. Parsed settings stay in memory; metadata checks detect edits. Valid changes apply on the next invocation/check as appropriate, without changing an already drawn photo midway. Invalid edits retain the last valid settings and are reported on explicit use. Background checks do not show configuration alerts.

| Setting | Default | Allowed values / purpose |
|---|---|---|
| `left`, `right` | `ui` | `ui` or `photo`: include UI backdrop or end at calculated photo edge |
| `top`, `bottom` | `ui` | Same per-side choice |
| `fitInsetPoints` | 18 | 0–100 macOS points; minimum Fit margin and split scan band |
| `sideSearchPercent` | 30 | 5–50%; side-border search from each window edge |
| `panelCheckIntervalSeconds` | 3 | 0–3600; 0 disables background capture checks |
| `verticalSnapFraction`, `horizontalSnapFraction` | 0.25 | 0.05–1; minimum sustained edge fraction |
| `snapDistancePoints` | 8 | 1–30; Option-snapping attraction radius |
| `snapGapPoints` | 4 | 0–12; tolerated gaps in snapping edges |
| `snapContrast` | 4 | Integer 1–64; minimum RGB edge contrast |

`sideSearchPercent = 30` resolved the author’s current Full/split failures. Wider values previously helped narrow windows. This remains an advanced tuning setting, not a universal recommendation.

An inset too small for reliable split scanning offers manual calibration. `overlayAnimation = true` or `false` from an old config is accepted but ignored; overlay animation is always off. Unknown keys, duplicates and invalid values are rejected.

On migration, `detection.conf` is copied to `config.conf` only if the latter is absent. Your values—including 30 or an interval of 0—are retained. The old file remains a backup and is no longer read once the new file exists. New setting defaults are appended where needed without discarding existing comments/values. The repository’s example contains defaults only, never your personal settings.

## Runtime files and RAM

All app-owned Application Support files now live under `~/Library/Application Support/Camera Reference/`:

- `config.conf`: advanced settings.
- `Plugins/`: installed Lightroom bridge.
- `Bridge/`: transient request/response, heartbeat and selection-revision files.
- `Backups/Legacy Bridge-…`: preserved contents of the former `CameraReference` folder.

Bridge 0.5.1 and this companion app must be upgraded together. Stop/disable old bridge copies and reload the new plugin. The companion checks for the old folder every five seconds until migration completes. If its heartbeat is less than ten seconds old, migration waits rather than moving files out from under an active old bridge. Diagnostics explain this condition. Once inactive, the entire old folder is moved into a uniquely named backup; unknown files are preserved and stale IPC is never copied into the live Bridge folder. Existing config and plugin files are untouched. If an old app/plugin is run again it may recreate the old directory; quit it and restart the new app to archive that directory too.

GUI settings intentionally remain in the conventional macOS Preferences domain described above; they are not duplicated here.

JPEG bytes, decoded images, captured pixels and automatic placement caches are held in RAM. No disk image cache is created. An independent floating display owns its displayed image until closed/reloaded.
