# Stage 6 user test responses

2026-11-20: all four checks marked complete; floating-display stacking bug reported and logged in docs/BACKLOG.md. This records testing completion, not resolution of the reported bug. Original annotations follow unchanged.

# Migration testing — 1.1.6 / stage 6

Quit the previous app, then open this worktree's `release/CameraReference Testing.app`. Main remains unchanged. Your completed stage 5 responses are preserved in [STAGE-5-ACCEPTANCE.md](docs/migration/STAGE-5-ACCEPTANCE.md). The four known bugs/policy items remain deferred in docs/BACKLOG.md.

- [x ] **Load and reopen:** in Accessibility mode, show the overlay for a selected photo, dismiss it with the shortcut, then show it again. The same photo and correct placement appear; the second invocation should feel no slower than before.
- [x ] **Change photo, update enabled:** with “Update overlay with LrC view” enabled and overlay visible, select another photo in Lightroom. The overlay shows that photo at Fit. Change selection quickly a few times; an older photo must not appear after the final selection.
- [x ] **Dismiss and cancel:** with the update option disabled, selecting another photo dismisses the overlay. Also dismiss an overlay/request while a photo is loading; a late result must not reopen it. Changing photos while the overlay is off must leave it off.
- [x. log bug: if overlay invoked after float, float gets covered. This is wrong and float should always be on top. ] **Other request destinations:** open and refresh the floating display, then invoke an overlay using Screenshot mode and an existing manual calibration. Loading and failure behaviour match the previous build; no unexpected placement or policy change.

If a read/extraction fails during normal use, the existing displayed image should remain as before. Report any repeatable increase in load time. Do not deliberately change RAW files or permissions for this test. Deferred bugs are not fixed by this build.
