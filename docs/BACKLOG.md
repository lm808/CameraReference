# Outstanding work

## 1.0 alpha acceptance

- Validate temporary hiding/restoration through Mission Control, App Exposé, minimising and Spaces.
- Validate partially off-screen following and return, including other apps covering Lightroom.
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
