# Implementation methods that work

This is the implementation reference, not a chronological experiment log. Keep it aligned with source and record uncertainty separately in VALIDATION.md/BACKLOG.md.

## Selection and image loading

The Lua bridge publishes the active module and responds to tokenised requests for the selected file. Reply tokens and END markers reject stale/partial responses. Bridge 0.5 adds an opaque session/revision sidecar, an active-photo observer with guarded registration, and polling. If that undocumented observer cannot register, image reuse is disabled rather than assuming selection continuity.

ImageSource.swift selects standalone or embedded JPEG according to preference, with fallback. CR3 extraction uses ExifTool with binary pipes, cancellation/timeouts and stderr handling; RAW data is read only. Orientation is reconciled before display. A single RAM cache entry includes image/bytes and file/preferences fingerprints. Epoch changes—including away and back—prevent reuse. An already-open floating display is independent.

Export.swift writes the view's retained embedded snapshot only on explicit Save, preserving compressed JPEG data while setting orientation. It checks existing/symlink/stale destinations and asks before replacement. No new extraction is needed for that export.

## Coordinate systems and capture

CG/ScreenCaptureKit window geometry is top-left screen coordinates; AppKit is bottom-left. Convert once using the primary display's top-left height relationship (`appKitRect`). Window movement must use deltas in the same coordinate system. Retina pixels are not points.

Capture uses a display-bound filter including only Lightroom's selected window and children, with an explicit display-local source crop. Wholly contained windows retain this accepted path. Off-screen/spanning windows use a short-lived SCStream and accept one complete frame. The frame's boundingRect multiplied by scaleFactor locates content in the bitmap; screenRect locates that content in screen points. The parent window is mapped into that rectangle and cropped before detector/snapping coordinates are computed. Reject missing, clipped, distorted or out-of-buffer metadata rather than assuming the entire bitmap equals the parent. This normalization is a 1.0.12 candidate requiring native validation. No sourceRect is set for independent-window capture. Capture remains in RAM; stop the stream on success/error/cancellation, with a three-second frame timeout. Movement stability checks remain in place.

