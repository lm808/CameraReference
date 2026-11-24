# Architecture and source map

Current accepted main: 1.1.16 / build 75. The completed native checklist is preserved in [1.1.16 test response](1.1.16-TEST-RESPONSE.md). This is a map of the code as it exists, not a proposed refactor. Paths below are relative to the repository root. Contributor rules are in [AGENTS.md](../AGENTS.md); calculation rationale is in [METHODS.md](METHODS.md).

## Required contributor contract

Both humans and agents must follow [CONTRIBUTING-STRUCTURE.md](CONTRIBUTING-STRUCTURE.md). These ownership boundaries are a maintenance contract: do not bypass them with UI side effects, copied policies or misleading flags. Keep new behaviours local to their owner and check neighbouring paths.

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
| AXCalibration.swift / AXCalibrationCoordinator.swift | Pure signed offset recovery and a separate guided Developer tools workflow: confirmed AX evidence, reused rectangle selector, consistency/review/backup/conflict checks. No manual-region preference changes. |
| ShortcutSettings.swift / ViewShortcuts.swift | Transactional shortcut editing and guarded view-action dispatch through selectLayout; menu and shortcut paths share behaviour. |
| CalibrationCoordinator.swift | Manual calibration accept/cancel/reset and failure prompts; shared selector preparation supplies optional snapping to both manual and guided workflows. |
| ExportCoordinator.swift | Save eligibility, confirmation and asynchronous export completion for the invoking overlay/floating photo view. |
| PlacementCoordinator.swift / PlacementImplementations.swift | Manual/cache/backend routing and async completion guards; separate Manual/AX/Screenshot adapters with global-AppKit UIPlacement. |
| PhotoRequestCoordinator.swift / PhotoRequestPipeline.swift | Qualification/dispatch versus request transport, polling, cancellation, immutable load context and RAM image cache ownership. |
| LightroomMonitor.swift | Read-only observations, heartbeat/display timers, notification subscriptions, module freshness and monitoring state. Synchronous event signals and optional live AX evidence; no window mutations. |
| MonitoringCoordinator.swift | Existing eligibility/freshness guards and policy execution in tick order; background screenshot checks retain their original route. Addresses observation state on the monitor. |
| OverlayController.swift / FloatingDisplayController.swift | Independent displayed-window state owners: overlay host/lifecycle/identity versus floating panel/view/title/zoom. No timers or placement calculations. |
| PresentationCoordinator.swift | App-facing presentation and lifecycle coordination; existing guards, callbacks and ordering retained. Lifecycle/identity state is addressed directly on its owner; three panel/view aliases support existing optional bindings. |
| Core.swift | Protocol/source primitives, cancellation and extraction helpers. |
| ImageSource.swift | JPEG selection/extraction/orientation/decode, optional camera-style metadata, fingerprints and the one-selection RAM cache. |
| Export.swift | Display-specific JPEG snapshots and explicit safe export. |
| AXTrial.swift | Raw panel/label geometry, view classification, signed corrections and pane geometry shared by AX placement and preview. |
| AXPanelState.swift / PlacementMode.swift | Preserved panel-change signature for view monitoring, and two-backend preference resolution; no AX-guided pixel search. |
| ScreenProbe.swift | Capture/normalisation and points-to-raster mapping; one pixel-only outer search and equal split selection. |
| ViewportDetector.swift | Pixel-only Full UI rectangle evidence, thin-frame-tolerant surround validation and raster cache; no calibrated AX input. |
| PhotoDetector.swift | Legacy/diagnostic photo-edge detection and fixtures, not the normal UI Fit calculation. |
| Layout.swift | Lightroom host metadata, coordinate conversion, bounded AX mapping/menu readers and lifecycle/overview evidence. |
| SplitLayout.swift | Pane geometry, floating half-viewport fit, placement memory and pure overlay action policies. |
| Interaction.swift | Navigation/display geometry and placement checks. |
| Views.swift | Photo view, overlay/floating panels, chrome, previews, diagnostics UI, toasts and menu diagrams. |
| Calibration.swift / Snapping.swift | Reusable rectangle/cancellation UI and optional edge snapping. Callers own persistence and interpretation. |
| DetectionConfig.swift / ConfigEditor.swift | Advanced schema/parser/cache/migration and file-driven value editor. |
| Shortcut.swift / ShortcutSettings.swift / ViewShortcuts.swift | Recording widget, transactional shortcut settings, keypad aliases and guarded dispatch through existing view actions. |
| Permissions.swift | Feature-specific permission checks/prompts. |
| AXCalibration.swift / AXCalibrationCoordinator.swift | Pure geometry/conflict calculations and the independently retryable measurement/review/save workflow. |

