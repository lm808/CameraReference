# CameraReference 1.0.7 — candidate

Run this worktree’s release/CameraReference.app. Main retains accepted 1.0.6; bridge 0.5.2 and config defaults are unchanged.

- Partially off-screen/spanning windows use an explicit window-only crop. Fully contained windows retain the accepted display capture and unchanged Full/split detection.
- When Accessibility is already authorised, listen for minimise/restore notifications and retry missing host binding. Lifecycle polling continues during window interactions. No new permission prompt.
- Diagnostics identify capture mode and minimise-notification availability.

Native off-screen and minimise/restore testing is required; see TESTING.md. Window-list fallback remains when notifications are unavailable. No DMG, installation or merge.
