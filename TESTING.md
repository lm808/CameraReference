# CameraReference 1.0.4 — focused candidate checks

Quit 1.0.3 and open **this worktree’s release/CameraReference.app**, confirming 1.0.4. Bridge 0.5.2 is unchanged. Your 1.0.3 annotations are preserved verbatim in docs/VALIDATION.md; accepted Full/split flicker behaviour is the baseline.

- [ ] With overlay visible, open **Email Photo** and **View Options**. Each dialog stays above the overlay and usable. Close it: overlay returns to floating without another shortcut.
- [ ] Minimise Lightroom with the yellow button, restore it, then repeat using Cmd-M. No part of the overlay remains at the Dock; restoration retains its image and alignment. Repeat with another app active and after moving Lightroom partly off-screen.
- [ ] Briefly repeat clicks/zoom/pan in split view: the accepted flicker fix remains intact. Another app can still cover the overlay.
- [ ] Trigger detection failure in Full, left/right and upper/lower modes. Title is “Cannot reliably identify viewing area.” Instructions show the selected layout/pane icon and current mode. Cancel preserves mode and region; accepted calibration switches to manual.

If dialog/minimise behaviour fails, copy Developer tools → Bridge diagnostics before invoking again. The Lifecycle line identifies dialog state, optional Accessibility availability and minimise state. No new Accessibility prompt is added: direct state checks use existing permission, otherwise window-list metadata is used. Native success remains to be confirmed.
