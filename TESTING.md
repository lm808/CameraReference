# 0.9.8 acceptance checklist

Quit the previous companion and open build/CameraReference.app. Confirm Camera Reference 0.9.8 at the top of its menu. No Lightroom plugin reinstall is needed. Keep your working configuration; use single-photo Develop at Fit for overlay checks. Unchecked items below require live user verification, even where automated tests passed.

## Priority 1 — current polish

- [ ] Menus: Automatic viewing area is in Settings with no experimental label. Development testing is gone; its commands and grey status line are in Developer tools. Settings has separators between display/source choices, shortcuts and configuration/maintenance. Edit config file opens the existing file.
- [ ] Floating toggle: Show floating display opens the selected photo. Zoom/pan it, then Hide and Show: the same photo, position and zoom should return without reloading. Select another Lightroom photo while hidden and verify it still retains the old photo until Reload or double-click.
- [ ] Floating size: close the floating window before checking initial size. A landscape photo should start at half the width and half the height of that photo fitted to the current display's available desktop area. The title bar is not part of the image dimensions. Portrait initial sizing should retain the previously accepted behaviour. Report if the desktop-based landscape size differs from the intended full-screen Lightroom-photo reference size.
- [ ] Shortcuts: overlay shortcut still toggles the overlay. Default floating shortcut Control–Option–Command–F toggles the floating display independently. Change each through its own Settings recorder; test Save, Cancel, Use Default and an unavailable/conflicting combination. Quit/reopen and verify both saved shortcuts persist.
- [ ] Trackpad: test both overlay and floating display. With the pointer over the image, pinch to zoom; once zoomed beyond Fit, use two-finger scrolling to pan. Test before and after clicking the image, including when Lightroom remains the active app. At Fit, bounded panning intentionally has no effect. Report which view/gesture/focus state fails. Command-scroll and click-drag should still work; double-click should reload and reset Fit.
- [ ] Privacy icon: quit and reopen System Settings, then inspect the existing Camera Reference entry under the relevant privacy permission. Check whether the camera icon appears. No permissions were reset; do not remove/re-add the entry merely for this test. Report the pane and icon shown if still missing.

## Priority 2 — speed evidence

- [ ] Invoke the overlay on a selected photo and immediately copy Developer tools → Bridge diagnostics. Record whether this was the first invocation after launching the companion and whether the source was standalone or embedded.
- [ ] Dismiss and invoke again on the same photo, without resizing Lightroom or changing its layout. Copy diagnostics again. A third sample is useful if timings vary greatly.
- [ ] If convenient, compare standalone-first and embedded-first on a photo with both available, recording the actual selected source/fallback rather than assuming the preference succeeded. Restore your usual preference afterwards.

Do not run Find viewing area or Preview captured Lightroom window before copying the overlay report: another inspection can replace the relevant sample. Send the full report, including Stage timing and Timing. These distinguish bridge, JPEG loading/extraction, enumeration, stability/configuration, capture, raster and detector time. Extraction is included in JPEG loading, so do not add it twice. Total-to-panel measures ordering the window, not completed GPU presentation. CPU benchmark results in PERFORMANCE.md do not establish the live bottleneck.

## Priority 3 — regression checks

- [ ] Normal/non-maximised window: invoke/dismiss; photo alignment should remain correct and not overlap Lightroom controls. Repeat on the external display if available, keeping the window wholly on one display.
- [ ] Full screen: enter, let the transition finish, invoke, then exit and invoke again. Check horizontal/vertical alignment.
- [ ] Resize: smaller, larger, then original size. Recovery should not require restarting Lightroom or clearing region data. Dismissal while the window moves/resizes is intentional.
- [ ] Narrow viewport: repeat the previously supplied 900 × 702 pt layout with sideSearchPercent = 45. The reference should fit the central viewport.
- [ ] Graceful interval failure: through Edit config file, set sideSearchPercent = 30 and invoke in that narrow layout. Expect “Working area too narrow for automatic placement—enlarge it or calibrate manually.” with Calibrate manually… and Cancel, and no overlay. Cancel/retry must preserve automatic mode. Also choose Calibrate manually… then Escape and check the same. Restore 45; detection should work on the next invocation without restart or cache reset.
- [ ] Successful manual calibration still switches to manual mode; re-enable Automatic viewing area afterwards if desired. A cancelled calibration preserves the previous region.
- [ ] Invalid configuration values retain the last valid settings and explain the error. Restore a valid file after this check.
- [ ] Genuine placement failures retain the failure message, never a misleading “Reference shown”.

If an overlay is offset, copy Bridge diagnostics immediately and include a screenshot with the overlay and one after dismissing it, without resizing/moving Lightroom. Panel visible=true alone does not prove correct alignment or visibility in the intended Space. No need to repeat every side combination or snapping test unless a regression appears.

## Split view — groundwork only, not enabled in 0.9.8

Do not expect automatic Reference/Before-After pane placement from this build. Geometry tests cover known left/upper panes, but live layout identification and divider evidence are still pending. Later evidence should identify separate left/right versus upper/lower layouts, Reference versus Before/After, and wipe layouts that must be rejected. See SPLIT-VIEW.md. No split-view acceptance is claimed here.
