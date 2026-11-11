# CameraReference 1.0.7 — candidate checks

Quit the current app and open **this worktree’s release/CameraReference.app**, confirming 1.0.7. Main’s release/ app remains the accepted 1.0.6 fallback. Bridge 0.5.2 is unchanged.

- [ ] Fully on-screen: clear region in auto mode and invoke in Full, side-by-side and above/below. Fit and split placement remain correct for portrait/landscape.
- [ ] Move Lightroom slightly off the left/right/bottom screen edge. **Clear region setting** to force fresh detection, then invoke. Placement should align with the full Lightroom viewport, clipped naturally at the screen edge. Repeat Full and split. Diagnostics should say window-only filter with an explicit content-local crop.
- [ ] Move it back, clear region and invoke: diagnostics return to display-bound capture with correct placement. If available, repeat across two displays, including different scales.
- [ ] With overlay visible, minimise using the yellow button and Cmd-M, then restore; repeat several times. No overlay remains near the Dock and it returns aligned. Diagnostics → Lifecycle reports whether minimise notifications are active. If unavailable, report that alongside the result; do not reset permissions.
- [ ] Briefly check Mission Control, another app covering Lightroom, ordinary movement, split RAW clicking/panning and switching to Library. No flicker; Library still dismisses. Floating display remains independent.

For any failure, copy Developer tools → Bridge diagnostics before invoking again. For shifted off-screen placement, also use Inspect screen layout / capture preview to check whether the entire parent window was captured. No screenshots are saved automatically. These native behaviours remain provisional until tested.
