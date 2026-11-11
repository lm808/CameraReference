# Camera Reference — 1.0 alpha 2

Camera Reference is a macOS menu-bar companion for Lightroom Classic. It displays a camera JPEG over Lightroom’s working area, or in an independent floating window, so you can compare it with your RAW edit.

It can read a matching standalone JPEG or extract the embedded JPEG from a Canon CR3 using ExifTool. It does not change the RAW file, Lightroom catalogue or Develop settings.

## Install

Download the disk image for your Mac’s architecture from the repository’s GitHub Releases, when available. Drag **CameraReference.app** to **Applications**, install the included Lightroom bridge, then enable it in Lightroom’s Plugin Manager.

See [installation and upgrades](docs/INSTALL.md) for the complete steps, dependencies and alpha signing limitations. The app requires macOS 13 or later; automatic detection, capture preview and calibration snapping require macOS 14 or later. The bridge has been developed/tested with Lightroom Classic 15.6; other releases need verification. ExifTool is required for CR3 extraction and lossless embedded-JPEG export.

Upgrading from alpha 1 requires reloading **bridge 0.5.1** as well as replacing the app. Both now use `~/Library/Application Support/Camera Reference/Bridge/`; inactive legacy files are preserved under `Camera Reference/Backups/`.

## Use

1. Start Camera Reference and the Lightroom bridge. In Lightroom, choose **File → Plug-in Extras → Start / restart Camera Reference bridge** if needed.
2. Select a photo in **Develop**, with Lightroom’s image zoom set to **Fit**.
3. Use **Show overlay**, or **Control–Option–Command–J**, to toggle the camera reference.
4. Use **Show floating display**, or **Control–Option–Command–F**, for an independent reference. Change either shortcut in **Settings → Keyboard shortcuts**.

The layout section appears only when **Automatic viewing area** is enabled. Select **Full**, **Side-by-side → Left/Right**, or **Above-and-below → Upper/Lower** to match Lightroom. This selection guides detection; it does not change Lightroom’s view.

If automatic placement is unavailable, choose **Set image region** and select the entire photo backdrop between panels (or the chosen split pane), including its margins. Hold **Option** to snap to edges. Successful calibration switches to manual mode; cancelling preserves your previous settings.

**Clear region setting** discards the current saved/cached region without changing auto/manual mode. The next invocation either detects again or asks for manual calibration.

## Floating display and navigation

- **Command-scroll:** zoom around the pointer. **Two-finger scroll:** pan a zoomed image.
- At Fit, drag the floating picture to move its window. When zoomed, drag the picture to pan; the title bar always moves the window.
- Hover over the floating picture to reveal its title and controls.
- Double-click to reload the selected photo and reset Fit. Right-click for Fit, 100%, Reload and embedded-JPEG export.
- An open floating display keeps its own photo when Lightroom selection changes. Closing/reopening loads the current selection.

Initial floating size approximates a photo fitted into one side-by-side pane: half the Full working-area width and its full height. Both portrait and landscape use this rule.

## Placement and speed

The current selected photo’s JPEG bytes and decoded image are cached in RAM. Automatic UI bounds are reused for repeated toggles; window movement translates them, while resize, selection and relevant settings changes invalidate reuse. No disk image cache is created.

The overlay follows Lightroom and can be covered by other applications. In this alpha, overview/Space/minimisation transitions suspend it rather than release its image; return to the same unchanged window permits restoration. Partial off-screen movement uses normal clipping. These behaviours still need native acceptance on your display setup.

Background checks detect internal panel changes while Lightroom is active. They default to every **3 seconds**, use a lower-resolution capture, and are cancelled for foreground requests. Set the interval to **0** to disable them; use Clear region after panel changes in that case.

## Settings

GUI preferences and calibration state remain in macOS-managed preferences. Advanced settings are in:

`~/Library/Application Support/Camera Reference/config.conf`

Open it through **Settings → Edit config file**. Existing `detection.conf` is copied automatically when no new file exists; existing values are preserved and the original remains as a backup. See [configuration](docs/CONFIGURATION.md) and the [example file](config/config.example.conf).

`sideSearchPercent = 30` is the verified setting on the author’s current setup. New configs default to 30 and all four bounds set to `ui`. Existing explicit settings are preserved.

## Limitations and help

Placement assumes Lightroom Fit and a supported, clearly bounded viewport. Crop, lens/perspective corrections and RAW/JPEG aspect differences can prevent exact alignment. Split wipe views and automatic synchronisation with Lightroom’s zoom/pan are not supported. New automatic detection requires the Lightroom window wholly on one display; an already placed overlay can follow it partially off-screen.

See [troubleshooting and uninstalling](docs/TROUBLESHOOTING.md), [privacy](PRIVACY.md), [current acceptance tests](TESTING.md), and [release notes](RELEASE-NOTES.md). Report failures with app/bridge versions, layout/pane, diagnostics and a screenshot if you are comfortable sharing it.

## Development

Run `bash build.sh` to build the app, `bash test.sh` for automated checks, and `bash scripts/package.sh` to produce a native-architecture DMG and checksum under `dist/`. Builds require Apple command-line development tools; Lua bridge tests additionally use `texlua`. Packaging uses macOS `hdiutil`. Generated artifacts and user settings are not tracked in Git.

[AGENTS.md](AGENTS.md) maps the source and development rules. [Methods](docs/METHODS.md) records why the implementation works; [validation](docs/VALIDATION.md) separates measured evidence from native acceptance still pending. [Backlog](docs/BACKLOG.md) tracks future work; [changelog](CHANGELOG.md) records releases.

Licensing is undecided for this alpha; no open-source licence has been selected yet.
