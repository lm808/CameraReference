# Camera Reference Testing 1.0.18 — AX diagnostic trial

Run this worktree's `release/CameraReference Testing.app`, with bridge 0.5.3. Quit the stable app first; both share settings. Main and its staged 1.0.15 app are unchanged. No new bridge required.

- [ ] With AX preview enabled, invoke and confirm coloured borders actually appear. An unchanged host must no longer be rejected because its AX and AppKit y coordinates differ. Copy the **AX placement trial** section: it now reports each border’s actual frame and visibility.
- [ ] With both new developer options off, confirm ordinary overlay placement, repeated toggles and manual calibration behave as before.
- [ ] Enable **Developer tools → Show AX placement preview** (Accessibility required). Invoke in single view: one green outline. Invoke in side-by-side/stacked Reference View: green left/top and purple right/bottom, regardless of the app's existing layout/pane selection. Normal photo placement still follows that selection.
- [ ] Turn Lightroom photo information off; hide panels and resize; invoke again. Outlines must use fresh panel/label evidence, not information rectangles. Raw edge estimates deliberately include unresolved toolbar/margin errors: report these with a screenshot.
- [ ] Dismiss/reinvoke quickly, move Lightroom, switch apps, minimise/restore: no late or orphan trial borders; borders do not intercept clicks. Disable the option: outlines disappear without dismissing the photo.
- [ ] **Diagnostics… → Refresh AX** shows a new snapshot timestamp and image-inspection section in the same window. **Copy all** includes normal placement, AX trial, display map and timings. No separate inspection alert to copy.
- [ ] Enable **Copy diagnostics after invocation**: clipboard is replaced by the full report automatically, including the completed AX result. Confirm with preview both on and off. A normal invocation failure should also copy its status. Disable to stop automatic clipboard writes.

Live acceptance is pending. No Screen Capture / AX placement switch yet. The normal detector is unchanged; the AX calculation is a heuristic experiment, not a verified replacement.
