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
