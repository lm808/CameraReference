# CameraReference 1.0.3 — candidate

Run this testing worktree’s release/CameraReference.app. Bridge 0.5.2 is unchanged; no plugin reinstall is needed. Original main worktree app remains 1.0.1.

The overlay now floats while Lightroom is active, so Lightroom clicks cannot repeatedly cover it. It drops to normal level when another app activates; ordinary host-relative ordering resumes. Movement follows the host only when it actually moves. Diagnostics show move, ordering and level-change counts.

Default sideSearchPercent remains 40; explicit settings are preserved. No permission/signing changes, automatic permission resets or DMG packaging are included. Native flicker, dialogs and app-switch acceptance remain in TESTING.md.
