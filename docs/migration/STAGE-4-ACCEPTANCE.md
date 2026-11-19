# Stage 4 user test responses

User completed testing; three reported items deferred until after migration by explicit instruction. Original responses follow unchanged.

# Migration testing — 1.1.4 / stage 4

Quit the previous app, then open this worktree’s `release/CameraReference Testing.app`. Main remains unchanged. [Stage 3 menu acceptance](docs/migration/STAGE-3-MENU-ACCEPTANCE.md) is preserved separately.

- [x ] **Loupe menu:** automatically detected Loupe appears normally, not greyed out, with its icon and no checkmark, submenu or action. Split pane choices still work.
- [x ] **AX update option on:** an open overlay follows photo/view/pane/panel changes as before. View/panel changes retain zoom; photo selection resets Fit. An off overlay stays off.
- [x ] **AX update option off:** those changes dismiss. Switching module or entering Library Grid still dismisses; returning to Loupe does not reopen it. Moving Lightroom still follows normally.
- [view change does not dismiss, it just stays. when invoking in library grid, it reports cannot find area. maybe this behaviour should mirror AX with live update off? seems more logical.] **Backup smoke check:** screenshot explicit view/pane selection still dismisses; inferred changes and panel checks retain their previous behaviour. Manual placement and floating display remain unchanged.

Focus on differences from the accepted build; do not investigate unrelated edge cases. Automated checks do not replace native acceptance.

## Build 62 — full-screen boundary fix only

- [x. AX placement preview is still off but strangely the final placement is correct. ] In macOS full screen with top panel hidden, check Loupe and both Reference View orientations; verify placement and inferred view on built-in and external displays.
- [x ] Show the top panel, then return to windowed mode: existing placement remains correct.
- [tell me when you are ready I will trigger and you can read the diagnostics ] If still incorrect, save diagnostics; the window map now reports AXFullScreen and the proposal identifies whether the 32 pt correction was applied.

## Build 63 — configurable allowance

- [x ] Advanced settings exposes axFullScreenTitleBarAllowancePoints with its comment; default 32 retains build 62 placement. A custom value affects full-screen hidden-top placement and classification only; 0 disables the allowance.
