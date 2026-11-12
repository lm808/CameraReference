# Outstanding work

## 1.0 alpha acceptance

- Use sectioned diagnostics to identify missing Accessibility permission/window binding/notification support; verify minimise/restore timing. Retain accepted Mission Control/App Exposé/Space behaviour.
- Compare on-screen baseline and off-screen window-only pixels (1.0.8). 1.0.9 re-enables placement/snapping with no source crop after the user’s matching-preview result; verify actual alignment. Retain off-screen following and other-app covering.
- Check DMG installation and advanced config migration without losing personal settings.
- Retain Full and all split-pane portrait/landscape placement; user accepted 0.9.15 with sideSearchPercent = 30.

## Before broader distribution

- Choose a licence (author explicitly deferred this decision).
- Decide on Developer ID signing/notarisation and a stable publisher identity.
- Test supported macOS/Lightroom versions and both processor architectures; current packages are native architecture only.
- Add release automation/CI when the supported build environment is agreed.
- Measure sustained background-check CPU/power cost; current detector benchmarks exclude some capture overhead.

## Possible later work

- Improve automatic placement across more panel widths without personal side-search tuning.
- Investigate reliable main-view identification only if Lightroom exposes evidence; current SDK diagnostics do not identify it.
- Broader RAW support beyond CR3/ARW, additional Sony camera samples and cropped RAW/JPEG aspect handling.

Completed functionality belongs in README; implementation rationale in METHODS; historical evidence in VALIDATION and Git history. Pinch gestures were deliberately removed; Cmd-scroll is supported.

- Library Loupe and module transitions passed user tests in 1.0.11. Validate per-module layout memory, off-screen capture normalization and minimise lingering in 1.0.12; main remains 1.0.6 pending acceptance.
- Later: investigate AX panel-derived viewport bounds and explicit 50/50 split fallback; preserve capture detection until accepted.
