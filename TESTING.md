# Camera Reference 1.0.32 — candidate

Run `release/CameraReference Testing.app` in `worktrees/ax-assisted-screenshot-detection`. Main remains 1.0.28. Previous user annotations are retained in docs/VALIDATION.md (trailing whitespace normalised). Automated checks do not replace native acceptance.

## Grid and dismissal option

- [ ] Settings → Dismiss overlay when view changes is in its own section after Choose ExifTool, initially off, and persists after restart. Turning it on does not dismiss the current overlay immediately.
- [ ] With it off, existing live/manual view following still works. With it on, changes between Loupe, Left/Right and Top/Bottom dismiss an open overlay. Test AX mode, screenshot + AX view detection, and manual screenshot view selection. Pane-only changes still move the overlay.
- [ ] In Library, show an overlay then switch to Grid: AX mode and screenshot + AX view detection dismiss within the normal poll interval. Returning to Loupe does not reopen it. Invocation in Grid is blocked when auto placement and AX view detection are enabled.
- [ ] Screenshot without AX view detection does not monitor Grid. Module switches still dismiss in all modes. No view/pane action opens an off overlay.
- [ ] Diagnostics → Grid view & view-change policy reports the menu mark. If Lightroom exposes an incomplete View menu after losing/regaining focus, the result is unknown and does not falsely dismiss the overlay. Native confirmation of the selected mark is required.

## Live view/pane checks carried forward

- [ ] With an overlay on, Accessibility mode follows Loupe ↔ left/right ↔ top/bottom view changes within the same module, after the existing two-second check. Preferred pane is respected.
- [ ] Screenshot + AX view detection does the same, with AX assistance both on and off. Without AX view detection, changing the menu view updates the overlay.
- [ ] In every placement method, selecting the other pane moves the open overlay. Repeated rapid choices leave it on the last selection. Image and zoom are retained; panning remains constrained to the new area.
- [ ] With the overlay off, changing views or menu panes never opens it. Manual calibration remains unchanged. Switching Lightroom module turns an open overlay off.
- [ ] Dismiss during calculation, change photo/module, or temporarily lose capture access: no stale result reopens/replaces the overlay. A failed placement keeps the existing overlay without a calibration prompt. Detected-view updates can retry on the next poll.

## 1.0.30 checks still awaiting native acceptance

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
