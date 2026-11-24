# Camera Reference — agent guide

## Collaboration

Discussion is not permission to implement. This user explicitly asks to hold work until a go-ahead; read the current request carefully. Preserve user test annotations before replacing a checklist. Do not push, publish a release, install/launch the app or change Lightroom unless authorised. Do not spawn subagents unless requested. Do not request or use Computer Use; leave all live interaction, app launches, Lightroom window manipulation and permission changes to the user. Use code inspection and automated checks only. Licensing is undecided; do not choose one on the user's behalf.

Keep accepted daily-use and candidate builds in separate Git worktrees. Do not rebuild the daily-use release/ when working on a candidate. Merge only after user acceptance; do not call a candidate verified from automated tests alone.

## Architectural contract — humans and agents

Read [docs/CONTRIBUTING-STRUCTURE.md](docs/CONTRIBUTING-STRUCTURE.md) and the current source map before changing logical paths. Respect responsibility boundaries, not just file placement. Selection/recording UI returns values; coordinators interpret them; pure policy decides behaviour; backend calculations remain independent; presentation consumes results. Never repurpose an unrelated boolean to reach a desired branch. Preserve evidence provenance/cancellation guards and single state ownership. Route new entry points through existing actions instead of copying behaviour. Document any necessary boundary change and test neighbouring modes. Keep guided calibration separate from manual-region persistence and production placement calculations.

## Build and checks

For each delivered update increment the patch version (1.0.1 → 1.0.2). For a user-requested packaged feature release increment minor and reset patch (1.1.0). Increment major and reset minor/patch only when the user requests a major revamp (2.0.0). Never make a DMG unless explicitly requested.

The user runs only staged apps: stable `release/CameraReference.app` or candidate `release/CameraReference Testing.app`, never build/. Keep build/ for intermediate binaries/tests. For documentation-only updates, do not rebuild, restage or change the app version. After a code update, refresh the ignored release/ staging folder with scripts/stage.sh; copy only changed components. Package that staged/tested payload when requested.

- `bash build.sh`: native-architecture macOS app at `build/CameraReference.app` (ad-hoc signed).
- `bash test.sh`: Swift regression executables and Lua stand-ins; requires Apple command-line tools and texlua.
- `bash scripts/stage.sh`: build and incrementally refresh release/; --no-build stages an already verified build.
- `bash scripts/package.sh`: package the existing release/ payload as a DMG/checksum under ignored dist/. Uses hdiutil; may require sandbox approval. Does not install the app or publish anything. Existing DMG is not overwritten.
- Verify signature/plist and `git diff --check` before committing. Run checks appropriate to the change; avoid repeating unchanged suites without reason.

Use plain three-component versions in CFBundleShortVersionString (candidate `1.1.6`); the menu and package script read that value. Stable keeps org.local.CameraReference. User authorised testing identity org.local.CameraReference.testing with a purple icon; candidate builds use bash build.sh --testing or bash scripts/stage.sh --testing. Both use the existing org.local.CameraReference preference domain and shared support/bridge folder; run only one app at a time. Do not rebuild main’s accepted staged app while working on candidates.

## Source map and flow

