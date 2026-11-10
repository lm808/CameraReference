# Camera Reference 0.9.12 — menu, floating chrome and overlay behaviour

Quit the old companion and open `build/CameraReference.app`. For RAM reuse, reload the updated `CameraReference.lrplugin` (bridge 0.5.0) and run File → Plug-in Extras → Start / restart Camera Reference bridge. Older bridges remain compatible but disable caching. Nothing is installed or launched by the build scripts.

## New in 0.9.12

The layout section is hidden in manual mode and shown only for Automatic viewing area. Diagram icons use fixed template bitmaps. Existing manual calibration and photo sizing are unchanged; selecting a detection layout while in auto mode keeps automatic detection enabled.

The floating title and controls reveal when hovering anywhere over the photograph, on a consistent full-width background. Dragging the title bar moves the window at any zoom; dragging the zoomed photo pans it. At Fit, the whole picture remains draggable. Chrome overlays the picture without resizing it.

Overlay animation is always disabled. The config option was removed; valid legacy `overlayAnimation = true/false` entries are accepted and ignored, and new config files omit it. App deactivation no longer dismisses the overlay. It uses normal window level and periodically reconciles ordering directly above Lightroom, allowing other normal windows above Lightroom to cover it. This cross-application behaviour requires live acceptance, especially fullscreen/Spaces and dialogs.

A background UI-boundary check runs at most every 1.5 seconds while Lightroom is active in Develop with an automatic placement cache. It uses the existing capture/detector, keeping capture out of repeated-toggle foreground requests. Changed or unvalidated bounds invalidate placement and dismiss any stale overlay; the next invocation redetects. Foreground requests cancel background work. This adds periodic capture/CPU work while active, and detection is delayed rather than instantaneous. No check runs in manual mode, in another foreground app, or without cached bounds. Clear region remains the immediate fallback and does not change the auto preference. The user confirmed clearing already worked in 0.9.11; the new work is detecting changes without clearing.

See the new TESTING.md checklist. Bridge 0.5.0 is unchanged. Native ordering, hover interactions, background panel checks and speed/idle-cost acceptance remain outstanding.

## New in 0.9.11

The layout section directly below Show overlay offers **Full**, **Side-by-side → Left / Right**, and **Above-and-below → Upper / Lower**, with pane diagrams and checkmarks. Full uses the existing single-photo detector and original calibration keys. Each split pane has separate calibration and automatic/manual preference; a newly selected split pane starts in manual mode. Selecting a menu layout does not change Lightroom's view: select the matching layout in Lightroom too. Split automatic placement requires a supported divider or validated previously calibrated pane; otherwise it offers calibration. Wipe views are not supported.

Calibrate the entire chosen pane's UI backdrop, including photo margins, between panels and divider. Its position is stored relative to the Lightroom window. Successful calibration turns off Automatic viewing area for that layout/pane; cancelling changes nothing. **Clear region setting** clears only the current layout/pane's saved bounds and placement cache, preserving its Automatic viewing area preference. In auto mode the next invocation redetects; in manual mode it asks for calibration.

Repeated automatic overlay toggles on the same photo reuse UI placement without capturing the screen. Window movement translates cached bounds; resize, layout/settings/display changes, a new photo or bridge selection revision prevent reuse. Timing reports `placement cache hit; capture skipped`. Internal panel changes are not automatically tracked yet: clear the region after showing/hiding/resizing panels or changing Lightroom's internal layout. Image RAM reuse still requires bridge 0.5.0; no plugin update is needed from 0.9.10.

Initial floating size now fits **either photo orientation into half the Full UI area's width and its full height**, with the usual Fit inset. It no longer halves the already-fitted photo. Full manual calibration provides the baseline; a split calibration can approximate the full area by doubling the pane's split dimension. The floating title and controls fade over the stationary image when the pointer enters/leaves its top edge. At Fit or below, dragging the picture moves the floating window; above Fit it pans the picture. Cmd-scroll zoom and two-finger pan remain. Pinch support and its diagnostics were removed.

