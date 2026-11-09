# Camera Reference 0.9.4 — small-window capture patch

Quit the old companion and open `build/CameraReference.app`. No Lightroom plugin reinstall or restart. Nothing is installed or launched by the build scripts.

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

Enable Development testing → **Automatic viewing area (experimental)** for automatic overlay placement. Developer tools → **Find viewing area** now loads the current selected photo's JPEG for its oriented aspect ratio, then previews the configured region. It does not reuse a previous photo's aspect ratio. This can perform an in-memory extraction. No screenshot or extracted-image cache is written.

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

**Prefer RAW-embedded JPEG** defaults Off. Both source-priority directions retain fallback. CR3 JpgFromRaw extraction is read-only, memory-only and on demand, without an extracted-image cache. Standalone JPEG pairing supports other RAW extensions too.

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
