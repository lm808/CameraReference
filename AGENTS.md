# Camera Reference — agent guide

## Collaboration

Discussion is not permission to implement. This user explicitly asks to hold work until a go-ahead; read the current request carefully. Preserve user test annotations before replacing a checklist. Do not push, publish a release, install/launch the app or change Lightroom unless authorised. Do not spawn subagents unless requested. Licensing is undecided; do not choose one on the user's behalf.

## Build and checks

- `bash build.sh`: native-architecture macOS app at `build/CameraReference.app` (ad-hoc signed).
- `bash test.sh`: Swift regression executables and Lua stand-ins; requires Apple command-line tools and texlua.
- `bash test.sh <stacked-left-crop.png> <side-by-side-bottom-crop.png>`: optional original crop scanner checks; images remain external.
- `bash scripts/package.sh`: build + DMG/checksum under ignored dist/. Uses hdiutil; may require sandbox approval. Does not install the app or publish anything. Existing DMG is not overwritten.
- Verify signature/plist and `git diff --check` before committing. Run checks appropriate to the change; avoid repeating unchanged suites without reason.

Build metadata currently uses CFBundleShortVersionString `1.0.0` plus CameraReferenceReleaseName `1.0 alpha`; menu reads the latter. Keep release docs/package names consistent when changing versions. Preserve org.local.CameraReference until an explicit bundle-ID migration is planned.

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
| `DetectionConfig.swift` | Advanced config schema, parser, metadata cache and legacy filename migration |
| `SplitLayout.swift` | Explicit pane geometry, floating half-viewport fit, placement memory, comparison/order helpers |
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
- Respect source/selection epochs, request IDs, cancellation and cache generations. Never display a late result for another request.
- Clear region must not change auto/manual preference. Successful calibration turns auto off; cancellation changes nothing.
- Temporary suspension retains content; explicit dismissal releases it. Do not reintroduce full-display containment as a movement requirement.
- Keep config migration non-destructive: new config wins, old file retained, user values preserved.
- No private macOS APIs or global security/permission resets. Native app/overview assertions need live evidence.

## Documentation and repository hygiene

README describes current functionality/usage, never a development diary. CHANGELOG records user-facing changes; RELEASE-NOTES describes the current downloadable build. docs/METHODS.md is the technical rationale; docs/VALIDATION.md records evidence; docs/BACKLOG.md lists unresolved work. TESTING.md is short/current only. Update related docs when behaviour changes; qualify synthetic versus native checks.

Do not commit build/dist artifacts, personal config, bridge runtime files, photographs, credentials or screenshot captures. Use config/config.example.conf for defaults. Preserve uncommitted user changes; inspect git status first. Keep working tree changes scoped and commit tested work. Do not create arbitrary release tags or push without instruction.
