# CameraReference Testing 1.0.14 — raw preview

Main remains **1.0.6**; bridge remains **0.5.3**. Run this worktree’s `release/CameraReference Testing.app`. No settings or plugin update needed. Minimise lingering is accepted.

- [ ] Use **Developer tools → Preview captured Lightroom window…** with Lightroom partly off-screen, including when overlay placement fails. If macOS returns an image, the raw preview should open with all padding/displacement intact. Geometry rejection must not block it.
- [ ] Copy diagnostics alongside any abnormal preview: it should say **RAW PREVIEW** and include frame rectangles, scale and buffer size. Do not interpret a successful preview as validated placement.
- [ ] Quick normal overlay check: placement/snapping must still reject malformed geometry; Full/split calculations are unchanged.

Continue collecting intermittent Full/split and off-screen cases during ordinary use; no need to force a reproduction now. Actual capture/permission/conversion failures can still prevent an image. Preview captures afresh; it does not yet recover an earlier failed attempt. Images stay in RAM and are not saved automatically.

Prior native results are in docs/VALIDATION.md. Module/app-switching and Mission Control check remains deferred. Do not merge until accepted.