| Source | Responsibility / relationship |
|---|---|
| `Sources/main.swift` | Composition/startup/shutdown, shortcuts, invocation entry points, contextual region preferences and shared placement/calibration operation state |
| `SettingsActions.swift`, `ViewCoordinator.swift` | Settings actions; explicit pane choices, invocation AX inference and guarded live view/photo geometry updates |
| `CalibrationCoordinator.swift`, `ExportCoordinator.swift` | Calibration transaction/failure prompts and explicit photo-view export coordination |
| `PlacementCoordinator.swift`, `PlacementImplementations.swift` | Manual/cache/backend routing and separate geometry adapters; calculations remain with their backend owners |
| `PhotoRequestCoordinator.swift`, `PhotoRequestPipeline.swift` | Request qualification/dispatch versus transport, cancellation and image-cache ownership |
| `OverlayBehaviour.swift` | Pure behaviour decisions; no reads, timers or window mutations. Callers preserve evidence guards and action order |
| `AppSettings.swift`, `SettingsMenu.swift` | Mode/default preference interpretation and menu ownership; AppDelegate retains actions and existing triggers |
| `Diagnostics.swift` | Diagnostic state, formatting, saving and preview ownership; App-facing AppDelegate adapters preserve collection/capture coordination |
| `Core.swift` | Protocol/source primitives, cancellation, extraction helpers |
| `ImageSource.swift` | Standalone/embedded selection, orientation/decode, file fingerprints, one-selection RAM cache |
| `Export.swift` | View-specific JPEG snapshots and explicit safe export |
| `ScreenProbe.swift` | ScreenCaptureKit capture/crop, points↔raster mapping, Full/split placement result, equal splitting |
| `ViewportDetector.swift` | Full UI rectangle evidence and cached raster-boundary validation; protect the established Full path |
| `PhotoDetector.swift` | Legacy/diagnostic photo-edge detection and related fixtures; not a replacement for UI Fit calculation |
| `ConfigEditor.swift` | File-driven advanced settings table, value-only edits, validation and external-edit protection |
| `DetectionConfig.swift` | Advanced config schema, parser, metadata cache and legacy filename migration |
| `SplitLayout.swift` | Explicit pane geometry, floating half-viewport fit, placement memory, comparison/order helpers |
| `AXPanelState.swift`, `PlacementMode.swift` | Preserved AX panel-change signature and two-backend preference resolution; no AX-guided pixel placement |
| `AXTrial.swift` | Panel/label geometry shared by AX preview and Accessibility placement |
| `Layout.swift` | Lightroom window metadata/coordinate helpers, bounded AX probes, overlay host state decisions and overview heuristic |
| `Interaction.swift` | Image navigation, display geometry and placement checks |
| `LightroomMonitor.swift`, `MonitoringCoordinator.swift` | Observation/timer/subscription ownership and separate existing policy execution; preserve cadence, synchronous notification delivery and stale-result guards |
| `OverlayController.swift`, `FloatingDisplayController.swift` | Independent overlay lifecycle/displayed identity and floating display state owners |
| `PresentationCoordinator.swift` | App-facing display/lifecycle coordination, using single presentation state owners; guards and order preserved |
| `Views.swift` | Shared photo view, overlay/floating panels, floating chrome, previews/toasts/menu diagrams |
| `Calibration.swift`, `Snapping.swift` | Drag-selection UI, Option edge snapping and region preference clearing |
| `Shortcut.swift`, `ShortcutSettings.swift`, `ViewShortcuts.swift`, `Permissions.swift` | Recording widget, transactional binding settings, guarded view-action dispatch and feature-triggered permission prompts |
| `AXCalibration.swift`, `AXCalibrationCoordinator.swift` | Pure six-setup/seven-selection geometry calculation and separate Developer tools workflow; existing selection UI, explicit reviewed config update with backup |
| `CameraReference.lrplugin/` | Lua bridge/init/shutdown/diagnostic menus; request tokens, module heartbeat, opaque selection revisions |
| `tests/` | Swift behaviour/geometry/raster/export checks and Lua bridge stand-ins; native acceptance is separate |

Main flow: shortcut → bridge request/epoch → image load or RAM hit → manual/cached/fresh UI placement → photo view. Screenshot background checks invalidate cached placement only. AX automatic live updates separately recalculate displayed geometry according to the user option. GUI settings/calibration use UserDefaults; advanced settings use config.conf; bridge files are separate runtime state.

## Invariants

