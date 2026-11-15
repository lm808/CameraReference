# Camera Reference 1.0.30 — candidate

Run `release/CameraReference Testing.app` in `worktrees/ax-assisted-screenshot-detection`. Main remains 1.0.28. Previous user annotations are retained in docs/VALIDATION.md (trailing whitespace normalised). Automated checks do not replace native acceptance.

## This update

- [ ] Settings follows the agreed groups, with Advanced settings last. Detection method shows its current choice; manual mode disables that section. Accessibility disables the two indented screenshot options; switching back remembers their preferences. AX preview remains independent in Developer tools.
- [ ] View menus and calibration instructions use Loupe View, Reference View (Left/Right), and Reference View (Top/Bottom), without an AX suffix.
- [ ] Without Screen Recording permission: calibration allows free dragging, explains optional snapping, and does not request permission. Instructions wrap and fit the screen. Capture preview reports missing permission gracefully; an existing overlay stays open.
- [ ] AX-assisted screenshot: Library side-by-side with Embedded Preview labels in both panes; verify the outer top/bottom and both pane choices. Repeat without labels and with toolbar hidden. Diagnostics identify a detected divider or a 50/50 fallback; fallback requires a validated outer area.
- [ ] A failed invocation saves its failure before the calibration dialog when automatic diagnostic saving is enabled. Cancelling preserves mode/region; subsequent success retains a separately labelled failure snapshot. Off-screen guidance is conditional wording, not a claim that all failures need a restart.
- [ ] AX-only and pure screenshot placement still behave as before. Test usual overlay/float invocation and repeated toggles. Main's stable app remains unchanged.

## Deferred to-dos

- [ ] Measure retained background screenshot checks during ordinary assisted use before deciding whether to disable them.
- [ ] Test toolbarUnknownFallback: shown, hidden, lastKnown; lastKnown should use same-module/process history, or shown without history.
- [ ] Broader AX edge cases during normal use: hidden-panel combinations, both split orientations/panes, minimum and larger windows, displays. Minimum-window AX placement already passed in 1.0.28.
- [ ] Investigate pure screenshot Library split failure associated with Embedded Preview text, and Develop side-by-side with right panel hidden. Confirm the cause before a separately authorised detector fix; this update preserves that path.
- [ ] Collect diagnostics/raw preview for intermittent oversized off-screen captures; restarting Lightroom has cleared the issue, but no capture fix is claimed here.
