# Development workflow

Use this single Git working tree. Edit only the relevant source/tests; do not copy the project into a new version directory per iteration.

- Imported source snapshots: tags v0.9 and v0.9.1, in chronological order. These are imports of delivered files, not a reconstruction of the original development commits.
- Commit each coherent change with its rationale and validation. Inspect git diff before committing.
- build/ and compiler caches are excluded. Run ./build.sh and ./test.sh on macOS with command-line tools installed.
- Do not create routine ZIP releases. Build the app in place on the user's Mac when a test build is requested; do not launch/install it or control Lightroom without authorisation.
- Keep existing plugin compatibility. Split-view groundwork is now authorised; keep production single-photo behaviour stable until view identity and native divider evidence are verified.
- The repository is now on the user's Mac at ~/Documents/Codex/CameraReference. Build in this working tree; build products remain excluded from Git.

# Open display defects

Confirmed v0.9.1 regression: Sources/main.swift uses sameWindowGeometry (0.5-point tolerance) to compare the requested overlay frame with the actual frame. The user's requested (304.94375,265.64814,890.890625,570.87138) becomes (304,265,891,571). That minor adjustment causes immediate dismissal. The caller unconditionally reports success afterwards. Fixed in 0.9.2: a separate one-point placement-rounding policy, screen-to-view mapping using the actual content-view coordinates, and success propagation from display(). Do not weaken capture/window-movement checks indiscriminately.

The user also reports no overlay on the built-in display with v0.9, which lacks this final-frame guard. Its cause is unconfirmed and requires its own failure-path evidence. Do not represent the rounding correction as resolving that earlier failure.

Current diagnostics: UI bounds are in the analysis raster (downsampled to at most2560px width), window geometry in macOS points, output frames in AppKit bottom-left coordinates. The reported3024px Retina capture is downsampled before analysis; those numbers must not be compared directly as if all were points.

Live user acceptance of 0.9.2 is pending.

## Small-window investigation (0.9.4)

The user's unobscured 3024×1964 screenshot, cropped to x0/y66/w3024/h1776, reproduces the reported bounds (722,153,1301,1042) within one raster pixel. Cropping to the reported Lightroom window x240/y66/w2784/h1776 instead yields bounds (563,166,1414,1132), aligned with the visible UI. This is strong evidence of an incorrect capture extent, not proof of the internal ScreenCaptureKit cause. Do not hard-code a display-width correction. The new display-bound window filter has an explicit display-local sourceRect and retains child windows while excluding other apps. A window spanning displays is rejected for automatic capture.

Calibration fallback used to disable automatic mode before acceptance. It now changes mode only on accepting a new region, preserving mode on Escape/cancellation. The initial alert's Cancel already preserved mode.

## Narrow viewport detection (0.9.5)

User confirmed 0.9.4 fixes non-maximised placement. The new 900×702 pt failure reproduces exactly from the supplied screenshot: x612 and x1166 viewport borders fall outside the old 30%/70% side search ranges in its 1800px capture. Widening to 45%/55% finds (612,180,554,860). Border support, surround consistency and ambiguity thresholds stay unchanged; no capture-coordinate changes are needed. More extreme layouts may still require manual calibration.

## Configurable side interval (0.9.6)

sideSearchPercent defaults to 45 and accepts 5–50 percent from each side. The config store appends it to existing files when absent. Both viewport cache and manual-layout keys account for the interval. On unsupported rectangles, a bounded second search reaching the centre can identify a valid viewport outside the configured range and set workingAreaTooNarrow; its bounds are discarded. The automatic overlay fallback offers the user's exact narrow-area message and Calibrate manually…/Cancel. Generic detection failures are not relabelled as narrow.

## 0.9.8 follow-up

User accepted 0.9.6 for most cases. Polish build committed separately; native shortcut, trackpad and privacy-icon checks pending. Current audited backlog supersedes historical statuses. PERFORMANCE.md records CPU benchmarks and the remaining live timing gap. SPLIT-VIEW.md and test-only SplitLayout.swift start the authorised split-view work without changing production detection.
