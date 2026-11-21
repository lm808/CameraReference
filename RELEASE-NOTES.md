# Camera Reference 1.1.10

Accepted migration and usability fixes, build 69:

- Clearer ownership of placement, image requests, monitoring, presentation, settings and diagnostics.
- Full-screen title-bar reveal clips the overlapping overlay strip without moving or resizing the photo. The slight reveal delay is accepted.
- Floating reference stays above the overlay after clicks; AX preview borders use the production frame constraints.
- Screenshot with AX view detection dismisses on confirmed photo/view/pane/panel changes and Grid, matching Accessibility with updating off. Missing evidence retains the overlay. Pure screenshot without AX view detection keeps its previous behaviour.
- Generic calibration guidance, shorter gesture tooltips and direct developer-menu access to AX preview.
- Optional delayed window-order diagnostics for future investigations.

Placement algorithms and calibrated offsets remain unchanged. Migration and deferred-fix native tests passed; broader screenshot edge cases and compatibility work remain in docs/BACKLOG.md. No release package was created as part of the documentation cleanup/merge.
