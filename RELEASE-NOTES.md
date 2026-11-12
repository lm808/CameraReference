# CameraReference 1.0.8 — diagnostic candidate

Main remains at accepted 1.0.6. Run only the candidate worktree’s release/CameraReference.app for these tests. Bridge 0.5.2 and config values are unchanged.

- Settings → Enable minimise monitoring requests Accessibility only when selected.
- Bridge diagnostics identify permission, AX window matching, individual notification failures and event timing.
- Developer tools can retain an on-screen capture baseline beside the latest preview, in RAM only.
- Fresh off-screen detection is declined because 1.0.7’s window-only pixels produced shifted placement. Existing overlays/cached translation and the accepted on-screen detector remain unchanged. Manual calibration is still offered.

This build gathers the missing native evidence; it does not claim either outstanding issue is solved. Follow TESTING.md. No merge, installation, live interaction or DMG by the agent.
