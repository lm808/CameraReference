# 0.9 focused test

Quit the old companion and open this build. Keep the existing Lightroom plugin.

1. In Lightroom, select single-picture Develop view and Fit in its Navigator. Clear all region data and enable Automatic viewing area. Run Find viewing area: no internal-divider ambiguity message should appear.
2. Preview the region: left/right at UI panes, top/bottom at the photograph. Invoke the overlay on landscape and portrait photographs. If the photo is slightly too large/small, adjust fitInsetPoints through Settings → Open detection configuration, save, dismiss and retry. Larger inset makes the calculated photo smaller.
3. Try left=photo or top=ui. Save and retry. Only that overlay boundary should change; the photograph itself should retain its calculated position and scale.
4. Start manual calibration and hold Option. Panel borders should remain available, while small controls/photo details attract less. Try verticalSnapFraction/horizontalSnapFraction=0.35 for stricter filtering, or 0.15 for more edges. Save and restart calibration, not the app.

If detection still fails, send Show last result / timing diagnostics. No need to repeat unrelated extraction/export tests. Native alignment, TextEdit config opening and full-screen behaviour await your tests.
