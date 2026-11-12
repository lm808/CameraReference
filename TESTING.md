# CameraReference Testing 1.0.11

Main remains 1.0.6. Quit it before running this worktree’s release/CameraReference Testing.app. **Update/reload the staged CameraReference.lrplugin manually; verify bridge 0.5.3.** Same purple T identity and shared settings/config. All live interaction is yours.

- [ ] In Library Loupe, select RAW: overlay, floating display, capture preview and Find viewing area work. Check portrait/landscape at Fit, automatic placement and manual calibration. Library Grid/Survey/Compare alignment is not claimed supported.
- [ ] Switch Library ↔ Develop with overlay visible: it dismisses. Reinvoke in the new module: fresh placement aligns, without using the other module’s calibration. Repeated toggles within the module still reuse valid caches.
- [ ] Switch modules while JPEG/capture/calibration is pending: no late overlay or calibration is saved in the new module. Switch to Map/Book/Print/Slideshow/Web: no new reference invocation; an explicit Library/Develop prompt appears. Existing floating display stays independent.
- [ ] Clear Library region: Develop’s region and preferences remain intact. Return to Develop: Full/split placement, shortcuts and calibration still behave as before. Library defaults auto on only when its preference is absent.
- [ ] Diagnostics after show: AX host is bound via main/focused or all-window search, even with >16 AX windows. Minimise/restore repeatedly; report counters/geometry source and any remaining linger/jump.
- [ ] Briefly repeat off-screen placement/snapping, ordinary movement, no flicker, app covering and sectioned diagnostics. Do not merge yet.

Use Copy all after failures before invoking again. Prior test annotations are preserved in docs/VALIDATION.md. This build does not add AX-derived photo bounds or guessed split dividers.
