# Historical research notes

Superseded development notes, retained as evidence only. Current architecture and methods are in AGENTS.md and docs/METHODS.md. These are not current instructions or outstanding requirements.

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
