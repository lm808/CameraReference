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

## 0.9.2

Full regression suite passed on the user's Mac, including the reported fractional-to-integer overlay frame, negative display origins, rejection of larger panel shifts/resizes, and preservation of the stricter capture-geometry check. AppKit screen-to-content-view conversion replaces the assumed requested-origin offset; failure propagation prevents the automatic caller from overwriting a placement error with success. Built-in display and full-screen/Spaces acceptance remain live user checks; the earlier v0.9 failure is not claimed resolved. External screenshot fixtures from earlier development were not supplied in this working tree.

## 0.9.4

Build, full regression suite, signature and Info.plist checks passed on the user's Mac. New capture tests cover explicit display-local crop geometry, negative display origins, full-screen bounds and cross-display rejection. Running build/capture-tests with the supplied unobscured screenshot reproduces the reported displaced bounds from a full-width crop and verifies that a correct window crop aligns both the UI viewport and fitted photograph. The image remains an optional external fixture, not a repository asset. Calibration cancellation mode preservation was checked by code review; native capture and the interactive cancel/retry sequence still require user acceptance.

## 0.9.5

The supplied 900×702 pt screenshot reproduces the complete 0.9.4 failure report exactly before the change. The wider side search finds (612,180,554,860), matching the visible viewport. Full regression suite passes, including new narrow-view fixtures with black/grey/white/coloured surrounds. Both optional user screenshot checks pass: previous non-maximised capture alignment and the new narrow viewport/photo placement. Build, code signature and Info.plist checks pass. Live user acceptance remains pending; no app launched or Lightroom controlled.

## 0.9.6

Full regression suite, app build, signature and Info.plist checks passed. Additional tests cover sideSearchPercent parsing/range/duplicates, migration without losing existing settings/comments or adding duplicate keys, live reload, manual-layout key changes, and invalidation of cached bounds after changing the interval. A valid narrow viewport outside a 30% interval returns the exact requested message and no candidate; a blank capture retains a general failure. The diagnostic centre-reaching search never supplies placement bounds. Native alert/button interaction remains a user acceptance check.

## 0.9.8

App build, full regression suite, signature and plist checks passed. Native acceptance is pending for the second shortcut, focus/indirect-touch routing changes, landscape initial sizing and Privacy Settings icon. Launch Services registration was refreshed successfully without resetting TCC permissions or launching the app. Timing instrumentation records stage durations without paths or image data; timings are to panel ordering, not proof of completed screen rendering. Single-photo detection remains unchanged.

## 0.9.9

Full regression suite passed after acceptance fixes. Targeted follow-ups also pass: manual UI coordinate conversion with asymmetric UI/photo sides; installation of native magnification recognizer; read-only plugin capability-report execution with SDK stand-ins. App build, signature and plist checks pass. No physical pinch, shortcut dialog, native permission-list or sizing acceptance is claimed. User 0.9.8 test notes are preserved verbatim under a new 0.9.9 retest list. Installed Lightroom version 15.6 and its LrApplicationView bytecode constants were inspected read-only; a runtime export report is supplied to verify the lack of a main-view getter before designing split integration.

## 0.9.10

Full regression suite and targeted bridge scenarios pass. RAM cache tests cover reuse, changed selection/session, A→B→A, late insertion rejection, stale tracking, clear and source/preference fingerprints. Lua stand-ins cover observer registration failure/unavailability and two selection events between poll ticks; runtime native observer acceptance remains required. Build and prior signature/plist checks pass; final artifact rechecked on delivery. Shortcut native layout was constructed offscreen: compact alert geometry and aligned columns were inspected programmatically (not a claimed live screenshot). Pinch routing has diagnostic counters, not a claim of physical success. Floating photo sizing now uses current detected photo geometry; manual calibration always means UI working area. User runtime SDK evidence rules out a main-view getter; a read-only View-menu AX probe is supplied for further research. No image cache is written to disk and no app was installed/launched for acceptance.

## 0.9.11

Build and full regression suite passed. New tests cover half-width/full-height floating fitting for landscape/portrait; explicit four-pane geometry and raster detection; wrong-orientation/single-view fallback; calibrated seed validation; translated placement with rejection of window-ID/size/epoch/config/mode changes; config parse reuse, reload and invalid-value retention; and full-size floating content geometry unchanged by hover chrome. A final core follow-up covers namespaced calibration clearing with auto/manual preference and Full-key preservation. Physical hover/drag/Cmd-scroll, native split placement and live speed require the new TESTING.md list. Pinch code/counters removed. The read-only AX test process reported Accessibility permission unavailable, so internal-panel change detection remains unverified and is not enabled. No companion was installed/launched and no Lightroom layout was changed for acceptance; native view tests constructed offscreen windows only.

## 0.9.12

Build and full regression suite passed. New checks verify all five eagerly rendered menu masks are nonempty/distinct, title-bar dragging moves the floating window at any zoom, chrome leaves full-size photo geometry unchanged, legacy animation booleans parse without affecting settings, changed/missing panel bounds invalidate placement, and ordering decisions leave other windows above Lightroom. These are geometry/state/rendering checks, not live cross-process acceptance. Full single-photo and split raster regressions pass unchanged. User 0.9.11 test results are preserved below the fresh 0.9.12 list; Clear region was confirmed working and not treated as a failure. Background polling, native menu visibility, hover chrome, macOS cross-app window order/Spaces, latency and idle cost need the new live tests. No app installation or Lightroom interaction was performed.
