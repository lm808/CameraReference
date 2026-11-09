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
