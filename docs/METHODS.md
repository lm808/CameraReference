# Implementation methods that work

This is the implementation reference, not a chronological experiment log. Keep it aligned with source and record uncertainty separately in VALIDATION.md/BACKLOG.md.

## Selection and image loading

The Lua bridge publishes the active module and responds to tokenised requests for the selected file. Reply tokens and END markers reject stale/partial responses. Bridge 0.5 adds an opaque session/revision sidecar, an active-photo observer with guarded registration, and polling. If that undocumented observer cannot register, image reuse is disabled rather than assuming selection continuity.

ImageSource.swift selects standalone or embedded JPEG according to preference, with fallback. CR3 extraction uses ExifTool with binary pipes, cancellation/timeouts and stderr handling; RAW data is read only. Orientation is reconciled before display. A single RAM cache entry includes image/bytes and file/preferences fingerprints. Epoch changes—including away and back—prevent reuse. An already-open floating display is independent.

Export.swift writes the view's retained embedded snapshot only on explicit Save, preserving compressed JPEG data while setting orientation. It checks existing/symlink/stale destinations and asks before replacement. No new extraction is needed for that export.

## Coordinate systems and capture

CG/ScreenCaptureKit window geometry is top-left screen coordinates; AppKit is bottom-left. Convert once using the primary display's top-left height relationship (`appKitRect`). Window movement must use deltas in the same coordinate system. Retina pixels are not points.

Capture uses a display-bound filter including only Lightroom's selected window and children, with an explicit display-local source crop. This fixed shifted captures in non-maximised windows. Wholly contained windows retain this path. Clipped/spanning windows use a desktop-independent window filter, cropping the parent frame relative to the filter content extent; if that extent does not contain the complete parent, reject rather than stretch visible pixels. Do not substitute display or child-surface width for the parent width. Stability checks reject movement during capture.

Analysis raster dimensions can differ from capture dimensions. Compute x/y scale from actual raster and window sizes; apply configured point insets through these scales. Background checks cap capture width at 1280; normal detection is not reduced for this optimisation.

## Full viewport and photo fit

Full detection generates UI-border candidates and validates complete rectangles with sustained edge evidence and consistent inner surround. Photo geometry is calculated from JPEG aspect ratio and configured Fit inset, not traced from photo content. The single-photo path remains the established baseline.

`sideSearchPercent` controls where side boundaries can be sought. 45 helped a narrow window; 30 resolved earlier wide/split failures; the current preferred default is 40 and avoids unwanted inner rectangles. There is no universally verified adaptive rule yet. Preserve user's value through upgrades.

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

Background validation defaults to 3 seconds while Lightroom is active in Develop with eligible auto placement. A 1280px capture compares UI bounds with 4-point tolerance; a change/unvalidated result invalidates cached placement for the next invocation but retains the visible overlay. Foreground work cancels it. Interval 0 disables only this capture loop. A separate 0.2-second metadata timer tracks windows; a float-only 80ms pointer sample drives hover chrome.

## Overlay lifecycle and ordering

The overlay is nonactivating and floats only while Lightroom is active. App activation notifications lower it immediately when another app activates; the timer is a fallback. Inactive ordering places it above its Lightroom host at normal level so other apps can cover both. While floating it avoids timer-driven ordering calls. Do not keep it globally floating across app switches or dismiss merely because another app becomes active.

Movement allows partial off-screen clipping. AppKit must not constrain the borderless overlay back inside a display. Resizing invalidates geometry.

Suspend retains the image while the host is invisible, minimised, on another Space or overview is active. Restore after a short settling interval without imposing a selection/size/module prerequisite. Resize invalidates cached geometry but keeps the current image and translates its origin with the host. Bridge failure, changed panels or uncertain detection cannot dismiss it. A confirmed absent host in a successful all-window enumeration or explicit user dismissal releases content. Display changes invalidate future placement only.

Native `.transient`/`.ignoresCycle` flags suppress overview participation. Public CG window metadata is used to recognise large Dock-owned overview surfaces; no private notification/API is used. This heuristic and App Exposé variants require native acceptance. Do not claim perfect macOS overview detection from unit tests.

## Floating window and chrome

Initial photo size fits into half the Full UI width and its full height, then applies the usual inset, for both orientations. Chrome overlays full-size content so fading does not resize the picture. A single window-coordinate pointer test avoids child-tracking flicker and handles the pointer already inside at creation.

At Fit/below, photo drag moves the window; above Fit it pans. Title-bar drag always moves. Cmd-scroll zooms around the pointer; precise two-finger scroll pans. Pinch was intentionally removed. Overlay dragging does not move its host-aligned frame.

## Evidence and known limits

