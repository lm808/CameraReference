# CameraReference 1.0.6 — candidate checks

Quit the previous candidate and open **this worktree’s release/CameraReference.app**, confirming 1.0.6. Bridge 0.5.2 is unchanged. Your previous annotations are preserved in docs/VALIDATION.md.

- [ ] Show an overlay, switch to Library: it dismisses. Return to Develop: it stays closed until invoked again. Repeat switching while an overlay is loading. A floating display should stay open.
- [ ] At Fit, landscape/portrait reference size and alignment are unchanged. Zoom the reference: it uses the full detected/calibrated region, including the previous backdrop margins, without spilling outside the region.
- [ ] Cmd-scroll stays centred around the pointer when pan limits allow; pan to each edge; Fit restores the original size/position. Check asymmetric ui/photo bounds if you use them. Floating display still zooms/pans normally.
- [ ] Detection-failure guidance shows pane icons without parentheses. Layout/mode wording and cancellation are unchanged.
- [ ] Select a Sony ARW and prefer embedded JPEG: overlay and floating display load. Check portrait orientation and repeated-toggle RAM reuse. Diagnostics identify JpgFromRaw or PreviewImage. The supplied sample has a 1616 × 1080 preview; zoom cannot recover detail beyond it.
- [ ] If desired, Save extracted JPEG and verify the chosen camera preview/orientation. Export keeps the existing _JpgFromRaw.jpg filename convention for either tag. RAW remains untouched.
- [ ] Quick CR3 regression: extraction, orientation and repeated toggles still work.

Off-screen fresh detection and unreliable minimise/restore are explicitly deferred, not fixed by this build. No need to repeat those tests yet. App-window ordering remains the 1.0.4 implementation.
