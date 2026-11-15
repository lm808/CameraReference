# Camera Reference — agent guide

## Collaboration

Discussion is not permission to implement. This user explicitly asks to hold work until a go-ahead; read the current request carefully. Preserve user test annotations before replacing a checklist. Do not push, publish a release, install/launch the app or change Lightroom unless authorised. Do not spawn subagents unless requested. Do not request or use Computer Use; leave all live interaction, app launches, Lightroom window manipulation and permission changes to the user. Use code inspection and automated checks only. Licensing is undecided; do not choose one on the user's behalf.

Keep accepted daily-use and candidate builds in separate Git worktrees. Do not rebuild the daily-use release/ when working on a candidate. Merge only after user acceptance; do not call a candidate verified from automated tests alone.

## Build and checks

For each delivered update increment the patch version (1.0.1 → 1.0.2). For a user-requested packaged feature release increment minor and reset patch (1.1.0). Increment major and reset minor/patch only when the user requests a major revamp (2.0.0). Never make a DMG unless explicitly requested.

The user runs only staged apps: stable `release/CameraReference.app` or candidate `release/CameraReference Testing.app`, never build/. Keep build/ for intermediate binaries/tests. After an update, refresh the ignored release/ staging folder with scripts/stage.sh; copy only changed components. Package that staged/tested payload when requested.

- `bash build.sh`: native-architecture macOS app at `build/CameraReference.app` (ad-hoc signed).
- `bash test.sh`: Swift regression executables and Lua stand-ins; requires Apple command-line tools and texlua.
- `bash test.sh <stacked-left-crop.png> <side-by-side-bottom-crop.png>`: optional original crop scanner checks; images remain external.
- `bash scripts/stage.sh`: build and incrementally refresh release/; --no-build stages an already verified build.
- `bash scripts/package.sh`: package the existing release/ payload as a DMG/checksum under ignored dist/. Uses hdiutil; may require sandbox approval. Does not install the app or publish anything. Existing DMG is not overwritten.
- Verify signature/plist and `git diff --check` before committing. Run checks appropriate to the change; avoid repeating unchanged suites without reason.

Use plain three-component versions in CFBundleShortVersionString (current `1.0.32`); the menu and package script read that value. Stable keeps org.local.CameraReference. User authorised testing identity org.local.CameraReference.testing with a purple icon; candidate builds use bash build.sh --testing or bash scripts/stage.sh --testing. Both use the existing org.local.CameraReference preference domain and shared support/bridge folder; run only one app at a time. Do not rebuild main’s accepted staged app while working on candidates.

## Source map and flow

| Source | Responsibility / relationship |
|---|---|
| `Sources/main.swift` | Menu/app lifecycle, shortcuts, bridge request pipeline, dispatch to display/capture, calibration, cache ownership, background/geometry timers, suspension and window ordering |
| `Core.swift` | Protocol/source primitives, cancellation, extraction helpers |
| `ImageSource.swift` | Standalone/embedded selection, orientation/decode, file fingerprints, one-selection RAM cache |
| `Export.swift` | View-specific JPEG snapshots and explicit safe export |
| `ScreenProbe.swift` | ScreenCaptureKit capture/crop, points↔raster mapping, Full/split placement result, margin divider scanner |
| `ViewportDetector.swift` | Full UI rectangle evidence and cached raster-boundary validation; protect the established Full path |
| `PhotoDetector.swift` | Legacy/diagnostic photo-edge detection and related fixtures; not a replacement for UI Fit calculation |
| `ConfigEditor.swift` | File-driven advanced settings table, value-only edits, validation and external-edit protection |
| `DetectionConfig.swift` | Advanced config schema, parser, metadata cache and legacy filename migration |
| `SplitLayout.swift` | Explicit pane geometry, floating half-viewport fit, placement memory, comparison/order helpers |
| `AXTrial.swift` | Panel/label geometry shared by AX preview and opt-in AX-only placement |
| `Layout.swift` | Lightroom window metadata/coordinate helpers, bounded AX probes, overlay host state decisions and overview heuristic |
| `Interaction.swift` | Image navigation, display geometry and placement checks |
| `Views.swift` | Shared photo view, overlay/floating panels, floating chrome, previews/toasts/menu diagrams |
| `Calibration.swift`, `Snapping.swift` | Drag-selection UI, Option edge snapping and region preference clearing |
| `Shortcut.swift`, `Permissions.swift` | Shortcut recording and feature-triggered native permission prompts |
| `CameraReference.lrplugin/` | Lua bridge/init/shutdown/diagnostic menus; request tokens, module heartbeat, opaque selection revisions |
| `tests/` | Swift behaviour/geometry/raster/export checks and Lua bridge stand-ins; native acceptance is separate |

