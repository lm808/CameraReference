# Final placement work

Baseline: accepted 1.1.10 build 69, commit ab92404. Keep main accepted; implement candidates here. Preserve AX-only placement/live behaviour and optional screenshot AX view detection. No automatic fallback between methods.

## Stages

- [x] Create worktree from merged main; retain previous testing payload and raw investigation reports.
- [ ] Inspect screenshot outer-bound search coverage and reproduce the small-window/panel issue with fixtures before choosing a correction.
- [ ] Validate equal splitting against supported Library/Develop layouts. Replace screenshot divider scanning with 50/50 only after valid outer-area detection; preserve pane margins.
- [ ] Remove AX-assisted placement setting/routing/implementation and exclusive diagnostics. Preserve screenshot choice and independent AX view-detection preference for existing users.
- [ ] Run focused regression and native tests: Loupe/both split directions, panel visibility, minimum-size windows, Embedded Preview labels, AX view detection on/off, and AX-only regression.
- [ ] Inspect current offset terms and finalise minimum independent manual-selector calibration cases. Proposed cases: Develop Loupe all shown; all hidden with toolbar; all hidden without toolbar; Develop split; Library split. Verify top/bottom and resized window independently.
- [ ] Add separate guided AX recalibration using manually selected working-area rectangles. Do not change manual-placement preferences/region. Derive replacements from raw AX/current settings with right/up-positive convention; review proposed changes and back up config before applying. Flag inconsistent measurements rather than hiding them in offsets.
- [ ] Preserve native test responses, clean current docs, and merge only after user acceptance.

Existing screenshot caching, permission handling and background checks stay unchanged unless explicitly agreed. Broader performance work remains deferred. The inherited testing app is the accepted baseline, not a build of these planned changes. No implementation changes made during worktree setup.
