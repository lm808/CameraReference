# 0.9.1 focused acceptance test

Quit the old companion and open build/CameraReference.app. No plugin reinstall or restart needed. Keep your working configuration and use single-photo Develop at Fit.

1. In the normal Lightroom window, invoke/dismiss the overlay. It should retain the alignment accepted in 0.9.
2. Enter macOS full screen, let the transition finish, then invoke. Check both horizontal and vertical alignment.
3. Exit full screen and invoke again. Resize smaller, invoke, then restore the original size and invoke. Recovery should not require restarting Lightroom or clearing region data. If a visible overlay is dismissed when the window moves/resizes, that is intentional.
4. A window too small for reliable detection can still offer manual calibration. Cancel that prompt to continue testing automatic mode. A transition in progress should instead ask you to wait and invoke again.

If any overlay is offset, open Developer tools → Bridge diagnostics immediately after invoking it, and send the full report (including requested and actual panel frames). Do not run Find viewing area first, because that would replace the overlay-placement report.

No need to repeat all side combinations or snapping tests. Full-screen/Spaces behaviour cannot be confirmed by the automated geometry tests alone.
