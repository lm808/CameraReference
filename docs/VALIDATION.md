# Validation evidence

## 1.0.1

Automated checks cover keeping an overlay on resize/metadata uncertainty, overview evidence, and consolidation into CameraReference: active old heartbeat defers movement, existing settings are seeded before waiting, differing conflicts are preserved, empty old directory removed, stale IPC discarded. Full regressions and final focused core checks pass. Native Mission Control/Space and actual installed migration still require the user checklist. The app is staged in release/; no DMG created.

## 1.0 alpha 2

Full automated suite passed, including active-legacy deferral, complete legacy file preservation, idempotent migration and no stale IPC replay. Lua stand-ins assert every bridge read/write uses Camera Reference/Bridge. Native arm64 app built; signature/plist and disk-image checks passed. No user installation was changed; actual coordinated bridge reload and migration acceptance remain in TESTING.md.

## 1.0 alpha

Automated regressions pass for host translation, temporary overview/Space suspension, stale size rejection and non-destructive config migration. Native Mission Control/Exposé, off-screen restoration and installation acceptance remain pending in TESTING.md. No app was installed or launched and no Lightroom UI was controlled for these checks.

Final checks: `bash test.sh` passed; final native arm64 app compiled, ad-hoc signature verified and plist validated. DMG creation and checksum verification passed. Installer scripts pass shell syntax checks; actual installation and native window acceptance are pending.

## Prior release evidence

The following entries are historical, with their original limitations; they do not describe current settings.

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

## User acceptance through 0.9.12

0.9.11: accepted RAM/placement reuse, movement/resize invalidation, selection/restart handling, manual calibration/cancel/clear behaviour, landscape/portrait floating size and reload. Repeats178/184ms; first1364ms. User later clarified clearing region does force correct detection; the issue was unobserved panel changes, not clearing.

0.9.12: accepted hiding layout section in manual mode, manual placement, calibration/clear semantics, background panel-change invalidation, floating size/reload, title-bar dragging while zoomed, Cmd-scroll and pan, cross-app overlay ordering, dialogs/fullscreen/Space safeguards. Repeated197ms (bridge154, image3). Outstanding: diagrams absent; floating hover inconsistent/flickering and wrong when cursor already inside; popup/Privacy app icon missing. Idle overhead and final legacy-config/no-animation checks were unchecked. Useful history retained here; obsolete setup instructions and duplicate release descriptions removed from TESTING.md at user request.

## 0.9.13

Full regression suite passed after split-axis, low-resolution capture, interval and chrome changes. Full single-photo detector branch is unchanged; explicit split orientation restricts divider scanning and raster tests cover crossed separators. Existing tests retain wrong-orientation fallback, four pane placement, calibration isolation, source safety and geometry. Icon assignment is explicit in app/alerts, bundle metadata uses AppIcon.icns, and inline menu symbols supplement native item images; native Privacy cache and menu rendering remain acceptance items. Floating hover uses one window-coordinate sample every80ms only while a float exists, including initial display and drag tracking; it does not capture pixels.

Supplied 900x702pt screenshot benchmark: 1800px fresh detector median47.16ms vs1280px33.57ms over five runs. Mapped UI bounds differed under1pt. This is one image's detector timing, not live ScreenCaptureKit/power measurement. Background capture is capped at1280px, with4pt comparison tolerance; normal placement capture remains unchanged. First/repeated live timing and idle CPU require acceptance.

Final 0.9.13 build/signature/plist checks and config follow-up tests passed. Launch Services registration of the built app refreshed successfully without TCC reset or launching the companion. Privacy icon display still requires reopening System Settings and native acceptance.

## User acceptance of 0.9.13

Accepted: menu/app icons, hover/fade including cursor already inside, floating drag/zoom/pan and size/reload, overlay following in ordinary window use, background3s/off behaviour, cache reuse and Full switching. Repeated148ms (bridge102, image3). Mission Control/Exposé remains faulty. Side-by-side fails with wrong pane/gap/tiny portrait overlays; a later landscape success does not retire the defect. Stacked works but needs the same robustness checks. User also reports the tiny overlay disappears quickly; a periodic boundary rejection is plausible but unconfirmed without diagnostics. Interval6/idle-cost and wrong-orientation tests remained unverified.

