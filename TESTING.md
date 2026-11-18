# Migration testing — 1.1.4 / stage 4

Quit the previous app, then open this worktree’s `release/CameraReference Testing.app`. Main remains unchanged. [Stage 3 menu acceptance](docs/migration/STAGE-3-MENU-ACCEPTANCE.md) is preserved separately.

- [ ] **Loupe menu:** automatically detected Loupe appears normally, not greyed out, with its icon and no checkmark, submenu or action. Split pane choices still work.
- [ ] **AX update option on:** an open overlay follows photo/view/pane/panel changes as before. View/panel changes retain zoom; photo selection resets Fit. An off overlay stays off.
- [ ] **AX update option off:** those changes dismiss. Switching module or entering Library Grid still dismisses; returning to Loupe does not reopen it. Moving Lightroom still follows normally.
- [ ] **Backup smoke check:** screenshot explicit view/pane selection still dismisses; inferred changes and panel checks retain their previous behaviour. Manual placement and floating display remain unchanged.

Focus on differences from the accepted build; do not investigate unrelated edge cases. Automated checks do not replace native acceptance.
