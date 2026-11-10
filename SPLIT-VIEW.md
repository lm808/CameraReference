# Split-view groundwork

Authorised scope: Reference and Before/After with separate side-by-side or stacked panes; target left/upper pane; reject wipe layouts and uncertain evidence with manual calibration. Single-photo production behaviour remains unchanged in 0.9.8.

Sources/SplitLayout.swift implements test-only geometry for a known separate-pane layout, a measured divider and divider thickness. It reuses the current Fit inset and side choices, and handles portrait/landscape images. tests/split/main.swift passes both orientations and rejects unknown/wipe/missing/undersized panes. The helper is deliberately not linked into the shipped app yet.

The floating photo is a useful visual size reference, but split placement must fit to the actual pane. Half-width/half-height scaling is not correct for every image in a half-width/full-height pane, especially portraits and stacked layouts.

## Lightroom view identity

The existing bridge reports getCurrentModuleName only. A current public main-view getter has not been verified from Adobe's official SDK reference. showView is a command and getSecondaryViewName concerns another display; neither proves the current main Develop layout. Adobe's April 2026 community feature request asks for a main-view getter, but that is not sufficient evidence to rule out every installed SDK capability.

Sources inspected:
- https://developer.adobe.com/lightroom-classic
- https://community.adobe.com/feature-requests-676/p-sdk-api-to-get-the-current-view-in-library-1557715

Next low-cost check: installed SDK API reference or a read-only plugin capability report, followed by screenshots of the intended Reference/Before-After layouts in both orientations. No undocumented getter or automatic mode-switching is assumed. If no reliable view getter exists, require explicit user split mode plus validated divider evidence; do not silently reinterpret a photo edge as a pane divider. Live wiring waits for that evidence to preserve the working single-photo baseline.

## Installed Lightroom 15.6 inspection — 10 November 2026

Read-only inspection of `/Applications/Adobe Lightroom Classic/Adobe Lightroom Classic.app/Contents/Resources/LrApplicationView.lua` (Lua 5.1 bytecode) found `showView`, `getCurrentModuleName`, `isSecondaryDisplayOn`, `showSecondaryView`, and `getSecondaryViewName`. Supported command names include develop_loupe, develop_before_after_horiz/vert and develop_reference_horiz/vert. No main-view getter name is present in that module's string constants. This is direct installed-code evidence, not a guarantee about every dynamic API export.

The updated plugin includes ViewDiagnostics.lua, exposed through File → Plug-in Extras → Camera Reference view API diagnostics. It enumerates actual LrApplicationView function names, reads the current module and checks getter-name presence without invoking unknown functions. It does not call showView or inspect/edit photos. Runtime export evidence is the next check; reload the repository plugin to see the new command. If no getter is available, investigate Accessibility selected menu/toolbar states while switching layouts manually. Do not enable auto splitting from divider edges alone.

## Runtime conclusion and next probe

User supplied identical LrApplicationView exports in single-photo, Reference left/right and Reference upper/lower views. getMainViewName, getCurrentViewName and getCurrentView are nil in all three. That API does not expose the desired state on the installed version. 0.9.10 adds a bounded, read-only Accessibility menu/checkmark report to compare those views without automatically selecting menu items. A matching label or available command is not enough: selected/checkmark states must distinguish modes and orientation before enabling placement.

## 0.9.11 — explicit mode, isolated implementation

User chose explicit Full/Side-by-side/Above-and-below menu selection instead of waiting for an SDK getter. All four panes are supported. Full still calls the original singlePhoto detector; split-only detection validates a saved pane rectangle or requires a divider matching the selected orientation. Menu selection does not control Lightroom. Calibration preserves pane coordinates relative to the whole window, with separate keys/preferences for each pane. Fresh split auto detection is opt-in; new split panes start manual. No wipe inference. Raster fixtures exercise all four targets and reject orientation mismatch/single view; native screenshots/acceptance remain outstanding.

The read-only Accessibility investigation run from a temporary test executable on 10 November returned permission unavailable. No TCC reset or extra prompt was issued. Existing in-app Accessibility diagnostics remain the next way to compare panel visibility. Cached placement deliberately does not claim internal-panel change detection.

## 0.9.14

Split candidates must represent a combined viewport (minimum25% window width/height), with the largest supported same-surround rectangle preferred. Full keeps its innermost-rectangle rule. Explicit split divider scanning samples offsets2...7 from both opposite margins and requires support at each end; unrelated photo edges terminating inside the viewport should fail. Multiple distinct divider clusters remain ambiguous. Seeded panes reconstruct a two-pane candidate and must validate combined bounds plus divider; stale tiny gap seeds are rejected. Synthetic pairs and normal/1280px consistency cover all four panes. Exact screenshot reproduction remains unavailable because the attached local path no longer exists. Native test remains essential, particularly true boundary visibility/captions and small windows.