Overlay animation defaults to off. Set `overlayAnimation = true` in Settings → Edit config file to opt into native utility-window animation. Parsed config is cached, with file metadata checked on invocation and edits reloaded without restart. Invalid edits retain the last valid settings.

Fresh native acceptance checks are at the top of TESTING.md. Split placement, hover chrome, physical dragging and live latency still need user testing; synthetic tests do not establish Lightroom acceptance.

## New in 0.9.10

The current selected photo's extracted JPEG bytes and decoded image are retained in one RAM-only slot. Repeated overlay/floating invocations revalidate the selected photo and source files, then reuse the image. Selection changes (including switching away and back), bridge restart/stale heartbeat, source preference/file changes and quitting invalidate reuse. Nothing is written as an image cache. An already-open floating display still owns its independent image until closed/reloaded.

Bridge 0.5 uses a guarded active-photo observer found in installed Lightroom 15.6 plus selection polling. It publishes only an opaque session/revision, not photo names/paths, in selection state. If the undocumented observer cannot register, caching stays disabled. Diagnostics report RAM cache hit/miss/unavailable. Full live acceptance is still required.

Shortcut settings now use two compact aligned rows. New manual calibration always selects the full photo viewport backdrop between the panels, including margins; configured side bounds/inset are applied afterwards. Older photo/final-region calibrations require reselecting the UI area instead of being silently reinterpreted.

Landscape floating size now derives from a fresh detected Lightroom photo rectangle, at half its width and height, rather than the full desktop. Portrait behaviour is preserved. If detection cannot establish the photo size, automatic floating placement asks for a usable area instead of guessing. Manual UI calibration also supplies the fitting area.

Pinch events are routed directly through an app-local monitor to the image view; counters and last delta/zoom in Bridge diagnostics distinguish absent events from routing failure. Physical pinch remains unverified. Developer tools → Inspect Lightroom view state… performs bounded read-only Accessibility menu/checkmark inspection for split-view research. No Lightroom view is changed and split placement remains disabled.

## New in 0.9.9

Hiding the floating display now closes/releases it; showing again loads the current Lightroom selection. An open floating display still retains its photo until reload. Initial sizing explicitly sets the photo content size, with requested/content/outer-frame dimensions in diagnostics. Both shortcut recorders now share one Keyboard shortcuts dialog.

Pinch uses an AppKit magnification gesture recognizer; pan handling is unchanged. Physical pinch acceptance remains required. Native permission requests are retried on explicit feature use instead of being suppressed forever by an old preference; macOS controls permission-list membership and may still require manual intervention.

Manual setup asks whether the selection is UI working area (applies current Fit inset and UI/photo side choices) or Photo bounds (exact selected rectangle). Older calibrations preserve their previous interpretation; recalibrate to use UI-aware placement.

JPEG lookup no longer prefetches file properties for every entry in the RAW folder, only matching candidates. Timings distinguish lookup, failed source attempts, standalone decode and embedded decode/orientation overhead. No image cache or resolution reduction is introduced.

Optional updated plugin menu: File → Plug-in Extras → Camera Reference view API diagnostics. Reload the plugin from this repository to expose it; this is a read-only capability report and does not change views. The companion remains compatible with the current bridge. Split auto mode is not enabled yet.

## New in 0.9.8

Automatic viewing area is now in Settings. Developer tools contains all diagnostics and the status line. Settings groups display/source choices, two shortcut recorders, and configuration/maintenance. Edit config file opens the existing settings file.

Show/Hide floating display preserves the current photo and zoom when hidden. Its default shortcut is Control–Option–Command–F, configurable separately from the overlay shortcut. Landscape initial sizing is half the width and height of a Fit photo on the current display's available desktop area; portrait sizing retains the accepted behaviour. Image views accept indirect touch events and keyboard focus in nonactivating panels; physical trackpad acceptance remains required. Panning only moves a zoomed image that exceeds its viewport.

Bridge diagnostics and Show last result / timing now expose bridge, JPEG loading/extraction, capture, raster, detector and total-to-panel times. Timings contain no file paths or pixels. The bundled icon has been re-registered with Launch Services; Privacy Settings icon visibility still needs checking after reopening System Settings.

