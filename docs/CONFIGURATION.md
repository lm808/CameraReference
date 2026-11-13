# Configuration and state

## GUI settings

The app uses macOS `UserDefaults` under `org.local.CameraReference`, normally stored in `~/Library/Preferences/org.local.CameraReference.plist`. Change these through the GUI, not by editing the plist while the app runs:

- Overlay/floating shortcuts, key labels and modifiers.
- JPEG source preference and custom ExifTool path.
- Selected layout/pane and auto/manual preference for each layout/pane.
- Internal saved calibration geometry, display/window association and migration metadata.

Each setting has one authoritative storage location. Calibration remains internal app state; it is not duplicated in the advanced file.

## Advanced configuration

`~/Library/Application Support/CameraReference/config.conf`

Settings → Edit config file opens this plain-text file. Parsed settings stay in memory; metadata checks detect edits. Valid changes apply on the next invocation/check as appropriate, without changing an already drawn photo midway. Invalid edits retain the last valid settings and are reported on explicit use. Background checks do not show configuration alerts.

| Setting | Default | Allowed values / purpose |
|---|---|---|
| `left`, `right` | `ui` | `ui` or `photo`: include UI backdrop or end at calculated photo edge |
| `top`, `bottom` | `ui` | Same per-side choice |
| `fitInsetPoints` | 18 | 0–100 macOS points; minimum Fit margin and split scan band |
| `sideSearchPercent` | 40 | 5–50%; side-border search from each window edge |
| `panelCheckIntervalSeconds` | 3 | 0–3600; 0 disables background capture checks |
| `verticalSnapFraction`, `horizontalSnapFraction` | 0.25 | 0.05–1; minimum sustained edge fraction |
| `snapDistancePoints` | 8 | 1–30; Option-snapping attraction radius |
| `snapGapPoints` | 4 | 0–12; tolerated gaps in snapping edges |
| `snapContrast` | 4 | Integer 1–64; minimum RGB edge contrast |

New installations and older configs missing this key use `sideSearchPercent = 40`, the author’s current preferred setting. Explicit existing values—including 30—remain unchanged. All four bounds still default to ui.

An inset too small for reliable split scanning offers manual calibration. `overlayAnimation = true` or `false` from an old config is accepted but ignored; overlay animation is always off. Unknown keys, duplicates and invalid values are rejected.

On migration, `detection.conf` is copied to `config.conf` only if the latter is absent. Your values—including 30 or an interval of 0—are retained. The old file remains a backup and is no longer read once the new file exists. New setting defaults are appended where needed without discarding existing comments/values. The repository’s example contains defaults only, never your personal settings.

## Runtime files and RAM

All app-owned Application Support files now live under `~/Library/Application Support/CameraReference/`:

- `config.conf`: advanced settings.
- `Plugins/`: installed Lightroom bridge.
- `Bridge/`: transient request/response, heartbeat and selection-revision files.
Bridge 0.5.2 and this app share CameraReference/Bridge. Stop/disable old bridge copies before moving their installed folder and reload the new plugin. Existing settings are copied first if the canonical files are absent, so defaults cannot replace them while waiting for old writers. A legacy heartbeat newer than ten seconds defers the remainder; the app retries every five seconds and reports progress in diagnostics.

Once inactive, contents of the spaced Camera Reference folder are merged into CameraReference. Known stale IPC is discarded rather than replayed. Unknown files are preserved, identical files deduplicated, and the empty spaced folder removed. If differing files have the same destination, the canonical file wins and the old file is preserved beside it with a `.migrated-…` suffix for review. No legacy folder backup is created. Previously created backups are user data and are not silently deleted. Do not run older apps again: they may recreate the old folder.

GUI settings intentionally remain in the conventional macOS Preferences domain described above; they are not duplicated here.

JPEG bytes, decoded images, captured pixels and automatic placement caches are held in RAM. No disk image cache is created. An independent floating display owns its displayed image until closed/reloaded.

Experimental AX preview reads toolbar visibility automatically. The legacy `axToolbarState` entry remains accepted for compatibility but is ignored by the app preview; no personal file is rewritten. A failed/ambiguous reading assumes shown and uses `axToolbarShownBottomOffsetPoints`. Confirmed hidden uses `axToolbarHiddenBottomOffsetPoints`. Both offsets still default to zero and affect only preview geometry, never screenshot placement.
