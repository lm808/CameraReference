# Migration testing — 1.1.3 / stage 3

Quit the previous app, then run this worktree’s `release/CameraReference Testing.app`. Main remains unchanged. [Stage 2 annotations](docs/migration/STAGE-2-ACCEPTANCE.md) are preserved separately.

- [x ] **Info-overlay fix:** with LrC info overlay on, hide both side panels: placement should no longer start below the info text. Show either or both side panels, and toggle the top panel: bounds should remain correct.
- [x ] **Settings menu:** existing choices are remembered; Accessibility shows its update option, Screenshot shows its two AX options, and manual placement disables detection controls. Advanced settings remains last.
- [x ] **View menus and actions:** Loupe/split pane choices, shortcuts and overlay/floating toggles work as before; menu titles/checkmarks follow current state. Switching a choice retains the previous update/dismiss behaviour.
- [x ] **Daily use:** brief normal AX overlay use, including photo/view/panel changes and Diagnostics. No unexpected delay or behaviour change apart from the authorised info-overlay fix.

Automated checks do not replace these native checks. Existing unrelated edge cases remain outside migration acceptance.