## New in 0.9.7

Adds a bundled camera icon for Finder and macOS application surfaces. Detection behaviour is unchanged from 0.9.6.

## New in 0.9.6

`sideSearchPercent = 45` controls the side-border search interval. Edit it in Settings → Open detection configuration…; range 5–50, reloaded on the next invocation. 45 searches the leftmost/rightmost 45% of the window, 30 restores the earlier ranges, and 50 reaches the centre. Existing configuration files gain the new setting without overwriting other values or comments. Changing it invalidates cached bounds and saved layout overrides for the previous setting.

When a valid viewport is found beyond the configured interval, the app says “Working area too narrow for automatic placement—enlarge it or calibrate manually.” and offers **Calibrate manually…** or **Cancel**. The wider diagnostic search never displays an overlay. Other failures retain their general explanation. Cancelling preserves automatic mode and calibration.

## New in 0.9.5

Side-border searches now reach 45% of the window width from each edge (previously 30%), allowing fixed-width side panels around a narrow photo viewport. The supplied 900 × 702 pt window failure is reproduced exactly before the change and detects the visible viewport afterwards. Complete-rectangle evidence and ambiguity thresholds are unchanged. Extremely narrow or unsupported layouts can still fall back to calibration.

## New in 0.9.4

Capture now uses a display-bound filter containing only the selected Lightroom window and its children, with an explicit crop to that window. A full-width interpretation of the supplied small-window screenshot reproduces the reported displaced detection; the correct window crop aligns the detected viewport and Fit photograph. Native capture acceptance remains to be tested. Automatic capture requires the window wholly on one display; manual calibration remains available otherwise.

Entering fallback calibration no longer disables automatic detection immediately. Manual mode is selected only after accepting a new region; cancelling preserves the current mode and saved region. Diagnostics include capture mode, display frame, source crop and analysis raster dimensions.

## New in 0.9.3

The menu now shows the running app version at the top. The menu and Bridge diagnostics both read the version from the app bundle metadata.

## New in 0.9.2

Fixes the confirmed 0.9.1 immediate-dismissal regression: final panel placement permits up to one point of rounding on each edge and dimension. Capture/window-movement checks retain their existing strict tolerance. The photo viewport is converted from screen coordinates through the actual window and content view, preserving its intended position after rounding. Failed placement no longer gets overwritten by a success message.

Diagnostics include the actual content bounds, photo viewport, visibility and display scale, plus rejected off-display regions. This does not establish the cause of the earlier v0.9 built-in-display failure. Live built-in-display and full-screen testing is still required.

## New in 0.9.1

This patch preserves the accepted 0.9 snapping, side bounds and Fit inset. It focuses on resize and macOS full-screen transitions. Full-screen placement still requires your live test; a specific root cause has not yet been established.

- Geometry changes observed through the existing timer invalidate cached viewing areas and dismiss an overlay in the old location. Space and display changes also invalidate cached geometry. No screenshots are taken by this observer.
- Capture is matched to the exact Lightroom window ID using current window-list coordinates. A 150ms stability check precedes capture, and the frame is checked again afterwards and before display. Transient changes retry up to three times. If still unstable, the app asks you to invoke again after the transition; it does not discard calibration or switch to manual mode.
- Cache keys include window position, size, pixel scale and primary-display geometry.
- The borderless overlay bypasses AppKit's automatic window-position constraint and explicitly sets the requested frame. If the actual frame differs, the app dismisses it instead of leaving a knowingly displaced overlay.
- Bridge diagnostics now include capture window origin, content-filter rectangle, primary-display bounds, calculated photo/overlay screen coordinates and requested/actual overlay panel frame. All coordinates are geometry only: no paths or image contents are logged.

Small-window detection limits are unchanged. If no reliable UI rectangle is found, the existing manual-calibration fallback remains. Split-view support is still deferred.

## Scope

Use single-picture Develop view at Lightroom's **Fit** zoom. Reference and Before/After layouts are deferred: this build does not search for internal dividers or ask to use a split pane. The plugin reports the active module, not the main view mode; choose the single-picture view yourself.

