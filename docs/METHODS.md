# Implementation methods that work

This is the implementation reference, not a chronological experiment log. Keep it aligned with source and record uncertainty separately in VALIDATION.md/BACKLOG.md.

## Selection and image loading

The Lua bridge publishes the active module and responds to tokenised requests for the selected file. Reply tokens and END markers reject stale/partial responses. Bridge 0.5 adds an opaque session/revision sidecar, an active-photo observer with guarded registration, and polling. If that undocumented observer cannot register, image reuse is disabled rather than assuming selection continuity.

ImageSource.swift selects standalone or embedded JPEG according to preference, with fallback. CR3 extraction uses ExifTool with binary pipes, cancellation/timeouts and stderr handling; RAW data is read only. Orientation is reconciled before display. A single RAM cache entry includes image/bytes and file/preferences fingerprints. Epoch changes—including away and back—prevent reuse. An already-open floating display is independent.

Export.swift writes the view's retained embedded snapshot only on explicit Save, preserving compressed JPEG data while setting orientation. It checks existing/symlink/stale destinations and asks before replacement. No new extraction is needed for that export.

## Coordinate systems and capture

CG/ScreenCaptureKit window geometry is top-left screen coordinates; AppKit is bottom-left. Convert once using the primary display's top-left height relationship (`appKitRect`). Window movement must use deltas in the same coordinate system. Retina pixels are not points.

Capture uses a display-bound filter including only Lightroom's selected window and children, with an explicit display-local source crop. This fixed shifted captures in non-maximised windows. New capture requires a window wholly on one display; do not substitute the display width for the window width. Stability checks reject movement during capture.

Analysis raster dimensions can differ from capture dimensions. Compute x/y scale from actual raster and window sizes; apply configured point insets through these scales. Background checks cap capture width at 1280; normal detection is not reduced for this optimisation.

## Full viewport and photo fit

Full detection generates UI-border candidates and validates complete rectangles with sustained edge evidence and consistent inner surround. Photo geometry is calculated from JPEG aspect ratio and configured Fit inset, not traced from photo content. The single-photo path remains the established baseline.

`sideSearchPercent` controls where side boundaries can be sought. 45 helped a narrow window; 30 is verified on the author's current wide/split setup and avoids unwanted inner rectangles. There is no universally verified adaptive rule yet. Preserve user's value through upgrades.

Each of the four overlay sides chooses UI edge or calculated photo edge. Photo position/scale remain the same regardless of these choices. The photo viewport is converted through the actual native panel after AppKit rounding; placement accepts sub-point rounding, not a displaced panel.

## Split detection — accepted approach

First call the same Full detector for combined UI bounds. Do not introduce separate split outer-bound ranking or minimum-window-percentage rules. Earlier attempts caused UI coverage and tiny-gap placements.

Then scan ONLY the configured inset gap:

- Side-by-side: horizontal traces in the **bottom** margin find a vertical divider. Avoid top labels.
- Above-and-below: vertical traces in the **left** margin find a horizontal divider.

Use multiple traces spanning 20–80% of the inset to tolerate a divider stopping short of the edge. A candidate is a thin contrast line with matching background on both sides, supported by at least half the traces. Multiple distinct candidates or no supported line offer manual calibration. Search is within the central 20–80% of the combined viewport. The menu's selected pane selects the appropriate side of the measured divider.

Cropped real examples passed at full/half/quarter resolution; they test margin scanning, not full-window detection. Seeded manual regions do not override Full bounds in auto mode. Wipe is unsupported. The user confirmed all four split panes with both photo orientations using `sideSearchPercent = 30`.

## Manual calibration and GUI state

Select the entire intended UI backdrop including photo margins. Save its screen rectangle, window geometry and display association; translate with same-size host movement. Configured Fit/side rules determine the photo and overlay within it. Acceptance turns auto off; cancel preserves state. Clearing the current region preserves auto/manual preference and the JPEG RAM slot.

Background capture checks pause while the host is clipped or spans displays, including late capture results. Window metadata tracking continues; returning fully on-screen permits validation again.

GUI preferences/calibration stay in UserDefaults. Advanced config is parsed from config.conf with file-metadata caching; detection.conf is copied only if the new file is absent. Do not introduce competing sources of truth.

## Placement reuse and monitoring

PlacementMemory stores UI bounds, window identity/size, selection epoch, layout, geometry-config key and surround colour. Repeated valid toggles skip capture. Movement translates; resize, changed selection/mode/config or invalid display context prevent reuse.

Background validation defaults to 3 seconds while Lightroom is active in Develop with eligible auto placement. A 1280px capture compares UI bounds with 4-point tolerance; a change/unvalidated result invalidates placement and explains any dismissal. Foreground work cancels it. Interval 0 disables only this capture loop. A separate 0.2-second metadata timer tracks windows; a float-only 80ms pointer sample drives hover chrome.

## Overlay lifecycle and ordering

The overlay is normal-level, nonactivating and ordered immediately above the selected Lightroom window. Other windows can cover both. Do not use a globally floating overlay or dismiss merely because another app becomes active.

Movement allows partial off-screen clipping. AppKit must not constrain the borderless overlay back inside a display. Resizing invalidates geometry.

1.0 alpha separates **suspend** (order out, retain image/host/epoch) from **dismiss** (release content). A hidden host, Space/overview transition or minimisation suspends. Returning to the same visible host with unchanged dimensions/selection in Develop permits restoration after a short settling interval. Closed host, resize, changed selection during suspension, or explicit toggle/cancel dismisses. Display reconfiguration still invalidates.

Native `.transient`/`.ignoresCycle` flags suppress overview participation. Public CG window metadata is used to recognise large Dock-owned overview surfaces; no private notification/API is used. This heuristic and App Exposé variants require native acceptance. Do not claim perfect macOS overview detection from unit tests.

## Floating window and chrome

Initial photo size fits into half the Full UI width and its full height, then applies the usual inset, for both orientations. Chrome overlays full-size content so fading does not resize the picture. A single window-coordinate pointer test avoids child-tracking flicker and handles the pointer already inside at creation.

At Fit/below, photo drag moves the window; above Fit it pans. Title-bar drag always moves. Cmd-scroll zooms around the pointer; precise two-finger scroll pans. Pinch was intentionally removed. Overlay dragging does not move its host-aligned frame.

## Evidence and known limits

See VALIDATION.md for accepted user results and measurements; TESTING.md for the current alpha checklist. Full/split fit assumes Lightroom Fit and compatible RAW/JPEG geometry. Native Mission Control and off-screen behaviour is not established by geometry-only tests. Preserve accepted functionality while narrowing changes to the failing path.
