# 0.9.4 focused acceptance test

Quit the old companion and open build/CameraReference.app. No plugin reinstall or restart needed. Keep your working configuration and use single-photo Develop at Fit.

1. Start on the built-in display in the normal Lightroom window. Invoke/dismiss the overlay; it should remain visible despite fractional frame rounding. It should retain the alignment accepted in 0.9.
2. Enter macOS full screen, let the transition finish, then invoke. Check both horizontal and vertical alignment.
3. Exit full screen and invoke again. Resize smaller, invoke, then restore the original size and invoke. Recovery should not require restarting Lightroom or clearing region data. If a visible overlay is dismissed when the window moves/resizes, that is intentional.
4. A window too small for reliable detection can still offer manual calibration. Cancel that prompt to continue testing automatic mode. A transition in progress should instead ask you to wait and invoke again.

If any overlay is offset, open Developer tools → Bridge diagnostics immediately after invoking it, and send the full report (including requested and actual panel frames). Do not run Find viewing area first, because that would replace the overlay-placement report.

No need to repeat all side combinations or snapping tests. Full-screen/Spaces behaviour cannot be confirmed by the automated geometry tests alone.

If placement fails, the status must retain the failure message rather than say “Reference shown”. Repeat on the external display if available. Diagnostics now include actual view coordinates and panel visibility; visibility alone does not prove the panel is unobscured in the intended Space.

## Small-window regression

Confirm 0.9.4 at the top of the companion menu. Enable Automatic viewing area if a previous cancelled calibration left it off. Use the small Lightroom window from the report, entirely on one display. Invoke repeatedly and check that the photograph aligns and does not overlap the right controls. Resize larger and smaller and repeat.

If detection fails, choose Calibrate then Escape: Automatic viewing area should remain enabled and the next shortcut should try detection again. Also check the initial Cancel button. Accepting a new region should switch to manual mode. Send Bridge diagnostics immediately after an incorrect overlay; the capture mode should say display-bound window filter, explicit crop.