- Never write RAW/catalogue/Develop settings. Image extraction/capture stays in memory. Export requires explicit user action.
- Never infer main Lightroom view from secondary-display API or command availability. Explicit menu selection guides screenshot mode when AX view inference is off; AX label inference supplies the view when enabled and always in Accessibility mode. A successful no-pair read assumes single, not confirmed Library Loupe.
- Screenshot splits use the validated Full bounds, then 50/50 division. Wider side search retries use the same pixel validation. AX uses its unchanged corrected panel geometry and midpoint/label constraints. Keep the two placement methods independent; see docs/METHODS.md.
- Preserve point/pixel and top-left/AppKit conversions; do not substitute display width for window crop.
- Full mode and accepted manual placement must remain usable during split development.
- Keep original Fit geometry separate from the whole-region zoom/pan boundary. Preserve the CR3 extraction path when adjusting ARW tag selection; RAW and extracted preview data remain read-only/in-memory.
- Respect source/selection epochs, request IDs, cancellation and cache generations. Never display a late result for another request.
- Clear region must not change auto/manual preference. Successful manual-region calibration turns auto off; cancellation changes nothing. Guided AX calibration only updates reviewed geometry offsets and never changes manual-region or auto/manual preferences.
- Pure AX automatic overlays follow photo-selection/view/pane/panel changes with Update overlay with LrC view on (default); off dismisses. Positive direct Grid selection evidence / confirmed module changes dismiss; native Grid mark reliability still needs verification. View/panel updates preserve zoom; photo refresh resets Fit. Screenshot with AX view detection dismisses on confirmed photo/view/pane/panel changes and Grid, matching AX update-off. Without inference, screenshot also dismisses on confirmed photo selection changes; pixel checks invalidate cache and explicit menu selections dismiss. Never open an off overlay. Preserve image/window identity and reject late results.
- Keep visible overlays open through detection failure and heartbeat/module uncertainty. Resize/panel and photo changes respect AX update/dismiss policy; screenshot with AX view detection dismisses on confirmed changes. Screenshot without inference dismisses on confirmed photo changes but retains its existing panel/resize behaviour; manual placement retains its existing behaviour. Invalidate cached placement for next invocation, not the current display. Follow known movement. Temporarily suspend for host invisibility/overview and restore even if selection or size changed. Explicit user dismissal, a confirmed module change, or confirmed host closure releases it. Never use full-display containment as a movement requirement.
- Accepted config defaults are `sideSearchPercent = 40` and all four bounds `ui`. Preserve explicit user values during upgrades; never replace a personal config with the example/template.
- Canonical support folder is CameraReference (no space). Merge old spaced contents, remove the empty old folder, preserve differing file conflicts beside their destination, and discard only known stale IPC. Do not create legacy folder copies. Preserve explicit settings; seed them before waiting for old bridge shutdown.
- No private macOS APIs or global security/permission resets. Native app/overview assertions need live evidence.

## Documentation and repository hygiene

README describes current functionality/usage, never a development diary. docs/ARCHITECTURE.md is the detailed current source/flow map; docs/AX-ASSISTANCE.md consolidates research findings and limits; docs/HISTORICAL-NOTES.md archives superseded investigations. Raw probes remain ignored under investigations/ax-reports, not in release/. CHANGELOG records user-facing changes; RELEASE-NOTES describes the current downloadable build. docs/METHODS.md is the technical rationale; docs/VALIDATION.md records evidence; docs/BACKLOG.md lists unresolved work. TESTING.md is short/current only. Update related docs when behaviour changes; qualify synthetic versus native checks.

Do not commit build/release/dist artifacts, personal config, bridge runtime files, photographs, credentials or screenshot captures. Use config/config.example.conf for defaults. Preserve uncommitted user changes; inspect git status first. Keep working tree changes scoped and commit tested work. Do not create arbitrary release tags or push without instruction.


## Accessibility placement and diagnostic evidence

`Sources/AXTrial.swift` owns diagnostic geometry and the view classifier (always used in Accessibility, optional in Screenshot). AX corrections never enter capture geometry or its cache key. Manual wins; Accessibility placement branches before screenshot/cache/permission paths and must never fall back to pixel capture. Explicit capture previews, screen inspection and calibration snapping remain available in either backend. Config entries use ordinary name = value syntax throughout; no prefixed directives or obsolete v1 settings. Classification supplies only layout to the independent pixel detector; no clear pair means single, read failure does not. Diagnostics retain the full window map and bounded toolbar menu reading; exhaustive child/AXSections probes belong only in AX Explorer. Toolbar failures follow toolbarUnknownFallback (shown/hidden/lastKnown); no history defaults to shown and diagnostics identify the fallback. Opt-in saved reports overwrite `CameraReference/Diagnostics/latest.txt`; do not commit these reports. Keep diagnostic timestamps when comparing cases.

