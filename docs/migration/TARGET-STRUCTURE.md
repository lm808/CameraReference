# Target structure and migration map

Design baseline: a568c6e / 1.0.32. Names below are proposed; do not add empty classes or rename all source files up front. Introduce a component when responsibility is actually moved. Current source map: [../ARCHITECTURE.md](../ARCHITECTURE.md). Working stages: [../../MIGRATION.md](../../MIGRATION.md).

## Intended flow

```text
Shortcut/menu → AppCoordinator → PhotoRequestPipeline
                                      ↓ LoadedReference + request identity
                               PlacementCoordinator
                     manual / AX / screenshot / assisted screenshot
                                      ↓ UI placement + photo Fit + evidence
                   OverlayController or FloatingDisplayController
                                      ↓
                                ReferenceView

LightroomMonitor → observation + provenance → OverlayBehaviourPolicy
                                                  ↓ explicit action
                              coordinator → relevant owner

Owners → diagnostic snapshots → DiagnosticsController/service
SettingsStore → immutable operation settings + menu presentation
```

The application coordinator owns the components and connects them. Avoid bidirectional access to AppDelegate or a shared mutable “everything” context. Pass specific inputs and narrow callbacks; retain current main-thread handoff points initially. Do not introduce a generic event bus, plugin system or additional framework targets.

## Component contracts and current symbols

All AppDelegate symbols below are in Sources/main.swift. Symbol names are navigation anchors; line numbers will drift.

| Target | Existing code to move/wrap | Owned state and boundary |
|---|---|---|
| AppCoordinator / thin AppDelegate | applicationDidFinishLaunching, quit; action wiring | Component lifetime, startup/shutdown order. Keep NSApplication/selector adapters thin; move startup blocks separately rather than wholesale. |
| SettingsStore + MenuController | buildLayoutMenu, updateLayoutMenu, updateDetectionMenu, menuNeedsUpdate, selectLayout, selectDetectionMethod, toggleAutomaticView, toggleScreenshotAssistance, toggleAXLiveUpdate, changeAutomatic, changePreference, chooseExifTool, changeShortcut, registration/menu construction | Preference access, menu items, recording/hotkey handles. UserDefaults remains authoritative, DetectionConfigStore remains file owner. Actions call policy/coordinators; menu does not directly mutate panels. |
| PhotoRequestPipeline | request, load, failed, cancelRequest, selectionEpoch, responseEpoch; ImageSource/Core helpers | pending token, destination, cancellation, pendingModule, response timer, invocation timing and SelectionImageCache. Return LoadedReference with selection/request identity. Do not own visible panel; refresh target identity is supplied by caller. |
| PlacementCoordinator | resolveOverlay, calibratedUI, cachedUI, rememberPlacement, resolveFloating, showUI geometry setup, reloadDetectionConfig | PlacementMemory, dispatch, relevant config snapshot and invalidation; manual/automatic precedence. Distinguish overlay target pane from floating combined-area request. Display and calibration decisions stay outside calculators. |
| ManualPlacement | savedRegion, region, regionKey, calibratedUI, displayManual geometry | Read saved region + host context; translate using current rules. Region storage access through settings. No selection UI or direct rendering. |
| AXPlacement | startAXPlacement; existing AXTrial/Layout functions | Fresh host/panel/toolbar reading plus existing corrections and pane calculation. Always AX view inference. No automatic capture fallback; preserves permission/failure behaviour. |
| ScreenshotPlacement / AssistedScreenshotPlacement | startPhotoDetection + ScreenProbe optional-hint route; AXAssisted hints | Existing original/guided pixel searches remain separate. Preserve capture normalisation, nil-hint behaviour, cache separation and fallback decisions. Adapters may share capture utilities but must not merge algorithms. |
| CalibrationCoordinator | beginCalibration, calibrate, clearAllRegionData, askForCalibration; Calibration/Snapping | Calibration controller/task/timer and region reset transaction. Accept writes current keys/auto off; cancellation changes nothing. Capture/snapping only with permission; preserve current wording. |
| OverlayBehaviourPolicy | existing helpers in SplitLayout; branches in selectLayout, checkOverlaySelection, followLiveOverlayView, module timer, dismissForGrid | Pure decisions from mode/options, displayed state and qualified observations. No AX, capture, UserDefaults, timers or window calls. Explicit actions, with flags for what state to preserve. |
| OverlayController | display, hide, suspendOverlay, reconcileOverlayHost, bindOverlayAccessibility, updateOverlayLifecycle, orderOverlayAboveLightroom, reloadOverlay; presentation parts of refreshAXSelection/followLiveOverlayView | Overlay panel/view, displayed epoch/module/layout, host, geometry settler, suspended/resume state, ordering/level counters and retained export snapshot. Does not infer backend policy. |
| FloatingDisplayController | openFloating, displayFloating, updateFloatingTitle, windowWillClose; floating branch of resolveFloating | Floating panel/view, title/zoom/hover timer and independent image snapshot. Sizing consumes placement output; does not copy overlay lifecycle rules. |
| Shared photo presentation | configureImageView, saveExtracted; ReferenceView/Interaction/Export/Views | Navigation/zoom/pan, display snapshot and explicit export callbacks. Keep Fit frame, pan boundary and view transform distinct. Avoid a monolithic window controller with floating/overlay conditionals. |
| LightroomMonitor | moduleTimer body, currentModule, isLightroom, observeWindowGeometry, checkLiveAXViewIfDue, checkPanelBoundariesIfDue, frontAppChanged, spaceChanged, displaysChanged | Observation scheduling, host/module/view/selection evidence, background tasks/signatures. Existing readers remain Layout/AX helpers. Report changes/unknowns; no independent decision to show/hide an overlay. |
| Diagnostics service + diagnostic previews | report, diagnosticSections, saveInvocationDiagnostics, collectCompleteDiagnostics, inspectLayout, showDiagnostics, inspectViewState, runAXTrial, clearAXTrialBorders, showCapturePreview, keepCaptureBaseline, previewCapture, inspectScreen | Diagnostic strings/counters/generation, reporting window, optional border panels/raw previews/baseline. Preserve guard interactions with foreground work; read-only snapshots from owners, no production geometry feedback. |
| Storage bootstrap | consolidateStorageIfDue + existing Core/preferences helpers | Migration status and timing. Same paths/conflict handling; invoke in existing startup/tick order initially. No storage format changes. |