`CameraReference.lrplugin/` owns the Lua bridge, module heartbeat, request tokens and opaque selection revisions. `tests/` contains Swift behaviour/geometry/raster checks and Lua stand-ins. `tools/AXExplorer/` is an independent read-only investigation tool, not part of the shipped app.

## Placement precedence

```text
Invocation → bridge token/selection epoch → JPEG load or RAM hit
  ├─ Manual → saved region or calibration
  └─ Automatic
       ├─ Accessibility → AX map + toolbar + corrections → inferred pane → Fit
       └─ Screenshot → eligible cached bounds, otherwise capture
            → pixel-validated Full outer bounds (wider side retry if needed)
                 → Loupe or 50/50 selected pane → Fit
```

AX view inference is always enabled for Accessibility, independently optional for Screenshot. Screenshot placement never consumes AX panel edges. Manual placement overrides all of these. Missing AX geometry in Accessibility never triggers automatic screenshot capture. Explicit capture preview and permission-available calibration snapping are separate actions.

AX correction values do not enter screenshot search geometry/cache keys. The raster cache stores the full outer area for both Loupe and split callers; splitting happens afterwards. The default-on developer reuse option lets placement memory reconstruct the combined area and derive the selected pane, with AppKit vertical orientation respected. It survives photo changes and movement; Develop permits all layout choices while Library Loupe/Compare transitions invalidate it. Module/config/display/host-size and background-validation guards remain. Off restores same-photo/same-pane placement and Loupe-only raster reuse. Settings are interpreted in AppSettings and passed as explicit cache inputs; detectors never read preferences.

## Display and update ownership

OverlayController owns the active panel and displayed host/layout/module/selection identity. FloatingDisplayController owns its independent panel/view. PhotoRequestPipeline owns transport/request state and the image cache; LightroomMonitor owns observation state and scheduling. AppDelegate remains the composition/coordinator surface for shared placement memory, calibration and operation IDs. Export uses the invoking overlay or floating window’s retained photo snapshot, not whichever file is currently selected in Lightroom.

| Event | Automatic Accessibility | Automatic Screenshot + AX view detection | Screenshot without inference / manual |
|---|---|---|---|
| Photo selection | Update on: reload at Fit; off: dismiss | Dismiss | Screenshot: dismiss; manual: keep previous photo |
| Inferred view / panel change | On: reposition preserving zoom; off: dismiss | Dismiss on confirmed change | Retain; screenshot checks invalidate cache |
| Explicit view/pane selection | On: reposition; off: dismiss | Dismiss | Existing dismissal behaviour |
| Confirmed module change | Dismiss | Dismiss | Dismiss |
| Positive direct Library Grid mark | Dismiss/block invocation | Dismiss/block invocation | No added Grid policy |
| Placement/read uncertainty | Retain | Retain | Retain |
| Off overlay | Never opened by monitoring | Never opened by monitoring | Never opened by monitoring |

The Grid policy is implemented but native selection-mark reliability remains an outstanding check. Missing marks/read errors are not proof of Grid. Manual geometry is not subject to AX live following.

## Timing and asynchronous guards

- The 0.2-second bridge/window maintenance loop observes module/selection and host state. It is not a screenshot loop.
- Eligible live AX view/panel reads run about every two seconds while Lightroom is active; menus change only when inference changes.
- Screenshot background validation defaults to three seconds (`panelCheckIntervalSeconds`), uses a 1280px-wide capture and invalidates reuse only. Zero disables this loop, not window tracking. AX-only does not use this capture loop.
- Diagnostics gather bounded AX evidence after invocation when saving is enabled. Exhaustive tree exploration is kept out of the app.

