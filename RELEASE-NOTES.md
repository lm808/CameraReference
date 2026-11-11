# CameraReference 1.0.2 — candidate

Test this worktree’s release/CameraReference.app. The original worktree’s 1.0.1 app is untouched. Quit one before running the other; both share live preferences/config. Bridge 0.5.2 is unchanged, so no plugin reinstall is needed for this update.

- Skip position changes when Lightroom has not moved.
- Do not force immediate adjacency around Lightroom-owned windows during redraws; retain other apps’ ability to cover the overlay.
- Show actual movement/ordering counts in Bridge diagnostics.
- Default new installations and configs missing sideSearchPercent to 40. Explicit saved values and ui/photo preferences are preserved.

Native split zoom/pan flicker acceptance is pending. See TESTING.md in this worktree. No DMG was created; do not merge until accepted.
