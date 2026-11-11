# Changelog

## 1.0.6 — candidate

Dismiss the overlay on a confirmed switch to Library, cancelling pending overlay loading. Preserve the floating display and retention through uncertain module/heartbeat state. Returning to Develop does not automatically reopen it.

## 1.0.5 — candidate

Remove icon parentheses; separate Fit geometry from the whole-region zoom/pan boundary. Add ARW embedded JPEG selection across JpgFromRaw/PreviewImage while retaining the CR3 path. Supplied ARW passed read-only extraction/export checks. Off-screen capture and minimise reliability remain deferred.

## 1.0.4 — candidate

Yield floating level to Lightroom dialogs, add host visibility/minimise checks and ignore thumbnail geometry during movement. Use existing Accessibility permission for direct state checks with window-list fallback. Shorten calibration instructions with current layout/pane/mode. Preserve the user’s 1.0.3 results. Native acceptance pending.

## 1.0.3 — candidate

Float the overlay while Lightroom is active; lower it and restore normal host-relative ordering when another app activates. Avoid periodic reordering while floating. Add level-change diagnostics. Native clicks, zoom/pan, dialogs and app-switch acceptance pending.

## 1.0.2 — candidate

Skip zero-distance window moves and tolerate intervening Lightroom-owned windows instead of forcing adjacency every timer tick. Preserve other apps’ window precedence; add maintenance counters to diagnostics. New/missing config defaults use sideSearchPercent 40, preserving explicit values. Built in a separate testing worktree; native flicker acceptance pending.

## 1.0.1

Keep overlays visible through uncertain placement; unify storage under CameraReference with conflict-preserving merge; add incremental release/ staging and patch/minor/major version rules. Bridge 0.5.2 required. No DMG packaged.

Require Dock activation as well as screen-sized presentation evidence before overview suppression. A permanent full-screen Dock surface must not hide ordinary overlays. Add visibility reasons to Bridge diagnostics. Native overview acceptance remains pending.

Correct fresh/missing config defaults to sideSearchPercent 30 and all four UI bounds. Preserve explicit saved values; align the example and agent instructions with the accepted settings.

## 1.0 alpha 2

Consolidate Application Support under Camera Reference, with Bridge subfolder and required bridge 0.5.1. Preserve the inactive legacy folder as a unique backup, defer while its heartbeat is active, and never replay stale IPC. GUI preferences remain in macOS Preferences.

## 1.0 alpha

- Retain overlay state during temporary overview/Space/minimisation suspension; restore to the same unchanged Lightroom window when eligible.
- Allow placed overlays to follow partially off-screen movement with clipping.
- Rename advanced configuration to config.conf with non-destructive migration. GUI preferences/calibration remain in macOS preferences.
- Add native-architecture DMG packaging and a user-local Lightroom bridge installer.
- Replace historical README content with usage/installation documentation; consolidate methods, agent instructions, validation and backlog.

## 0.9.15

- Use Full detection for combined split viewport; scan the bottom inset for side-by-side and left inset for stacked panes.
- Tolerate short divider endpoint gaps. User verified all panes/orientations with sideSearchPercent30.

## 0.9.14

- Attempted split-boundary and overview changes. Split method regressed and was replaced in0.9.15; not a recommended detector baseline.

## 0.9.13

- Add configurable3-second/disabled background checks and lower-resolution validation.
- Follow ordinary Lightroom movement; improve hover/icon handling and menu-guided split search.

## 0.9.10–0.9.12

- Add current-selection RAM image caching and placement reuse.
- Add explicit split menus, independent floating display controls, revised sizing and Lightroom-relative overlay ordering.

## Earlier development

- Introduce read-only JPEG source selection/extraction, explicit export, manual calibration/snapping, single-photo UI-boundary detection and diagnostics.

Detailed findings and accepted results are in docs/VALIDATION.md, not this user-facing log.