Metadata references: [Apple SCStreamFrameInfo](https://developer.apple.com/documentation/screencapturekit/scstreamframeinfo), and [WebRTC's boundingRect/scaleFactor pixel crop](https://webrtc.googlesource.com/src/+/bf85c38fb360040c0a6f303a97a03b5929f57011/modules/desktop_capture/mac/screen_capturer_sck.mm).

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

## Capture alignment and minimise diagnostics

The 1.0.7 window-only fallback produced shifted placement in native tests. Its metadata matched the full parent dimensions, but this did not validate the pixels. Apple documents that single-window capture ignores `sourceRect`: https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/sourcerect . The accepted display-bound crop stays unchanged. Fresh off-screen placement and automatic snapping now decline rather than accepting displaced bounds. Cached placement translation, already-visible overlays and manual calibration are not cleared by this failure.

Window-only capture remains available through explicit preview, without setting sourceRect. A separate on-screen baseline preview holds one image in memory while the user moves the same Lightroom window without resizing. The latest preview logs both geometries, output sizes, content extent and scale; it warns on a different window or point size. No pixel correspondence is inferred from those dimensions. Close releases the image, callback and baseline metadata. Live pixel comparison is performed only by the user. No correction of detection bounds is applied without that evidence.

An optional AX observer listens for host miniaturise/deminiaturise notifications on common run-loop modes. Miniaturise suspends immediately on receipt and overrides lagging AX attributes for 0.4 seconds; subsequent polling can recover if a restore notification is missed. This does not establish that notification delivery precedes the animation. Failed initial AX binding retries at most once per second, without prompting. Settings → Enable minimise monitoring invokes the existing feature-triggered permission flow. Permission is never granted programmatically.

Binding reports missing permission, AXWindows failure, unreadable/nonmatching/ambiguous frames or a unique match. Notification creation and each registration report their AX error separately; keep a supported notification even when the other is unsupported, with polling as fallback. Diagnostics include current AXMinimized status, receipt counts and bounded uptime-based event/suspension/restoration history. Only geometry/status is logged, not window titles or images. Native timings and permission state remain to be supplied by the user.

## 1.0.9 changes

User reported the on-screen and uncropped off-screen previews identical. Fresh detection and calibration snapping now use that no-sourceRect window-only path; on-screen display capture and Full/split detector are unchanged. This supersedes 1.0.8’s diagnostic-only guard, but native placement still needs testing.

Overlay movement prefers the matched AX logical frame while retaining CG visibility. Resize and restoration coordinates must settle for 0.3 seconds before updating the saved host origin; ordinary same-size movement remains immediate. This prevents accepting transient scaled geometry as the new base. Native AX geometry behaviour must still be verified; no claim that AX notifications arrive before animation.

Diagnostics now use a selectable, scrollable six-section window with Copy all. Performance is emitted once. Capture tools invoked outside Develop show an explicit message. Testing builds use a separate bundle ID/name and purple native icon; a shared UserDefaults suite preserves the existing GUI preferences and config/bridge locations. Startup refuses another recognised copy before touching IPC. Default builds remain stable. Ad-hoc signing is unchanged, so separate identity is not a promise of durable permissions across rebuilds.

## Testing permission identification (1.0.10)

Stable and testing already had different bundle IDs, but used identical app/executable filenames. Testing now stages as CameraReference Testing.app with executable CameraReferenceTesting and a large T badge. This removes ambiguity when selecting it in System Settings; it is not proof that duplicate names caused the denied grant. Existing ambiguous generated testing payloads are moved under ignored build/retired-testing.* during staging; stable payloads are not moved.

The native permission request is attempted once per process per permission, while public preflight checks continue on feature use. False preflight still blocks capture; no security checks or designated requirements are weakened. Permission messages identify the exact running path and recommend a relaunch if the matching entry is enabled. No valid code-signing identity was returned by the available keychain query; ad-hoc signing remains. Live permission recovery is unverified.

## Library/Develop support (1.0.11 candidate)

Audit found no Develop-only dependency in activeCatalog/getTargetPhoto/getRawMetadata, embedded/standalone decoding or geometric UI border capture. Restriction was explicit app/bridge policy. Library and Develop are now the only allowed modules for requests; bridge 0.5.3 enforces the same policy, including floating requests. Existing floating displays remain independent. A confirmed module change cancels pending requests/capture/calibration, dismisses the overlay and invalidates placement. Unknown heartbeat state alone does not dismiss. Asynchronous image/capture results verify their originating module before display.

Library calibration/automatic-mode keys use a library. prefix in the same existing preferences domain; Develop keys stay unchanged. Library defaults automatic mode on when absent. Clear region removes only the active module/layout calibration and never its auto/manual preference. No view getter was invented: Library Loupe placement requires native acceptance; Grid/Survey/Compare are not claimed supported. AX-derived viewport geometry and 50/50 splits are deferred.

AX host matching first verifies public main/focused-window geometry, then scans the entire returned AXWindows list within a 150 ms budget and ranks by area. Only an exact unique host geometry match is accepted. A time-budget exhaustion reports incomplete enumeration instead of choosing a panel. This removes the fixed 16-window blind spot; no AX layout-based photo placement is added.

## Module layout and presentation suspension (1.0.12)

Develop retains the historical overlayLayout preference. Library uses library.overlayLayout in the same shared domain and defaults Full only when absent. The enum includes the pane. Calibration keys are unchanged; unknown module samples retain the last known module for layout selection.

Before translating an overlay, compare CG presentation size with AX logical size. A proportional shrink greater than two points on both axes while logical dimensions remain at the saved size temporarily suspends the overlay. A matching logical resize, ordinary translation or clipped width alone is not evidence. Existing restore settling and user-dismissal rules remain. No private API, global input monitor or extra polling timer is added. This can reduce lingering only if CG exposes the animation early enough; native acceptance is required.

## Capture error reporting (1.0.13)

The outer capture handler must preserve error domain/code and localized description, including up to three nested causes, together with capture mode, parent/filter geometry and requested dimensions. Do not replace all failures with permission advice. Frame failures distinguish conversion status, missing metadata, geometric rejection and crop failure; retain the expected parent, actual buffer dimensions and frame rectangles/scales. This is necessary to diagnose off-screen failures without altering capture geometry speculatively. Capture preview starts independent performance timing.

The user accepts brief minimise lingering; further command/input monitoring is deferred. The 1.0.12 shrinking check did not demonstrate earlier suspension in the supplied trace. Keep current lifecycle behaviour without claiming synchronised minimisation.
