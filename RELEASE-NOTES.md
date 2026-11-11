# CameraReference 1.0.4 — candidate

Run this worktree’s release/CameraReference.app. Bridge 0.5.2 and config defaults (40/all ui) are unchanged.

- Lower the overlay for Lightroom dialogs and restore floating behaviour afterward.
- Check on-screen membership/opacity and, when already authorised, Accessibility minimise state. Do not move overlays into thumbnail-sized host geometry.
- Use shorter calibration instructions showing the selected layout, pane/icon and current mode.

1.0.3 passed flicker, placement, movement and app-switch checks; Email Photo/View Options and minimising remained problematic. Those user annotations are preserved in docs/VALIDATION.md. Retest the focused cases in TESTING.md. No new permission prompts, plugin installation, merge or DMG packaging.
