# 1.1.16 / build 75 — boundary fixes

1.1.15 remains user-accepted; its exact annotations are in [1.1.15 test response](docs/1.1.15-TEST-RESPONSE.md). This candidate fixes the two audit findings without changing placement formulas or screenshot detection. Main remains untouched.

- [ ] Accessibility placement and AX preview still agree in Loupe and both split orientations, including a hidden top panel in macOS full screen. Existing update/dismiss behaviour remains correct.
- [ ] Guided calibration: select a normal working area and its photo bounds, cancel another selection, then close/reopen. Accepted measurements remain and Option-snapping works as before. No need to repeat all seven measurements or Apply unless something differs.
- [ ] Manual calibration still supports Option-snapping when available and cancellation retains the previous region/mode. If Screen Recording is already unavailable, freehand selection includes the settings guidance and does not prompt for permission.

Automated checks cover invalid signed offsets leaving raw calibration evidence available, both permission-denial routes and unrelated error classification. They also compare 1,728 synthetic old/new production AX results. You do not need to deliberately damage your config or revoke permissions to reproduce those artificial cases.
