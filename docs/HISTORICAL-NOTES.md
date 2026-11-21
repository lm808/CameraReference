# Historical research notes

Superseded development notes, retained as evidence only. Current architecture and methods are in [ARCHITECTURE.md](ARCHITECTURE.md), [METHODS.md](METHODS.md) and [AGENTS.md](../AGENTS.md). Consolidated research findings are in [AX-ASSISTANCE.md](AX-ASSISTANCE.md). These are not current instructions or outstanding requirements.

## DEVELOPMENT.md

# Development workflow

Use this single Git working tree. Edit only the relevant source/tests; do not copy the project into a new version directory per iteration.

- Imported source snapshots: tags v0.9 and v0.9.1, in chronological order. These are imports of delivered files, not a reconstruction of the original development commits.
- Commit each coherent change with its rationale and validation. Inspect git diff before committing.
- build/ and compiler caches are excluded. Run ./build.sh and ./test.sh on macOS with command-line tools installed.
- Do not create routine ZIP releases. Build the app in place on the user's Mac when a test build is requested; do not launch/install it or control Lightroom without authorisation.
- Keep existing plugin compatibility. Split-view groundwork is now authorised; keep production single-photo behaviour stable until view identity and native divider evidence are verified.
- The repository is now on the user's Mac at ~/Documents/Codex/CameraReference. Build in this working tree; build products remain excluded from Git.

# Open display defects

Confirmed v0.9.1 regression: Sources/main.swift uses sameWindowGeometry (0.5-point tolerance) to compare the requested overlay frame with the actual frame. The user's requested (304.94375,265.64814,890.890625,570.87138) becomes (304,265,891,571). That minor adjustment causes immediate dismissal. The caller unconditionally reports success afterwards. Fixed in 0.9.2: a separate one-point placement-rounding policy, screen-to-view mapping using the actual content-view coordinates, and success propagation from display(). Do not weaken capture/window-movement checks indiscriminately.

The user also reports no overlay on the built-in display with v0.9, which lacks this final-frame guard. Its cause is unconfirmed and requires its own failure-path evidence. Do not represent the rounding correction as resolving that earlier failure.

Current diagnostics: UI bounds are in the analysis raster (downsampled to at most2560px width), window geometry in macOS points, output frames in AppKit bottom-left coordinates. The reported3024px Retina capture is downsampled before analysis; those numbers must not be compared directly as if all were points.

Live user acceptance of 0.9.2 is pending.

## Small-window investigation (0.9.4)

The user's unobscured 3024×1964 screenshot, cropped to x0/y66/w3024/h1776, reproduces the reported bounds (722,153,1301,1042) within one raster pixel. Cropping to the reported Lightroom window x240/y66/w2784/h1776 instead yields bounds (563,166,1414,1132), aligned with the visible UI. This is strong evidence of an incorrect capture extent, not proof of the internal ScreenCaptureKit cause. Do not hard-code a display-width correction. The new display-bound window filter has an explicit display-local sourceRect and retains child windows while excluding other apps. A window spanning displays is rejected for automatic capture.

Calibration fallback used to disable automatic mode before acceptance. It now changes mode only on accepting a new region, preserving mode on Escape/cancellation. The initial alert's Cancel already preserved mode.

## Narrow viewport detection (0.9.5)

User confirmed 0.9.4 fixes non-maximised placement. The new 900×702 pt failure reproduces exactly from the supplied screenshot: x612 and x1166 viewport borders fall outside the old 30%/70% side search ranges in its 1800px capture. Widening to 45%/55% finds (612,180,554,860). Border support, surround consistency and ambiguity thresholds stay unchanged; no capture-coordinate changes are needed. More extreme layouts may still require manual calibration.

## Configurable side interval (0.9.6)

sideSearchPercent defaults to 45 and accepts 5–50 percent from each side. The config store appends it to existing files when absent. Both viewport cache and manual-layout keys account for the interval. On unsupported rectangles, a bounded second search reaching the centre can identify a valid viewport outside the configured range and set workingAreaTooNarrow; its bounds are discarded. The automatic overlay fallback offers the user's exact narrow-area message and Calibrate manually…/Cancel. Generic detection failures are not relabelled as narrow.

## 0.9.8 follow-up

User accepted 0.9.6 for most cases. Polish build committed separately; native shortcut, trackpad and privacy-icon checks pending. Current audited backlog supersedes historical statuses. PERFORMANCE.md records CPU benchmarks and the remaining live timing gap. SPLIT-VIEW.md and test-only SplitLayout.swift start the authorised split-view work without changing production detection.

## Current-photo RAM cache authorisation (0.9.10)

The user explicitly authorised retaining extracted bytes plus decoded image in RAM while staying on the same selected photo, superseding earlier no-between-invocation caching. One slot is keyed by bridge session/selection revision, source preference and file metadata. Independent open windows retain their own displayed image. Bridge 0.5 uses installed LrApplication.addActivePhotoChangeObserver(functionContext, observer, callback), guarded because it is undocumented, plus polling; failure disables cache reuse. Observer callbacks increment revision even when a selection returns between polls. Missing/stale selection state or a response whose epoch no longer matches cannot hit the cache. Older bridge protocol remains compatible; the new selection metadata is separate from its existing response. Native observer and physical pinch acceptance still pending. Future discussion alone is not permission to work: wait for an explicit go.

## 0.9.11 authorisation and invariants

User explicitly authorised the next version after discussion and requested a fresh test list. Full uses unchanged detector logic and original preference keys; split modes have namespaced calibration and auto/manual state. Clear region clears current-mode geometry only and never changes auto preference or image RAM reuse. Accepted calibration always turns auto off. PlacementMemory stores UI bounds, window identity/geometry, epoch, geometry-config key, mode and surround colour; it is not an image cache. Different epochs cannot reuse it. UI capture/detection is skipped only on validated repeated placement. Window movement translates; resize/Space/display transitions invalidate. Panel changes remain unobserved and require Clear region.

Floating windows have full-size content with chrome overlaid, so frame size equals picture Fit viewport. Initial requested photo size fits into a half-width/full-height Full UI backdrop after inset, for both aspect orientations. Manual split backdrop can approximate the whole by doubling its split dimension. No physical interaction acceptance is claimed by offscreen geometry tests.

## 0.9.12

User clarified that Clear region already redetected correctly; only unobserved panel changes were stale. Preserve their TESTING.md notes. Manual placement is accepted: hide layout menu in manual rather than redesigning region storage. Identical AX samples expose only eight elements including a tiny icon, not panel geometry. Background validation therefore uses existing window capture/detection (1.5s minimum start interval), only with active Lightroom/Develop and valid automatic cache. It is cancelled on foreground work and guarded by job ID, epoch, mode, settings and window geometry. It invalidates geometry only, not the JPEG RAM slot. No guarantee of detecting a change before an immediate invocation; Clear region remains available.