## Detection configuration

Settings → **Open detection configuration…** opens a commented plain-text file in TextEdit:
`~/Library/Application Support/Camera Reference/detection.conf`

Save your edits. The file is reloaded at the next detection or calibration, without restarting. Existing visible overlays/calibration sessions do not change midway; dismiss and invoke again. Invalid settings produce a message and retain the last valid settings in the current app session. After restart, defaults are the fallback. Missing keys use defaults; duplicate/unknown keys are rejected. Clear all region data does not erase configuration.

| Setting | Default | Meaning |
|---|---|---|
| left / right | ui | Each side independently accepts ui or photo |
| top / bottom | photo | Photo bounds calculated from Fit geometry |
| sideSearchPercent | 45 | Search inward from each horizontal window edge, range 5–50 percent |
| fitInsetPoints | 18 | Minimum margin inside detected UI viewport, range 0–100 points |
| verticalSnapFraction | 0.25 | Minimum vertical segment length/window height, range 0.05–1 |
| horizontalSnapFraction | 0.25 | Minimum horizontal segment length/window width, range 0.05–1 |
| snapDistancePoints | 8 | Option attraction distance, range 1–30 points |
| snapGapPoints | 4 | Small permitted gaps in an edge, range 0–12 points |
| snapContrast | 4 | RGB channel difference threshold, integer 1–64 |

The outer UI rectangle is found first. The JPEG is fitted and centred inside that rectangle minus the inset. Each side then selects the UI edge or calculated photo edge. The photograph retains the same position/scale for all 16 combinations, including asymmetric choices. UI-bound sides include the background margin; the JPEG does not expand to fill that extra margin.

Photo-bound means **calculated at Fit**, not traced from image contrast. Dark photographs therefore do not require visible photo edges. Cropping, perspective/lens corrections and different RAW/JPEG proportions can still prevent alignment. Lightroom zoom/pan is not synchronised.

## Margin estimate

The supplied 2048-pixel-wide screenshot has viewing-area top/bottom near y95/y957 and photograph top/bottom near y109/y944: approximately 13–14 image pixels of vertical background. At the assumed 2560-point window scale, this is about 16–18 points. Default 18 is a rounded empirical starting value; the screenshot alone does not establish its original point scale or an Adobe-defined constant. Tune fitInsetPoints if alignment needs adjustment. The other supplied screenshot also shows roughly 14 pixels of vertical margin.

## Detection and calibration

Enable Settings → **Automatic viewing area** for automatic overlay placement. Developer tools → **Find viewing area** now loads the current selected photo's JPEG for its oriented aspect ratio, then previews the configured region. It does not reuse a previous photo's aspect ratio. This can perform an in-memory extraction. No screenshot or extracted-image cache is written.

Preview: Return accepts, drag adjusts, Escape cancels. A manual correction is retained for the same detected layout, settings and aspect ratio. Clear all region data before comparing automatic placement with new settings if you previously accepted a manual correction.

Settings → **Set image region…** captures edges once. Hold Option to align full crosshair lines independently; release for free selection. Long edges are filtered relative to the Lightroom window; short UI/photo details are rejected. Small gaps are allowed. Escape cancels and retains the previous calibration. Screen Recording permission is needed for detection/snapping, not free manual selection.

If detection fails, automatic overlay offers Calibrate/Cancel. Accepting a calibration switches automatic mode off; cancelling preserves the current mode. Re-enable automatic mode to test detection after accepting a manual region. Manual calibration persists across sleep/wake; resize suspends stale geometry rather than erasing it.

Developer tools → **Preview captured Lightroom window…** displays the exact capture in memory with zoom/pan and no save command. Close it before calibration. Capture includes child windows on macOS 14.2+; the user confirmed it now matches Lightroom visually.

## Floating window and image controls

The independent floating reference stays on its current image until double-clicked or Reload is chosen. Its title shows filename, source and live zoom percentage. **100% means one photo pixel per physical display pixel**, including Retina. Resizing and zooming update the percentage.

