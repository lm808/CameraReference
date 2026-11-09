# Development workflow

Use this single Git working tree. Edit only the relevant source/tests; do not copy the project into a new version directory per iteration.

- Imported source snapshots: tags v0.9 and v0.9.1, in chronological order. These are imports of delivered files, not a reconstruction of the original development commits.
- Commit each coherent change with its rationale and validation. Inspect git diff before committing.
- build/ and compiler caches are excluded. Run ./build.sh and ./test.sh on macOS with command-line tools installed.
- Do not create routine ZIP releases. Build the app in place on the user's Mac when a test build is requested; do not launch/install it or control Lightroom without authorisation.
- Keep existing plugin compatibility; split-view development is deferred.
- The repository is now on the user's Mac at ~/Documents/Codex/CameraReference. Build in this working tree; build products remain excluded from Git.

# Open display defects

Confirmed v0.9.1 regression: Sources/main.swift uses sameWindowGeometry (0.5-point tolerance) to compare the requested overlay frame with the actual frame. The user's requested (304.94375,265.64814,890.890625,570.87138) becomes (304,265,891,571). That minor adjustment causes immediate dismissal. The caller unconditionally reports success afterwards. Fixed in 0.9.2: a separate one-point placement-rounding policy, screen-to-view mapping using the actual content-view coordinates, and success propagation from display(). Do not weaken capture/window-movement checks indiscriminately.

The user also reports no overlay on the built-in display with v0.9, which lacks this final-frame guard. Its cause is unconfirmed and requires its own failure-path evidence. Do not represent the rounding correction as resolving that earlier failure.

Current diagnostics: UI bounds are in the analysis raster (downsampled to at most2560px width), window geometry in macOS points, output frames in AppKit bottom-left coordinates. The reported3024px Retina capture is downsampled before analysis; those numbers must not be compared directly as if all were points.

Live user acceptance of 0.9.2 is pending.
