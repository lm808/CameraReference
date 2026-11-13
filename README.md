# Camera Reference — 1.0.11

Camera Reference is a macOS menu-bar companion for Lightroom Classic. It displays a camera JPEG over Lightroom’s working area, or in an independent floating window, so you can compare it with your RAW edit.

It can read a matching standalone JPEG or extract the embedded JPEG from Canon CR3 or Sony ARW using ExifTool. It does not change the RAW file, Lightroom catalogue or Develop settings.

ARW extraction checks `JpgFromRaw` and `PreviewImage`, choosing the largest valid JPEG by pixel dimensions. Available preview size depends on the camera/file; it may be much smaller than the RAW. The original CR3 extraction path is unchanged. Diagnostics identify the chosen tag. Export retains the existing `_JpgFromRaw.jpg` filename convention for either tag.

## Install

Download the disk image for your Mac’s architecture from the repository’s GitHub Releases, when available. Drag **CameraReference.app** to **Applications**, install the included Lightroom bridge, then enable it in Lightroom’s Plugin Manager.

See [installation and upgrades](docs/INSTALL.md) for the complete steps, dependencies and alpha signing limitations. The app requires macOS 13 or later; automatic detection, capture preview and calibration snapping require macOS 14 or later. The bridge has been developed/tested with Lightroom Classic 15.6; other releases need verification. ExifTool is required for CR3/ARW extraction and lossless embedded-JPEG export.

For candidate testing, run **release/CameraReference Testing.app** after `bash scripts/stage.sh --testing`. The purple Camera Reference Testing app has a separate permissions identity; stable retains its teal icon. Run only one copy at a time; settings and the bridge are shared. Ad-hoc signing can still require permission approval after testing updates. build/ is internal. This update requires bridge **0.5.3**. Stop old copies before consolidation; see the upgrade instructions.

## Use

1. Start Camera Reference and the Lightroom bridge. In Lightroom, choose **File → Plug-in Extras → Start / restart Camera Reference bridge** if needed.
2. Select a photo in **Library Loupe or Develop**, with Lightroom’s image zoom set to **Fit**.
3. Use **Show overlay**, or **Control–Option–Command–J**, to toggle the camera reference.
4. Use **Show floating display**, or **Control–Option–Command–F**, for an independent reference. Change either shortcut in **Settings → Keyboard shortcuts**.

The layout section appears only when **Automatic viewing area** is enabled. Select **Full**, **Side-by-side → Left/Right**, or **Above-and-below → Upper/Lower** to match Lightroom. This selection guides detection; it does not change Lightroom’s view. Library and Develop remember their own layout and pane.

If automatic placement is unavailable, choose **Set image region** and select the entire photo backdrop between panels (or the chosen split pane), including its margins. Hold **Option** to snap to edges. Successful calibration switches to manual mode; cancelling preserves your previous settings.

**Clear region setting** discards the current saved/cached region without changing auto/manual mode. The next invocation either detects again or asks for manual calibration.

## Floating display and navigation

- **Command-scroll:** zoom around the pointer. **Two-finger scroll:** pan a zoomed image.
- At Fit, drag the floating picture to move its window. When zoomed, drag the picture to pan; the title bar always moves the window.
- Hover over the floating picture to reveal its title and controls.
- Double-click to reload the selected photo and reset Fit. Right-click for Fit, 100%, Reload and embedded-JPEG export.
- An open floating display keeps its own photo when Lightroom selection changes. Closing/reopening loads the current selection.

Initial floating size approximates a photo fitted into one side-by-side pane: half the Full working-area width and its full height. Both portrait and landscape use this rule.

Zoomed overlays can draw and pan across their whole region; Fit keeps the original photo alignment and inset.

## Placement and speed

The current selected photo’s JPEG bytes and decoded image are cached in RAM. Automatic UI bounds are reused for repeated toggles; window movement translates them, while resize, selection and relevant settings changes invalidate reuse. No disk image cache is created.

The overlay floats while Lightroom is active, preventing Lightroom clicks from covering it. When another app becomes active, it drops to normal window level so other applications can cover it. It follows Lightroom movement. In this alpha, overview/Space/minimisation transitions suspend it rather than release its image; return to the host window permits restoration, even after resize or selection changes. Partial off-screen movement uses normal clipping. Placement uncertainty invalidates the cache for the next invocation without dismissing the visible overlay. Switching modules dismisses the overlay; invoke again in Library or Develop. Other modules are not supported. The floating display stays open. You can also dismiss the overlay manually. These behaviours still need native acceptance on your display setup.

Background checks detect internal panel changes while Lightroom is active. They default to every **3 seconds**, use a lower-resolution capture, and are cancelled for foreground requests. Set the interval to **0** to disable them; use Clear region after panel changes in that case.

