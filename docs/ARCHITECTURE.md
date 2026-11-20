# Architecture and source map

Current candidate implementation: 1.1.9 (structure-migration; main remains 1.0.32). This is a map of the code as it exists, not a proposed refactor. Paths below are relative to the repository root. Contributor rules are in [AGENTS.md](../AGENTS.md); calculation rationale is in [METHODS.md](METHODS.md).

## Source ownership

| File under Sources/ | Owns / connects to |
|---|---|
| OverlayBehaviour.swift | Pure per-event decisions for geometry/photo changes, host movement/suspension, modules, Grid evidence and explicit selection. Original guards and action execution remain at callers. |
| AppSettings.swift | Existing preference-domain access for mode interpretation and startup defaults/legacy registration; no second store. |
| SettingsMenu.swift | Menu construction, references, refresh and validation; one current-view root with manual five-choice or inferred two-pane submenu (automatic Loupe has none). AppDelegate adapters retain action targets and event triggers. |
| Diagnostics.swift | DiagnosticsService owns report state/formatting/saving and diagnostic windows/previews. App-facing AppDelegate adapters retain existing collection/capture guards and scheduling; production AX observation and shared capture tasks remain outside the service. |
| main.swift | Composition/startup/shutdown, hotkeys, invocation entry points and contextual region preferences. Owns shared placement/cache/calibration operation state; keeps native selector/delegate identity. |
| SettingsActions.swift | Preference, backend, diagnostic-option and config-editor actions; no changes to settings storage or action policy. |
| ViewCoordinator.swift | Explicit pane choices, invocation-time AX inference and live view/photo geometry updates, including existing identity/generation guards. |
| CalibrationCoordinator.swift | Manual calibration preparation/accept/cancel/reset and failure prompts; uses existing CalibrationController and optional snapping. |
| ExportCoordinator.swift | Save eligibility, confirmation and asynchronous export completion for the invoking overlay/floating photo view. |
| PlacementCoordinator.swift / PlacementImplementations.swift | Manual/cache/backend routing and async completion guards; separate Manual/AX/original screenshot/assisted adapters with global-AppKit UIPlacement. |
| PhotoRequestCoordinator.swift / PhotoRequestPipeline.swift | Qualification/dispatch versus request transport, polling, cancellation, immutable load context and RAM image cache ownership. |
| LightroomMonitor.swift | Read-only observations, heartbeat/display timers, notification subscriptions, module freshness and monitoring state. Synchronous event signals and optional live AX evidence; no window mutations. |
| MonitoringCoordinator.swift | Existing eligibility/freshness guards and policy execution in tick order; background screenshot checks retain their original route. Addresses observation state on the monitor. |
| OverlayController.swift / FloatingDisplayController.swift | Independent displayed-window state owners: overlay host/lifecycle/identity versus floating panel/view/title/zoom. No timers or placement calculations. |
| PresentationCoordinator.swift | App-facing presentation and lifecycle coordination; existing guards, callbacks and ordering retained. Lifecycle/identity state is addressed directly on its owner; three panel/view aliases support existing optional bindings. |
| Core.swift | Protocol/source primitives, cancellation and extraction helpers. |
| ImageSource.swift | JPEG selection/extraction/orientation/decode, fingerprints and the one-selection RAM cache. |
| Export.swift | Display-specific JPEG snapshots and explicit safe export. |
| AXTrial.swift | Raw panel/label geometry, view classification, signed corrections and pane geometry shared by AX placement and preview. |
| AXAssisted.swift | Raw structural hints/signatures, independently maintained guided pixel search and placement preference resolution. |
| ScreenProbe.swift | Capture/normalisation and points-to-raster mapping; dispatch to original or assisted search; original split-margin scanner. |
| ViewportDetector.swift | Original Full UI rectangle evidence and raster boundary validation. Protected baseline for pure screenshot mode. |
| PhotoDetector.swift | Legacy/diagnostic photo-edge detection and fixtures, not the normal UI Fit calculation. |
| Layout.swift | Lightroom host metadata, coordinate conversion, bounded AX mapping/menu readers and lifecycle/overview evidence. |
| SplitLayout.swift | Pane geometry, floating half-viewport fit, placement memory and pure overlay action policies. |
| Interaction.swift | Navigation/display geometry and placement checks. |
| Views.swift | Photo view, overlay/floating panels, chrome, previews, diagnostics UI, toasts and menu diagrams. |
| Calibration.swift / Snapping.swift | Manual selection, optional pixel edge snapping and region clearing. |
| DetectionConfig.swift / ConfigEditor.swift | Advanced schema/parser/cache/migration and file-driven value editor. |
| Shortcut.swift / Permissions.swift | Shortcut recording and permission helpers. |

`CameraReference.lrplugin/` owns the Lua bridge, module heartbeat, request tokens and opaque selection revisions. `tests/` contains Swift behaviour/geometry/raster checks and Lua stand-ins. `tools/AXExplorer/` is an independent read-only investigation tool, not part of the shipped app.

## Placement precedence

```text
Invocation → bridge token/selection epoch → JPEG load or RAM hit
  ├─ Manual → saved region or calibration
  └─ Automatic
       ├─ Accessibility → AX map + toolbar + corrections → inferred pane → Fit
       └─ Screenshot → eligible cached bounds, otherwise capture
            ├─ assistance off → original Full detector → original divider scan
            └─ assistance on → raw AX hints → guided pixel search
                 → validated outer area → divider scan or assisted midpoint fallback
```

