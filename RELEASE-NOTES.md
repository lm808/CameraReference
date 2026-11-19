# Camera Reference 1.1.4 — testing candidate

Migration stage 4 consolidates existing overlay behaviour decisions into a pure policy. Geometry updates, photo refreshes, host suspension/movement, module changes, Grid evidence and explicit menu selection retain their existing rules. Request guards, scheduling, cancellation, screenshot checks and placement algorithms were unchanged by the extraction.

Automatically detected Loupe View now appears normally rather than greyed out, with no submenu or action. Other view-menu behaviour remains as accepted in build 60.

Main’s accepted 1.0.32 app remains untouched. This candidate requires native acceptance; no merge or DMG. Quit the previous app before running the testing app because stable/testing share settings and the Lightroom bridge.

Build 62 is a separately authorised full-screen correction: when AXFullScreen is true and the top panel is hidden, remove the 32 pt windowed title-bar allowance before AX view classification and placement. Shown-top and windowed geometry are unchanged. Unknown full-screen state retains the previous calculation and is identified in diagnostics. Version remains 1.1.4 for migration stage 4.

Build 63 replaces the fixed full-screen allowance with `axFullScreenTitleBarAllowancePoints` (default 32, range 0...200 macOS points; 0 disables). It is a calibrated value supported by the recorded reports, not an AX boundary measurement. The file-driven advanced editor exposes it; config generation and missing-key upgrades preserve existing values. Both AX classification and placement use it, while screenshot geometry and windowed placement are unchanged.