Overlay is normal-level and uses AppKit order(_:relativeTo:) above Lightroom's visible main-window number, reconciling only when not adjacent in layer-zero order. App switching no longer dismisses. Fullscreen, Spaces and cross-process ordering still need native acceptance. Apple API reference: https://developer.apple.com/documentation/appkit/nswindow/order(_:relativeto:). No private window-server APIs or cross-process NSWindow parenting used.

## 0.9.13

Authorised combined scope includes menu-guided split work and slimming TESTING.md. SplitAxis argument defaults0 so existing callers/Full remain unchanged; selected split group searches only its corresponding divider orientation. Low-resolution checks may flag changes but never supply displayed placement; foreground detection stays normal resolution. Capture raster dimensions already prevent cache reuse across resolutions. Valid legacy animation values remain ignored. Manual mode/pane storage was not redesigned. Visible overlay translates on same-size movement; it is still dismissed on resize/Space/display changes. macOS icon metadata/Launch Services repair does not reset TCC.

## 0.9.14 Mission Control

Use public `.transient` + `.ignoresCycle` on the normal-level overlay; do not use private Dock notifications. Apple documents transient as hidden in Mission Control: https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/transient . Ordering has an explicit initial-show path; subsequent reconciliation does not reinsert a window missing from the onscreen list. Fullscreen/Space guards remain. Native verification is required.


## RESEARCH.md

# Architecture findings — 7 November 2026

## Evidence and limits

Adobe's official developer page confirms the Classic Lua SDK and plugin model. The separate Lightroom
cloud REST API operates on cloud assets and is not the interface for the active Classic Develop selection.
Adobe's current full SDK download is offered through Developer Console; I could not obtain/authenticate
that download here. The API detail below comes from Adobe-authored reference documentation hosted at
`lrc.mcor.dev` (a third-party mirror), supplemented by Adobe's official guide/search result and Apple's
installed macOS SDK headers. This is not a claim that the mirror is the newest SDK release.

| Capability | Evidence / confidence | Decision |
|---|---|---|
| Active photograph | `LrCatalog:getTargetPhoto()` documents the selected or most-selected photo, or nil. No Library-only restriction in that entry. | Call from a cooperative task in Develop; verify in the installed Lightroom. |
| Original path | `LrPhoto:getRawMetadata('path')` documents current or last-known path. | Independently check readability; Smart Preview availability does not imply an online original. |
| Current module | `LrApplicationView.getCurrentModuleName()` documents `develop` and other module names. | Reject other modules without switching modules. |
| Background work | `LrTasks` cooperative tasks / sleep are part of the SDK; `LrInitPlugin` starts the bridge. | No blocking wait on Lightroom's UI. Test startup, disable/re-enable and timeout behaviour. |
| File communication | SDK guide allows Lua `io`; `LrPathUtils` exposes home; `LrFileUtils` exposes recursive directory creation. | Request/response files in a dedicated local app-support folder. This protocol is our design, not an Adobe-provided bridge. |
| Socket alternative | `LrSocket.bind` documents localhost send/receive sockets. | Supported alternative, deferred because it adds connection lifecycle machinery for V1. |
| Develop viewport / zoom / pan | No corresponding complete readout identified in the inspected ApplicationView/DevelopController reference. | Do not claim it is impossible in every SDK version. Manual rectangle for V1; investigate newest SDK and macOS Accessibility exposure for V2/V3. |
| Drawing inside Develop | No documented injection point for arbitrary image content in the Develop canvas identified. | Separate native window above Lightroom, without patching Lightroom. |
| Overlay without activation | AppKit `NSPanel`, `.nonactivatingPanel`, `orderFrontRegardless`; available in installed headers/compiler. | Opaque floating panel. Verify focus, Spaces and full-screen behaviour on the user's setup. |
| Global shortcut | Apple HIToolbox `RegisterEventHotKey` header documents keycode/modifiers and exclusive registration. It is not thread-safe. | Call on the main thread. Avoid event taps/global key monitors. Test actual delivery and any system conflicts. |
| Menu-bar-only app | AppKit NSStatusItem and LSUIElement agent-app flag. | No Dock presence; settings and quit in menu. |
| JPEG orientation/colour | ImageIO applies embedded orientation; AppKit draws the decoded image with its colour space. | Verify Canon portrait files, ICC profiles and visual appearance; do not promise equivalence to Lightroom soft-proof/HDR modes. |

## Minimum viable architecture

One small read-only Lightroom plugin plus one dependency-free AppKit application. The companion owns
keyboard handling and display; the plugin is the authoritative source of the selected path.
A UUID per request, completion marker, deadline and cancellation prevent stale or partial bridge replies
from being mistaken for a new selection. JPEG decoding happens off the app's main thread. No image export,
JPEG catalogue import, preset application, selection changes or Develop writes are required.

Manual placement deliberately narrows V1: each invocation gets a fresh photograph but uses a saved
screen rectangle. It cannot yet meet the eventual requirement to follow a moved viewport or changed
zoom/pan automatically. Do not expand V2/V3 until selection and Fit overlay testing pass.

## Next milestones and acceptance gates

1. **Selection:** two different RAW photographs return the correct adjacent JPEGs while staying in Develop.
2. **Overlay:** toggle without focus loss; correct portrait orientation; useful Fit alignment; no file/setting changes.
3. **Lifecycle:** plugin disable/re-enable, app restart, missing JPEG, external disk offline, busy Lightroom and shortcut cancellation.
4. **V2 investigation:** inspect whether macOS Accessibility exposes a stable image viewport; if it does not,
   retain manual calibration or explicitly discuss screen-capture/image-analysis tradeoffs before implementing them.
5. **V3 investigation:** obtain reliable read-only zoom and pan state or document the need for a visual registration
   approach. Do not infer pan from mouse position, or promise pixel matching from undocumented controls.

## Sources

- Adobe Classic developer overview: https://developer.adobe.com/lightroom-classic/
- Adobe SDK download portal: https://developer.adobe.com/console/servicesandapis
- Adobe cloud API scope: https://developer.adobe.com/lightroom/lightroom-api-docs/
- Adobe Classic SDK Guide (Adobe distribution host): https://ioconsolerykerprodcdn.azureedge.net/static/installers/lr/sdk/2022/cross_platform/v13/doc/Lightroom%20Classic%20SDK%20Guide_1655133965.pdf
- Adobe-authored reference, mirrored: https://lrc.mcor.dev/modules/LrCatalog.html
- https://lrc.mcor.dev/modules/LrPhoto.html
- https://lrc.mcor.dev/modules/LrApplicationView.html
- https://lrc.mcor.dev/modules/LrDevelopController.html
- https://lrc.mcor.dev/modules/LrSocket.html
- https://lrc.mcor.dev/modules/LrPathUtils.html
- https://lrc.mcor.dev/modules/LrFileUtils.html
- Apple NSPanel: https://developer.apple.com/documentation/appkit/nspanel
- Apple panel style: https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel
- Apple agent-app flag: https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement
- Installed Apple SDK: `Carbon.framework/Frameworks/HIToolbox.framework/Headers/CarbonEvents.h`, RegisterEventHotKey documentation.

