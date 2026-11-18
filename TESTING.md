# Migration testing — 1.0.33 / stage 2

Quit the stable app, then run this worktree’s `release/CameraReference Testing.app`. Compare with your usual 1.0.32 behaviour; report regressions, rather than investigating existing edge cases.

- [ ] **Daily use:** invoke/toggle the AX overlay, change photo/view/pane/panels, and briefly use the floating window. Behaviour and responsiveness should feel unchanged.
- [ ] **Diagnostics:** open the report; check its usual sections. Enable saving and invoke: `Diagnostics/latest.txt` updates. Disable saving: it stops updating. Any retained failure remains separately labelled.
- [ ] **AX preview:** enable the boundary preview, invoke and dismiss. Borders should appear and disappear as before, with no late borders after dismissal.
- [ ] **Capture preview, if already permitted:** open a capture preview, retain a baseline and compare another capture. Closing/reopening should work as before. Skip if Screen Recording is unavailable.

Automated checks passed; these native checks are pending. If responsiveness differs, use the [timing comparison protocol](docs/migration/BASELINE.md).

The [older testing backlog](docs/migration/PRE-MIGRATION-TESTING.md) is preserved separately and is outside this migration checklist.
