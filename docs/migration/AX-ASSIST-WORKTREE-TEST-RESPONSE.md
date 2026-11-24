# Camera Reference 1.0.32 — remaining checks

Merged to main at the user’s request. Run `release/CameraReference.app` from the main checkout. Unchecked items below remain outstanding; merge acceptance does not mark them passed. Previous user annotations are retained in docs/VALIDATION.md (trailing whitespace normalised). Automated checks do not replace native acceptance.

## AX-only overlay updates

- [x ] Accessibility shows only the indented **Update overlay with LrC view** option beneath Detection method, default on. Screenshot shows only AX view detection and AX-assisted placement. Switching methods remembers preferences; manual placement disables detection controls.
- [Generally updates correctly. If resize too fast then overlay will not follow correctly ] **Update overlay with LrC view** on: an open overlay follows Loupe/split view, chosen pane, and surrounding panel/toolbar visibility or size changes. Same photo and zoom remain; an off overlay stays off.
- [x, Dissmissal is reluctant. If resized, it will attempt to follow but then dismisses. ] **Update overlay with LrC view** off: those same view, pane and panel changes dismiss. Toggling the setting alone does not dismiss. Test toolbar and filmstrip independently.
- [x ] Grid diagnostics list only the direct View → Grid command, excluding Loupe Overlay → Grid. Test Grid selected and Loupe selected, with the Loupe grid overlay both on and off. Missing selection marks must remain unknown.
- [x ] AX Library Grid always dismisses and blocks invocation, regardless of the update option. Returning to Loupe stays off. Incomplete menu evidence does not falsely dismiss. Module changes dismiss in all modes.
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
