# CameraReference Testing 1.0.13 — off-screen diagnostics

Main remains **1.0.6**. Run this worktree’s `release/CameraReference Testing.app`; bridge remains **0.5.3**. No plugin update required. Previous results are preserved in docs/VALIDATION.md.

- [ ] Move Lightroom slightly off-screen and invoke once. If it fails, cancel calibration, then **Bridge diagnostics → Copy all** before invoking again. Placement & Capture must include the actual error domain/code and explanation, plus window/capture context. If a frame arrived, it also includes expected parent, frame rectangles, scale and pixel-buffer size.
- [ ] Repeat through **Preview latest capture**. Performance should describe this capture alone, without repeating an earlier invocation’s timing.
- [ ] Quick on-screen placement check. The detector, capture geometry, module preferences and minimise behaviour are unchanged in this update.

Off-screen placement is still unresolved; this build identifies the failure instead of masking it. Brief minimise lingering is accepted; no repeat minimise testing needed. Main must not be merged yet. The previously unchecked module/app-switching and Mission Control check remains deferred.
