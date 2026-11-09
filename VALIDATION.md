# 0.7 validation

The app is compiled and ad-hoc signed locally; no app is launched/installed and no Lightroom UI is controlled during development.

Automated checks cover source selection, extraction process failures/cancellation/limits, orientation, export safety, gesture maths, calibration geometry, shared view ownership, toast lifecycle and Lua bridge behaviour. Legacy photo-edge tests remain regression tests; the new path uses UI borders.

New detector tests cover black/grey/white/coloured surrounds, near-black image content, hidden panels, side-by-side/stacked dividers, missing boundaries, cached outer bounds and invalidation by panel/background/window changes. The supplied screenshot is used locally (not bundled): expected bounds are x244–1794 and y95–957 in its 2048×1102 pixel grid. No live Lightroom capture is taken by development tools.

Native capture timeout/cancellation, permission prompts, full-screen, display changes, live title updates and exact Fit padding require user tests. Synthetic tests do not prove recognition of all Lightroom layouts. A split divider does not prove Reference mode; the app asks for confirmation. The screenshot supports the initial 16 pt Fit inset but does not establish it universally.

No existing plugin changes. The packaged bridge remains 0.4-compatible. Screen/geometry cache retains only UI samples and geometry in memory, not a screenshot. Calibration preferences retain coordinates/layout identifiers, not image bytes or photo paths.

## 0.7.1

Added screenshot regression cases resampled to the reported 2560×1349 capture, with several menu/title-bar crop offsets. The original 0.7 detector chose x2057 (photo fringe) rather than x2242 (right UI border); the patch selects x2242 across these fixture variants. These are simulated capture dimensions, not an actual failing ScreenCaptureKit frame. Live failure attribution remains unconfirmed.

## 0.7.2

Adds deterministic checks for free versus Option-only snapping, independent axes, radius/segment rejection, capture-to-screen conversion, preference-reset isolation and rejection of stale capture generations after cache reset. Full existing regression suite is run before delivery. Native modifier/drag highlighting and clear-menu interaction remain user acceptance checks. The full-rectangle automatic detector improvement is deliberately not part of this focused patch.

## 0.8

New complete-rectangle search is checked against the original screenshot, its 2560×1349 crop/resampling variants, and the latest 2048×1055 screenshot with a narrow overlay. The latter is not claimed to be a pristine native failing frame: the detector must ignore its inner overlay and still locate the surrounding Lightroom UI. Added a synthetic weak-inner-border/strong-outer-rail case, short low-contrast panel snapping, and label placements in horizontal/vertical empty margins. Native ScreenCaptureKit capture still requires user acceptance.

## 0.8.1

Full regression suite and build passed. Added independent full-guide snapping checks, current-display filtering, and a supplied cropped-pane fixture confirming x31 and the thin line at top y20. Both complete Lightroom screenshots and resampling/crop variants pass. Preview tests confirm only Fit/100% context actions and image release. Code signature verifies. Capture explicitly includes child windows on macOS 14.2+, but live capture completeness remains unverified; preview lets the user inspect it without saving pixels. No detector-threshold changes in this patch. No native app installation or launch.

## 0.9

Single-photo production path bypasses internal-divider analysis after outer-rectangle validation. Tests retain legacy split coverage while adding cluttered-interior single-photo acceptance. Tests cover all 16 side combinations for landscape and portrait, config parsing/range errors/live reload/last-valid retention, and proportional snapping. Supplied screenshots remain local fixtures and are not bundled. The 18-point inset is an empirical scale-dependent estimate, not documented by Adobe. Live application acceptance is not claimed.

Final checks: full regression suite passed; both complete screenshot fixtures pass through the production single-photo path, and the cropped pane fixture retains its long vertical/top edges. Latest full screenshot detector time about33ms locally (excluding capture/extraction). Final app compiled without warnings and code signature/plist checks passed.

## 0.9.1

User accepted proportional snapping and mixed side placement for landscape/portrait/dark photos in 0.9. Resize and full-screen offsets remain the target of this patch. Added tests for the supplied full-screen photo rectangle (top-left y107,height1137 converts to AppKit y196 on1440pt screen), negative-origin displays, moved/resized/missing-window checks and window/full-screen/restore cache transitions. Existing capture-generation tests cover invalidation while capture is pending. Native panel constraining, Space events and timing require user acceptance; no native app launched or installed during development.

Final 0.9.1 checks: app compilation, full regression suite, code signature and Info.plist validation passed. No native full-screen acceptance claimed.
