# Configuration and state

## GUI settings

The app uses macOS `UserDefaults` under `org.local.CameraReference`, normally stored in `~/Library/Preferences/org.local.CameraReference.plist`. Change these through the GUI, not by editing the plist while the app runs:

- Overlay/floating shortcuts, key labels and modifiers.
- JPEG source preference and custom ExifTool path.
- Selected layout/pane and auto/manual preference for each layout/pane.
- Detection method, independent screenshot AX options, and Update overlay with LrC view (Accessibility only, default on).
- Diagnostic saving and AX preview preferences.
- Internal saved calibration geometry, display/window association and migration metadata.

Stable and testing identities share this preference domain and the support folder. Run only one at a time.

Each setting has one authoritative storage location. Calibration remains internal app state; it is not duplicated in the advanced file.

## Advanced configuration

`~/Library/Application Support/CameraReference/config.conf`

Settings → Advanced settings… → Open config file opens this plain-text file. Parsed settings stay in memory; metadata checks detect edits. Valid changes apply on the next invocation/check as appropriate; automatic Accessibility updates may apply changed geometry when recalculation is required. Invalid edits retain the last valid settings and are reported on explicit use. Background checks do not show configuration alerts.

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
- `Diagnostics/latest.txt`: optional automatically saved diagnostic report (text only).

Bridge 0.5.3 and this app share CameraReference/Bridge. Stop/disable old bridge copies before moving their installed folder and reload the new plugin. Existing settings are copied first if the canonical files are absent, so defaults cannot replace them while waiting for old writers. A legacy heartbeat newer than ten seconds defers the remainder; the app retries every five seconds and reports progress in diagnostics.

Once inactive, contents of the spaced Camera Reference folder are merged into CameraReference. Known stale IPC is discarded rather than replayed. Unknown files are preserved, identical files deduplicated, and the empty spaced folder removed. If differing files have the same destination, the canonical file wins and the old file is preserved beside it with a `.migrated-…` suffix for review. No legacy folder backup is created. Previously created backups are user data and are not silently deleted. Do not run older apps again: they may recreate the old folder.

GUI settings intentionally remain in the conventional macOS Preferences domain described above; they are not duplicated here.

JPEG bytes, decoded images, captured pixels and automatic placement caches are held in RAM. No disk image cache is created. An independent floating display owns its displayed image until closed/reloaded.


## Geometry corrections

Use ordinary name = value entries in config.conf. Missing geometry keys are appended with defaults; explicit values are preserved. Obsolete v1 settings and prefixed directives have been removed. Screenshot settings and their cache key are unaffected.

All signed offsets start at raw AX boundaries: **right/up positive; left/down negative**. The code subtracts vertical offsets from top-left Y coordinates. Base hidden insets are distances inward from the window, applied before signed corrections.

| Setting | Default (pt) |
|---|---:|
| axShownLeftOffsetPoints / axHiddenLeftOffsetPoints | -17 / -1 |
| axShownRightOffsetPoints / axHiddenRightOffsetPoints | +17 / +1 |
| axShownTopOffsetPoints / axHiddenTopOffsetPoints | +11 / +1 |
| axFilmstripShownOffsetPoints / axFilmstripHiddenOffsetPoints | -11 / +17 |
| axToolbarHeightPoints | 43 |
| axLibraryBottomOffsetPoints | 25 |
| axBaseHiddenLeftInsetPoints / axBaseHiddenRightInsetPoints | 18 / 18 |
| axBaseHiddenTopInsetPoints / axBaseHiddenBottomInsetPoints | 50 / 0 |

Bottom correction is cumulative: filmstrip correction + toolbar height when effectively shown (including a shown fallback) + Library correction in Library split views only (zero in single view). The user-calibrated Library split-view allowance defaults to +25 pt; positive moves the bottom upwards. Unknown toolbar visibility uses toolbarUnknownFallback: shown (default), hidden, or lastKnown. Last-known state is held in RAM per Lightroom process and module; if none exists, assume shown. Diagnostics distinguish fresh readings from fallback. Filmstrip shown/toolbar hidden's -11 pt remains inferred. Correct the combined area, then split at its midpoint constrained between labels.

These defaults ship in the parser and example for fresh installations. They apply to AX preview and Accessibility placement, never the screenshot detector. Geometry is read anew per AX invocation; no placement cache. JPEG RAM caching remains enabled.

### Advanced settings editor

Settings → Advanced settings… reads the current file into Name, Value and Comment columns; only values are editable. Rows and explanations come from assignments, preceding comment lines and inline comments, with no separate editor schema. Unchanged lines, ordering, line endings are preserved. Search matches names and comments, case-insensitively, while retaining unsaved edits to filtered-out rows. New supported settings entered in the file appear when the editor is reopened; no editor code change is required. Save validates with the existing parser and performs a coordinated atomic write only if the file still matches the opened content. Unknown entries remain visible/preserved, but unsupported active keys still fail existing parser validation. Cancel and the close button discard unsaved edits. Open config file retains the existing external editor action.
