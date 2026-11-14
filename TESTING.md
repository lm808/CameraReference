# Camera Reference Testing 1.0.24

Quit stable first; use this worktree's release/CameraReference Testing.app. Main remains 1.0.15. Native checks pending; no live testing by the agent.

- [ ] With AX-only OFF: existing screenshot Full/split placement, cache hits/background checks and manual calibration still work as before.
- [ ] Enable Experimental features → Use AX data only for placement. With automatic viewing area ON, overlay and floating display use AX; diagnostics say capture skipped, no placement cache. No Screen Recording prompt or new captured preview. Background checks report disabled.
- [ ] With AX-only ON, explicit capture-preview/baseline commands and manual calibration edge snapping still work. Turn main automatic placement OFF: saved manual region wins. Turn it back ON: fresh AX geometry is used.
- [ ] Develop all shown, each panel hidden, and multiple panels hidden: Full/side-by-side/above-and-below bounds use corrected outer edges before splitting. Select either pane; with automatic view inference OFF, explicit layout applies (mismatch offers manual calibration). With it ON, fresh inference selects layout and remembered pane.
- [ ] Toolbar shown/hidden and filmstrip shown/hidden: corrections are cumulative. Unknown toolbar status assumes shown. Filmstrip shown + toolbar hidden (-11 pt total) needs confirmation.
- [ ] Library uses its separate configurable bottom allowance (initially zero, uncalibrated). Do not calibrate against failed Library split screenshot detection.
- [ ] Edit a v2 offset: right/up positive; placement and independent AX preview both respond next invocation. Existing source/config preferences remain unchanged; old v1 values remain but are ignored. Preview toggle works with either backend.
- [ ] Rapid invocation/cancellation, photo/module switch and window movement during AX reads: no stale result appears. AX failure never captures; cancellation keeps settings. Existing visible-overlay movement/minimisation behaviour remains usable.

For comparisons, read Diagnostics/latest.txt after each case; no saved images needed. Test another window size after the fixed-size baseline.