Web availability was incomplete: official PDF retrieval failed and Apple web pages require JavaScript;
macOS declarations and shortcut semantics were checked against installed SDK headers and compilation.

## 0.2 correction: deferred plugin initialisation

The 0.1 request file existed on the user's Mac, but no response file had been written. This local
observation establishes that the companion wrote its request; it does not by itself identify why
Lightroom did not answer. On rechecking Adobe's guide, the startup declaration was incomplete:
`LrForceInitPlugin = true` forces startup for this type of plugin **only if it contributes a menu item**.
Otherwise initialisation is deferred until first use. Version 0.1 provided neither condition.

Version 0.2 adds both, with a manual restart command for use in the existing Lightroom session.
This corrects a documented configuration defect; successful real integration still requires the
user's retry. A once-per-second heartbeat, guarded loop errors, status file and diagnostics menus
now distinguish a missing/stalled bridge from a running bridge that cannot answer.
The loop also services a pending request after delayed startup. UUID matching continues to prevent
an old response being accepted by a new request.

The original mock test executed Init.lua directly and therefore missed Adobe's lazy-loading rule.
The revised test checks both manifest conditions and exercises queued cooperative tasks, delayed
startup and manual restart. It remains a stand-in, not a test of Lightroom itself.

The plugin accepts SDK `fileFormat` values RAW and DNG, so it is independent of camera brand.
https://lrc.mcor.dev/modules/LrPhoto.html documents these values.


## 0.3: source extraction, floating window and layout investigation

ExifTool's official application documentation confirms binary output with -b and disabling user configuration
with a first -config empty-string option. Production code uses argv directly (no shell), selecting JpgFromRaw
and no write options. Standalone decoding and embedded decoding share the same rendering path. Optional
RAW orientation is another read-only numeric query when JPEG metadata lacks it.
Source: https://exiftool.org/exiftool_pod2.html (also checked installed ExifTool 13.55 application documentation).

Apple exposes read-only AXUIElementCopyAttributeValue and AXImage roles, but those API capabilities do not
establish Lightroom's actual accessibility layout. Version 0.3 adds an opt-in bounded investigation. It accepts
only an unambiguous large central image with matching aspect ratio, otherwise falls back. This heuristic
requires user testing and may yield no candidate. No screen capture or AX actions are used.
Sources: https://developer.apple.com/documentation/applicationservices/1462085-axuielementcopyattributevalue
and https://developer.apple.com/documentation/applicationservices/kaximagerole

AppKit NSPanel provides the floating window; NSWindow.contentAspectRatio maintains proportions during
user resizing. Double-click is handled in the image view; selection changes alone never trigger a refresh.
Sources: https://developer.apple.com/documentation/appkit/nspanel
and https://developer.apple.com/documentation/appkit/nswindow/contentaspectratio

Manual fallback still cannot automatically correct Lightroom's padding, window movement, crop or zoom/pan.
The old working 0.2 folder/build remains untouched. No running Lightroom app was inspected or manipulated.

## 0.5 screen and input investigation (8 November 2026)

