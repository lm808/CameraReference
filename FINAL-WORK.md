# Final placement work

Baseline: accepted 1.1.10 build 69, commit ab92404. Keep main accepted; implement candidates here. Preserve AX-only placement/live behaviour and optional screenshot AX view detection. No automatic fallback between methods.

## Stages

- [x] Create worktree from merged main; retain previous testing payload and raw investigation reports.
- [x] Inspect screenshot outer-bound search coverage and reproduce the small-window/panel issue with fixtures before choosing a correction.
- [x] Implement pixel-validated 50/50 splitting and preserve pane Fit margins; synthetic coverage passes. Native Library/Develop layout validation remains in TESTING.md.
- [x] Remove AX-assisted placement setting/routing/implementation and exclusive diagnostics. Preserve screenshot choice and independent AX view-detection preference for existing users.
- [ ] Run focused regression and native tests: Loupe/both split directions, panel visibility, minimum-size windows, Embedded Preview labels, AX view detection on/off, and AX-only regression.
- [x] Inspect current offset terms and finalise minimum independent manual-selector calibration cases. Proposed cases: Develop Loupe all shown; all hidden with toolbar; all hidden without toolbar; Develop split; Library split. Verify top/bottom and resized window independently.
- [x] Add separate guided AX recalibration using manually selected working-area rectangles. Do not change manual-placement preferences/region. Derive replacements from raw AX/current settings with right/up-positive convention; review proposed changes and back up config before applying. Flag inconsistent measurements rather than hiding them in offsets.
- [ ] Preserve native test responses, clean current docs, and merge only after user acceptance.

Existing screenshot caching, permission handling and background checks stay unchanged unless explicitly agreed. Broader performance work remains deferred. The inherited testing app is the accepted baseline, not a build of these planned changes. No implementation changes made during worktree setup.

1.1.11 candidate: search-zone failure reproduced synthetically; fully validated 50% retry now accepted. Equal splitting implemented, native layout/margin acceptance pending. AX-only logic and optional inference signature preserved. Recalibration has not started.

1.1.12 fixes: border-tolerant screenshot validation, shared outer raster cache/opposite-pane reuse, screenshot photo dismissal independent of inference, explicit placement permission request and configurable numeric view shortcuts. Prior native responses preserved. New candidate needs native acceptance.

Guided calibration implemented separately: five windowed cases, raw AX evidence with panel/toolbar guards, pure offset decomposition, repeated-edge consistency checks, existing selection UI, explicit review and config backup/conflict checks. Native acceptance remains pending.

## 1.1.13 agreed follow-up (current)

- [x] Preserve 1.1.12 native responses verbatim; passed cases and deferred cache/calibration cases recorded separately.
- [x] Retain successful expanded screenshot area on inconclusive background checks; legacy-off behaviour unchanged.
- [x] Add camera-recorded style metadata for CR3/C-RAW and ARW to independent displayed-image context menus.
- [x] Default-hidden Developer tools advanced option; grouped config/default generation with value/comment preservation and backup.
- [x] Replace sequential guide with six setup rows/seven selections, countdown/Escape, independent retry, red conflicts, full-screen allowance and photo Fit inset; calibration in its own commit.
- [x] Automated checks/build; updated architecture, methods, source contract and lean test list.
- [ ] Native acceptance of 1.1.13, especially Apply, full-screen countdown/snapping and actual C-RAW/Sony metadata.
- [ ] Merge only after acceptance. Main remains ab92404 / 1.1.10 build 69.