Main flow: shortcut → bridge request/epoch → image load or RAM hit → manual/cached/fresh UI placement → photo view. Background checks never replace normal-resolution displayed geometry; they invalidate it. GUI settings/calibration use UserDefaults; advanced settings use config.conf; bridge files are separate runtime state.

## Invariants

- Never write RAW/catalogue/Develop settings. Image extraction/capture stays in memory. Export requires explicit user action.
- Never infer main Lightroom view from secondary-display API or command availability. User menu selection guides split mode.
- Split uses unchanged Full bounds, then bottom/left inset scanning. See docs/METHODS.md before changing this; prior alternate outer-bound logic regressed badly.
- Preserve point/pixel and top-left/AppKit conversions; do not substitute display width for window crop.
- Full mode and accepted manual placement must remain usable during split development.
- Keep original Fit geometry separate from the whole-region zoom/pan boundary. Preserve the CR3 extraction path when adjusting ARW tag selection; RAW and extracted preview data remain read-only/in-memory.
- Respect source/selection epochs, request IDs, cancellation and cache generations. Never display a late result for another request.
- Clear region must not change auto/manual preference. Successful calibration turns auto off; cancellation changes nothing.
- Pure AX automatic overlays follow view/pane/panel changes with Live update on (default); off dismisses. Grid/module changes dismiss. Screenshot backup modes keep pre-live behaviour: inference updates menus, panel checks invalidate cache, explicit menu selections dismiss. Never open an off overlay. Preserve image/window identity and reject late results.
- Keep visible overlays open through resize, detection failure, heartbeat/module uncertainty and changed selection. Invalidate cached placement for next invocation, not the current display. Follow known movement. Temporarily suspend for host invisibility/overview and restore even if selection or size changed. Explicit user dismissal, a confirmed module change, or confirmed host closure releases it. Never use full-display containment as a movement requirement.
- Accepted config defaults are `sideSearchPercent = 40` and all four bounds `ui`. Preserve explicit user values during upgrades; never replace a personal config with the example/template.
- Canonical support folder is CameraReference (no space). Merge old spaced contents, remove the empty old folder, preserve differing file conflicts beside their destination, and discard only known stale IPC. Do not create legacy folder copies. Preserve explicit settings; seed them before waiting for old bridge shutdown.
- No private macOS APIs or global security/permission resets. Native app/overview assertions need live evidence.

## Documentation and repository hygiene

README describes current functionality/usage, never a development diary. CHANGELOG records user-facing changes; RELEASE-NOTES describes the current downloadable build. docs/METHODS.md is the technical rationale; docs/VALIDATION.md records evidence; docs/BACKLOG.md lists unresolved work. TESTING.md is short/current only. Update related docs when behaviour changes; qualify synthetic versus native checks.

Do not commit build/release/dist artifacts, personal config, bridge runtime files, photographs, credentials or screenshot captures. Use config/config.example.conf for defaults. Preserve uncommitted user changes; inspect git status first. Keep working tree changes scoped and commit tested work. Do not create arbitrary release tags or push without instruction.


## AX investigation candidate

`Sources/AXTrial.swift` owns diagnostic geometry and the opt-in view classifier. AX corrections never enter capture geometry or its cache key. Manual wins; experimental AX-only branches before screenshot/cache/permission paths and must never fall back to pixel capture. Explicit capture previews, screen inspection and calibration snapping remain available in either backend. Config entries use ordinary name = value syntax throughout; no prefixed directives or obsolete v1 settings. Classification supplies only layout to the unchanged detector; no clear pair means single, read failure does not. Diagnostics retain the full window map and bounded toolbar menu reading; exhaustive child/AXSections probes belong only in AX Explorer. Toolbar failures follow toolbarUnknownFallback (shown/hidden/lastKnown); no history defaults to shown and diagnostics identify the fallback. Opt-in saved reports overwrite `CameraReference/Diagnostics/latest.txt`; do not commit these reports. Keep diagnostic timestamps when comparing cases.

## Standalone AX exploration

`tools/AXExplorer/` is a separate interactive read-only executable, built by `bash scripts/build-ax-explorer.sh` into `build/AXExplorer/`. It never rebuilds the app or changes its version/settings. Exploratory commands, branch skips and budgets are runtime options. Reports are saved explicitly under the worktree’s ignored investigations/ax-reports folder (never in Application Support). Leave all live use and permission prompts to the user; `--self-test` performs no live AX calls. Review tool findings separately before integrating production selectors.

## Assisted screenshot candidate

`Sources/AXAssisted.swift` contains raw structural hints, a separately maintained guided pixel search and placement-mode preference resolution. Do not modify ViewportDetector or the original split scanner to tune this experiment. The optional ScreenProbe hook must leave nil-hint behaviour unchanged. AX view inference remains separate from placement-method selection. Background screenshot checks are retained until measured evidence supports reducing them.