See VALIDATION.md for accepted user results and measurements; TESTING.md for the current alpha checklist. Full/split fit assumes Lightroom Fit and compatible RAW/JPEG geometry. Native Mission Control and off-screen behaviour is not established by geometry-only tests. Preserve accepted functionality while narrowing changes to the failing path.

## Unified support directory

App and bridge 0.5.2 use CameraReference/Bridge. Settings and plugins are siblings. The companion merges the old spaced directory after old writers stop, seeds existing settings before waiting, preserves differing file conflicts, and removes the empty old directory. It discards known stale protocol files rather than replaying them. See CONFIGURATION.md.

## Build, staging and packaging

build/ is internal. scripts/stage.sh builds then checksum-syncs changed components into release/, which is the user-tested payload. scripts/package.sh reads its app version/architecture and packages that folder without rebuilding. Patch bumps accompany delivered updates; minor/major bumps follow the documented user-triggered release convention.

## Avoiding unnecessary overlay updates (1.0.2)

The geometry timer applies a frame-origin change only for a nonzero host translation. Window ordering requires the overlay to remain above its host, not immediately adjacent: intervening Lightroom-owned windows are tolerated. An intervening foreign window still causes correction so another application can cover Lightroom and its overlay. Diagnostics count actual frame moves and ordering calls since show. These counts help test zoom/pan flicker; native improvement is not established by synthetic ordering tests alone.

1.0.3 changes the window-level strategy after the user reported flicker on every click in 1.0.2. The earlier adjacency-only fix was insufficient. Dialog/sheet and native overview behaviour need explicit acceptance; do not claim the floating approach has passed live tests.

## Dialog and minimise handling (1.0.4 candidate)

When Accessibility is already granted, bind a read-only AX window to the selected host by geometry and inspect minimise/focused dialog/sheet state with short messaging timeouts. Do not prompt from the timer. The fallback uses on-screen window IDs/opacity and new substantial titled Lightroom windows above the host, excluding known panes and untitled redraw surfaces. Window names are not logged. Dialog presence lowers to normal level; closing restores the accepted floating behaviour. Thumbnail-sized geometry suspends rather than translating the overlay into the Dock. Native confirmation is required, particularly when AX is unavailable.

## Whole-region zoom and ARW (1.0.5)

ReferenceView separates the Fit rectangle (imageViewport, original position and minimum margin) from its drawing boundary (the full overlay content area). ImageNavigation clamps pan against that boundary using the unchanged Fit scale/centre; pointer zoom and actual-pixel zoom still refer to the original fitted image. Returning to Fit resets pan/scale exactly. Floating views normally have identical Fit/drawing bounds.

CR3 continues to request JpgFromRaw only. ARW probes JpgFromRaw then PreviewImage under a shared extraction time budget, chooses the largest decodable JPEG by pixel count, and reuses the existing orientation, RAM cache and export pipeline. Candidate bytes remain in memory; missing/invalid tags may fall back, cancellation propagates and per-image byte/decode limits remain enforced. Diagnostics report the selected tag. Embedded source labels are generic JPEG; export keeps the historical _JpgFromRaw suffix for compatibility.

Optional real-file check (read-only; no image output): compile tests/arw-sample/main.swift with Sources/Core.swift, Sources/ImageSource.swift and Sources/Export.swift, then pass a local ARW path. Requires ExifTool. It checks extraction, orientation/export in memory, cache reuse and unchanged RAW hash/mtime. Do not commit the sample.

A fresh bridge heartbeat reporting `library` is an explicit overlay dismissal condition. The existing module timer uses `hide()` to release a visible/suspended overlay and cancel pending overlay requests. Unknown/stale module state is not a dismissal signal; floating displays are independent.

## Off-screen capture and minimise notifications (1.0.7 candidate)

The off-screen fallback uses Apple's public `SCContentFilter(desktopIndependentWindow:)`; the existing Full/split detector and point/raster mapping are unchanged. Cache keys distinguish capture modes/extents. Preview/calibration share the same capture. Background checks still pause off-screen. Verify native content extent and child composition through diagnostics/preview before declaring this fallback accepted. API reference: https://developer.apple.com/documentation/screencapturekit/sccontentfilter

An optional AX observer listens for host miniaturise/deminiaturise notifications on the common run-loop modes. Miniaturise suspends immediately and overrides potentially lagging AX attributes for 0.4 seconds; subsequent polling can recover even if a restore notification was missed. Window visibility must also recover before restoring. Failed initial AX binding retries at most once per second while an overlay exists, without prompting for permission. Lifecycle polling also runs in common modes during tracking. With no Accessibility permission or unsupported notifications, the existing window-list fallback remains; native minimisation is not claimed fixed without testing. Diagnostics report whether notifications are active.
