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
| Screenshot | Finds viewport boundaries in captured pixels. With both AX options off, uses your menu view selection and the original detector. |
| Screenshot + AX view detection | Infers the view for the menu and screenshot detector. Placement still comes from pixels. |
| Screenshot + AX-assisted placement | Uses raw AX structure to guide a separate pixel search. Can be combined with AX view detection; calibrated AX offsets are not applied. |

Choose the desired pane for split views. These choices do not change Lightroom’s own view. Accessibility needs macOS Accessibility permission. Screenshot features need Screen Recording permission, which the app **does not request**: grant it yourself if wanted. Existing preferences are preserved when upgrading.

For manual placement, choose **Set overlay region…** and drag around the entire desired photo backdrop, including its inset margins. Hold **Option** for edge snapping if Screen Recording permission is already available; otherwise free dragging still works. Accepting switches to manual mode. Cancelling changes nothing. **Clear overlay region setting** clears bounds without changing auto/manual mode. Calibration and layout state are kept separately for Library and Develop.

## What happens while an overlay is open

In automatic Accessibility mode, **Update overlay with LrC view** defaults on:

- View, selected pane and panel changes reposition the existing reference, preserving its photo and zoom.
- Photo-selection changes load the new JPEG into the same overlay at Fit.
- Turning the option off makes those changes dismiss instead. Toggling the option alone does not dismiss.
- Failed updates retain the previous reference. An overlay that is off never opens automatically.

Confirmed module changes dismiss in every mode. Accessibility mode also checks the direct **View → Grid** menu selection to dismiss/block overlays in Library Grid; selection-mark reliability still needs native confirmation. Missing menu evidence is treated as unknown.

Screenshot with AX view detection now matches Accessibility with updating off: confirmed photo/view/pane/panel changes dismiss; positive Library Grid dismisses and blocks invocation. Missing evidence retains the overlay. Screenshot with inference off, manual and floating behaviour are unchanged. AX-assisted placement remains independent; no placement algorithms or calibrated offsets change. Background screenshot checks still invalidate cached placement only. Nothing automatically opens a dismissed overlay.

The overlay follows Lightroom movement and can be covered by other apps. Overview, minimise and Space transitions temporarily suspend it; a brief linger during minimise is a known limitation. Intermittent off-screen capture failures remain under investigation.

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

Use **Developer tools → Diagnostics…** for consolidated information. **Save diagnostics after invocation** automatically updates `~/Library/Application Support/CameraReference/Diagnostics/latest.txt`, including AX evidence. No screenshot is saved. Capture previews are under **Developer tools → Capture / bridge actions**; they show raw captures even if placement rejects their geometry. **Developer tools → Show AX placement preview** draws independent boundary outlines.

See [troubleshooting](docs/TROUBLESHOOTING.md), [privacy](PRIVACY.md), [remaining tests](TESTING.md) and [current release notes](RELEASE-NOTES.md). Fit alignment can differ after cropping, perspective/lens corrections or differing RAW/JPEG aspect ratios. ARW preview size varies by camera. Library split screenshot failures associated with status text remain unresolved; assisted fixes need further testing.

## Development

[Architecture and source map](docs/ARCHITECTURE.md) describes ownership, mode routing and asynchronous guards. [Methods](docs/METHODS.md) explains current implementation; [research findings](docs/AX-ASSISTANCE.md) records evidence and limitations. [Validation](docs/VALIDATION.md) retains test evidence, [backlog](docs/BACKLOG.md) tracks remaining work, and [historical notes](docs/HISTORICAL-NOTES.md) preserves superseded investigations. [AGENTS.md](AGENTS.md) defines contributor constraints.

Run `bash test.sh` for automated checks. `bash scripts/stage.sh` builds and refreshes the stable app in `release/`; use `--testing` in a separate candidate worktree for the purple testing app. Run only one copy at a time: settings and bridge are shared. `build/` is intermediate output. Packaging is explicit via `scripts/package.sh`; it does not rebuild. See the source-build guide before replacing a working app.

Licensing remains undecided. No open-source licence has been selected.
