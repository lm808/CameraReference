# Camera Reference

A macOS menu-bar companion for Lightroom Classic. Display the camera JPEG over Lightroom’s working area, or in an independent floating window, to compare it with your RAW edit.

Camera Reference reads a matching standalone JPEG or extracts an embedded JPEG from Canon CR3 or Sony ARW using ExifTool. It does not modify RAW files, the catalogue or Develop settings.

## Install and start

The app requires macOS 13 or later; screenshot detection, capture previews and calibration snapping require macOS 14 or later. Embedded extraction/export requires ExifTool. The Lightroom bridge is version 0.5.3; development verification used Lightroom Classic 15.6. Other versions need verification.

See [installation](docs/INSTALL.md) for the app and bridge, or [building from source](docs/SOURCE-BUILD.md) for manual installation and keeping a known-good version. Packaged downloads are available only when a release has been published. Current builds are ad-hoc signed, not notarised.

1. Start the app and enable its bridge in Lightroom’s Plug-in Manager. If needed, choose **File → Plug-in Extras → Start / restart Camera Reference bridge**.
2. Select a photo in Library Loupe or Develop, with Lightroom at **Fit**.
3. Toggle **Show overlay** with **Control–Option–Command–J**.
4. Toggle the floating display with **Control–Option–Command–F**. Change shortcuts in **Settings → Keyboard shortcuts…**.

## Placement

**Settings → Auto-detect viewing area** enables automatic placement. Choose its method under **Detection method**:

| Method | Behaviour |
|---|---|
| Accessibility (default for new settings) | Uses panel geometry, view labels and toolbar state, with configurable geometry corrections. Always infers the view; no automatic screenshots or capture fallback. |
| Screenshot | Finds viewport boundaries in captured pixels. With AX view detection off, uses your menu view selection and independent pixel detection. |
| Screenshot + AX view detection | Infers the view for the menu and screenshot detector. Placement still comes from pixels. |

Choose the desired pane for split views. These choices do not change Lightroom’s own view. Accessibility needs macOS Accessibility permission. Explicit screenshot placement requests Screen Recording permission when needed. Accessibility placement, background checks and manual snapping do not request it. Existing preferences are preserved when upgrading.

For manual placement, choose **Set overlay region…** and drag around the entire desired photo backdrop, including its inset margins. Hold **Option** for edge snapping if Screen Recording permission is already available; otherwise free dragging still works. Accepting switches to manual mode. Cancelling changes nothing. **Clear overlay region setting** clears bounds without changing auto/manual mode. Calibration and layout state are kept separately for Library and Develop.

## What happens while an overlay is open

In automatic Accessibility mode, **Update overlay with LrC view** defaults on:

- View, selected pane and panel changes reposition the existing reference, preserving its photo and zoom.
- Photo-selection changes load the new JPEG into the same overlay at Fit.
- Turning the option off makes those changes dismiss instead. Toggling the option alone does not dismiss.
- Failed updates retain the previous reference. An overlay that is off never opens automatically.

Confirmed module changes dismiss in every mode. Accessibility mode also checks the direct **View → Grid** menu selection to dismiss/block overlays in Library Grid; selection-mark reliability still needs native confirmation. Missing menu evidence is treated as unknown.

Screenshot with AX view detection now matches Accessibility with updating off: confirmed photo/view/pane/panel changes dismiss; positive Library Grid dismisses and blocks invocation. Missing evidence retains the overlay. Screenshot without inference also dismisses on a confirmed photo-selection change; panel pixel checks only invalidate the cache. Manual and floating behaviour are unchanged. Screenshot placement uses pixel-validated outer bounds and equal splits; AX view detection never supplies placement edges. Background screenshot checks still invalidate cached placement only. Nothing automatically opens a dismissed overlay.

The overlay follows Lightroom movement and can be covered by other apps. Clicking an exposed overlay activates Lightroom and brings both forward. Overview, minimise and Space transitions temporarily suspend it; a brief linger during minimise is a known limitation. Intermittent off-screen capture failures remain under investigation.

## Floating display and navigation

- **Command-scroll:** zoom around the pointer. **Two-finger scroll:** pan a zoomed image.
- The floating window stays above ordinary windows and participates in Exposé/Mission Control.
- At Fit, drag the floating picture to move its window; when zoomed, drag to pan. The title bar always moves the window and appears when hovering over the picture.
- Double-click to reload the selected photo at Fit. Right-click for Fit, 100%, Reload and embedded-JPEG export.
- Floating displays keep their own photo until reload or reopening. Initial size approximates a photo fitted into half the full viewport width, using its full height.

Zoomed overlays use the whole placement region; Fit preserves the photo alignment/inset. Pinch zoom and automatic synchronisation with Lightroom zoom/pan are not supported.

## Settings, speed and diagnostics

GUI preferences use macOS preferences. Advanced settings are edited through **Settings → Advanced settings…**, with an **Open config file** button for the underlying `~/Library/Application Support/CameraReference/config.conf`. See [configuration](docs/CONFIGURATION.md). Fresh defaults include `sideSearchPercent = 40` and all four bounds set to `ui`; upgrades preserve explicit values.

The current selection’s JPEG is cached in RAM. Screenshot placement can reuse validated bounds; its background checks default to every **3 seconds** at reduced resolution. Accessibility reads fresh geometry instead and performs no automatic pixel checks. See [methods](docs/METHODS.md) for cache and polling details.

Developer tools are hidden by default; enable `showDeveloperTools` in Advanced settings to access them. Use **Developer tools → Diagnostics…** for consolidated information. **Save diagnostics after invocation** automatically updates `~/Library/Application Support/CameraReference/Diagnostics/latest.txt`, including AX evidence. No screenshot is saved. Capture previews are under **Developer tools → Capture / bridge actions**; they show raw captures even if placement rejects their geometry. **Developer tools → Show AX placement preview** draws independent boundary outlines.