AX view inference is always enabled for Accessibility, independently optional for Screenshot. Screenshot assistance does not imply AX view inference. Manual placement overrides all of these. Missing AX geometry in Accessibility never triggers automatic screenshot capture. Explicit capture preview and permission-available calibration snapping are separate actions.

AX correction values do not enter screenshot search geometry/cache keys. Assisted results do not populate the original detector’s internal raster cache. Mode/selection/config changes prevent inappropriate placement-memory reuse.

## Display and update ownership

OverlayController owns the active panel and displayed host/layout/module/selection identity. FloatingDisplayController owns its independent panel/view. PhotoRequestPipeline owns transport/request state and the image cache; LightroomMonitor owns observation state and scheduling. AppDelegate remains the composition/coordinator surface for shared placement memory, calibration and operation IDs. Export uses the invoking overlay or floating window’s retained photo snapshot, not whichever file is currently selected in Lightroom.

| Event | Automatic Accessibility | Screenshot / manual |
|---|---|---|
| Photo selection | Update option on: load into existing panel at Fit; off: dismiss | Keep previous displayed photo |
| Inferred view / panel change | On: recalculate geometry, preserve photo/zoom; off: dismiss | Screenshot inference updates menus; pixel checks invalidate future placement only |
| Explicit view/pane selection | On: reposition; off: dismiss | Dismiss |
| Confirmed module change | Dismiss | Dismiss |
| Positive direct Library Grid mark | Dismiss/block invocation | No added AX Grid policy |
| Placement/read uncertainty | Retain existing reference | Retain existing reference |
| Off overlay | Never opened by monitoring | Never opened by monitoring |

The Grid policy is implemented but native selection-mark reliability remains an outstanding check. Missing marks/read errors are not proof of Grid. Manual geometry is not subject to AX live following.

## Timing and asynchronous guards

- The 0.2-second bridge/window maintenance loop observes module/selection and host state. It is not a screenshot loop.
- Eligible live AX view/panel reads run about every two seconds while Lightroom is active; menus change only when inference changes.
- Screenshot background validation defaults to three seconds (`panelCheckIntervalSeconds`), uses a 1280px-wide capture and invalidates reuse only. Zero disables this loop, not window tracking. Assisted mode retains it for measurement.
- Diagnostics gather bounded AX evidence after invocation when saving is enabled. Exhaustive tree exploration is kept out of the app.

Initial invocation uses request tokens, cancellation and selection epochs. Screen work uses inspection IDs/tasks; live view work uses probe IDs/generations; diagnostics have their own generation. Completions check relevant panel/host, module, selection, backend and preference state before applying. Explicit dismissal must defeat late completions. Failed selection refresh attempts are limited per epoch; failure retains the old photo without repeated calibration prompts. View/panel refresh preserves zoom, whereas a new image resets Fit.

Window movement translates known geometry. Suspension for minimise/overview/Space preserves content; it differs from dismissal, which releases the overlay. Host uncertainty is not a confirmed closure. See [METHODS.md](METHODS.md) for coordinate and ordering rules.

## Maintenance boundaries and risks

The coordinator files are extensions of the same AppDelegate. This is an intentional shared composition surface, not independent services with duplicate state. Native menu selectors/delegates and weak callback targets retain their identities. Concrete owners hold request, observation, presentation, menu and diagnostic state. Forty-two storage aliases were removed in stage 9; reads/writes now name their owner directly. Panel/request-handle aliases and diagnostic/menu adapters remain where they preserve local bindings or integrate native action targets.

Shared placement memory, capture/calibration tasks and invocation-view IDs remain on composition because foreground placement, explicit capture preview and calibration share cancellation rules. Splitting them into separate owners without a replacement lifetime contract could accept stale results or change cancellation order. These are explicit remaining dependencies, not a claim that every target component became an independent object. Do not introduce a second authoritative store.

To change update/dismiss policy, start in OverlayBehaviourPolicy, then check evidence qualification in MonitoringCoordinator and ViewCoordinator. To change calculations, use the specific placement implementation; preserve original screenshot versus assisted separation. Calibration prompts belong in CalibrationCoordinator; floating/overlay ordering belongs in PresentationCoordinator; extraction/format support belongs in ImageSource/Core. This keeps likely follow-up work local without unifying unrelated modes.

## Monitoring and performance boundary

The monitor emits tick, foreground, Space, display-change and delayed display-check events synchronously. MonitoringCoordinator reads selection/module/overview/geometry and applies effects in their original order rather than eagerly assembling a snapshot. Live AX workers return optional Grid/proposal/hint evidence on the existing main-queue handoff. Missing evidence is unknown; invocation-time AX inference remains on its separate ViewCoordinator request path.

Cadence remains 0.2 seconds for maintenance, 2 seconds for eligible live AX polls, 0.6 seconds for display-check debounce, 50 ms for bridge response polling, with a five-second request deadline. Background capture starts only after its original guards. No new capture, AX read, extraction, dispatch queue or display prerequisite was introduced by consolidation. Native ordering and latency cannot be certified by source equivalence or synthetic tests. Matched native timing samples remain pending; see [baseline protocol](migration/BASELINE.md).

The six known bugs/policy items remain in [BACKLOG.md](BACKLOG.md), not silently fixed by migration. Current validation and limitations are in [VALIDATION.md](VALIDATION.md); migration history and target deviations are in [final review](migration/FINAL-REVIEW.md) and [MIGRATION.md](../MIGRATION.md).
