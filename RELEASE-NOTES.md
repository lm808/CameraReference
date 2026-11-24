# Camera Reference 1.1.16 — build 75

Accepted main source and staged stable build. No downloadable package or GitHub release has been published for this update.

Since 1.1.10:

- Simplified independent Screenshot placement to validated outer bounds and 50/50 splits, improved narrow-window and boundary detection, and removed AX-assisted placement. Optional AX view detection remains.
- Added default-on, switchable expanded screenshot working-area reuse and configurable view shortcuts, including numeric keypad support.
- Added camera picture-style information for Canon CR3/C-RAW and Sony ARW in overlay and floating-window menus.
- Grouped advanced configuration while preserving user values; Developer tools are hidden by default and enabled through `showDeveloperTools`.
- Added guided AX calibration with independently retryable measurements, countdown, optional snapping, review and backup before Apply.
- Fixed calibration layout and clicking an overlay to activate Lightroom.
- Separated shared raw AX evidence from corrected placement validation and made capture-permission guidance use typed failure reasons. Production AX placement formulas remain unchanged.

Native feature and regression checks passed through 1.1.16. Automated checks include 1,728 old/new AX geometry comparisons. Exact responses and coverage limits are retained in docs/VALIDATION.md and docs/1.1.16-TEST-RESPONSE.md. Wider platform coverage and occasional ambiguous pixel boundaries remain in docs/BACKLOG.md.
