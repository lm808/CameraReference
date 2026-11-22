# Camera Reference 1.1.12 — testing candidate

Build 71 corrects screenshot Compare selection-frame validation, shares the outer-bound raster cache and reuses opposite equal panes. Photo changes dismiss Screenshot overlays with or without AX view detection. Explicit screenshot placement can request Screen Recording; AX-only and manual snapping do not.

Keyboard shortcuts now include Top/Left/Right/Bottom/Loupe on Control+Option+Command+8/4/6/2/5. Defaults use number-row keys; recordings can use other keys. Active choices follow view detection. Existing overlay/floating bindings are preserved. Save an empty recording or use Clear to remove a binding.

Developer tools now includes guided AX calibration using five manual region selections. It reviews signed offset replacements, rejects inconsistent measurements and backs up the config before applying. It neither changes manual-placement preferences nor captures screenshots.

Native acceptance is pending. Main remains accepted 1.1.10 build 69. No package created.