For minimise troubleshooting, **Developer tools → Bridge diagnostics…** provides six selectable sections with **Copy all**. Permission, window binding, notification events, placement and timing are separated. The redundant monitoring action is removed; if Accessibility access is missing, **Inspect Accessibility layout…** provides the existing permission flow. Movement prefers Lightroom’s logical Accessibility frame and holds resize/restoration geometry until stable. The overlay may briefly linger during minimise animation; this is an accepted limitation of the current cross-app monitoring.

To compare capture alignment, use **Developer tools → Keep on-screen capture baseline…** with Lightroom fully on-screen. Keep that preview open, move Lightroom without resizing, then use **Preview captured Lightroom window…**. The two named previews retain pixels only in RAM; close them to release the images. Compare full window corners and panel edges. Diagnostics include both geometries and warn if the window/size changed.

## Settings

GUI preferences and calibration state remain in macOS-managed preferences. Advanced settings are in:

`~/Library/Application Support/CameraReference/config.conf`

Open it through **Settings → Edit config file**. Existing `detection.conf` is copied automatically when no new file exists; existing values are preserved and the original remains as a backup. See [configuration](docs/CONFIGURATION.md) and the [example file](config/config.example.conf).

`sideSearchPercent = 40` is the current preferred setting. New configs default to 40 and all four bounds set to `ui`. Existing explicit settings are preserved.

## Limitations and help

Placement assumes Lightroom Fit and a supported, clearly bounded viewport. Crop, lens/perspective corrections and RAW/JPEG aspect differences can prevent exact alignment. Split wipe views and automatic synchronisation with Lightroom’s zoom/pan are not supported. Off-screen capture now uses the complete window surface without setting sourceRect, matching the user-tested preview path. Fresh placement and Option-snapping are enabled again; actual off-screen placement still needs acceptance. The fully on-screen display-capture path is unchanged.

See [troubleshooting and uninstalling](docs/TROUBLESHOOTING.md), [privacy](PRIVACY.md), [current acceptance tests](TESTING.md), and [release notes](RELEASE-NOTES.md). Report failures with app/bridge versions, layout/pane, diagnostics and a screenshot if you are comfortable sharing it.

## Development

See [source builds, manual installation and Git rollback workflow](docs/SOURCE-BUILD.md) to keep a known-good version while testing updates.

Run `bash test.sh` for automated checks and `bash scripts/stage.sh` to build and update the app you test in **release/**. `build/` holds internal compiler/test output. Only when packaging is requested, run `bash scripts/package.sh`; it packages the staged payload without rebuilding it.

Each delivered update increments patch (1.0.1 → 1.0.2). A requested packaged feature release increments minor and resets patch (1.1.0). Major revamps increment major and reset both smaller numbers only on the author's instruction (2.0.0).

Builds require Apple command-line tools; Lua bridge tests use texlua. Packaging uses macOS hdiutil. Generated build/, release/ and dist/ contents are not tracked in Git.

[AGENTS.md](AGENTS.md) maps the source and development rules. [Methods](docs/METHODS.md) records why the implementation works; [validation](docs/VALIDATION.md) separates measured evidence from native acceptance still pending. [Backlog](docs/BACKLOG.md) tracks future work; [changelog](CHANGELOG.md) records releases.

Licensing is undecided for this alpha; no open-source licence has been selected yet.

Library and Develop use separate saved calibration keys within the same GUI preferences file. Library starts in automatic placement mode; Develop settings are preserved. Use Library Loupe for single-photo alignment—Grid/Survey/Compare placement is not validated. AX-based viewport detection and a guessed 50/50 split remain deferred.

Diagnostic capture previews show the raw image even when geometry checks would reject overlay placement. Use **Developer tools → Preview captured Lightroom window…** to inspect padding or displacement, then copy Bridge diagnostics. A preview captures afresh and stays in RAM; it is not proof that placement is valid.

For Accessibility-to-screenshot mapping, run **Developer tools → Inspect Accessibility layout…**, then copy the **Accessibility & display map** section (or Copy all). It lists AX rectangles and display names/scales without reading titles or control values. Send an original full-display screenshot taken with Lightroom's geometry unchanged, and identify its D-number/name. Unavailable visibility properties are reported as unknown, not hidden.

### Candidate AX diagnostics



Experimental AX tools are grouped under **Developer tools → Experimental features** in the investigation build. Optional automatic view detection chooses the layout; the established screen detector still determines placement. AX preview outlines have independent, zero-default `# AX:` geometry settings in `config.conf`; preserve that prefix when editing so older apps can still read the shared file.

For investigation, enable **Save diagnostics after invocation** to maintain one text report at `~/Library/Application Support/CameraReference/Diagnostics/latest.txt`. **Diagnostics → Refresh AX** refreshes window mapping and toolbar-menu evidence and refreshes this file when saving is enabled. Manual **Copy all** remains available. No screenshots are saved automatically.

In the investigation build, automatic AX view detection polls while Lightroom is active. Saving diagnostics also gathers fresh window and toolbar-menu data after invocation; manual Refresh AX is optional.