## Standalone AX exploration

`tools/AXExplorer/` is a separate interactive read-only executable, built by `bash scripts/build-ax-explorer.sh` into `build/AXExplorer/`. It never rebuilds the app or changes its version/settings. Exploratory commands, branch skips and budgets are runtime options. Reports are saved explicitly under the worktree’s ignored investigations/ax-reports folder (never in Application Support). Leave all live use and permission prompts to the user; `--self-test` performs no live AX calls. Review tool findings separately before integrating production selectors.

## Screenshot fallback

Screenshot placement is independent of AX geometry; optional AX view detection supplies layout only. AXPanelState retains the prior signature for view/panel-change policy. Preserve background pixel checks, permission preflights and cache guards. Retired assisted preferences resolve to Screenshot; never reintroduce a third placement path. Current work is tracked in FINAL-WORK.md; guided recalibration and the final candidate are user-accepted through 1.1.15. Main remains unchanged until an explicit merge instruction.

## Structure migration worktree

This branch follows MIGRATION.md and docs/migration/TARGET-STRUCTURE.md. Keep the checklist and docs/migration/FINDINGS.md current at each stage. Preserve current user-visible behaviour and timing; prioritise the default Accessibility workflow. Record issues and proposed fixes separately rather than fixing edge cases during extraction. Current architecture docs describe existing code; the target map is a proposal until stages actually move it. Stage 0 is documentation-only: no build, version change or release staging.

For the current migration round, user-directed candidate versions are 1.1.<stage> (stage 3: 1.1.3). Preserve completed stage annotations separately when replacing the lean current checklist.

Current coordinator files are AppDelegate extensions sharing one composition surface. Native selectors and weak callbacks retain the same targets. Request/panel aliases and diagnostic/menu adapters remain intentionally; most state accesses name their owner. Shared placement/cache/calibration IDs remain on composition because their cancellation lifetimes overlap. See docs/ARCHITECTURE.md and docs/migration/FINAL-REVIEW.md before changing these boundaries. Stage 9 code consolidation does not imply native acceptance or permission to merge.

Explicit automatic screenshot placement may request Screen Recording; AX-only, background checks and manual snapping must not prompt. Guided AX calibration uses permission-available pixel edges only for explicit selector snapping, and changes only 12 reviewed geometry/Fit keys after backup and external-edit checks. Its pure calculator and workflow remain separate from CalibrationController and manual region persistence.

Screenshot expanded working-area reuse is a default-on developer preference interpreted by AppSettings. Off preserves the earlier same-photo/same-pane placement and Loupe-only raster cache; it is not “disable all caching”. On may reuse across photos, movement and Develop layouts, but Library Loupe/Compare boundary changes invalidate it. Keep source/request epochs guarding display even though geometry can outlive a photo. Explicit clearing/toggle changes invalidate both geometry layers. AX-only must never consume this option.

1.1.13: inconclusive background pixel checks retain successful placement memory only when expanded screenshot reuse is on; confirmed geometry changes still invalidate. Picture-style metadata belongs to LoadedReference/cache and each displayed ReferenceView, never global current-selection state. Developer visibility is config-owned (showDeveloperTools, default false). Guided calibration uses six independently retryable setup slots plus setup-1 photo bounds; countdown/selector remain presentation-only, workflow owns cancellation/evidence/persistence, pure plan owns signed calculations and conflict checks.

## Accepted boundary audit (2026-11-24)

Read docs/BOUNDARY-AUDIT.md for the 1.1.15 review. Primary boundaries remain intact. Two documented follow-ups remain: raw calibration evidence should not depend on corrected-placement validity; permission guidance should use typed results rather than diagnostic text. Do not silently fold these into unrelated work. Shared Fit settings intentionally affect both backends; AX-specific corrections never enter pixel geometry. Preserve exact user test responses in docs/ before replacing TESTING.md. A documentation-only acceptance/audit update does not authorise rebuilding, restaging, merging or publishing.
