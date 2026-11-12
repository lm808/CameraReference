# CameraReference Testing 1.0.10

Keep main’s accepted 1.0.6 app. Quit it before opening this worktree’s **release/CameraReference Testing.app**. Confirm **Camera Reference Testing 1.0.10**, purple icon with a large T. This new testing identity needs its own Screen Recording and optional Accessibility approval; stable’s entry should remain. Settings/config and bridge 0.5.2 are shared. All live interaction is yours.

- [ ] Existing shortcuts, layout and calibration/config preferences remain. Stable and Testing are distinguishable in macOS permission settings. If Accessibility is missing, Developer tools → Inspect Accessibility layout… requests it.
- [ ] Show overlay; minimise/restore repeatedly without moving Lightroom. Check no downward jump and whether moves remains zero. In diagnostics, report geometry source and whether any lingering/late reappearance remains. Early hiding is still under investigation.
- [ ] Clear region in auto mode, move Lightroom slightly off-screen and invoke: fresh Full/split placement aligns. Test portrait/landscape. Manual calibration Option-snapping works on visible edges. Return on-screen and verify accepted placement remains correct.
- [ ] Bridge diagnostics has six selectable sections, scrollable text and Copy all. Performance appears once; the standalone monitoring menu action is gone.
- [ ] In Library, baseline/preview/Find viewing area show “Switch Lightroom to Develop.” In Develop they work. Preview baseline still remains available for comparison.
- [ ] Briefly check ordinary window following/resizing, no flicker during RAW pan/clicks, app covering, Library dismissal and floating display. Main remains unchanged until acceptance.

Copy all diagnostics after any failure, before invoking the overlay again. Prior annotations and chat findings are preserved in docs/VALIDATION.md.

**Permission gate first:** add the exact newly named CameraReference Testing.app to Screen Recording, leaving stable untouched, then quit/reopen Testing if required. If it still reports no permission, stop functional tests and copy App & permissions diagnostics. The rebuild does not yet prove that macOS will accept the grant.