Initial invocation uses request tokens, cancellation and selection epochs. Screen work uses inspection IDs/tasks; live view work uses probe IDs/generations; diagnostics have their own generation. Completions check relevant panel/host, module, selection, backend and preference state before applying. Explicit dismissal must defeat late completions. Failed selection refresh attempts are limited per epoch; failure retains the old photo without repeated calibration prompts. View/panel refresh preserves zoom, whereas a new image resets Fit.

Window movement translates known geometry. Suspension for minimise/overview/Space preserves content; it differs from dismissal, which releases the overlay. Host uncertainty is not a confirmed closure. See [METHODS.md](METHODS.md) for coordinate and ordering rules.

## Maintenance boundaries and risks

The coordinator files are extensions of the same AppDelegate. This is an intentional shared composition surface, not independent services with duplicate state. Native menu selectors/delegates and weak callback targets retain their identities. Concrete owners hold request, observation, presentation, menu and diagnostic state. Forty-two storage aliases were removed in stage 9; reads/writes now name their owner directly. Panel/request-handle aliases and diagnostic/menu adapters remain where they preserve local bindings or integrate native action targets.

Shared placement memory, capture/calibration tasks and invocation-view IDs remain on composition because foreground placement, explicit capture preview and calibration share cancellation rules. Splitting them into separate owners without a replacement lifetime contract could accept stale results or change cancellation order. These are explicit remaining dependencies, not a claim that every target component became an independent object. Do not introduce a second authoritative store.

To change update/dismiss policy, start in OverlayBehaviourPolicy, then check evidence qualification in MonitoringCoordinator and ViewCoordinator. To change calculations, use the specific placement implementation; preserve independent AX versus pixel placement. Calibration prompts belong in CalibrationCoordinator; floating/overlay ordering belongs in PresentationCoordinator; extraction/format support belongs in ImageSource/Core. This keeps likely follow-up work local without unifying unrelated modes.

## Monitoring and performance boundary

The monitor emits tick, foreground, Space, display-change and delayed display-check events synchronously. MonitoringCoordinator reads selection/module/overview/geometry and applies effects in their original order rather than eagerly assembling a snapshot. Live AX workers return optional Grid/proposal/hint evidence on the existing main-queue handoff. Missing evidence is unknown; invocation-time AX inference remains on its separate ViewCoordinator request path.

Cadence remains 0.2 seconds for maintenance, 2 seconds for eligible live AX polls, 0.6 seconds for display-check debounce, 50 ms for bridge response polling, with a five-second request deadline. Background capture starts only after its original guards. No new capture, AX read, extraction, dispatch queue or display prerequisite was introduced by consolidation. Native ordering and latency cannot be certified by source equivalence or synthetic tests. Matched native timing samples remain pending; see [baseline protocol](migration/BASELINE.md).

The six deferred bugs/policy items were subsequently fixed and accepted in 1.1.10; broader outstanding work remains in [BACKLOG.md](BACKLOG.md). Current validation and limitations are in [VALIDATION.md](VALIDATION.md); migration history and target deviations are in [final review](migration/FINAL-REVIEW.md) and [MIGRATION.md](../MIGRATION.md).

## Post-migration presentation corrections

Confirmed native full-screen hosts use normal-level relative ordering above Lightroom. Windowed/unknown hosts retain the active floating-level policy. LightroomHostAccessibility retains the last explicit AXFullScreen reading through transient failures.

For full-screen title-bar reveal, Layout.swift identifies the shared AX parent of named close/zoom controls and correlates its measured frame to a same-PID CG window. The cached CG identity follows animation; all-window metadata includes the hidden bar. The existing maintenance tick samples this evidence. PresentationCoordinator applies a top mask through OverlayPanel.clipTop in Views.swift; frame, image viewport and navigation transform remain unchanged. Explicit hidden/windowed evidence clears the mask; unknown evidence retains it. AX preview borders share clipping; floating references do not. Failed companion/top-chrome relative-ordering workarounds were removed. Native tests passed; the slight polling delay is accepted.

