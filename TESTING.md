# Camera Reference 1.0.33 candidate — remaining checks

The 1.0.32 baseline was merged to main at the user’s request; this 1.0.33 candidate is not merged. Unchecked baseline items below remain outstanding; earlier merge acceptance does not mark them passed. Previous user annotations are retained in docs/VALIDATION.md (trailing whitespace normalised). Automated checks do not replace native acceptance.

## Stage 2 candidate acceptance

Run only this worktree’s `release/CameraReference Testing.app` (1.0.33); quit the stable app first. Main’s accepted 1.0.32 app remains unchanged. No native acceptance is claimed yet.

- [ ] Default Accessibility overlay: invoke, toggle off/on, change photo/view/pane/panels; behaviour and responsiveness match 1.0.32. Float remains unchanged.
- [ ] Diagnostics opens with the same sections/content. With saving enabled, invocation refreshes `Diagnostics/latest.txt`; saving disabled does not write it. A previous placement failure remains in its separate section.
- [ ] AX boundary preview follows existing show/hide/suspension behaviour. Dismiss during collection: no late border appears on a new/off overlay.
- [ ] If Screen Recording is already granted, explicit capture preview and retained baseline still open/close/compare as before. No automatic screenshot is introduced in AX placement. Without permission, existing guidance remains.
- [ ] Compare matched timings with 1.0.32 using the baseline protocol below; record differences without trying to fix existing edge cases here.

## Structure migration baseline

Stage 1 adds an isolated coordinator harness to `bash test.sh`; it does not deliver a new app. Existing native checks and annotations below remain unchanged. Before comparing the first migrated candidate, collect matched stable-app timings following [the baseline protocol](docs/migration/BASELINE.md). Native timing samples are still pending; automated checks cannot certify display latency or window lifecycle behaviour.

## AX-only overlay updates

- [ ] Accessibility shows only the indented **Update overlay with LrC view** option beneath Detection method, default on. Screenshot shows only AX view detection and AX-assisted placement. Switching methods remembers preferences; manual placement disables detection controls.
- [ ] **Update overlay with LrC view** on: an open overlay follows Loupe/split view, chosen pane, and surrounding panel/toolbar visibility or size changes. Same photo and zoom remain; an off overlay stays off.
- [ ] **Update overlay with LrC view** off: those same view, pane and panel changes dismiss. Toggling the setting alone does not dismiss. Test toolbar and filmstrip independently.
- [ ] Grid diagnostics list only the direct View → Grid command, excluding Loupe Overlay → Grid. Test Grid selected and Loupe selected, with the Loupe grid overlay both on and off. Missing selection marks must remain unknown.
- [ ] AX Library Grid always dismisses and blocks invocation, regardless of the update option. Returning to Loupe stays off. Incomplete menu evidence does not falsely dismiss. Module changes dismiss in all modes.
- [ ] Screenshot backup modes: detected views update the menu but leave an open overlay alone; panel checks invalidate cache only. Explicit menu view/pane selection dismisses as before. No AX live update/Grid policy applies.
- [ ] Repeated photo edits/clicks cause no unnecessary movement. Move Lightroom without changing panels: translation follows without dismissal. Failed AX placement retains the overlay; rapid changes, selection/module changes and explicit dismissal reject stale results.
- [ ] Manual calibration and floating display retain their photo until explicitly reloaded/reopened. Test AX panel updates after a successful photo refresh and after a failed refresh retaining the previous photo.

## Photo-selection usability checks — same version

- [ ] Accessibility → Update overlay with LrC view: on refreshes an open overlay to the new selection at Fit (portrait/landscape, embedded/standalone). Off dismisses on selection change. Toggling the option alone does nothing.
- [ ] Rapidly step through several photos, dismiss during loading, or switch module: no late photo appears or reopens the overlay. Grid still dismisses.
- [ ] Missing/unreadable JPEG keeps the old photo without repeated requests or calibration dialogs. A later selection refreshes normally. Export refers to the newly displayed photo after success.
- [ ] Screenshot modes and manual placement retain their previous selection behaviour. With overlay off, selection never opens it. Floating display is unaffected.

## Settings and screenshot backup checks

- [ ] Settings follows the agreed groups, with Advanced settings last. Detection method shows its current choice; manual mode disables that section. Accessibility hides the two indented screenshot options; switching back remembers their preferences. AX preview remains independent in Developer tools.
- [ ] View menus and calibration instructions use Loupe View, Reference View (Left/Right), and Reference View (Top/Bottom), without an AX suffix.
- [ ] Without Screen Recording permission: calibration allows free dragging, explains optional snapping, and does not request permission. Instructions wrap and fit the screen. Capture preview reports missing permission gracefully; an existing overlay stays open.
- [ ] AX-assisted screenshot: Library side-by-side with Embedded Preview labels in both panes; verify the outer top/bottom and both pane choices. Repeat without labels and with toolbar hidden. Diagnostics identify a detected divider or a 50/50 fallback; fallback requires a validated outer area.
- [ ] A failed invocation saves its failure before the calibration dialog when automatic diagnostic saving is enabled. Cancelling preserves mode/region; subsequent success retains a separately labelled failure snapshot. Off-screen guidance is conditional wording, not a claim that all failures need a restart.
- [ ] AX-only and pure screenshot placement still behave as before. Test usual overlay/float invocation and repeated toggles. In Screenshot mode test all four AX view detection / AX-assisted placement on/off combinations, including remembered menu choices and no Accessibility permission.

## Deferred to-dos

- [ ] Measure retained background screenshot checks during ordinary assisted use before deciding whether to disable them.
- [ ] Test toolbarUnknownFallback: shown, hidden, lastKnown; lastKnown should use same-module/process history, or shown without history.
- [ ] Broader AX edge cases during normal use: hidden-panel combinations, both split orientations/panes, minimum and larger windows, displays. Minimum-window AX placement already passed in 1.0.28.
- [ ] Investigate pure screenshot Library split failure associated with Embedded Preview text, and Develop side-by-side with right panel hidden. Confirm the cause before a separately authorised detector fix; this update preserves that path.
- [ ] Collect diagnostics/raw preview for intermittent oversized off-screen captures; restarting Lightroom has cleared the issue, but no capture fix is claimed here.
