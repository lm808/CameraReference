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

- Library Loupe/module transitions passed in 1.0.11; per-module layout memory and on-screen placement passed in 1.0.12. Off-screen capture remains blocked: 1.0.13 exposed inconsistent content geometry and later successes; 1.0.14 enables raw previews during failure. Collect native intermittent cases before changing mapping again. Consider retaining the last failed frame/diagnostics separately from later successes. Main accepted at 1.0.14 for continued use. Brief minimise lingering is accepted; no further early-command monitoring planned.
- Later: investigate AX panel-derived viewport bounds and explicit 50/50 split fallback; preserve capture detection until accepted.


### AX diagnostic candidate 1.0.16

- Native validation of independent green/purple outlines and their lifecycle is pending.
- Determine exact toolbar/backdrop edges; current panel-edge estimate is deliberately raw.
- Validate label heuristics across Library, display scales, session changes and hidden panels.
- Only after acceptance, discuss switching actual placement to AX and retiring layout selection. Do not alter the existing detector during this trial.


### AX investigation follow-up (1.0.19)
- Trial automatic view classification and per-orientation pane choices in native Lightroom; keep the capture backend intact.
- Compare fresh child/parent AX reports with toolbar shown/hidden, then after resizing. Establish whether a real toolbar container replaces the provisional offsets.
- Validate geometry hints across modules/scales/hidden panels. All preview adjustment defaults remain zero.
- AX placement backend switch remains deferred until preview geometry is accepted.
