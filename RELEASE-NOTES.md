# Camera Reference 1.1.4 — testing candidate

Migration stage 4 consolidates existing overlay behaviour decisions into a pure policy. Geometry updates, photo refreshes, host suspension/movement, module changes, Grid evidence and explicit menu selection retain their existing rules. Request guards, scheduling, cancellation, screenshot checks and placement algorithms are unchanged.

Automatically detected Loupe View now appears normally rather than greyed out, with no submenu or action. Other view-menu behaviour remains as accepted in build 60.

Main’s accepted 1.0.32 app remains untouched. This candidate requires native acceptance; no merge or DMG. Quit the previous app before running the testing app because stable/testing share settings and the Lightroom bridge.