Some functions currently combine several rows. Split them at an existing calculation/completion boundary, preserve the order of effects and test before moving the remainder. Do not make the source table itself a reason for a single large edit.

## Data boundaries (minimal abstractions)

- **Operation context:** existing request token, destination, selection epoch, module, host identity, settings snapshot and applicable generation. Wrap current checks first; retain distinction between unknown and confirmed evidence. A single global generation is not a safe drop-in replacement.
- **Placement result:** existing global/AppKit UI geometry, photo Fit geometry where applicable, host, surround/provenance and failure reason. State coordinate convention explicitly in names/types. Do not change conversion arithmetic or rounding during extraction. Original capture/raster types can remain internal to screenshot implementations.
- **Displayed reference:** image + export snapshot + displayed source epoch. This is not always Lightroom’s current selection. Geometry-only changes retain image/zoom; photo replacement resets Fit exactly as now.
- **Observation:** confirmed value/change or unavailable/ambiguous evidence, with host/module/generation provenance. Keep polling timestamps and distinction between observation and displayed baselines.
- **Action:** leave unchanged, invalidate future placement, update geometry, replace photo, suspend, restore or dismiss. Initial policy must express existing side effects and their order; do not force mutually exclusive actions where current code both invalidates and dismisses.
- **Presentation state:** absent versus visible versus temporarily suspended. Model pending loading/placement separately because an old image can remain visible while a new request runs. Preserve existing flags until equivalence is established; do not replace them all with one simplistic enum.

Use a small placement interface because four concrete paths genuinely need the same output. Other components can remain concrete types. Add protocols only where test doubles or multiple implementations justify them. Keep main-thread window mutation and current worker-queue calculations explicit; do not migrate to a new concurrency model as part of this work.

## Default path and compatibility contract

First prove the production AX workflow: initial invocation → current image/RAM cache → fresh AX region → Fit → warm toggle → live geometry/photo update. AX-only must not capture pixels automatically. Unknown evidence retains previous state; real failures retain the existing reference according to current guards.

Then protect option-off and alternative paths. Manual remains first priority. Screenshot AX view detection remains independent of screenshot assistance. Screenshot background checks only invalidate reuse; explicit menu selection dismisses; screenshot/manual selection does not replace the current displayed image. Floating photo independence and half-width/full-height initial sizing remain unchanged. Positive Grid evidence and confirmed module changes retain their current scope; do not “fix” unavailable marks by guessing.

## Timing, work ownership and guards

Preserve the existing tick sequence initially: storage check → selection/cache observation → module handling → overview/geometry/order → screenshot boundary check → live AX view check → selection refresh. The 0.2-second timer also updates menu state; moving this ordering can affect which operation starts first.

Preserve 50ms bridge response polling and five-second timeout, two-second eligible AX polling, configurable screenshot checks, and existing hover/geometry timing. Measurement boundaries remain bridge, image load and placement through panel shown. Diagnostics must not add a blocking prerequisite to display.

Guard inventory to carry across extraction:

| Existing state | Eventual owner / requirement |
|---|---|
| pending / cancellation / pendingModule / response epoch | Photo pipeline; cancellation rejects old replies and decode completions |
| screenInspectionID / screenTask / screenTimeout / screenModule | Placement operation owner; explicit preview/calibration orchestration initially retains existing shared cancellation semantics |
| viewProbeID / liveViewGeneration / liveViewBusy | Monitor + view operation context; invalidation must still defeat pending completion |
| selectionRefreshPanel / attemptedSelectionRefresh / overlayEpoch | Coordinator refresh context + displayed-reference owner; once per epoch, exact panel identity |
| panelCheckID / panelCheckTask / nextPanelCheck | Screenshot background monitor; foreground cancellation and stale result rejection |
| diagnosticGeneration / diagnosticPending / savingInvocation | Diagnostics; do not publish a report as fresh for a different invocation |
| axTrialGeneration / axTrialBorders | Diagnostics preview lifetime tied to actual overlay |

