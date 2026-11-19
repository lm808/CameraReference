# Migration testing — 1.1.5 / stage 5

Quit the previous app, then open this worktree's `release/CameraReference Testing.app`. Main remains unchanged. Your stage 4 annotations are preserved verbatim in [STAGE-4-ACCEPTANCE.md](docs/migration/STAGE-4-ACCEPTANCE.md). Its three reported bugs/policy items are deferred until after migration in docs/BACKLOG.md.

- [ ] **Accessibility placement:** invoke in Loupe and both split orientations/panes. Placement and photo Fit match build 63, including full-screen hidden-top placement. Toggle off/on and change photo; update/dismiss behaviour stays the same.
- [ ] **Floating display:** open a new floating display with Accessibility, then Screenshot selected. Initial sizing/position match the previous build. Refreshing an existing floating display retains the previous size/position behaviour.
- [ ] **Manual:** use an existing calibrated region; placement and automatic/manual precedence are unchanged.
- [ ] **Screenshot backup:** invoke with AX assistance off and on; placement, warm-cache reuse and failures behave as before. Changing view in Lightroom still leaves an open screenshot overlay in place; this policy is intentionally deferred. Selecting a different view/pane in Camera Reference's menu still dismisses it.

Do not retest the three deferred issues as stage 5 fixes. Native acceptance and timing comparisons remain separate from automated checks.
