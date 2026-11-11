# CameraReference 1.0.6 — candidate

Run this worktree’s release/CameraReference.app. Bridge 0.5.2 and defaults (40/all ui) are unchanged.

- Switching to Library dismisses the overlay and cancels pending overlay loading, including while suspended. Floating display is unaffected; returning to Develop requires invoking again. Unknown/stale module state still keeps the overlay.
- Zoom/pan uses the full overlay region while preserving the original Fit rectangle.
- Calibration pane icons no longer have parentheses.
- Sony ARW embedded previews supported: select the largest valid JpgFromRaw/PreviewImage, retain orientation, caching and explicit export. The supplied sample yields 1616 × 1080; higher detail depends on available embedded previews. No RAW writes or persistent image cache.

Off-screen detection and minimise/restore reliability are unchanged and deferred. Native zoom/ARW acceptance is in TESTING.md; previous results are preserved. No DMG or merge.