- Pinch or Command-scroll: zoom around pointer.
- Two-finger movement or click-drag: pan. Plain coarse wheel/momentum ignored.
- Double-click either overlay or floating picture: reload current selection and reset Fit.
- Right-click: Fit / 100% / Reload / Save extracted JPEG.

The floating window uses the most recent detected area when its window geometry remains compatible, otherwise calibration or screen bounds. It can fetch the selected RAW in Library/Grid; overlays remain Develop-only.

## JPEG sources and export

**Prefer RAW-embedded JPEG** defaults Off. Both source-priority directions retain fallback. CR3 JpgFromRaw extraction is read-only, memory-only and on demand, with the current-photo RAM slot described above and no disk image cache. Standalone JPEG pairing supports other RAW extensions too.

Right-click **Save extracted JPEG…** is enabled only for an embedded reference in that view. It explicitly writes `<stem>_JpgFromRaw.jpg` beside its RAW, confirms replacement and briefly displays success. No second extraction is made. RAW/catalogue/Develop settings are never modified. Save failures can leave an incomplete export; normal extraction writes no JPEG file.

See `TESTING.md` for the short acceptance list. To build locally: `bash build.sh`; tests: `bash test.sh`.

## 0.7.1 detection patch

At 2560 × 1349, resampling the supplied screenshot exposed a false right boundary at a faint photograph-edge fringe. The vertical UI-border check now requires stronger contrast, rejecting that fringe while preserving the actual panel border in the fixture. This is a reproduced defect; whether it caused the reported live failure remains to be tested.

Failure diagnostics now list accepted left/right coordinates and top/bottom candidates. They no longer claim a viewport was detected or an inset applied when detection failed.

## 0.7.2 — manual snapping and clean-test reset

Calibration remains free by default. Hold **Option** to snap each coordinate to a sustained horizontal/vertical edge within 8 points; the selected edge is highlighted cyan. Option must be held at the first click to snap the starting corner and at release to snap the final corner. Releasing Option restores free placement for the moving corner. The top message explains the shortcut; Esc cancels and Return accepts a proposed region.

One Lightroom-window capture is analysed in memory before calibration is shown. Screen Recording permission is requested if necessary; macOS 14+ is required for snapping. No permission, no suitable edges or a 3-second preparation timeout leaves free calibration available. Snapping is local edge assistance, not proof of the correct viewport: nearby photo edges can also be eligible. Nothing is written to disk.

**Settings → Clear all region data** dismisses the overlay, cancels pending loading/detection/calibration, removes all manual region preferences/overrides and resets auto-boundary samples and Reference-pane confirmations. Old capture generations cannot repopulate the cache. Shortcut, source preference, ExifTool path and automatic toggle stay unchanged; the floating photograph stays open. No Terminal command or restart is required.

Removed Cancel region setup; use Esc. The automatic detector is unchanged from 0.7.1: the reported outer-rail failure remains an open issue. The next development iteration will focus on evaluating complete UI rectangles rather than accepting the side borders first.

## 0.8 — complete-rectangle automatic detection

Detection now collects alternative left/right/top/bottom boundaries and validates complete rectangles. All four sides need distributed edge evidence plus a consistent inner surround. Nested header rails are resolved within the same surround colour; a distinct dark, flat photo interior should not be chosen instead. Strong outer rails are no longer accepted before checking the top and bottom. Ambiguous or unsupported rectangles still fall back to manual calibration.

Diagnostics list candidate coordinates, rectangles checked and supported, and final bounds. Cached outer bounds are revalidated as complete rectangles before reuse. Fit inset remains the provisional 16 pt; no new Lightroom zoom/pan matching. Native capture and exact alignment require user tests.

Manual Option snapping now accepts sustained edges as short as 24 points and lower contrast (4 RGB levels), including UI panel edges. It still stays free without Option. This makes more photo details eligible too; the 8 pt attraction radius remains unchanged.

Camera reference can now appear in empty top/bottom or left/right margins, without covering photo pixels. The text is not rotated and is omitted if no margin can contain it.

Use Clear all region data before this detection test to avoid a saved manual override. No Lightroom plugin reinstall.
