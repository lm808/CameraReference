# Changelog

## 1.0.21 — Live AX view and complete diagnostics (candidate)

- Poll inferred AX view while Lightroom is active; update pane menus on changes only.
- Automatically collect full bounded AX diagnostics after invocation when report saving is enabled.

## 1.0.20 — Focused AX toolbar investigation (candidate)

- Added structural AX diagnostics to investigate overlooked toolbar containers or visibility state; no placement changes.

## 1.0.19 — AX investigation controls (candidate)

- Optional AX view classification feeds the existing capture detector; per-orientation pane selection remains available.
- Preview-only zero-default geometry adjustments and observed inline hints, compatible with the stable app’s shared config.
- Consolidated controls/parent diagnostics and opt-in latest report on disk instead of automatic clipboard copying.
- Existing working detector and stable staging remain unchanged; native acceptance pending.

## 1.0.18 — AX trial host coordinate correction (candidate)

Convert AX top-left host coordinates to AppKit before comparing with the overlay host. Previously the trial incorrectly rejected unchanged windows. Production host tracking and detection remain unchanged.

## 1.0.17 — show AX trial borders (candidate)

Explicitly show the trial child panels after attaching them to the normal overlay. Add per-border frame/visibility diagnostics. Normal detector unchanged; native confirmation pending.

## 1.0.16 — AX diagnostic trial (candidate)

Add independent single/split AX placement outlines, optional automatic diagnostic copying, and consolidated Accessibility/image inspection reporting. Production placement remains unchanged. Raw toolbar/margin corrections and native acceptance remain pending.

## 1.0.15 — Accessibility mapping diagnostics

Expand explicit Accessibility inspection with all returned AX window entries, available roles/state and precise rectangles, matching window-list metadata, and named display geometry/scales. Dedicated copyable diagnostic section; no placement or background-monitoring changes.

## 1.0.14 — raw preview

Allow diagnostic previews to show the original captured frame despite missing/inconsistent geometry or window movement. Do not crop/normalize independent-window previews. Overlay placement and snapping retain validation. Intermittent off-screen placement remains under investigation.

## 1.0.13 — diagnostic candidate

Preserve original capture errors, codes and geometry through the outer failure handler. Distinguish missing frame metadata, conversion failure, rejected geometry and failed image cropping. Capture previews reset stale performance timing. Off-screen placement remains unresolved pending this evidence; remaining minimise lingering accepted.

## 1.0.12 — testing candidate

Remember layout/pane per module without changing existing Develop settings. Normalize off-screen window capture using frame metadata before placement/snapping; preserve on-screen capture. Suspend an overlay when the presentation shrinks while AX layout stays fixed, in addition to minimise notifications. Native off-screen and minimise acceptance pending.

## 1.0.11 — testing candidate

Allow Library and Develop only; dismiss overlays and invalidate placement on module changes. Preserve separate module calibrations in the shared preferences file. Bridge 0.5.3 required. Search main/focused AX windows then all returned frames within a time budget instead of first 16. Library placement and native AX binding need acceptance.

## 1.0.10 — permission identification candidate

Give testing a distinct on-disk app/executable name and large T badge. Permission messages identify the running copy and request native access once per launch. Preserve shared settings and stable identity; no TCC reset. Ad-hoc signing remains and permission recovery needs native confirmation.

## 1.0.9 — testing candidate

Consolidate diagnostics into six selectable sections, remove duplicate timing and redundant monitoring action, and explain Develop-only capture. Restore off-screen detection/snapping with uncropped window capture. Prefer logical AX movement and settle resize/restoration geometry. Add purple, separately identified testing builds while preserving stable and shared preferences. Native acceptance pending.

## 1.0.8 — diagnostic candidate

Expose specific Accessibility permission/binding/notification failures and an explicit minimise-monitoring setup action. Retain an on-screen capture baseline alongside the latest preview. Reject known-unreliable fresh off-screen placement while preserving existing overlays and on-screen detection. Native comparison/notification timing remains unverified; main stays at 1.0.6.

## 1.0.7 — candidate

Add explicitly cropped window-only capture for off-screen windows, preserving contained-window capture. Add optional Accessibility minimise notifications, binding retries and common-mode lifecycle polling. Native acceptance pending.

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

## 1.0.22

- Inspect AXSections structure and element references in automatically saved toolbar diagnostics; no placement changes.

## 1.0.23 (candidate)

- Use AX View-menu toolbar visibility for experimental geometry only; assume shown on failed reads.
- Retain useful consolidated AX diagnostics; move deep exploration entirely into the build-only explorer.
- Preserve existing screenshot detection and personal geometry settings.

## 1.0.24 (candidate)

- Add independent experimental AX-only automatic placement, with no screenshot fallback or background captures.
- Add calibrated, configurable shown/hidden offsets using right/up-positive signs and cumulative bottom corrections; keep a separate Library allowance.
- Preserve screenshot detection, manual precedence, JPEG caching and the independent AX preview.

## 1.0.25 (candidate)

- Add a file-driven advanced config editor with editable values, comments, validation and external-edit protection.
- Include the +25 pt Library bottom correction only for split views. Preserve the existing screenshot detector.