AXTrialPanel shares production frame constraints and cannot become key. FloatingPanel applies its higher presentation level after floating-panel configuration, with managed Mission Control participation. Floating click/invocation ordering tests passed.

### Opt-in window-order recording

`WindowOrderDiagnostics.swift` owns a bounded five-second-delay/fifteen-second trace, started only by the developer menu. It samples CG metadata and existing AppKit/cached AX state on the main run loop every 100 ms, observes own-window focus notifications, and accepts observational action markers from PresentationCoordinator. It never captures pixels, reads new AX geometry, activates an app or orders a window. Disk output is asynchronous and separate from latest.txt. When inactive, action messages are not evaluated and there is no recording timer. Reports retain all owners without window titles, and identify our overlay/floating/border/host IDs.

## Guided calibration boundary

The existing CalibrationController returns a global AppKit rectangle or cancellation. Manual CalibrationCoordinator saves a region and switches auto placement off; AXCalibrationCoordinator instead converts the rectangle to top-left points and collects it with raw AX evidence. AXCalibrationPlan calculates twelve replacements from six working-area observations and one photo rectangle; it checks repeated edges and reports the conflicting setup numbers. ConfigEditorDocument validates/preserves the file and refuses external-edit conflicts; the coordinator creates a backup and saves only after explicit review. AXTrial exposes AXRawGeometry through axRawGeometry, the single raw panel/label classifier. The guide reads it directly; axTrialProposal applies production corrections and validation afterward. Placement arithmetic is unchanged. The guide keeps hidden base insets fixed, calibrates full-screen allowance and photo Fit inset and uses the shared permission-gated, in-memory edge capture only for Option snapping. `prepareCalibrationSelection` owns preparation and its timeout; each workflow owns completion and cancels its preparation when finished or closed. The selector still returns coordinates without deciding how to save them.


### 1.1.13 ownership additions

`ImageSource` reads optional Canon/Sony style metadata (bounded, cancellation-aware ExifTool request) and stores it in `LoadedReference`. The RAM cache retains that value. Existing request/placement completions carry it through their stale-result guards to `ReferenceView`, which owns only the displayed value and renders a disabled menu line. No global current-photo metadata, no reads from a context menu, and no changes to extraction/placement mathematics. Optional metadata failures do not discard a valid JPEG.

`SelectionCountdown` is presentation-only: shows the delay on available displays, handles Escape, removes its panels before completion. `AXCalibrationCoordinator` owns independent measurement slots, captures before/after evidence, ignores stale generations, cancels shared selector preparation on close, validates through the pure plan, and owns review/backup/apply. The full-screen observation passes zero allowance into a local settings copy to measure the allowance rather than reuse the old answer; production settings are never changed during measurement. The photo and setup-1 area must share the same host/panel geometry.

`DetectionConfig` owns the default-hidden developer flag and config layout. SettingsMenu owns visibility; SettingsActions/menu refresh applies changes without rebuilding menus. One-time config organization preserves assignments/inline comments, retains deduplicated standalone notes and backs up the old file. `invalidateScreenshotArea` expresses the narrow expanded-reuse exception for inconclusive checks; MonitoringCoordinator retains all existing observation identity guards.

PresentationCoordinator binds an overlay-only host-activation callback on the shared ReferenceView. The view forwards interactive left-clicks; the coordinator validates current panel identity and activates Lightroom. No placement, ordering policy, timers or app lookup are added to the view. Guided calibration row alignment remains presentation-only.

## Boundary audit status

The [2026-11-24 audit](BOUNDARY-AUDIT.md) reviewed this branch through 1.1.15. Primary boundaries remain intact; its two findings are fixed in 1.1.16: raw calibration reads the shared AXRawGeometry before correction validation, and snapping permission guidance consumes ScreenProbeResult.failureReason rather than diagnostic text. Native confirmation is tracked in TESTING.md. Shared Fit settings intentionally affect both backends after guided calibration; AX-only geometric corrections do not.
