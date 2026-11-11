# CameraReference 1.0.3 — candidate checks

Quit the original app and open **this testing worktree’s release/CameraReference.app**. Confirm 1.0.3. Bridge 0.5.2 is unchanged; no reinstall is needed. Keep the original 1.0.1 release/ app for fallback. `[x]` or `[x ]` means pass.

- [ ] In side-by-side, show the overlay and zoom/pan the neighbouring RAW repeatedly: no flicker. Repeat left/right and portrait/landscape.
- [ ] Repeat in above-and-below, then check ordinary Full placement.
- [ ] Compare Developer tools → Bridge diagnostics before/after zoom/pan. With the Lightroom window stationary, “moves” should stay zero. While Lightroom stays active, ordering and level-change counts should stay stable after initial show. If it does, report both counts and the gesture/layout.
- [ ] Click different Lightroom controls repeatedly with overlay visible: no cover-and-restore flashes. Open a Lightroom dialog/sheet and check it remains usable; close it and check the overlay.
- [ ] Move Lightroom: overlay follows. Switch to another app: its windows cover the overlay normally. Return to Lightroom: ordering remains correct.
- [ ] Resize/change panels: existing overlay stays open; toggling it off/on refreshes placement. Mission Control/Space/minimise handling should not regress.
- [ ] Confirm your existing sideSearchPercent and ui/photo bounds have not been overwritten. New/missing config defaults are 40/all ui (covered automatically; do not delete your live config just to test this).

To fall back, quit the candidate and open the original worktree’s release/CameraReference.app. No branch switching, settings reset or plugin swap is needed between these two versions. Report remaining flicker with Bridge diagnostics before invoking again.