## 0.9.14

Split-only search prefers the combined supported viewport rather than the innermost narrow gap, rejects combined candidates under25% of either window dimension, and requires divider transitions in both opposite margin bands. Full's single-photo branch retains its existing choices. Seeded auto panes must validate against a complete two-pane viewport; tiny old-gap hints cannot bypass validation. Synthetic portrait/landscape-like pairs cover all four panes and resolution consistency. The0.9.13 baseline rejects these fixtures; the new detector selects correct panes. The supplied screenshot's exact path is unavailable locally (a similarly named file is a different screenshot), so no exact pixel reproduction is claimed.

Overlay uses public AppKit transient/ignoresCycle behaviour, intended to hide during Mission Control, and ordering reconciliation does not reinsert an already shown panel absent from the onscreen list. Native overview/return behaviour remains acceptance work. Background rejection diagnostics now distinguish changed from unvalidated bounds and include before/after UI plus detector report; they do not claim the user's disappearance cause is proven.

Full regression suite passed for the margin/combined-viewport change. Final targeted viewport tests also passed after seed hardening and normal/1280px consistency additions; final app build, signature, plist and diff checks passed. No native Mission Control or Lightroom acceptance is claimed.

## 0.9.14 user regression and 0.9.15 replacement

User reports0.9.14 side-by-side recognition failed for both orientations and stacked placement covered Lightroom UI; reject the prior synthetic successes as sufficient acceptance. User confirms selecting Full in Lightroom split layouts finds the combined area correctly.0.9.15 therefore restores ViewportDetector.swift exactly to0.9.13 and invokes its singlePhoto/Full path for combined bounds. No split-specific rectangle ranking, minimum25% size rule, or saved-pane substitution remains in that path.

The new divider scanner uses only the bottom configured inset for side-by-side and left inset for stacked layouts, with12 or fewer traces spanning20–80% of the inset. It requires a thin contrast line with matching background on both sides across at least half the traces. This tolerates missing endpoint pixels; top labels/right photo content are not sampled. Missing/ambiguous evidence or an unusably small inset offers calibration.

Full suite passed. The0.9.14 portrait fixture exposes an ambiguous Full result, so it is now explicitly a known-viewport margin-scanner test rather than justification to modify Full. Pipeline fixtures still verify identical Full bounds and pane selection/fallback. Tests cover wrong orientation, all four panes, stale hints, endpoint gaps, unused-margin labels, zero inset and resolution consistency.

Actual user margin crops passed at full/half/quarter resolution: horizontal divider1118.5/1118/1116 original crop pixels; vertical divider2075.39/2076/2074.90. Crop tests use explicit local viewport coordinates and do not claim to test full-window detection. Optional tests/margin-crops/main.swift takes the two original files; screenshots are not committed. Other native tests deferred by user; no Mission Control or unrelated UI changes in0.9.15.

Final0.9.15 app build, signature/plist and diff checks passed. ViewportDetector.swift is byte-for-byte identical to the0.9.13 commit. Native split acceptance remains required; no unrelated UI changes were made.


# Overlay latency investigation — 10 November 2026

Measured on the user's Mac with an optimised Swift benchmark, 10 repetitions of each stage. The supplied screenshots were cropped to their recorded Lightroom windows; no live screenshot was taken. These are CPU-stage measurements, not end-to-end overlay latency.

| Stage | 1392×888 pt window | 900×702 pt window |
|---|---:|---:|
| Raster, first | 57.1 ms | 18.6 ms |
| Raster, median | 1.5 ms | 0.9 ms |
| Fresh detector, median | 71.1 ms | 44.1 ms |
| Cached validation, median | 0.1 ms | 0.1 ms |

The bridge sleeps 150 ms between checks; companion response polling is 50 ms. Capture deliberately waits 150 ms for stable window geometry, before ScreenCaptureKit work. Those are configured intervals, not measured end-to-end delays. Embedded extraction starts ExifTool on demand; its cost is unknown for the user's current photo/storage.