Documented Apple mechanisms:
- [SCScreenshotManager.captureImage](https://developer.apple.com/documentation/ScreenCaptureKit/SCScreenshotManager/captureImage(contentFilter:configuration:completionHandler:)) captures one image using a content filter.
- [SCContentFilter](https://developer.apple.com/documentation/screencapturekit/sccontentfilter) supports a desktop-independent single window.
- [CGRequestScreenCaptureAccess](https://developer.apple.com/documentation/coregraphics/cgrequestscreencaptureaccess()) requests screen-capture access; preflight checks it.
- [VNRecognizeTextRequest](https://developer.apple.com/documentation/vision/vnrecognizetextrequest) supplies local OCR.
- [hasPreciseScrollingDeltas](https://developer.apple.com/documentation/appkit/nsevent/hasprecisescrollingdeltas) distinguishes precise deltas, NOT device identity. Some mice also provide precise deltas.

Installed SDK headers confirm screenshot manager availability at macOS 14, ignoreShadowsSingleWindow at 14,
and includeChildWindows at 14.2. Guard these APIs; baseline companion remains macOS 13. ScreenCaptureKit is
not called by tests. This feature does not capture system audio, cursor, other apps, or save screenshot files.

Unverified design assumptions: visible English Navigator/Histogram labels provide reliable anchors; long
neutral separators identify the viewing area; captured window coordinates match displayed content coordinates.
These are explicitly experimental and need real Lightroom test reports. The detector does not infer Fit zoom,
crop state, internal photo padding or pan. Candidates are shown for user confirmation, never auto-applied.


## 0.5.1 OCR follow-up

The previous parser required each complete OCR line to equal a whitelist label, so grouped UI headings were
rejected. It now uses whole-word matches and Vision's word bounding boxes. Capture retains the filter's display
pixel scale, capped at 6000 × 4000 pixels. Diagnostics add capture dimensions and OCR region count, without
exposing arbitrary recognised text.

Apple's [minimumTextHeight documentation](https://developer.apple.com/documentation/vision/vnrecognizetextrequest/minimumtextheight)
reports a default of 1/32, whereas the installed SDK header says 0.0. We therefore explicitly set 0.0 to preserve
small text, without claiming that the default caused the user's failure. Real Lightroom recognition remains
unverified; the test uses synthetic UI labels only.


## 0.6 image-first strategy

The earlier OCR strategy is no longer used. Pixel analysis proposes edges by sustained changes and uniformity
on either side; candidate rectangles must be large/central, agree with the current reference aspect ratio, have
at least three supported sides, a mostly uniform outside ring and a varied interior. Similar competing regions
are rejected. This is deterministic Swift CPU code, not a trained model or a documented Lightroom capability.

One missing edge can be inferred from aspect ratio, which is useful but ambiguous with a cropped RAW. The current
release therefore requires visual preview/acceptance. Synthetic fixtures establish algorithm behaviour only;
real Lightroom image recognition has not been validated. Frame capture still uses Apple's ScreenCaptureKit.

## 0.9.4 explicit capture extent

Apple's SCStreamConfiguration documentation describes sourceRect and scalesToFit; the installed macOS SDK specifies sourceRect in the display's logical coordinate system. SCContentFilter(display:including:) captures only the selected windows, excluding the desktop and Dock. The SDK describes includeChildWindows as applying to display-bound sharing. Use this path with an explicit display-local window crop, instead of assuming a desktop-independent capture's composited extent equals SCWindow.frame.

- https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration
- https://developer.apple.com/documentation/screencapturekit/sccontentfilter/init(display:including:)

The supplied screen screenshot reproduces the wrong bounds when analysed at full display width. This supports an extent mismatch but does not independently establish which native surface or framework behaviour enlarged the previous capture. Native acceptance remains required.


## SPLIT-VIEW.md

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

## Runtime conclusion and next probe

User supplied identical LrApplicationView exports in single-photo, Reference left/right and Reference upper/lower views. getMainViewName, getCurrentViewName and getCurrentView are nil in all three. That API does not expose the desired state on the installed version. 0.9.10 adds a bounded, read-only Accessibility menu/checkmark report to compare those views without automatically selecting menu items. A matching label or available command is not enough: selected/checkmark states must distinguish modes and orientation before enabling placement.

## 0.9.11 — explicit mode, isolated implementation

User chose explicit Full/Side-by-side/Above-and-below menu selection instead of waiting for an SDK getter. All four panes are supported. Full still calls the original singlePhoto detector; split-only detection validates a saved pane rectangle or requires a divider matching the selected orientation. Menu selection does not control Lightroom. Calibration preserves pane coordinates relative to the whole window, with separate keys/preferences for each pane. Fresh split auto detection is opt-in; new split panes start manual. No wipe inference. Raster fixtures exercise all four targets and reject orientation mismatch/single view; native screenshots/acceptance remain outstanding.

The read-only Accessibility investigation run from a temporary test executable on 10 November returned permission unavailable. No TCC reset or extra prompt was issued. Existing in-app Accessibility diagnostics remain the next way to compare panel visibility. Cached placement deliberately does not claim internal-panel change detection.

## 0.9.14

Split candidates must represent a combined viewport (minimum25% window width/height), with the largest supported same-surround rectangle preferred. Full keeps its innermost-rectangle rule. Explicit split divider scanning samples offsets2...7 from both opposite margins and requires support at each end; unrelated photo edges terminating inside the viewport should fail. Multiple distinct divider clusters remain ambiguous. Seeded panes reconstruct a two-pane candidate and must validate combined bounds plus divider; stale tiny gap seeds are rejected. Synthetic pairs and normal/1280px consistency cover all four panes. Exact screenshot reproduction remains unavailable because the attached local path no longer exists. Native test remains essential, particularly true boundary visibility/captions and small windows.

## 0.9.15 — replaces0.9.14

User evidence: Full finds correct combined viewport in split layouts. Reuse detectViewport(singlePhoto:true) unchanged, then scan the configured bottom or left inset. Tests use actual supplied margin crops at three resolutions, plus independent pipeline and scanner fixtures.0.9.14 outer ranking/minimum-size/opposing-margin logic is removed, not further tuned. A saved pane is not an alternative source of outer bounds. Missing/ambiguous thin-line candidates fail safely. Crop regression can be run with `bash test.sh <stacked-left-margin.png> <side-by-side-bottom-margin.png>`; original images stay outside the repository.


---

## Archived METHODS.md before the 1.0.32 documentation reconciliation

The following is a historical snapshot. Statements about current defaults, menus, pending implementation and candidate status apply to the time of writing, not the current app. Consult METHODS.md, AX-ASSISTANCE.md and ARCHITECTURE.md for current guidance.

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

## Diagnostic previews are not placement (1.0.14)

Independent-window preview returns the original converted image before checking frame geometry. Missing rectangles/scales or inconsistent parent bounds are reported as metadata, not grounds for withholding a preview. No crop or normalization is applied. Pre/post-capture stability and final display geometry checks still protect placement, but do not discard an acquired preview. Cancellation, module/request guards and actual capture failures remain in force. A raw preview must never populate placement state; candidate remains nil and lastProbe is not updated. The on-screen baseline retains the existing display crop.

The preview is a new capture, not a retained image from an earlier failure. Native abnormal-frame evidence is still needed; do not infer a reliable pixel correction from inconsistent metadata alone.

## Explicit AX/display mapping diagnostics (1.0.15)

Inspect Accessibility layout gathers an independent, read-only mapping report; it never supplies geometry to placement or lifecycle code. Display data is sampled on the main thread, AX/CG window inspection on a worker. All AXWindows entries receive numbered rows, even after the four-second scan budget; each AX call has a short timeout. Rectangles retain three decimals in global top-left points. Main/focused identity is checked by AX equality; duplicate geometry is labelled without deduplicating. Optional AXVisible must not be treated as reliable visibility. Public CG rows are restricted to Lightroom and matched by geometry only, with IDs/onscreen/layer/alpha reported separately. No window titles/control values/filenames are queried. A before/after main-frame check flags movement during the scan. No screenshot or AX action is performed.

The display map includes D-number/name, CGDisplayID, CG global bounds, AppKit frame/usable frame, main/built-in flags, backing scale, mode pixel dimensions, rotation and mirror target. Actual supplied screenshot dimensions determine final point-to-pixel mapping; do not blindly assume backing scale or full native panel resolution. The diagnostic snapshot persists in a dedicated Copy all section until another explicit inspection. The old image-element probe is retained unchanged.


## AX diagnostic trial (1.0.16 candidate)

`AXTrial.swift` is a separate geometry experiment, not a placement backend. Main/focused host and all AX window rectangles are read on a worker with a time budget, matched to public CG window metadata for opacity/layer. IDs and array indices are not persistent identities. Hidden panels must not subtract space. Visible tall edge panels and wide top/bottom strips define a raw inner rectangle; missing panels use 18-point window insets. This is intentionally not exact: panel windows overlap margins and the filmstrip top does not exclude the photo toolbar.

Reference/Active label-size rectangles (observed 50–160 pt wide, 15–40 pt high) provide paired horizontal/vertical evidence near the midpoint. No clear pair means single view, independent of menu selection. Begin with a 50/50 division; constrain it into the nearby label gap and report when this changes the midpoint. Duplicate geometry is deduplicated. Information rectangles are never required: they updated while hidden in one session but disappeared when the window objects were recreated in the smaller-window sample (34 AX entries became 15).

Optional child panels show both pane outlines after production display returns; they are transparent, click-through, generation-guarded and removed with the overlay or disabling the option. AX failure does not invalidate production geometry. Existing ViewportDetector/ScreenProbe and calibration logic are untouched. Green denotes single/left/top; purple right/bottom. No code automatically chooses this trial for actual placement.

Observed evidence: panel hide combinations matched separate deltas; top panel 42 pt, filmstrip 123 pt, toolbar approximately 44 pt. Both hidden sidebars yielded x=18…2542 on the 2560-point HP display. Reference labels remained visible with photo information off in both split orientations. These are sample observations, not universal constants. Smaller-window data retains labels/panels but not information areas. Library, screen scales, unusual panel widths, hidden-all states and session changes still need native validation.


### Experimental AX geometry and view inference

The accepted screenshot boundary scanner is unchanged. Opt-in live view inference polls every two seconds while Lightroom is active, trusted and in Library/Develop; it avoids overlapping requests and updates menus only when layout changes. Clear label pairs identify split orientation; a successful scan without a pair means single. Failed scans retain the previous inference. Only the layout enum is supplied to the existing detector; AX bounds position the real photo only when the separate AX-only backend is explicitly enabled.

The independent preview uses surrounding window rectangles and supplementary CG alpha metadata to estimate the combined area, then label geometry to split it. Both panes are drawn. Diagnostics retain all window rows, display mappings, opacity/visibility evidence, labels, raw/adjusted bounds and uncertainty. CG metadata is explicitly distinguished from AX evidence.

The bounded View-menu reader (250 elements, depth six, 0.5-second best-effort budget) reads titles and shortcuts without opening menus or taking actions. A unique Hide Toolbar command means shown; Show Toolbar means hidden. Permission/focus/read/ambiguity failures use toolbarUnknownFallback and are labelled as assumptions. English menu titles are currently required. Readings are fresh per preview/diagnostic collection, with previous state used only when lastKnown is explicitly selected (in-memory, scoped by Lightroom process/module; no history assumes shown). Toolbar height is not exposed: state-dependent cumulative offsets remain configurable; see CONFIGURATION.md for calibrated v2 defaults. Toolbar state is internal; the user config controls only the failure policy.

Preview offsets and hidden-edge insets are excluded from the production placement cache key. All config keys now use normal assignment syntax; obsolete v1 fields are removed. Preserve explicit personal config values; append only missing keys. General edge offsets add to hidden insets and the effective toolbar correction.

Opt-in report saving collects window mapping and toolbar evidence automatically after invocation, with generation/module guards and one collection at a time. It atomically replaces CameraReference/Diagnostics/latest.txt; no images or clipboard writes. Optional Refresh AX updates the same consolidated report. Deep AXChildren/AXSections/attribute exploration is isolated in tools/AXExplorer, built only under build/AXExplorer. Its explicit saved probes live in ignored investigations/ax-reports, never in release staging.

See AX-ASSISTANCE.md for evidence and possible future uses; these do not authorise changes to working screenshot detection.


### AX-only placement backend (1.0.24)

Manual placement is checked first. For automatic placement, the AX switch branches before screenshot-cache lookup or Screen Recording permission. The original screenshot route remains below the branch, unchanged. AX queries the panel/label map and toolbar state, applies v2 corrections, selects the requested pane (or fresh inferred view when automatic view detection is enabled), validates the host and selection/module/request generation, then passes UI bounds to the existing Fit/display path. Floating sizing uses the combined AX area. No AX placement cache; JPEG RAM cache is independent.

AX-only selection disables background placement pixel checks. Explicit screen inspection, capture previews and calibration snapping retain their existing screenshot paths. Switching backend cancels outstanding placement/request work and invalidates placement memory; a visible overlay is retained. AX failure offers manual calibration, never screenshot fallback. Window/CG metadata and AX attributes are read without capturing pixels. Boundary preview remains a separate switch.

### Small-window AX panels (1.0.28)

The former width < 30% rule rejected visible 324 pt panels in 1047 pt and 900 pt windows. AX panel classification now retains tall visible rectangles attached to exactly one side of the host, excluding full-width rectangles. Existing visibility, host containment and height checks remain; screenshot detection and geometry offsets are unchanged.

## AX-assisted screenshot trial (1.0.29)

AXAssisted.swift is an isolated experimental search. Its initial rectangle evidence checks were copied from the accepted Full checks; ViewportDetector.swift and the original split scanner are untouched. ScreenProbe adds only an optional raw-hint dispatch, gated by exact captured host geometry. Nil/stale hints use the existing path. The original cache is not populated with guided results.

Visible side/upper/filmstrip rectangles give raw global-point edges. Missing sides start at the host edge. Search uncertainty is ±64 pt horizontally and ±128 pt vertically, clipped to raster bounds. These are search widths, not calibrated placement shifts. Pixels still choose and validate all four borders. An inconclusive guided search uses the original search. Splits use the unchanged bottom/left margin scanner and the selected layout, never calibrated AX pane geometry.

The assisted background check compares translation-independent panel/toolbar signatures and retains every scheduled 1280px pixel check. AX change or pixel mismatch invalidates the next placement, retaining the visible overlay. Reports distinguish unchanged-AX pixel changes, AX failure and pixel validation failure. This first trial deliberately does not reduce check frequency; measurements precede that decision. Config interval zero still disables checks. View inference is independently controlled.

1.0.29 follow-up: AX-only always enables view inference. Screenshot mode exposes independent assistance/view checkboxes and remembers them across mode switches. Screen Recording is checked without requesting access; absent access skips calibration capture/background checks, and explicit preview/inspection report unavailability before hiding existing windows. User requested no version increment.

## Assisted-only candidate refinements (1.0.30)

Raw side-panel tops constrain the upper search band and reject any fallback rectangle extending above that structural boundary (4 pt sampling tolerance). This is not a calibrated AX placement offset. Pixel validation still determines all four edges. The independent assisted validator allows up to two compact bottom-surround interruptions, each at most six of forty samples, with at least 75% bottom support. Left/right/top support remains 90%, and every border still needs distributed transition evidence. This models two Library status labels; it is a synthetic-tested hypothesis pending native confirmation.

After validating the combined outer area, the unchanged inset divider scanner runs. Only its failure permits a midpoint split in assisted mode. Failure to validate the outer rectangle never permits midpoint placement. ViewportDetector.swift, PhotoDetector.swift, the original split scanner and AX-only geometry remain unchanged.

Settings exposes the method submenu and the independent screenshot options. Calibration hints wrap to available screen width. Runtime ScreenCaptureKit denial is distinguished from rejected geometry. Diagnostic failures are snapshotted and saved before opening the calibration modal when saving is enabled; background results are explicitly labelled as potentially older. No personal settings are reset.

## AX-only live overlay policy (1.0.32 correction)

This supersedes the 1.0.31/early 1.0.32 cross-backend experiment. Screenshot background functions are restored verbatim from 1.0.30: invalidate cached placement only. Screenshot AX view inference updates the menu only; explicit view/pane menu selection hides the overlay. No screenshot placement calculation is invoked by AX live following.

The shared GUI preference axLiveUpdate defaults true and applies only to pure Accessibility placement. The old WIP keys are ignored. Its item appears below Detection method only in Accessibility mode; screenshot mode instead shows its two independent AX options. Manual placement disables these controls.

The two-second AX poll compares inferred view/pane and a translation-independent raw structural panel/toolbar signature with the displayed overlay. Initial successful AX placement records the signature in the same read, avoiding a first-poll false dismissal. If a baseline is unavailable, the first valid sample establishes it. Toolbar interpretation uses the same configured fallback as placement. Live update on recalculates using the unchanged AX geometry; off dismisses on a change. Same image, window, zoom and export snapshot are retained on update. Failure retains displayed geometry and permits retry. Completion checks panel identity, module, epoch, view generation, selected view, backend, host and automatic preference. Nothing opens an absent overlay.

Only pure AX checks Library’s View → Grid menu selection, both on polling and invocation. The public AX menu reader is bounded to 0.5 seconds/250 nodes and the first View menu level (AXMenu wrappers only; never command submenus). A unique Grid/Grid View item with a nonempty AXMenuItemMarkChar means selected; absent/incomplete/ambiguous evidence is unknown. Grid and confirmed module changes dismiss regardless of Live update. Native menu and lifecycle validation remains required. Placement algorithms are unchanged.

### AX photo-selection updates (same 1.0.32)

The existing 0.2-second bridge poll compares a fresh selection epoch with the displayed overlay epoch. Only pure AX automatic placement participates: update enabled requests the new JPEG through the existing cancellable bridge/load pipeline; disabled dismisses. Missing epochs are uncertainty, never proof of change. The initial epoch is established if absent. One automatic attempt per selection avoids failure retry storms. Visible/unsuspended host and idle foreground work are required before loading; inactive overlays never open.

Load and placement completion check panel identity, selection epoch, module, backend, preference, host and generation. Fresh AX placement uses the new aspect ratio, reuses the existing panel and sets a new image/export snapshot at Fit. Failure retains the old image without manual-calibration prompts. Screenshot, manual and floating selection behaviour is unchanged.


---

## Archived AX-ASSISTANCE.md before the 1.0.32 documentation reconciliation

The following is a historical snapshot. Statements about current defaults, menus, pending implementation and candidate status apply to the time of writing, not the current app. Consult METHODS.md, AX-ASSISTANCE.md and ARCHITECTURE.md for current guidance.

# AX assistance for screenshot detection — investigation log

This is a record of ways Accessibility evidence could assist the established screenshot detector. It is not approval to change that detector. Keep capture, Full rectangle validation, split margin scanning, caching and visible-overlay behaviour intact until a specific change is authorised and tested. AX preview geometry remains independent of actual placement.

## Evidence collected on 13 November 2026

Native reports from 1.0.19, Develop single view on HP E273q (2560 × 1440, scale 1). Coordinates below are global top-left macOS points. These measurements are specific observations, not universal constants.

| Report | Host (x, y, width, height) | Toolbar | Raw AX bottom | Screenshot-placement bottom | Main-window toolbar checkboxes |
|---|---|---|---:|---:|---:|
| 13:34:54 | 0, 30, 2560, 1349 | Shown | 1228 | 1197 | 2 |
| 13:38:21 | 0, 30, 2560, 1349 | Hidden | 1228 | 1240 | 0 |
| 13:46:11 | 673, 113, 1823, 1165 | Shown | 1127 | 1096 | 2 |
| 13:47:29 | 673, 113, 1823, 1165 | Hidden | 1127 | 1139 | 0 |

The 13:46 placement used previously accepted cached bounds; the other listed placement reports show fresh detection. The hidden-toolbar gain is 43 pt at both sizes. Observed bottom corrections are −31 shown and +12 hidden; the older +13 hint was an inference and is superseded by these measurements for this setup. Config defaults remain zero; no personal config was changed.

At both sizes, side scroll-area inner edges match the screenshot placement's left/right edges exactly: 306/2243 for the large window, 979/2179 for the smaller one. Raw AX panel-edge corrections are left −18, right +18, top −12. Side scroll areas end 2 pt above the shown-toolbar viewport bottom and do not change when the toolbar hides. They therefore cannot directly define the bottom in both states.

The two likely toolbar checkboxes sit 8 pt below the shown-toolbar viewport bottom, directly under the main AX window. They disappear in both hidden-toolbar reports. No AXToolbar container was exposed. A complete exposed child traversal found 303 elements shown and 301 hidden; the initial large-window traversal took 66 ms. Absence of these particular controls is not yet a universal hidden-toolbar test.

Earlier evidence: hidden panel AX rectangles can persist while their matched CG windows have alpha=0; AXVisible is unsupported. Information-overlay rectangles can disappear after resizing/recreation, so they are unsuitable anchors. Reference/Active label geometry survived tested information-overlay changes and can suggest split orientation, but the geometric label classifier is experimental.

## Potential assistance by detector stage

| Stage | How AX could help | Evidence / limits | Next validation |
|---|---|---|---|
| Capture geometry | Logical main-window frame can cross-check window-list/capture metadata and coordinate conversion. | Already useful for host tracking; AX cannot repair a distorted pixel buffer or prove its scale/origin. | Off-screen and multi-display cases separately; never silently stretch a capture to fit AX. |
| Border search ranges | Visible surrounding panels and their child scroll areas could suggest narrow search bands near the expected UI edges. | Side inner edges agree in the two tested sizes. Raw outer panels include margins and toolbar errors. | Compare suggested bands with unchanged full-search results across panel widths, hidden panels, Library and scales. Initially report suggestions only. |
| Photo-edge versus panel-edge ambiguity | Give candidate rectangles extra supporting evidence when their edges agree with independently measured panel boundaries; flag candidates that cut across visible UI. | Screenshot validation currently relies on a uniform inner surround and four supported transitions; a uniform-edged photo could mimic that. AX supplies structural evidence, not photo recognition. | Use ambiguous/dark/uniform-border photographs. Compare candidate rankings without changing the chosen result first. |
| Top/bottom bounds and toolbar | Child-control geometry may indicate toolbar presence and anchor a small correction or a targeted screenshot scan. | Checkbox appearance/disappearance and fixed offsets repeated across two sizes; no actual toolbar container. Side scroll bottoms are insufficient alone. | Toolbar customisation, Library, hidden filmstrip, panel changes and other scales. Missing controls must remain inconclusive until tested. |
| Hidden panels | Matched CG opacity can exclude retained AX panel rectangles; host edges provide a fallback starting region. | Panel rectangles can remain exposed when hidden. CG opacity is additional evidence, not pure AX; stale/unmatched entries require care. | Individual and combined hidden panels, auto-hide hover states, resize and module transitions. |
| View and split orientation | Visible Reference/Active label pairs can choose single, side-by-side or stacked layout, guiding the existing split scanner. | Opt-in invocation-based experiment exists. User requests live monitoring with menu updates only on a change. Successful scan with no clear pair means single; read failure retains uncertainty. | Test live transitions, resize, labels recreated, Library and info overlay off. Keep normal detector geometry unchanged. |
| Split divider location | A label gap and 50/50 estimate could suggest where the existing bottom/left margin scanner should look or help explain a rejected divider. | Label rectangles are labels, not pane bounds. Raw outer bounds can shift the midpoint. | Compare against actual scanner dividers in both orientations, varied aspect ratios and unequal pane arrangements. No unapproved midpoint fallback. |
| Cache invalidation | A change in visible panel/control geometry could signal that cached placement needs checking for the next invocation. | AX can miss visual-only changes. No measured replacement for the existing screenshot boundary checks yet. | Log AX changes alongside existing invalidation results; measure missed changes and false positives before altering cache policy. |
| Diagnostics and speed | Save paired AX estimates and screenshot results with timing/provenance; deeper inspection can run after presentation. | Opt-in latest.txt saving exists. Child refresh is currently manual; automatic post-invocation refresh is requested for a future update. | Ensure coherent host/module snapshots, cancellation, fresh timestamps and no placement delay. Measure typical and worst-case collection cost. |

## Guardrails and open work

- Missing or incomplete AX data must not be treated as a proven panel boundary. Do not gate working screenshot detection on speculative AX geometry.
- Keep points, raster pixels and AppKit coordinates distinct. Match observations to the same host size, module and display; distinguish fresh detection from cached placement.
- Never use control indices, window IDs or filenames as permanent identifiers. Account for hidden ancestors and scroll clipping: a reported child rectangle need not be visible.
- Screen Recording remains required for screenshot detection even if AX supplies view/search hints.
- Do not infer Library/Grid/Loupe solely from lack of Reference/Active labels. The agreed “single” fallback describes the overlay layout, not positive proof of Loupe.
- Live view monitoring is opt-in; automatic reports retain useful evidence without deep child scans.
- Before implementation, trial proposed AX assistance as diagnostic suggestions alongside the unchanged result. Record disagreements as well as successes.

Update this file as evidence arrives. Keep raw diagnostic files and screenshots outside Git; record relevant measurements and limitations here, implementation rationale in METHODS, and accepted test outcomes in VALIDATION.


## Consolidated toolbar evidence — 13 November 2026

- Library shown/hidden reports at 15:18/15:20: screenshot UI bottom 1197→1240 (+43 pt), while raw AX filmstrip top stays 1228. Main-child text/checkbox disappear; no stable toolbar container. Main AXSections identifies the title-bar image. Initial 180-element probes were incomplete.
- Develop exhaustive standalone scans: 838/866 elements, no traversal caps. No dedicated toolbar container found through queried relationships. Most attribute errors were AXSections on sidebar rows; main sections read successfully. Control indices and incidental checkboxes are not accepted selectors.
- Develop delayed menu pair at 16:27/16:30: Hide Toolbar when shown, Show Toolbar when hidden; 65 elements, 40 ms, no errors.
- Confirmed Library fresh pair at 16:58:23/16:58:49: same title/state correspondence; 103 elements, 50/40 ms, no errors. Earlier 16:55/16:56 pair has uncertain module and is excluded from module-specific conclusions.
- Menu checkmarks were absent. Shortcut T/modifiers 8 supports identifying the command; the generic AgMenu identifier is not unique. Titles currently require English.
- Lightroom can expose incomplete menus after focus changes. One delayed test rejected focus despite the user's observation. Thus unavailable status is an explicit assumption of shown in the preview, not proof of visibility. Repeated native testing remains necessary.

Visibility is supported by these pairs; height remains unreported and configurable. Full AX-only placement is still experimental. The existing screenshot detector remains intact.

## Investigation ownership

App diagnostics keep host/display maps, panel rectangles, AX visibility and supplementary CG opacity, label candidates, view inference, preview corrections/bounds, toolbar command/state/timestamp and failure reasons. Exhaustive child/parent/section dumps were removed from the app in 1.0.23. Standalone source and launcher are in tools/AXExplorer; the executable/launcher are built in build/AXExplorer only. Raw probes are preserved in ignored investigations/ax-reports. Historical build/check evidence stays in VALIDATION.md, not README or the current checklist.


## Calibration against screenshot bounds — 14 November 2026

User designated screenshot-calculated UI bounds as reference. Window (0,30,2560,1349), point coordinates; compare UI bounds, not the extra one-point panel border. Library single-view fresh reports 19:44:49–19:49:33 established per-edge shown/hidden corrections. Develop side-by-side reports 20:10:30, 20:12:29 and stacked 20:13:29, 20:14:23 supported the same edge corrections. Corrected outer-area midpoints differ from pixel divider detection by 0.5 pt; no separate divider correction introduced.

V2 signed offsets use right/up positive: shown L/R/T = -17/+17/+11; hidden L/R/T = -1/+1/+1, relative to raw fallback insets 18/18/50 pt. Bottom = filmstrip shown -11 or hidden +17, plus toolbar shown +43 (hidden 0), plus Library split-view allowance. Base hidden-bottom inset is zero. Filmstrip shown/toolbar hidden is inferred; other bottom combinations measured. Library split screenshot detection failed, so its apparent extra bottom allowance and divider differences are excluded from calibration. The user subsequently calibrated the Library split-view allowance to +25 pt; this is now the default. Resizing/other display-scale acceptance remains pending.

1.0.24 introduces an opt-in AX placement backend, not a replacement detector. Manual placement wins; with automatic placement on, the experimental switch chooses AX or the existing screenshot path. AX errors never fall back to capture. Preview remains independently available. Prior exploratory v1 offsets remain stored/parseable, but v2 names alone control AX geometry so positive-down legacy values cannot be silently reused with reversed semantics.

## Current accepted geometry and next investigation (1.0.27)

Calibrated offsets are accepted geometry settings, not restricted in principle to AX-only use. Library's +25 pt applies only to inferred split views. Config now uses plain assignments; prior prefixed/v1 descriptions above are historical. Never apply these offsets a second time to screenshot-detected edges.

Next worktree: AX-assisted screenshot placement, a separate off-by-default experimental switch. Preserve the original screenshot path when off, and let manual placement override both automatic backends. AX-only has priority over AX assistance. Investigate AX layout signatures to reduce captures, narrow screenshot searches, guide splits and report disagreements. Record session AX checks/changes, retained screenshot check count/time, changes caught only by screenshots after successful unchanged AX reads, and AX read failures separately. Use those results to decide whether a later update can remove retained periodic screenshot checks. No assistance implementation is included in 1.0.27.

## Implemented experiment — 1.0.29

User authorised an independent assisted backend, with raw AX bands and pixel-authoritative placement. No calibrated offsets enter the assisted detector. Main remains unchanged while candidate is tested. Retained background screenshots are counted/timed alongside AX signatures; pixel changes with unchanged AX provide evidence of their contribution. Do not remove or reduce these checks until native measurements support it. See METHODS for exact routing and fallback.

## Main integration — 1.0.32

Merged at the user’s request. AX-assisted screenshot placement is implemented as a separate optional path: raw AX structure narrows pixel searches; screenshot evidence determines final edges, without calibrated AX offsets. Original screenshot detection remains available. The contribution and overhead of retained background screenshots are instrumented but not yet established by sufficient native measurements; no background screenshot reduction is claimed. Remaining edge cases and comparison tests are in TESTING.md.


## Migration deferred-fix investigation archive (closed 2026-11-21)

The following preserves intermediate findings and unsuccessful attempts verbatim. Pending statements are historical. Final implementation uses AX-identified title-bar clipping; all deferred-fix tests passed and the slight delay was accepted.

## Post-migration fixes — candidate 1.1.10 (native verification pending)

- **UI text — floating-window hover instructions (2026-11-20):** stage 7 testing passed, but the user requested tidying the hover text. Review the tooltips/instructions for clarity and consistency with current controls after migration; Candidate: separate overlay/floating tooltips with shorter, multiline gesture instructions. Verify native tooltip readability.

- **Bug — full-screen stacking:** overlay covers macOS menu/title bars when revealed at the screen top. Investigate ordering/window level; retain Lightroom-content visibility without moving placement. Candidate: confirmed AX full-screen hosts use normal-level relative ordering above Lightroom, rather than floating level. Cached full-screen evidence survives transient read failures. Geometry unchanged; native testing required.
- **Bug — AX diagnostic border constraints:** report 2026-11-19 11:37:40 shows identical calculated preview/production bounds, but standard preview NSPanel requested AppKit y=183 and appeared at y=170. Production OverlayPanel accepted its requested frame. Candidate: AXTrialPanel inherits OverlayPanel frame constraints and cannot become key. Geometry calculations unchanged; verify native placement.
- **Screenshot response to Lightroom changes:** implemented in candidate 1.1.10; user accepted on 2026-11-21. Screenshot with AX view detection now matches Accessibility with updating off: confirmed photo/view/pane/panel changes dismiss; positive Library Grid dismisses and blocks invocation. Missing evidence retains the overlay. Screenshot with inference off, manual and floating behaviour are unchanged. AX-assisted placement remains independent; no placement algorithms or calibrated offsets change.
- **Bug — stale view in calibration instructions:** calibration currently builds its prompt from `overlayLayout`, which can resolve to a saved view/pane unrelated to Lightroom's current view. Replace view-specific instructions with a neutral prompt to select whatever region the user wants the overlay to occupy. Suggested wording: “Select the region where you want the overlay to appear. Esc cancels.” Do not mention Loupe, a particular pane or a divider, and do not require fresh view detection merely to generate this prompt. Candidate: remove the pane-specific drag prompt and layout-specific failure guidance; preserve acceptance/cancellation semantics.
- **Bug — floating display covered by a later overlay (2026-11-20):** stage 6 user test: open the floating display, then invoke the overlay; the overlay covers the floating display. Required behaviour: the floating display must remain above the overlay regardless of invocation order. Investigate window levels and ordering alongside the full-screen stacking issue, without placing either above macOS system controls. Candidate: order overlay and AX borders below an already visible same-level floating window, without raising the floating window or changing its level. Native invocation-order testing required.

### 2026-11-21 test follow-up

Verbatim response: [1.1.10-TEST-RESPONSE.md](migration/1.1.10-TEST-RESPONSE.md). AX preview geometry and screenshot fallback/isolation/late-result cases passed. User requested three tooltip bullets and promotion of AX preview to a direct developer tool. Menu bar ordering passed; revealed title bar remained behind the overlay. Floating invocation order passed, but click ordering and Exposé participation failed. Follow-up keeps full-screen Lightroom companion windows above the reference, elevates the floating reference one level above ordinary floating panels, and explicitly opts it into managed Mission Control behaviour. Only these cases need native retesting; earlier candidate descriptions above record the prior attempt.

### Window-order diagnostic follow-up

User confirmed both title-bar occlusion in full screen and floating-window occlusion after overlay clicks persist. Later screenshots supersede the floating-window checkbox in the saved follow-up response. Added an opt-in delayed metadata trace, not another ordering fix. Await the two recordings in TESTING.md to establish actual levels, focus transitions, system-window ownership and order. Placement remains unchanged.

2026-11-21 recordings: the windowed float and overlay both actually used level 3; clicks exchanged key status. Candidate now assigns the float's intended level 4 after setting isFloatingPanel. Full-screen recording confirmed the title bar revealing at y=30, height 32, alpha 1 while repeated companionCovered ordering attempts continued. The diagnostic now logs the exact pre-order on-screen level-zero input and intervening companion IDs; title-bar ordering remains unchanged pending that evidence. Native float verification remains required.

Title-bar follow-up: recording 19:49:54 identified title-bar window 1598 below overlay 1591 while 36 companions triggered repeated corrections, including transparent panels/labels. Candidate now uses visible, overlapping host-wide top chrome as a direct below-window anchor. It uses reported geometry without a calibrated height and leaves placement untouched. User reports the floating-window fix appears successful; title-bar native verification remains pending.


Current title-bar candidate supersedes the above ordering attempts: remove companion/top-chrome reordering and mask the overlapping overlay strip using named AX control-parent identification. Keep frame/photo geometry fixed; clear on retraction or exit from macOS full screen. Native clipping and title-bar click handling are pending in TESTING.md. Float initialization fix is retained and user reports it appears successful.


### Read-only title-bar probing history

## Pending native title-bar identification probe (2026-11-21)

The full-screen ordering fix remains unaccepted: the user reports title-bar occlusion persists. Existing windowed AX reports advertise named close/minimize/zoom/full-screen controls, but do not establish their relationship to the separate revealed full-screen CG window. Explorer 1.0.5 adds `titlebar-after` to compare semantic controls and their container links, alongside Lightroom-only CG metadata, with the bar hidden/revealed. No live results yet. Public AX and CG identifiers are not assumed interchangeable; any bounds match remains evidence to assess, not a production selector. Main app and placement are unchanged by this explorer update.

### Title-bar control pair and ordering investigation

Explorer report `2026-11-21T21-56-16Z-fullscreen-titlebar-controls-pair-81BE3C.txt` completed both targeted probes (42 nodes, no limits/partial result, Lightroom frontmost). Main AXCloseButton/AXMinimizeButton/AXZoomButton share AXGroup N42. Its frame changes from (0,-32,2560,32) to (0,30,2560,32), exactly matching CG window 1993 whose alpha changes 0→1. Control AXWindow and AXTopLevelUIElement still point to the main AX window; the title text frame does not track reveal. This provides semantic parent identification with measured-frame correlation, not a direct AX-to-CG ID API. IDs are session-specific.

Existing saved ordering traces predate commit 4167451's below-chrome action, so they cannot establish whether that action executes, has no effect, or is subsequently reversed. Explorer 1.0.6 adds a read-only timed on-screen-order trace using the named-control shared parent, to pair with the existing app action recorder. No main app code/build/placement change. Full-screen grouping or cross-application ordering constraints are hypotheses, not established causes. Public AppKit ordering documentation does not give a persistence guarantee against subsequent window operations. Do not infer actual ordering from optionAll's array positions; optionOnScreenOnly explicitly specifies front-to-back order in the SDK.