See [troubleshooting](docs/TROUBLESHOOTING.md), [privacy](PRIVACY.md), [remaining tests](TESTING.md) and [current release notes](RELEASE-NOTES.md). Fit alignment can differ after cropping, perspective/lens corrections or differing RAW/JPEG aspect ratios. ARW preview size varies by camera. Pixel-only boundary detection can remain ambiguous on some photos; working-area reuse mitigates this without claiming reliable fresh detection in every case.

## Development

[Architecture and source map](docs/ARCHITECTURE.md) describes ownership, mode routing and asynchronous guards. [Methods](docs/METHODS.md) explains current implementation; [research findings](docs/AX-ASSISTANCE.md) records evidence and limitations. [Validation](docs/VALIDATION.md) retains test evidence, [backlog](docs/BACKLOG.md) tracks remaining work, and [historical notes](docs/HISTORICAL-NOTES.md) preserves superseded investigations. [AGENTS.md](AGENTS.md) defines contributor constraints. The [boundary audit](docs/BOUNDARY-AUDIT.md) records the 1.1.15 review and remaining maintenance seams.

Run `bash test.sh` for automated checks. `bash scripts/stage.sh` builds and refreshes the stable app in `release/`; use `--testing` in a separate candidate worktree for the purple testing app. Run only one copy at a time: settings and bridge are shared. `build/` is intermediate output. Packaging is explicit via `scripts/package.sh`; it does not rebuild. See the source-build guide before replacing a working app.

Licensing remains undecided. No open-source licence has been selected.

For window-stacking investigations, **Developer tools → Record window ordering (5-second delay)…** records fifteen seconds of window metadata after a five-second delay. Reports are saved separately under `~/Library/Application Support/CameraReference/Diagnostics/WindowOrdering/`; no screenshots or window titles are collected. These traces are only needed for a specific stacking investigation.

View shortcuts are configurable in **Settings → Keyboard shortcuts…**. Defaults use Control+Option+Command with 8 (Top), 4 (Left), 6 (Right), 2 (Bottom), and 5 (Loupe), accepting both number-row and numeric-keypad keys. They choose this app’s view/pane, not Lightroom’s view. Automatic view detection permits only the matching pane choices; manual Screenshot view selection permits all five. Assigned bindings appear in the menu. Save while a recorder is waiting for a key clears that binding; untouched bindings remain. Clear explicitly removes a binding. The existing overlay shortcut stays Control+Option+Command+J.

**Developer tools → Guided AX calibration…** lists six setups in one window: five windowed working areas (Develop Loupe with all shown; all hidden with toolbar; all hidden without toolbar; Develop Left/Right all shown; Library Compare all shown), then macOS full-screen Develop Loupe with all panels and toolbar hidden. Setup 1 also measures the actual photo at Fit: **six setups, seven rectangle selections**. Select the combined working area, including both panes and photo margins, excluding toolbars. Keep panel widths unchanged and use one display. The photo must match its untransformed camera JPEG; do not use crop/perspective edits. Each row can be reselected independently; red text identifies conflicting setups. Cancellation preserves the previous measurement. Measurements survive closing/reopening the guide within this app session; Reset or quitting clears them.

The guide hides itself during a three-second countdown, visible across Spaces; return to Lightroom. Escape cancels the countdown. The badge disappears before edge capture, then the shared selector opens. Hold Option to snap when Screen Recording permission is already granted; otherwise select freehand without a permission prompt. The guide reviews 12 proposed values, backs up the config and changes them only on Apply. It calibrates full-screen allowance and photo Fit inset as well as panel corrections; hidden base insets remain reference values. It never saves a manual region or changes auto/manual placement. Validate resized windows and Top/Bottom separately afterwards.

For contributors (human or agent), [respect the structure and abstraction boundaries](docs/CONTRIBUTING-STRUCTURE.md) before changing behaviour. The [source map](docs/ARCHITECTURE.md) describes current ownership.

**Developer tools → Reuse screenshot working area** is on by default and applies only to Screenshot mode. It preserves valid working-area geometry across photo changes and window moves, and derives new panes using 50/50 splitting. Develop can reuse the area across Loupe and either split direction; Library Loupe ↔ Compare requires fresh detection because the lower controls differ. Resize, confirmed panel changes, settings/module/display changes and **Clear overlay region setting** invalidate reuse. Background screenshot checks still run: an inconclusive check retains the last successful area when reuse is on; a confirmed changed boundary invalidates it. Turning this option off restores the earlier caches: same-photo/same-pane placement reuse and Loupe raster-boundary reuse; split captures perform a fresh outer search. It does not disable photo caching or affect AX placement. Switching either way clears geometry first.


The overlay and floating window context menus show **In-camera picture style** as a disabled first line. Canon CR3 (including C-RAW) uses PictureStyle; Sony ARW uses CreativeStyle (also used for Creative Look on newer cameras). The value belongs to the displayed photo, including cached references; missing metadata shows Unavailable. It describes the camera setting, not Lightroom processing. JPEG extraction and orientation are unchanged.

Developer tools is hidden by default. Open **Settings → Advanced settings…**, search for `showDeveloperTools`, set it to `true`, and Save to show it. The config is grouped by interface, shared Fit/region, screenshot checks, snapping and Accessibility geometry. A one-time layout migration preserves values and comments and creates `config.before-layout-1.1.13-<ID>.conf` beside `config.conf`. Stable and testing apps share this file.
