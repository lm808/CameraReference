# Stage 8 user test responses

2026-11-20: all four checklist items marked complete, with no new issue annotations. Optional Spaces/monitor-layout and AX-assisted repeat checks were not separately confirmed. Six deferred issues remain unresolved. Original responses follow unchanged.

# Migration testing — 1.1.8 / stage 8

Quit the previous app, then open this worktree’s `release/CameraReference Testing.app`. Main remains unchanged. Your stage 7 annotations are preserved in [STAGE-7-ACCEPTANCE.md](docs/migration/STAGE-7-ACCEPTANCE.md). The six deferred issues, including hover-text cleanup, remain in [BACKLOG.md](docs/BACKLOG.md).

- [x ] **Lightroom view and photo changes:** use Accessibility mode with “Update overlay with LrC view” enabled. While the overlay is visible, change Lightroom from Loupe to Reference View, hide/show a side panel, and select another photo. The overlay follows view/panel changes; selecting a photo refreshes it at Fit. Switch between Library and Develop: the overlay dismisses and stays off. With the update option disabled, a view or photo change dismisses instead.
- [x ] **Foreground and host visibility:** show an overlay, bring another app forward, then return to Lightroom. Ordering behaves as before. Minimise and restore Lightroom; the overlay disappears and returns after restoration. Move Lightroom; the overlay follows. Once you dismiss the overlay yourself, these actions must not reopen it. Known stacking issues are still deferred.
- [x ] **Live menu while overlay is off:** in Accessibility mode, change Lightroom between Loupe and Reference View. The Camera Reference view menu catches up as before (the eligible AX poll remains every 2 seconds), but no overlay opens. Repeat in Screenshot mode with AX view detection enabled; only the existing screenshot behaviour should occur.
- [x ] **Screenshot backup behaviour:** in Screenshot mode, show an overlay and hide/show a Lightroom panel. The currently visible overlay stays in place; after dismissing and invoking it again, placement reflects the changed panels. Repeat with AX-assisted placement enabled if you use it. Background checks must not cause the overlay to reopen after dismissal.

Only if you normally change Spaces or monitor layout, also check that overlay suspension/restoration and saved-calibration messages behave as before. No permission changes, new calibration or file exports are required. Report any changed responsiveness or repeated menu updates. These checks test migration, not fixes for deferred issues.
