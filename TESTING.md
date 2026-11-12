# CameraReference Testing 1.0.12

Main stays at 1.0.6. Quit the stable app, then run this worktree’s `release/CameraReference Testing.app` (purple T). Bridge remains **0.5.3**; no plugin update if already loaded. All live interaction is yours. Prior annotations are preserved in docs/VALIDATION.md.

- [ ] Choose Full in Library and a split pane in Develop. Switch back and forth, then relaunch: each module remembers its own selection. Existing Develop calibration/preferences remain intact. Clear region still leaves auto/manual mode unchanged.
- [ ] On-screen: Full and split placement, repeated toggles and Option snapping still work in Library Loupe and Develop.
- [ ] With the same window size, keep an on-screen capture baseline, move Lightroom slightly off each edge (also left + bottom together), then preview. Latest capture should show just the complete Lightroom window, without the extra padding. Try fresh placement and Option snapping in both modules. Copy diagnostics if it fails; look for Frame screen rect / bounding rect / Parent pixel crop or a geometry-verification error.
- [ ] Minimise/restore with an overlay visible: check whether lingering is reduced, with no downward jump or orphan overlay. Copy lifecycle history if it persists. Move partly off-screen and resize normally: overlay remains usable; ordinary clicks do not flicker.
- [ ] Switch Library ↔ Develop and another app; check dismissal on module change, other apps covering the overlay, and normal restoration after Mission Control.

Do not merge until accepted. Off-screen capture normalization and earlier minimise suspension are candidates, not confirmed native fixes.
