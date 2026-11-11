# CameraReference 1.0.1 — acceptance tests

Quit the old app; run **release/CameraReference.app**, confirm **1.0.1**, and reload bridge **0.5.2**. `[x]` or `[x ]` means pass. No DMG test is needed for this update.

- [ ] Show an overlay and wait through several background checks: it stays visible.
- [ ] Resize Lightroom, change internal panels, or change photo/module: the visible reference remains until you dismiss it. Toggle off/on in Develop to get fresh placement/current photo.
- [ ] Move Lightroom partially off-screen and back: the overlay follows. Other apps can cover it.
- [ ] Enter/exit Mission Control and App Exposé; minimise/restore and switch Spaces. It hides temporarily and returns, including after resize or selection changes. Close the actual host window: overlay closes.
- [ ] Stop old bridges and start the updated app/bridge. Config and plugins end up under CameraReference; the spaced folder disappears after consolidation. Verify personal values (30 and ui bounds) survive. Re-add the plugin's new path if moved.
- [ ] If a legacy bridge is still active, diagnostics report migration waiting; existing config still loads. Stop it: migration completes. Conflicting files are preserved with a .migrated suffix, never silently overwritten.
- [ ] Full and all split panes still align for landscape/portrait at Fit. Repeated toggles reuse RAM/placement when valid. Manual calibration/clear preference behaviour remains intact.
- [ ] Floating display size, hover chrome, Fit dragging and Cmd-scroll still work independently.

For unexpected hiding, copy Developer tools → Bridge diagnostics before invoking again; it now includes visibility reasons. Native behaviour is not proven by automated geometry tests.
