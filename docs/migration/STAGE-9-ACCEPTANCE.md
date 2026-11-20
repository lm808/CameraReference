# Stage 9 user test responses

2026-11-20: all four items marked complete, with no new annotations. Optional actions and matched timing samples were not separately confirmed. This accepts migration behaviour testing, not a merge. Original responses follow unchanged.

# Migration testing — 1.1.9 / stage 9

Quit the previous app, then open this worktree’s `release/CameraReference Testing.app`. Main remains unchanged. Stage 8 responses are preserved in [STAGE-8-ACCEPTANCE.md](docs/migration/STAGE-8-ACCEPTANCE.md). The six [deferred issues](docs/BACKLOG.md) remain unfixed.

- [x ] **Default Accessibility workflow:** enable “Update overlay with LrC view”, show the overlay, zoom/pan, then change Lightroom between Loupe and Reference View and choose the other pane in Camera Reference. Geometry changes retain zoom. Selecting another Lightroom photo refreshes at Fit. Dismiss and invoke again on the same photo; there should be no noticeable new delay. Changing Lightroom module dismisses and leaves the overlay off.
- [x ] **Dismiss option and manual region:** disable “Update overlay with LrC view”; a Lightroom view or photo change dismisses the visible overlay. Use an existing manual region and confirm placement/dismissal work as before. If you normally recalibrate, cancel one selection and confirm the previous region remains; the known stale pane wording is not fixed here.
- [x ] **Screenshot modes:** in Develop, invoke once with both screenshot AX options off, once with AX view detection on, and once with AX-assisted placement on. The first uses your selected view/pane; the second infers Lightroom’s view; the third uses assisted placement. Placement and failure behaviour should match the previous build. Changing panels retains the visible overlay; after background checking, dismissing and invoking again uses the changed layout.
- [x ] **Floating window and lifecycle:** open the floating window, refresh it with a double-click and close it. Its image interaction/title and the overlay’s independent lifetime work as before. With an overlay open, minimise/restore and move Lightroom, then bring another app forward and return. No new ordering/restoration behaviour. Known native stacking issues remain deferred.

Mark any optional actions you did not try. Report a repeatable slowdown rather than relying on one invocation; matched timing evidence is still pending. No exports, permission changes or new manual calibration are required. Final acceptance does not automatically merge this candidate.
