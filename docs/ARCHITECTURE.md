# Architecture and source map

Current implementation: 1.0.32. This is a map of the code as it exists, not a proposed refactor. Paths below are relative to the repository root. Contributor rules are in [AGENTS.md](../AGENTS.md); calculation rationale is in [METHODS.md](METHODS.md).

## Source ownership

| File under Sources/ | Owns / connects to |
|---|---|
| main.swift | AppDelegate: menus/preferences, bridge request pipeline, cache ownership, mode dispatch, calibration, timers, diagnostics and overlay lifecycle. Coordinates all paths below. |
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

AppDelegate owns the active overlay, request state, image/placement caches and work generations. A floating display owns its image independently. Export uses the displayed photo’s retained snapshot, not whichever file is currently selected in Lightroom.

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

Calculation modules are reasonably isolated, especially original versus assisted screenshot detection. Coordination is less separated: main.swift is roughly one third of the Swift source and combines menus, reporting, timers and lifecycle. Mode decisions and asynchronous guards occur in several paths rather than one state machine. Tests cover many pure helpers, but cannot prove native permission/menu/capture behaviour or every event sequence.

Future structural work should extract diagnostics/menu ownership, centralise update policy, and add sequence tests for selection/view/module/dismiss races before changing orchestration. This documentation update performs no refactor. Preserve the original detector and keep new experiments independently selectable.
