# 1.1.13 / build 72 — focused candidate tests

Prior annotations are preserved verbatim in docs/1.1.12-TEST-RESPONSE.md. Main is untouched. Run only release/CameraReference Testing.app in this worktree; quit the previous copy first.

## Settings and metadata

- [ ] Developer tools is initially hidden. Settings → Advanced settings → showDeveloperTools = true → Save reveals it; false hides it again. Normal settings remain accessible.
- [ ] Existing config values survive the grouped layout; check its backup beside config.conf. Fresh defaults match the example. Editing a value still updates the relevant behaviour.
- [ ] Right-click the overlay and float for Canon CR3, Canon C-RAW and Sony ARW: grey picture-style line first, divider below, value agrees with the camera setting. Missing data shows Unavailable; the JPEG still loads.
- [ ] Keep the float on one photo and change the overlay photo; each menu retains its own style. Repeat with a warm cache and AX live refresh. Existing JPEG extraction/orientation and Save remain correct.

## Screenshot working-area reuse

- [ ] With reuse ON, detect a good area, change to the formerly failing photo without resizing/changing panels, then invoke. An inconclusive background check must retain the area; diagnostics distinguish retained/inconclusive from confirmed change.
- [ ] Move the window: reused area follows it. Resize or change panel/toolbar geometry: confirmed changes invalidate and subsequent invocation recalculates. Develop layout changes reuse equal panes; Library Loupe ↔ Compare recalculates.
- [ ] Clear overlay region setting forces detection without changing automatic/manual mode. Reuse OFF preserves earlier cache eligibility and inconclusive-check invalidation.

## Guided AX calibration (Developer tools)

Keep panel widths unchanged, use one display, and measure WORKING AREA including margins and both panes, excluding toolbars. Each row is independently retryable. Enable existing Screen Recording permission for Option-snapping; no prompt is issued by this guide.

- [ ] Setup 1: windowed Develop Loupe, all panels/toolbar shown. Select area, then actual PHOTO bounds at Fit using a matching untransformed photo. No crop/perspective edits.
- [ ] Setup 2: windowed Develop Loupe, all panels hidden, toolbar shown. Select area.
- [ ] Setup 3: same, toolbar hidden. Select area.
- [ ] Setup 4: windowed Develop Left/Right, all panels/toolbar shown. Select combined area.
- [ ] Setup 5: windowed Library Compare, all panels/toolbar shown. Select combined area.
- [ ] Setup 6: macOS full-screen Develop Loupe, all panels/toolbar hidden. Select area with the native title/menu bars retracted.
- [ ] Every Select hides the guide, shows 3–2–1 across Spaces, removes the badge before capture, and returns after selection. Escape during countdown/selection retains prior measurements. Hold Option to snap. Scrolling the guide exposes the full review/Apply controls on a smaller display.
- [ ] Deliberately misselect one row: red conflict identifies the related row; retry either without resetting others. Wrong setup, changed geometry during selection, or changed setup-1 geometry before photo measurement rejects it. Close/reopen retains measurements; Reset clears them.
- [ ] Review all 12 proposed values. Apply creates a backup, preserves unrelated values/comments, changes no manual region or auto/manual preference. An external config edit during the guide blocks Apply.
- [ ] Validate resulting Fit/placement in Loupe and both split orientations, Library split, panel/toolbar variations, resized windows and macOS full screen. Without recording permission, selection stays freehand with guidance and no prompt.

## Unchanged paths

- [ ] AX live/update-off behaviour, floating window, full-screen title-bar clipping and manual calibration still work. J/F and view shortcuts remain unchanged.
