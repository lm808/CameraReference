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
| `top`, `bottom` | `photo` | Same per-side choice |
| `fitInsetPoints` | 18 | 0–100 macOS points; minimum Fit margin and split scan band |
| `sideSearchPercent` | 45 | 5–50%; side-border search from each window edge |
| `panelCheckIntervalSeconds` | 3 | 0–3600; 0 disables background capture checks |
| `verticalSnapFraction`, `horizontalSnapFraction` | 0.25 | 0.05–1; minimum sustained edge fraction |
| `snapDistancePoints` | 8 | 1–30; Option-snapping attraction radius |
| `snapGapPoints` | 4 | 0–12; tolerated gaps in snapping edges |
| `snapContrast` | 4 | Integer 1–64; minimum RGB edge contrast |

`sideSearchPercent = 30` resolved the author’s current Full/split failures. Wider values previously helped narrow windows. This remains an advanced tuning setting, not a universal recommendation.

An inset too small for reliable split scanning offers manual calibration. `overlayAnimation = true` or `false` from an old config is accepted but ignored; overlay animation is always off. Unknown keys, duplicates and invalid values are rejected.

On migration, `detection.conf` is copied to `config.conf` only if the latter is absent. Your values—including 30 or an interval of 0—are retained. The old file remains a backup and is no longer read once the new file exists. New setting defaults are appended where needed without discarding existing comments/values. The repository’s example contains defaults only, never your personal settings.

## Runtime files and RAM

The bridge uses `~/Library/Application Support/CameraReference/` (without a space) for request/response, heartbeat and opaque selection-revision files. The separate path is retained for bridge compatibility; these files are protocol state, not another configuration file.

JPEG bytes, decoded images, captured pixels and automatic placement caches are held in RAM. No disk image cache is created. An independent floating display owns its displayed image until closed/reloaded.