0.9.8 reports bridge, load/decode (including extraction), capture/detection total and total-to-panel timings in Bridge diagnostics. Within successful capture diagnostics it also reports enumeration, stability/configuration, capture, raster and detector stages. No paths or pixels are logged. Total-to-panel is not a GPU presentation timestamp. Opening another diagnostic replaces some samples: copy after invoking the overlay.

Next evidence: first invocation and two repeated invocations of the same photo, plus standalone versus embedded if convenient. Use measurements to select the optimisation. Do not remove stability guards, introduce persistent JPEG caching or guess that detector time dominates. Potential next steps are reducing repeated ScreenCaptureKit enumeration/setup, overlapping independent bridge/capture work with generation checks, or addressing ExifTool startup if measurements justify it.

Reproduce CPU benchmark: compile tests/performance/main.swift with the same sources used for capture-tests and -O. Pass the larger supplied screenshot path, or the 900×702 screenshot followed by `small`. Fixtures are external and not committed.

## User's 0.9.8 live samples

Totals: 1061, 1020, 1070 ms. Bridge: 78, 87, 105 ms. JPEG load: 689, 691, 717 ms, including extraction: 269, 281, 300 ms. Capture/detection: 290, 224, 229 ms. Loading dominates; the remaining ~410–420 ms is not yet attributed to decode versus failed standalone lookup. All samples show extraction, so no confirmed standalone comparison is available.

0.9.9 removes eager file-property prefetch for every RAW-folder entry and only inspects matching filenames, preserving ambiguity and regular-file checks. New stage timings identify failed source attempts, lookup, standalone decode and embedded decode/orientation overhead. This is a targeted low-risk change; no live speedup is claimed before retesting. No reduced decode resolution or persistent image cache was added.

## 0.9.9 live feedback and 0.9.10 cache

User measurements: first embedded total 821 ms (bridge 56, load 409 including extraction 312, capture/detection 334); repeated totals 690 and 711 ms (load 396/373, extraction 295/274, capture 223/219); standalone total 637 ms (bridge 153, lookup 13, decode 198, capture 245). These are different invocation samples, not a controlled cold benchmark. Extraction now dominates the repeated embedded load. The user explicitly authorised retaining one selected photo in RAM, superseding the prior no-between-invocations cache requirement. 0.9.10 implements this with selection-revision and file/preference validation. No cache-hit live timing is claimed yet.

## 0.9.11 — skip capture on repeated toggles

User 0.9.10 sample: bridge 195 ms, RAM load 5 ms, capture/detection 219 ms, total 451 ms. Manual sample: bridge 84 ms, RAM load 5 ms, total 115 ms. These are different bridge latencies, not a controlled benchmark. 0.9.11 reuses the detected UI area only with matching selection epoch, window identity/size, layout and config; movement translates it. File metadata revalidation and bridge round-trip remain. Config metadata is checked without rereading unchanged text. No measured 0.9.11 latency claim yet. Internal panel changes require clearing the region until an inexpensive reliable signal is established.

## 0.9.12

User 0.9.11 first sample: bridge179 ms, load849 ms (extract294, decode/orientation556), capture321, total1364. Repeats: total178/184 ms, bridge151/152, RAM load6; capture skipped. These confirm repeated-path improvement but first-load cost varies. New panel checks run off the invocation path at most every1.5 seconds while Lightroom is active and automatic placement is cached, and are cancelled on foreground work. This trades periodic idle capture/CPU cost for automatic panel-change detection; speed and power acceptance must be measured. No 0.9.12 timing claim yet.

## 0.9.13

Background interval defaults3s (20 checks/min maximum), zero disables; captures capped1280px, full placement unchanged. On user's small-window screenshot, five-run median fresh detector47.16ms at1800px versus33.57ms at1280px, bounds agree within1pt. No claim for live capture/battery cost. Diagnostic background duration includes setup/stability/capture/detection. Geometry timer stays0.2s without screenshots; float-only pointer sampling80ms replaces competing hover events.