A change of owner must not imply a change of invalidation scope. Avoid retain cycles in callbacks/timers and keep shutdown cancellation equivalent. Any proposed simplification of these guards requires a separate tested commit.

## Future seams, not features to implement now

Lightroom zoom/pan following would supply a view-transform observation to shared presentation policy; keep source Fit and whole-region pan bounds distinct now. More RAW formats belong behind existing ImageSource extraction choices, not new placement branches. Environmental refinements belong in evidence interpretation/policy, with execution delegated to controllers. Neither capability is implemented by this migration plan.


## Stage 2 implementation note

DiagnosticsService now exists in Sources/Diagnostics.swift. It owns stored report/preview state, section formatting, atomic save and diagnostics-window creation. AppDelegate forwarding accessors and diagnostic coordination adapters are colocated in that file as a temporary bridge; these retain their original request/monitor/capture dependencies and dispatch order. The formatter reads the current AppDelegate synchronously rather than introducing eagerly generated snapshots. Later owner extractions should replace that dependency locally. Production AX readers/classification and shared capture ownership have not moved into the diagnostics service.


## Stage 3 implementation note

AppSettings owns mode/default preference interpretation and original startup registration/migration using the same shared UserDefaults instance. SettingsMenuController owns menu references, construction and refresh/validation. It holds an unowned AppDelegate reference; menu actions/delegation and contextual current-module/layout decisions remain on AppDelegate through forwarding adapters. No timer, action order or preference schema changed. Later stages can replace these synchronous dependencies with the extracted coordinator/settings contexts locally. The separately authorised info-overlay strip fix is not part of the structural extraction.


## Stage 4 implementation note

OverlayBehaviourPolicy now owns existing pure decisions in OverlayBehaviour.swift. AppDelegate calls the policy at the same branch points; compatibility helpers remain for established tests/callers. Qualifying observations and applying effects remain in the existing coordinator. This deliberately does not consolidate request freshness, native visibility or asynchronous completion guards into an eagerly populated context: doing so could alter short-circuit reads and execution timing. Presentation/controller and monitor ownership remain later stages.

## Stage 5 implementation boundary

The actual placement coordinator is currently an AppDelegate extension in PlacementCoordinator.swift, not a new state owner. This deliberate intermediate boundary keeps request, cancellation, cache and presentation state singular until stages 6–8. Twelve methods moved; eight bodies are byte-identical and four differ only by concrete adapter calls. PlacementImplementations.swift supplies ManualPlacement translation, AX selected/combined area conversion, and separate original/assisted screenshot adapters. UIPlacement names global AppKit UI geometry; screenshot probe metadata and precomputed candidate/photo geometry remain untouched. Calibration preparation, background screenshot validation and diagnostic capture actions retain their existing direct paths. No general event bus or new timer was added.

## Stage 6 implementation boundary

PhotoRequestPipeline owns request state/transport and image cache without an AppDelegate reference. PhotoLoadContext snapshots the existing token, target, cancellation object, invocation time, module, epoch and refresh target/generation. PhotoRequestCoordinator keeps qualification and dispatch as an extension, with forwarding accessors for unchanged external call sites. The pipeline reads/loads on the same queues and returns through the original main-queue handoff. It retains a refresh panel only as identity/lifetime context; presentation remains outside it. No event bus, new deadline, unified generation or new retry policy.

## Stage 7 implementation boundary

OverlayController and FloatingDisplayController are concrete, independent state owners with no back-reference to AppDelegate. OverlayController owns panel/host/lifecycle and displayed identity; FloatingDisplayController owns its panel/view/title/zoom. PresentationCoordinator is a transitional AppDelegate extension for cross-component actions. Forwarding properties maintain one source of truth, including inout geometry-settler and AX-binding access. Lifecycle trace maintenance and floating-title formatting execute on their respective owners.

Fourteen existing methods moved without changing their bodies. Window construction, NSWindowDelegate callbacks, weak image-view callbacks, ordering and cancellation sequences retain their original coordinator context. Geometry-only updates remain distinct from image replacement in the existing AX completion paths; ReferenceView and export snapshots are unchanged. This stage intentionally does not fix the deferred native stacking or diagnostic preview constraints. Monitoring ownership follows in stage 8, composition cleanup in stage 9.

## Stage 8 implementation boundary

LightroomMonitor owns observation state, timers/subscriptions and read-only heartbeat/foreground/live AX readers. It emits small synchronous events and an AXEvidence value with optional fields; it has no reference to AppDelegate or presentation controllers. MonitoringCoordinator is the transitional app-facing extension applying existing guards/policy/effects. Background screenshot scheduling and completion remain adjacent there to preserve their shared placement/cache/request guards; task identity is owned by the monitor. Invocation-time view probing and calibration timers are deliberately outside continuous monitoring. Stage 9 reviews the remaining adapters and composition boundaries.
