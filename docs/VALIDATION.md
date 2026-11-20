# Validation evidence

Dated build/test records and original user annotations follow. A historical “pending” or “current” statement belongs to that entry, not necessarily today. For current outstanding checks see [TESTING.md](../TESTING.md); for the implemented behaviour see [METHODS.md](METHODS.md).

## 1.0.4 candidate

Full automated suite passed, including new-dialog fallback versus known panes/untitled redraws, thumbnail versus ordinary/off-screen host geometry, and calibration text for all five layouts and both modes. App compiled and staged; signature/plist checks passed. Native AX/window-list semantics, Email Photo/View Options, minimise animation and restoration remain pending. No app launch, plugin change or new permission request was performed.

## 1.0.3 candidate

Local app built and staged with foreground-dependent floating level. Targeted split/ordering/config tests passed; these test normal-level fallback and configuration, not native cross-process activation. Signature/plist verified. Clicking, zoom/pan, dialogs/sheets, app switching and overview acceptance remain pending. No permissions changed and no plugin reinstall required.

## 1.0.2 candidate

Built/staged in the codex/flicker-fix worktree; original main app remains 1.0.1. Full automated suite passed, including intervening Lightroom-window tolerance, foreign-window precedence, fresh-install default 40, missing-key defaults and preservation of explicit saved values. Generated template and distributed example agree exactly. App signature and plist verified. Native zoom/pan flicker acceptance is pending; maintenance counters and TESTING.md describe the check. No app was launched, plugin installed, merge performed or DMG produced.

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


## User acceptance of 1.0.3 (11 November 2026)

Verbatim completed checklist; diagnostic-counter check explicitly skipped. Dialog exceptions and minimise failure are outstanding, not passes.

```text
# CameraReference 1.0.3 — candidate checks

Quit the original app and open **this testing worktree’s release/CameraReference.app**. Confirm 1.0.3. Bridge 0.5.2 is unchanged; no reinstall is needed. Keep the original 1.0.1 release/ app for fallback. `[x]` or `[x ]` means pass.

- [x ] In side-by-side, show the overlay and zoom/pan the neighbouring RAW repeatedly: no flicker. Repeat left/right and portrait/landscape.
- [x ] Repeat in above-and-below, then check ordinary Full placement.
- [since the above works well i am skipping this.] Compare Developer tools → Bridge diagnostics before/after zoom/pan. With the Lightroom window stationary, “moves” should stay zero. While Lightroom stays active, ordering and level-change counts should stay stable after initial show. If it does, report both counts and the gesture/layout.
- [x. Most dialogues work, the one got behind was 'email photo'  and 'view options'.] Click different Lightroom controls repeatedly with overlay visible: no cover-and-restore flashes. Open a Lightroom dialog/sheet and check it remains usable; close it and check the overlay.
- [x ] Move Lightroom: overlay follows. Switch to another app: its windows cover the overlay normally. Return to Lightroom: ordering remains correct.
- [x ] Resize/change panels: existing overlay stays open; toggling it off/on refreshes placement. Mission Control/Space/minimise handling should not regress.
- [x, only that minuimising leaves the overlay half stuck on the screen. ] Confirm your existing sideSearchPercent and ui/photo bounds have not been overwritten. New/missing config defaults are 40/all ui (covered automatically; do not delete your live config just to test this).

To fall back, quit the candidate and open the original worktree’s release/CameraReference.app. No branch switching, settings reset or plugin swap is needed between these two versions. Report remaining flicker with Bridge diagnostics before invoking again.
```


## User acceptance of 1.0.4 (11 November 2026)

Verbatim annotations; minimise remains unreliable and is deferred to the next investigation.

```text
# CameraReference 1.0.4 — focused candidate checks

Quit 1.0.3 and open **this worktree’s release/CameraReference.app**, confirming 1.0.4. Bridge 0.5.2 is unchanged. Your 1.0.3 annotations are preserved verbatim in docs/VALIDATION.md; accepted Full/split flicker behaviour is the baseline.

- [x ] With overlay visible, open **Email Photo** and **View Options**. Each dialog stays above the overlay and usable. Close it: overlay returns to floating without another shortcut.
- [50/50 chance it works. ] Minimise Lightroom with the yellow button, restore it, then repeat using Cmd-M. No part of the overlay remains at the Dock; restoration retains its image and alignment. Repeat with another app active and after moving Lightroom partly off-screen.
- [x ] Briefly repeat clicks/zoom/pan in split view: the accepted flicker fix remains intact. Another app can still cover the overlay.
- [x ] Trigger detection failure in Full, left/right and upper/lower modes. Title is “Cannot reliably identify viewing area.” Instructions show the selected layout/pane icon and current mode. Cancel preserves mode and region; accepted calibration switches to manual.




If dialog/minimise behaviour fails, copy Developer tools → Bridge diagnostics before invoking again. The Lifecycle line identifies dialog state, optional Accessibility availability and minimise state. No new Accessibility prompt is added: direct state checks use existing permission, otherwise window-list metadata is used. Native success remains to be confirmed.
```

## 1.0.5 candidate

Sony ARW sample supplied by the user was tested read-only: PreviewImage selected, 1616 × 1080 decoded pixels, 272733 JPEG bytes. In-memory export/orientation round-trip and cache reuse passed; RAW SHA-256 and modification time stayed unchanged. No extracted JPEG was saved. This establishes that sample, not every Sony model. Synthetic cases cover larger valid candidates from either tag, invalid fallback and rotated output. Native portrait ARW acceptance and the new zoom interaction remain in TESTING.md.

Automated verification: `bash test.sh` passed, including ARW candidate selection/fallback/orientation/cache tests, whole-region navigation geometry, and a rendered-pixel test confirming zoom draws outside the original Fit rectangle. Native build, staged app signature verification, plist version 1.0.5 and `git diff --check` passed. Native acceptance remains pending; no app launch, installation or DMG was performed.

## 1.0.6 candidate

Confirmed Library heartbeat now dismisses visible/suspended overlays, cancels pending overlay loads and discards ongoing Develop screen-inspection callbacks. Unknown/stale module state and floating displays retain their previous behaviour. Existing Lua bridge tests passed, including immediate reporting of a module switch; native app build passed. Native switch/return acceptance is pending in TESTING.md. No changes to detection geometry or window-ordering policy.

## Acceptance before 1.0.7

User accepted 1.0.6 ("Looks good, merge into main branch"); main was fast-forwarded to 3895434 with the tested app staged. No individual 1.0.6 checklist annotations were supplied. The 1.0.7 work remains isolated in the candidate worktree.

## 1.0.7 candidate validation

`bash test.sh` passed: existing Full/split raster, bridge, preview and geometry regressions plus off-screen content-local crop/child-extent/coordinate checks. After adding a missed-restore safeguard, the core suite was rebuilt and rerun separately. Native build, staged signature/plist and diff checks passed. These synthetic tests do not establish native ScreenCaptureKit child composition or Lightroom notification delivery. No app was launched or Lightroom manipulated; user acceptance remains pending in TESTING.md. Main’s accepted 1.0.6 payload remains untouched.

## User results for 1.0.7

Not accepted for merge. Verbatim checklist and diagnostics supplied by the user:

```text
# CameraReference 1.0.7 — candidate checks

Quit the current app and open **this worktree’s release/CameraReference.app**, confirming 1.0.7. Main’s release/ app remains the accepted 1.0.6 fallback. Bridge 0.5.2 is unchanged.

- [ ] Fully on-screen: clear region in auto mode and invoke in Full, side-by-side and above/below. Fit and split placement remain correct for portrait/landscape.
- [Detection succeeds but placement is offset. I will not expect it to work when an entire panel is off screen. Unless there is a way of capturing the whole window even if partially offscreen] Move Lightroom slightly off the left/right/bottom screen edge. **Clear region setting** to force fresh detection, then invoke. Placement should align with the full Lightroom viewport, clipped naturally at the screen edge. Repeat Full and split. Diagnostics should say window-only filter with an explicit content-local crop.

Storage: consolidated under CameraReference.
Overlay floating while Lightroom is active.
Lifecycle: minimise notifications unavailable; dialog false; minimised unavailable; window-list fallback.
Window maintenance since show: moves 0; ordering changes 1; level changes 1.
Stage timing: enumerate 18 ms; stability/config 152 ms; capture 57 ms; raster 19 ms; detector 58 ms.
Capture mode: window-only filter, explicit content-local crop.
Capture extent (top-left): (-122.0, 30.0, 2560.0, 1349.0).
Source crop (capture-local): (0.0, 0.0, 2560.0, 1349.0).
Side search: left 0…40.0%, right 60.0…100%.
Analysis raster: 2560 × 1349.
Child windows: included.
UI-boundary detection (no OCR; no image saved).
Window: 2560 × 1349 pt.
Window origin (top-left): (-122.0, 30.0).
Filter content rect: (-122.0, 30.0, 2560.0, 1349.0).
Primary display: (0.0, 0.0, 2560.0, 1440.0).
Capture: 2560 × 1349 pixels.
Searched for UI borders.
Rectangle search: L [184, 805], R [2121, 2126, 2402, 2407, 2422], T [30, 62, 120, 138], B [1179, 1197, 1235, 1238, 1241, 1273, 1276, 1284]; 320 checked, 6 supported.
Single-photo mode: UI bounds (184.0, 120.0, 1937.0, 1077.0). Internal divider search disabled.
Sides L/R/T/B: ui/ui/ui/ui. Fit inset: 18.0 pt. Calculated photo: (683.33056640625, 168.0, 694.3388671875, 1041.0).
Final overlay region (AppKit): (62.0, 213.0, 1937.0, 1077.0).
Photo frame (AppKit): (683.33056640625, 231.0, 694.3388671875, 1041.0).
Overlay panel requested (AppKit): (61.0, 212.0, 1939.0, 1079.0). Actual: (61.0, 212.0, 1939.0, 1079.0).
Overlay content bounds: (0.0, 0.0, 1939.0, 1079.0). Photo viewport (view): (622.33056640625, 19.0, 694.3388671875, 1041.0). Panel visible: true. Display scale: 1.0.
Background check paused: Lightroom is off-screen or spans displays.

Timing: Bridge 105 ms; JPEG load/decode 9 ms; RAM cache hit; source files revalidated; capture and detection 303 ms; total to panel shown 446 ms

Bridge 105 ms; JPEG load/decode 9 ms; RAM cache hit; source files revalidated; capture and detection 303 ms; total to panel shown 446 ms

- [x ] Move it back, clear region and invoke: diagnostics return to display-bound capture with correct placement. If available, repeat across two displays, including different scales.

- [Still not quite working. Why can't it be dismissed before minimising then restored afterwards? ] With overlay visible, minimise using the yellow button and Cmd-M, then restore; repeat several times. No overlay remains near the Dock and it returns aligned. Diagnostics → Lifecycle reports whether minimise notifications are active. If unavailable, report that alongside the result; do not reset permissions.

Storage: consolidated under CameraReference.
Overlay floating while Lightroom is active.
Lifecycle: minimise notifications unavailable; dialog false; minimised unavailable; window-list fallback.
Window maintenance since show: moves 0; ordering changes 1; level changes 1.
Stage timing: enumerate 18 ms; stability/config 152 ms; capture 57 ms; raster 19 ms; detector 58 ms.
Capture mode: window-only filter, explicit content-local crop.
Capture extent (top-left): (-122.0, 30.0, 2560.0, 1349.0).
Source crop (capture-local): (0.0, 0.0, 2560.0, 1349.0).
Side search: left 0…40.0%, right 60.0…100%.
Analysis raster: 2560 × 1349.
Child windows: included.
UI-boundary detection (no OCR; no image saved).
Window: 2560 × 1349 pt.
Window origin (top-left): (-122.0, 30.0).
Filter content rect: (-122.0, 30.0, 2560.0, 1349.0).
Primary display: (0.0, 0.0, 2560.0, 1440.0).
Capture: 2560 × 1349 pixels.
Searched for UI borders.
Rectangle search: L [184, 805], R [2121, 2126, 2402, 2407, 2422], T [30, 62, 120, 138], B [1179, 1197, 1235, 1238, 1241, 1273, 1276, 1284]; 320 checked, 6 supported.
Single-photo mode: UI bounds (184.0, 120.0, 1937.0, 1077.0). Internal divider search disabled.
Sides L/R/T/B: ui/ui/ui/ui. Fit inset: 18.0 pt. Calculated photo: (683.33056640625, 168.0, 694.3388671875, 1041.0).
Final overlay region (AppKit): (62.0, 213.0, 1937.0, 1077.0).
Photo frame (AppKit): (683.33056640625, 231.0, 694.3388671875, 1041.0).
Overlay panel requested (AppKit): (61.0, 212.0, 1939.0, 1079.0). Actual: (61.0, 212.0, 1939.0, 1079.0).
Overlay content bounds: (0.0, 0.0, 1939.0, 1079.0). Photo viewport (view): (622.33056640625, 19.0, 694.3388671875, 1041.0). Panel visible: true. Display scale: 1.0.
Background check paused: Lightroom is off-screen or spans displays.

Timing: Bridge 105 ms; JPEG load/decode 9 ms; RAM cache hit; source files revalidated; capture and detection 303 ms; total to panel shown 446 ms

Bridge 105 ms; JPEG load/decode 9 ms; RAM cache hit; source files revalidated; capture and detection 303 ms; total to panel shown 446 ms

- [x ] Briefly check Mission Control, another app covering Lightroom, ordinary movement, split RAW clicking/panning and switching to Library. No flicker; Library still dismisses. Floating display remains independent.

For any failure, copy Developer tools → Bridge diagnostics before invoking again. For shifted off-screen placement, also use Inspect screen layout / capture preview to check whether the entire parent window was captured. No screenshots are saved automatically. These native behaviours remain provisional until tested.

```

## 1.0.8 diagnostic candidate

Native build and the final `bash test.sh` run passed, including new AX geometry ambiguity/read-failure/error-description checks and existing capture, Full/split, bridge, preview and navigation regressions. Staged signature/plist and `git diff --check` passed. An earlier test compilation overlapped a source edit; the full suite was rerun after edits stopped.

Live inspection was blocked by Computer Use permission. No live test result was obtained; the user explicitly requires all live interaction to remain theirs, now recorded in AGENTS.md. This version does not establish whether Accessibility is granted to the running app, whether notification arrival precedes animation, or how off-screen pixels map to the parent. It exposes those distinctions and preserves a comparison baseline in memory. Native evidence is pending in TESTING.md. Main and its 1.0.6 staged app remain unchanged.

## User results for 1.0.8

Verbatim checklist:

```text
# CameraReference 1.0.8 — diagnostic checks

Main stays at **1.0.6**. Quit the current app and open this candidate’s **release/CameraReference.app**. Bridge 0.5.2 is unchanged. Your 1.0.7 annotations are preserved verbatim in docs/VALIDATION.md. All live interaction is yours.

- [Discussed ] Show an overlay, then copy **Developer tools → Bridge diagnostics…**. It should distinguish missing Accessibility permission, failed window matching or specific notification registration errors. The diagnostics dialog dismisses the overlay, so invoke it again before testing.
- [Discussed ] If permission is missing, choose **Settings → Enable minimise monitoring…** and enable this candidate yourself in macOS Accessibility. Reopen the app if macOS requires it. Show the overlay; minimise/restore via yellow button and Cmd-M several times, then copy diagnostics. Report whether hiding occurs before/during/after animation and whether restoration succeeds. No reset of other permissions is needed.
- [They appear completely the same. ] With Lightroom fully on-screen, choose **Developer tools → Keep on-screen capture baseline…**. Keep its preview open. Move Lightroom slightly off-screen **without resizing or changing the photo/panels**, then choose **Preview captured Lightroom window…**. Compare the complete title bar, all window corners and panel edges in the two named previews. Report clipping/shift/stretch and copy Bridge diagnostics (contains both capture geometries). Close both previews afterward; no images are saved automatically.
- [Yes, but when off-screen, even the snapping doesn't work during calibration.] Off-screen, clear region in auto mode and invoke: it should decline fresh detection and offer manual calibration, without producing a displaced overlay. Cancel, move Lightroom fully on-screen and invoke: normal Full/split detection still works. Existing overlays should continue following ordinary movement.
- [x ] Briefly check no flicker while clicking/panning RAW, other apps covering Lightroom and Library dismissal. Do not merge until the outstanding behaviour is accepted.

```

Chat evidence: Accessibility granted; both registrations succeeded and mini/restore events reached 1/1. Polling suspended at uptime 702698.269, notification arrived at 702698.290, restore notification at 702700.935 and overlay restored at 702701.439. No intentional movement; each cycle added two moves. User observed lingering, stutter and downward jump during minimise, then late reappearance on restoration. Baseline/latest previews looked identical. Main remains 1.0.6.

## 1.0.9 automated validation

Native testing build and `bash test.sh` passed, including immediate ordinary movement versus settled resize/restore sequences, diagnostic section headings and single timing emission. Shell syntax, staged signature/plist and diff checks passed. The generated purple icon was inspected locally. Testing bundle identity is org.local.CameraReference.testing; main’s clean tree and staged 1.0.6 were verified unchanged. No application was launched, no permissions changed and no live UI interaction was performed. Native minimisation geometry/timing, section-window usability, off-screen placement/snapping and new testing permissions remain in TESTING.md.

## 1.0.9 automated validation

Native testing build and bash test.sh passed, including immediate movement versus settled resize/restore sequences, diagnostic section headings and single timing emission. Shell syntax, staged signature/plist and diff checks passed. The generated purple icon was inspected locally. Testing bundle identity is org.local.CameraReference.testing; main remains clean with staged 1.0.6 unchanged. No application was launched, no permissions changed and no live UI interaction was performed. Native minimisation timing, diagnostic-window usability, off-screen placement/snapping and testing permissions remain in TESTING.md.

## 1.0.9 permission blocker

User could not successfully grant Screen Recording to the testing app; functional acceptance was blocked. No annotated checklist was supplied. Stable remains at 1.0.6.

## 1.0.10 rebuild checks

Native testing build, shell syntax, staged plist/signature and diff checks passed. Staged path is release/CameraReference Testing.app; bundle ID remains org.local.CameraReference.testing, executable is CameraReferenceTesting, version 1.0.10. T badge inspected at small icon size. Old ambiguously named testing payload moved into ignored build/retired-testing.*; main source and staged 1.0.6 remain untouched. No new Library folder or preference domain. Permission code compiled; native permission recovery has not been tested. No certificate was installed, no TCC reset or live UI interaction performed. Unchanged detection/geometry suites were not repeated for this identity/permission-message rebuild.

## User acceptance of 1.0.10 candidate

```text
# CameraReference Testing 1.0.10

Keep main’s accepted 1.0.6 app. Quit it before opening this worktree’s **release/CameraReference Testing.app**. Confirm **Camera Reference Testing 1.0.10**, purple icon with a large T. This new testing identity needs its own Screen Recording and optional Accessibility approval; stable’s entry should remain. Settings/config and bridge 0.5.2 are shared. All live interaction is yours.

- [Discussed. ] Existing shortcuts, layout and calibration/config preferences remain. Stable and Testing are distinguishable in macOS permission settings. If Accessibility is missing, Developer tools → Inspect Accessibility layout… requests it.
- [x ] Show overlay; minimise/restore repeatedly without moving Lightroom. Check no downward jump and whether moves remains zero. In diagnostics, report geometry source and whether any lingering/late reappearance remains. Early hiding is still under investigation.
- [x ] Clear region in auto mode, move Lightroom slightly off-screen and invoke: fresh Full/split placement aligns. Test portrait/landscape. Manual calibration Option-snapping works on visible edges. Return on-screen and verify accepted placement remains correct.
- [x ] Bridge diagnostics has six selectable sections, scrollable text and Copy all. Performance appears once; the standalone monitoring menu action is gone.
- [x. This should show up whenever I invoke in Library. The actual wanted behaviour is that it should be usable in both Library and Develop. However when I swich module the overlay should disappear. Unless there are some functionality that you have to have develop enabled. In the case we want do disable usage under Library, then it should prompt the user to swich to Develop whenever appropriate.] In Library, baseline/preview/Find viewing area show “Switch Lightroom to Develop.” In Develop they work. Preview baseline still remains available for comparison.
- [x ] Briefly check ordinary window following/resizing, no flicker during RAW pan/clicks, app covering, Library dismissal and floating display. Main remains unchanged until acceptance.

Copy all diagnostics after any failure, before invoking the overlay again. Prior annotations and chat findings are preserved in docs/VALIDATION.md.

**Permission gate first:** add the exact newly named CameraReference Testing.app to Screen Recording, leaving stable untouched, then quit/reopen Testing if required. If it still reports no permission, stop functional tests and copy App & permissions diagnostics. The rebuild does not yet prove that macOS will accept the grant.

```

Chat: no downward jump observed. AX list exposed 24 windows but only 16 examined; binding failed. User wants Library and Develop only, with overlay dismissed on module changes. AX-derived viewport geometry and 50/50 split remain deferred.

## 1.0.11 validation

Audit found explicit module guards, not a Develop-only photo/extraction API dependency. Testing build and full bash test.sh passed. Lua stand-ins now accept Library overlay/floating requests and reject Map/Book/Print/Slideshow/Web, including floating requests outside allowed modules. Swift checks cover confirmed module transitions versus unknown heartbeat, Library region clearing without changing Develop or mode preference, and a host at index 23. Existing detector/geometry/image/preview checks passed. Signature/plist, staged bridge 0.5.3 and diff checks passed. Main remains clean with app 1.0.6. No bridge installation, app launch, permissions changes or live interaction by the agent. Library placement and AX native matching remain pending.

## User results — 1.0.11 (preserved verbatim)

# CameraReference Testing 1.0.11

Main remains 1.0.6. Quit it before running this worktree’s release/CameraReference Testing.app. **Update/reload the staged CameraReference.lrplugin manually; verify bridge 0.5.3.** Same purple T identity and shared settings/config. All live interaction is yours.

- [x ] In Library Loupe, select RAW: overlay, floating display, capture preview and Find viewing area work. Check portrait/landscape at Fit, automatic placement and manual calibration. Library Grid/Survey/Compare alignment is not claimed supported.
- [x ] Switch Library ↔ Develop with overlay visible: it dismisses. Reinvoke in the new module: fresh placement aligns, without using the other module’s calibration. Repeated toggles within the module still reuse valid caches.
- [x ] Switch modules while JPEG/capture/calibration is pending: no late overlay or calibration is saved in the new module. Switch to Map/Book/Print/Slideshow/Web: no new reference invocation; an explicit Library/Develop prompt appears. Existing floating display stays independent.
- [x. If the menu item selection is not remembered for the two modules, then switching back and forth with different views won't work. ] Clear Library region: Develop’s region and preferences remain intact. Return to Develop: Full/split placement, shortcuts and calibration still behave as before. Library defaults auto on only when its preference is absent.
- [Still lingers. but otherwise no bad behaviour. ] Diagnostics after show: AX host is bound via main/focused or all-window search, even with >16 AX windows. Minimise/restore repeatedly; report counters/geometry source and any remaining linger/jump.
OVERLAY VISIBILITY & MINIMISATION
Overlay floating while Lightroom is active.
Geometry source: Accessibility logical frame
Lifecycle: minimise notifications active; dialog false; minimised false; Accessibility + window list.
AX host bound via main/focused window, geometry verified (1 examined; 32 listed).
notifications mini: success (0); restore: success (0); AXMinimized: success (0); value false; events mini/restore 1/1
AX event history (uptime seconds): 714411.176 mini received; 714412.379 restore received
Moves: 4; ordering changes: 2; level changes: 1.

Event history (uptime seconds):
714403.618 overlay created
714411.176 suspend: Lightroom minimise notification
714411.302 suspend: Lightroom minimised or thumbnail transition
714412.902 restore: host visible and settled

- [Off screen snapping and placement no longer working. As discussed.] Briefly repeat off-screen placement/snapping, ordinary movement, no flicker, app covering and sectioned diagnostics. Do not merge yet.

Use Copy all after failures before invoking again. Prior test annotations are preserved in docs/VALIDATION.md. This build does not add AX-derived photo bounds or guessed split dividers.

## 1.0.12 candidate

Read-only comparison found ScreenProbe, ViewportDetector and Views unchanged between 1.0.10 and 1.0.11. User reports off-screen regression in both modules; bitmap padding is suspected, not proven to be caused by child windows. New off-screen path uses one SCStream frame and its boundingRect/scaleFactor/screenRect to normalize the parent surface. Synthetic checks cover padding, Retina scaling, child-union extents and invalid metadata; native results remain pending. Minimise shrinking-presentation evidence also requires native confirmation; AX notifications alone can arrive late.

Automated checks: bash test.sh passed all Swift/Lua suites, including new module-layout isolation, animation evidence and padded capture geometry cases. Testing build compiled successfully. No live capture, permission changes or Lightroom interaction were performed; main/release remains untouched.

## User results — 1.0.12 (preserved verbatim)

# CameraReference Testing 1.0.12

Main stays at 1.0.6. Quit the stable app, then run this worktree’s `release/CameraReference Testing.app` (purple T). Bridge remains **0.5.3**; no plugin update if already loaded. All live interaction is yours. Prior annotations are preserved in docs/VALIDATION.md.

- [x ] Choose Full in Library and a split pane in Develop. Switch back and forth, then relaunch: each module remembers its own selection. Existing Develop calibration/preferences remain intact. Clear region still leaves auto/manual mode unchanged.
- [x ] On-screen: Full and split placement, repeated toggles and Option snapping still work in Library Loupe and Develop.
- [As discussed. Even a tiny bit of offscreen triggers capture failure] With the same window size, keep an on-screen capture baseline, move Lightroom slightly off each edge (also left + bottom together), then preview. Latest capture should show just the complete Lightroom window, without the extra padding. Try fresh placement and Option snapping in both modules. Copy diagnostics if it fails; look for Frame screen rect / bounding rect / Parent pixel crop or a geometry-verification error.
- [I think slightly reduced but still there. No jump but orphaned.] Minimise/restore with an overlay visible: check whether lingering is reduced, with no downward jump or orphan overlay. Copy lifecycle history if it persists. Move partly off-screen and resize normally: overlay remains usable; ordinary clicks do not flicker.

APP & PERMISSIONS
Camera Reference Testing 1.0.12
Accessibility: granted
Screen Recording: granted
ExifTool: available
App: /Users/lm808/Documents/Codex/CameraReference/worktrees/flicker-fix/release/CameraReference Testing.app
Bundle ID: org.local.CameraReference.testing
Storage: consolidated under CameraReference.

────────────────────────

LIGHTROOM BRIDGE
Heartbeat: 0 seconds ago
Plugin status: Running 0.5.3

────────────────────────

OVERLAY VISIBILITY & MINIMISATION
Overlay floating while Lightroom is active.
Geometry source: Accessibility logical frame
Lifecycle: minimise notifications active; dialog false; minimised false; Accessibility + window list.
AX host bound via main/focused window, geometry verified (1 examined; 32 listed).
notifications mini: success (0); restore: success (0); AXMinimized: success (0); value false; events mini/restore 4/4
AX event history (uptime seconds): 716350.335 mini received; 716352.334 restore received; 716355.126 mini received; 716357.108 restore received; 716359.855 mini received; 716361.895 restore received; 716404.122 mini received; 716406.895 restore received
Moves: 0; ordering changes: 8; level changes: 3.

Event history (uptime seconds):
716355.122 suspend: Lightroom minimised or thumbnail transition
716355.126 suspend: Lightroom minimise notification
716355.292 suspend: Lightroom minimised or thumbnail transition
716357.497 restore: host visible and settled
716359.855 suspend: Lightroom minimise notification
716360.094 suspend: Lightroom minimised or thumbnail transition
716361.304 suspend: host presentation shrinking during minimise
716361.481 suspend: Lightroom minimised or thumbnail transition
716362.296 restore: host visible and settled
716404.122 suspend: Lightroom minimise notification
716404.292 suspend: Lightroom minimised or thumbnail transition
716407.285 restore: host visible and settled

────────────────────────

PLACEMENT & CAPTURE
Stage timing: enumerate 21 ms; stability/config 158 ms; capture 43 ms; raster 18 ms; detector 55 ms.
Display-bound crop; frame normalization not needed.
Capture mode: display-bound window filter, explicit crop.
Capture extent (top-left): (0.0, 0.0, 2560.0, 1440.0).
Source crop (capture-local): (0.0, 30.0, 2560.0, 1349.0).
Side search: left 0…40.0%, right 60.0…100%.
Analysis raster: 2560 × 1349.
Child windows: included.
UI-boundary detection (no OCR; no image saved).
Window: 2560 × 1349 pt.
Window origin (top-left): (0.0, 30.0).
Filter content rect: (0.0, 0.0, 2560.0, 1440.0).
Primary display: (0.0, 0.0, 2560.0, 1440.0).
Capture: 2560 × 1349 pixels.
Searched for UI borders.
Rectangle search: L [16, 31, 306, 927], R [1621, 2243, 2248, 2524, 2529, 2544], T [32, 90, 108], B [1149, 1167, 1205, 1208, 1211, 1243, 1246, 1320, 1333]; 648 checked, 8 supported.
Single-photo mode: UI bounds (306.0, 90.0, 1937.0, 1077.0). Internal divider search disabled.
Sides L/R/T/B: ui/ui/ui/ui. Fit inset: 18.0 pt. Calculated photo: (927.33056640625, 138.0, 694.3388671875, 1041.0).
Final overlay region (AppKit): (306.0, 243.0, 1937.0, 1077.0).
Photo frame (AppKit): (927.33056640625, 261.0, 694.3388671875, 1041.0).
Overlay panel requested (AppKit): (305.0, 242.0, 1939.0, 1079.0). Actual: (305.0, 242.0, 1939.0, 1079.0).
Overlay content bounds: (0.0, 0.0, 1939.0, 1079.0). Photo viewport (view): (622.33056640625, 19.0, 694.3388671875, 1041.0). Panel visible: true. Display scale: 1.0.

────────────────────────

CACHE & BACKGROUND CHECKS
Background check invalidated cached placement (visible overlay retained): UI boundaries changed.
Previous UI: Optional((16.0, 243.0, 2528.0, 1077.0)); checked UI: Optional((16.0, 245.13649851632044, 2226.0, 1072.7952522255193)).
Stage timing: enumerate 25 ms; stability/config 166 ms; capture 40 ms; raster 5 ms; detector 27 ms.
Display-bound crop; frame normalization not needed.
Capture mode: display-bound window filter, explicit crop.
Capture extent (top-left): (0.0, 0.0, 2560.0, 1440.0).
Source crop (capture-local): (0.0, 30.0, 2560.0, 1349.0).
Side search: left 0…40.0%, right 60.0…100%.
Analysis raster: 1280 × 674.
Child windows: included.
UI-boundary detection (no OCR; no image saved).
Window: 2560 × 1349 pt.
Window origin (top-left): (0.0, 30.0).
Filter content rect: (0.0, 0.0, 2560.0, 1440.0).
Primary display: (0.0, 0.0, 2560.0, 1440.0).
Capture: 1280 × 674 pixels.
Searched for UI borders.
Rectangle search: L [7, 391], R [1122, 1125, 1263, 1273], T [17, 44, 53], B [575, 583, 603, 606, 622, 660, 667]; 168 checked, 4 supported.
Single-photo mode: UI bounds (8.0, 46.0, 1113.0, 536.0). Internal divider search disabled.
Sides L/R/T/B: ui/ui/ui/ui. Fit inset: 18.0 pt. Calculated photo: (783.2328333642433, 140.06824925816022, 691.5343332715133, 1036.7952522255193).
Final overlay region (AppKit): (16.0, 245.13649851632044, 2226.0, 1072.7952522255193).
Photo frame (AppKit): (783.2328333642433, 263.13649851632044, 691.5343332715133, 1036.7952522255193). 1280px check: 264 ms elapsed.

────────────────────────

PERFORMANCE
Bridge 90 ms; JPEG load/decode 3 ms; RAM cache hit; source files revalidated; capture and detection 296 ms; total to panel shown 413 ms

- [ ] Switch Library ↔ Develop and another app; check dismissal on module change, other apps covering the overlay, and normal restoration after Mission Control.

Do not merge until accepted. Off-screen capture normalization and earlier minimise suspension are candidates, not confirmed native fixes.

User subsequently accepted the remaining brief minimise orphan/linger as a limitation. Per-module layout and on-screen checks passed. Off-screen capture fails even with slight clipping; its actual error was swallowed by the outer handler. 1.0.13 exposes that error without changing capture geometry.

1.0.13 automated validation: full bash test.sh suite passed, including injected nested capture errors retained through the reporting boundary. Testing app compiled without warnings. No live capture or Lightroom interaction performed. Off-screen root cause still awaits native diagnostic evidence.

## Native follow-up — 1.0.13 and original 1.0.10

The unchanged 1.0.10 comparison build also displaced off-screen placement at (-28,50,2438,1303). 1.0.13 rejected that geometry: content bounds 2438 × 963.725 and content scale 0.726244. Right clipping also failed (content height 1038.481; scale 0.796992). Later, after Lightroom restart but at a different size/position, both left and right clipping worked with a 2348 × 1264 bitmap matching the parent and content scale 1. AX window count changed from 32 to 15; causation is unproven. Subsequent side-by-side failure recovered after further interactions without diagnostics, so off-screen reliability remains unresolved. User intends to gather edge cases during use and requested raw previews regardless of geometry rejection.

## 1.0.14 raw preview separation

Preview returns the original captured CGImage before metadata validation/normalization, including missing metadata and malformed geometry. Window movement does not reject an already acquired diagnostic preview. Normal placement and snapping keep their guards. Synthetic checks verify original image identity/dimensions on preview and rejection/cropping on placement. Native intermittent failure reproduction is left to the user. No runtime setting changes or live app interaction.

1.0.14 automated checks: full bash test.sh passed, including unchanged-image preview with absent/invalid geometry and retained placement rejection/cropping. Testing build succeeded; no live UI checks performed. User constrained this update to raw-preview behaviour only and will consider a merge after brief native testing.

## Acceptance and main promotion — 2026-11-12

User reported 1.0.14 looks good for now and explicitly requested merge into main. Main fast-forwarded to 5494c24; normal-identity release/CameraReference.app rebuilt from accepted sources. Brief minimise lingering remains accepted. Intermittent off-screen/split failures remain open for longer-term observation; this acceptance is not a claim those cases are solved. No settings changed, app launched, plugin installed, DMG packaged or remote pushed.

## 1.0.15 diagnostic-only update on main

User explicitly authorised this update on main and requested removal of old worktrees after preserving testing assets. Inspect Accessibility layout now adds a dedicated AX/display mapping section: numbered AXWindows entries (including duplicate/unreadable/budget-limited rows), role/subrole, main/focused/minimized/optional AXVisible state, precise global rectangles, matching public CG IDs and CG on-screen/layer/alpha evidence. Display names/IDs, point bounds, backing scale, mode pixels, rotation and mirroring support screenshot alignment. No titles, filenames, control values or screenshots are queried. Geometry/state is observational and never used as placement input. Existing probe and app behaviour remain otherwise unchanged. Native mapping requires the user's screenshot/report.

Automated validation: full bash test.sh passed, including a 40-row synthetic AX report preserving duplicates, unavailable entries and negative/subpoint coordinates. Normal app build succeeded. Signature/plist staging checks performed; no live AX inspection or screenshot was collected by the agent.


## 1.0.16 candidate

Synthetic AX fixtures cover single/split estimates, hidden labels/panels, and the translated 1950 × 1253 smaller host without information rectangles. User screenshots established the evidence described in METHODS; they do not validate the new implementation. Native acceptance checklist is TESTING.md. Main remains 1.0.15.

Automated checks: `bash test.sh` passed (Swift regression executables and Lua stand-ins, including AX trial fixtures). Testing app builds with native Apple tools. No app launch, permission change or Lightroom interaction was performed by the agent.


## 1.0.17 candidate

The AX option was confirmed enabled in read-only preferences. Source review found no explicit order-front call for newly attached diagnostic panels. Added it, preserving suspension, with per-panel visibility/frame reporting. Native verification remains with the user; no live app interaction performed.


## 1.0.18 candidate

User report confirmed a valid proposal was rejected by the preview host check. Source inspection established AX top-left was compared directly against HostWindowSnapshot AppKit bounds. Corrected only the trial comparison; regression includes the reported (0,30,2560,1349) host and its AppKit (0,61,2560,1349) counterpart on the 1440-point primary display, plus a negative-origin display.

## 1.0.19 candidate — AX investigation groundwork

Automated: full `bash test.sh` suite passed after shared-config/parser changes. Core checks were rebuilt and rerun after adding zero-default/inline-comment parsing, conditional toolbar offsets, unchanged production cache key, invalid-setting rejection, append-only/idempotent migration and older-parser compatibility cases; all passed. Native testing app builds successfully. The capture/boundary detector sources are unchanged.

The all-window child-control traversal and automatic-view routing still require native acceptance. No app launch, Lightroom interaction, permission change or personal config edit was performed by the agent. Candidate config additions occur when the user runs the app; `# AX:` directives remain comments to stable 1.0.15. Main and its release staging were not rebuilt.

Next evidence: single view, toolbar shown versus hidden at unchanged host size, then toolbar shown at a smaller size. Collect screenshots plus explicit Refresh AX reports before experimenting with the commented geometry hints. Zero defaults intentionally leave unresolved raw bounds visible. Saved text reports overwrite `CameraReference/Diagnostics/latest.txt`; read each case before the next replaces it.

## 1.0.20 candidate — focused toolbar structure

Testing app built successfully with native Swift tools. This change adds read-only diagnostic queries on explicit Refresh AX, with element/depth/time limits and failure reporting. No geometry/detector/placement algorithm changed; full unchanged image suites were not rerun. Native attribute availability and toolbar shown/hidden comparison remain unverified. No app launched or live AX query made by the agent. Earlier saved reports were inspected only.

## 1.0.21 candidate — live view and automatic diagnostics

Testing app built and staged successfully; strict signature verification, staged version check and `git diff --check` passed. Full `bash test.sh` suite passed. ScreenProbe, ViewportDetector, PhotoDetector and SplitLayout sources are unchanged from 1.0.20. Scheduling changes are confined to the app coordinator.

Live polling, menu transitions and automatic report freshness require user acceptance in Lightroom; automated geometry tests do not verify native timing. Diagnostics retain bounded traversal limits and report truncation rather than promising every accessible element. No app launch, live AX query, permission change or personal settings edit was performed. Main and its staged app remain untouched.

## 1.0.22 candidate — AXSections

Native testing build passed. Diagnostic-only traversal added inside accessibilityToolbarReport; screenshot detector files and runtime view/placement coordinator unchanged. Existing full regression suite passed in 1.0.21; it was not rerun for this isolated reporting change. Native AXSections payload/toolbar evidence remains pending. No live app interaction or personal settings edits performed.

## Standalone AX Explorer 1.0.0

Separate executable, no app source/build changes. Native compilation, strict signature verification, shell syntax and diff checks passed. The no-live-AX self-test passed, as did scripted interactive checks for valid/invalid limits, disconnected scan rejection, help and report clearing. User acceptance is still required for permission attribution, interactive traversal and report comparison. No live AX calls or permission requests made by the agent. App remains candidate 1.0.22; main remains 1.0.15.

## Standalone AX Explorer 1.0.1

Adds only a read-only toolbar menu command. Pure checks cover Show/Hide inference, unknown titles and avoiding Command-T as a toolbar shortcut. No live AX/permission/menu action is performed by the agent. Native menu freshness and availability remain pending; app unchanged at 1.0.22.

Native build, staged signature verification, self-test and disconnected interactive command checks passed for Explorer 1.0.1. Initial execution after an in-place staged binary replacement was killed by macOS; staging now atomically replaces the executable, after which both checks passed. This staging change affects only the standalone explorer. Shell syntax and git diff checks passed.

## Standalone AX Explorer 1.0.2

Delayed toolbar command built/staged successfully and strict signature verification passed. Pure tests validate finite 1–60 second delays; scripted command checks confirm invalid arguments and disconnected requests return immediately without sleeping or querying AX. Native delayed focus/menu freshness testing remains with the user. No live interaction performed; main app and screenshot detector unchanged.

## Standalone AX Explorer 1.0.3

Moved five existing probe reports from Application Support into the development worktree’s ignored investigations/ax-reports directory. Future saves resolve that directory from the executable location. Pure path checks cover release, build and externally copied executables; self-tests, native build, strict signature verification and diff checks passed. Git ignores the report directory. No live AX calls were made; main app, screenshot detector and personal settings are unchanged. Reopen the explorer to use the new save location.

## 1.0.23 candidate — toolbar menu state and investigation cleanup

Full bash test.sh suite passed, including title classification and unknown-to-shown fallback checks. Native candidate build/staging, strict signature verification, explorer self-tests and shell/diff checks passed. ScreenProbe, ViewportDetector, PhotoDetector and SplitLayout are byte-unchanged from the preceding candidate. Main's staged app and personal settings were not modified. Native app toolbar readings, focus behaviour and preview placement still require the TESTING.md checks; standalone user evidence is not app acceptance.

Removed exhaustive control/AXSections routines from the app; retained window/display/opacity evidence and concise toolbar reports. Standalone AX Explorer 1.0.4 builds atomically under build/AXExplorer, with no release staging. Removed only the obsolete release/AXExplorer payload; saved investigation reports remain under ignored investigations/ax-reports. Consolidated current methods and investigation evidence; historical validation and changelog entries remain in their respective files. No live interaction, installation, packaging or push performed.


## 1.0.24 — AX-only placement candidate

Full automated regression suite passed during implementation; core behaviour/config/AX geometry checks were rerun after the final append-only config adjustment and passed. Testing build completed without compiler warnings; staged signature verification passed, with version 1.0.24 and testing bundle identity. `git diff --check` passed. ScreenProbe.swift, ViewportDetector.swift, PhotoDetector.swift and SplitLayout.swift have no changes from the previous candidate.

Synthetic coverage includes signed shown/hidden borders, cumulative filmstrip/toolbar corrections, independent Library allowance, manual/backend precedence and selected-pane geometry. Explicit screen inspection, capture previews and calibration snapping retain their existing paths in AX mode; automatic AX placement skips screenshot cache/capture, and background placement captures are disabled. No live app was launched or Lightroom queried; native acceptance remains in TESTING.md. Library's extra allowance remains zero pending measurement; filmstrip shown with toolbar hidden is an inferred offset combination requiring confirmation. Main and its staged daily-use app remain unchanged.


### Library default follow-up (no version/build change)

User calibrated the additional Library bottom correction to +25 pt and updated their personal config. Source defaults and fresh-install template now use 25; current documentation and the existing geometry assertions reflect that default. Historical zero-default notes above describe the earlier build. No personal config, detector, version or staged app changed.

User clarification: the +25 pt Library correction applies only to inferred split views, never single view. Updated the condition and regression checks for both split orientations and unchanged Library single view. No app rebuild or version change.


## 1.0.25 — File-driven config editor

Editor regression executable passed: exact CRLF round-trip, directive/inline/preceding comment retention, value-only replacement, unknown-row visibility, invalid ranges and multiline input rejection, external-edit conflict refusal, and atomic save. File-coordination tests required execution outside the command restriction; all writes used unique temporary fixtures, never personal config. The Library single-view/both-split geometry assertions passed in the preceding source correction and that correction is now included in the staged app.

Testing app compiled without warnings; staged signature and plist verified (1.0.25, org.local.CameraReference.testing). Diff whitespace checks passed. Screenshot detector/capture/split source files are unchanged. No app launch or live interaction; native editor usability and placement remain for user testing. Main and stable staging are untouched; # AX: removal is deferred until the requested merge.

## 1.0.26 — Config menu cleanup

Removed only the standalone Edit config file menu entry; source inspection confirms the editor button retains its existing action. Testing build and staged signature/plist checks passed; diff whitespace checks passed. No behaviour tests repeated for this menu-only change. Native menu check remains in TESTING.md. No app launch; main unchanged.

Advanced settings… is the final Settings menu item.

## User acceptance notes for 1.0.26 (verbatim)

# Camera Reference Testing 1.0.26

Quit stable first; use this worktree's release/CameraReference Testing.app. Main remains 1.0.15. Native checks pending; no live testing by the agent.

- [x ] Advanced settings… is last in Settings. Settings has no separate Edit config file item; Open config file remains available inside Advanced settings.
- [x, a search function should be included. ] Settings → Advanced settings…: Name / Value / Comment columns and warning are readable. Double-click a value; Save applies it. Cancel/window close leaves the file unchanged. Comments have full hover text.
- [x ] Invalid value: Save reports an error and leaves the file unchanged. Correct it and save successfully. Edit externally while the window is open: Save refuses to overwrite; cancel/reopen shows the latest file.
- [x not tested as directive will be ommited. " appears on reopening without an editor update" is very unclear.] Both ordinary and # AX: settings appear; editing preserves comments/directives. A new supported entry added in plain text appears on reopening without an editor update.
- [x ] Library single view has no additional Library offset. Library side-by-side and above-and-below use +25 pt; Develop is unchanged.

- [Deve sbs split with right panel hidden fails to detect. Not sure if this is regression. ] With AX-only OFF: existing screenshot Full/split placement, cache hits/background checks and manual calibration still work as before.
- [x ] Enable Experimental features → Use AX data only for placement. With automatic viewing area ON, overlay and floating display use AX; diagnostics say capture skipped, no placement cache. No Screen Recording prompt or new captured preview. Background checks report disabled.
- [x ] With AX-only ON, explicit capture-preview/baseline commands and manual calibration edge snapping still work. Turn main automatic placement OFF: saved manual region wins. Turn it back ON: fresh AX geometry is used.
- [Will defer this test. so far good, will catch edge cases during normal use. currently identified one: when window is small, the AX prediction covers the panels on the side shown ] Develop all shown, each panel hidden, and multiple panels hidden: Full/side-by-side/above-and-below bounds use corrected outer edges before splitting. Select either pane; with automatic view inference OFF, explicit layout applies (mismatch offers manual calibration). With it ON, fresh inference selects layout and remembered pane.
- [x, "Unknown toolbar status assumes shown" expose setting in config. Alternative is use last know state. ] Toolbar shown/hidden and filmstrip shown/hidden: corrections are cumulative. Unknown toolbar status assumes shown. Filmstrip shown + toolbar hidden (-11 pt total) needs confirmation.
- [ x] Library split views use their separate configurable bottom allowance (default +25 pt, confirmed by the user). Do not calibrate against failed Library split screenshot detection.
- [x clean up before next merge with main] Edit a v2 offset: right/up positive; placement and independent AX preview both respond next invocation. Existing source/config preferences remain unchanged; old v1 values remain but are ignored. Preview toggle works with either backend.
- [ x] Rapid invocation/cancellation, photo/module switch and window movement during AX reads: no stale result appears. AX failure never captures; cancellation keeps settings. Existing visible-overlay movement/minimisation behaviour remains usable.

For comparisons, read Diagnostics/latest.txt after each case; no saved images needed. Test another window size after the fixed-size baseline.

## 1.0.27 — Search, toolbar fallback and plain config

Automated Swift/Lua regression suites passed. The config-editor fixture required macOS file coordination access outside the command restriction and passed separately. Search tests cover case-insensitive names/comments, no matches, empty query, and correct edits through filtered indexes. Toolbar tests cover fresh-state precedence, shown/hidden fallback, last-known reuse, separate Library/Develop and process contexts, and no-history default. Example text equals generated defaults; prepared personal config parses and preserves all 26 active values while removing 11 obsolete entries. Testing build passed without warnings.

Native search/fallback checks are pending in TESTING.md; user authorised merge with those limits and the three deferred placement-testing items retained. Full user annotations for 1.0.26 are preserved above. Existing screenshot detector and capture sources are byte-identical to main 1.0.15. No live application interaction, permission changes or screenshots performed.

Promotion completed: main fast-forwarded to the completed work; stable 1.0.27 built and staged at release/CameraReference.app. Signature and stable bundle ID org.local.CameraReference verified. The active config was converted with a before-write fingerprint check and atomic replacement; all 26 active values preserved. Previous personal config and retired testing/build payload are retained under ignored build/retired-ax-investigation; probing reports are retained under ignored investigations/ax-reports. No launch, installation, DMG or push.

## 1.0.28 — Small-window side-panel classification

Reports from 2026-11-14 22:49:37 and 22:51:21 UTC show Library hosts 1047 × 702 and 900 × 702 pt, with both visible side panels 324 × 469 pt. The old 30% width threshold rejected both panels and produced false hidden-side evidence. Removed that threshold; require attachment to exactly one host side while retaining visibility, containment and vertical extent checks.

Core regression executable passed, including both reported host positions/sizes, expected corrected bounds, each hidden side, full-width tall distractors and short edge controls. Existing large-window and split AX checks also passed. Screenshot detector/capture and offsets are unchanged; personal config untouched. Native acceptance remains pending.

Main build and staged signature/plist verified: 1.0.28, org.local.CameraReference. No app launch, permission changes, packaging or push.

## 1.0.29 candidate

User accepted 1.0.28 at minimum window size before this work. Synthetic assisted fixtures compare pixel geometry against pure screenshot for Full and four panes, hidden panels, wrong-hint fallback, toolbar/translation signatures, config-offset independence and preference migration. Native assisted acceptance remains pending; no Lightroom interaction performed by agent.

Automated results: core/Lua, photo detection, viewport (including assisted fixtures), reset, preview, capture, split and config-editor suites passed. Config-editor temporary file coordination required running that executable outside the sandbox. Candidate build, plist and ad-hoc signature verified. Byte comparison confirms ViewportDetector/PhotoDetector and ScreenProbe split scanner/capture helpers unchanged from main; only the optional assisted dispatch was added to capture orchestration.

1.0.29 follow-up: AX-only always enables view inference. Screenshot mode exposes independent assistance/view checkboxes and remembers them across mode switches. Screen Recording is checked without requesting access; absent access skips calibration capture/background checks, and explicit preview/inspection report unavailability before hiding existing windows. User requested no version increment.

Follow-up checks: testing app build and viewport/assisted/option-state regressions passed. Source audit found no CGRequestScreenCaptureAccess calls or screenCapture.ensure callers; the shared permission helper also returns immediately when Screen Recording is absent. Native menu/denied-permission acceptance remains pending.

## User annotations for 1.0.29 (preserved verbatim)

```text
# Camera Reference 1.0.29

Run release/CameraReference Testing.app in worktrees/ax-assisted-screenshot-detection. Main remains 1.0.28. Automated checks and user acceptance are separate. Prior test annotations are preserved verbatim in docs/VALIDATION.md.

## This update

- [x ] Toggle Use screenshot detection in Developer tools → Experimental features. Its two indented options are independent; AX-only always detects the view. Switching method does not dismiss the visible overlay. Manual placement still takes precedence, and AX view detection remains independent in screenshot mode.
- [Mostly working, except those discussed. ] AX-assisted: Full, both split orientations and each pane; show/hide each panel and toolbar; resize to minimum. Compare against Pure screenshot. Collect diagnostics for disagreement.
- [? ] Repeat overlay/float invocation on the same image. Check cache reuse and the assisted evidence counters after internal layout changes. Leave retained screenshot checks enabled for this trial.
- [Mostly, but hard to test as not all edge cases are caught before. ] Pure screenshot and AX-only still behave as before; AX-only reports background capture disabled. AX preview remains independently selectable.

- [When try to capture preview:

Screen inspection failed.
Enumerating Lightroom windows.
com.apple.ScreenCaptureKit.SCStreamErrorDomain (-3801): The user declined TCCs for application, window, display capture
No capture was saved.

capture and detection 21 ms

This needs to be more graceful and indicate that permission is missing. Calibration asks for permission which it shouldn't.

] Without Screen Recording permission, calibration opens without snapping or permission prompts. Preview/inspection explain unavailability without closing an existing overlay; background capture pauses. AX-only continues to work with Accessibility.

## Carried forward

- [x ] Search Advanced settings by name and comment (case-insensitive). Edit a filtered row, clear/change search and verify the edit remains on the correct row. Save/Cancel and external-edit protection still work.
- [x. You check obsolete entries. ] Plain name = value config retains your active values; no obsolete v1 entries or # AX: prefixes remain. Open config file still works from the editor.
- [x ] File-driven rows: close the editor, add a supported setting that is currently absent to config.conf, reopen; its row appears without modifying editor code. Do not add duplicate keys.
- [ ] toolbarUnknownFallback accepts shown, hidden and lastKnown. When AX cannot read toolbar state, diagnostics show the chosen fallback; lastKnown uses prior state for the same module/process, or shown without history.
- [x ] Library's additional +25 pt applies only to split views. Confirm usual overlay/float and screenshot/manual paths remain usable after promotion.

## Deferred to-dos — do not remove until resolved

User confirmed minimum-window AX placement works on 1.0.28.

- [Only via prolonged use, deferred ] Extend small-window testing with each side hidden, then return to a large window.
- [ Works with AX and screenshot AX assist, doesn't work in pure screenshot. Suspect it is the searchwidth setting.] Investigate screenshot detection failure in Develop side-by-side with the right panel hidden; regression status unknown.
- [Only via prolonged use, deferred   ] Broader AX edge-case testing during normal use: panel combinations, both split orientations/panes, window sizes and displays. Record diagnostics for failures.

```

## 1.0.30 candidate automated validation

- Full Swift/Lua suite passed through split tests, including original detector fixtures, AX geometry, two assisted bottom labels, raw top-panel rejection, validated-only midpoint fallback, and capture permission denial reporting.
- The config editor temporary-file save failed under restricted execution (Cocoa 512); its unchanged test executable passed with temporary-file access, including round-trip, external-edit conflicts, atomic saves and filtered-row edits.
- Testing app built successfully. AXTrial.swift, ViewportDetector.swift and PhotoDetector.swift are byte-unchanged from 1.0.29; ScreenProbe changes only permission-error reporting. AX-only geometry/offsets and pure screenshot algorithms remain unchanged.
- Read-only check of personal config: no # AX: prefixed entries; accepted sideSearchPercent 40 and Library split allowance 25 retained. No personal config changes made.
- Native acceptance pending, especially actual Library status labels, menu disabled states and calibration wrapping. Synthetic fixtures do not prove the native failure cause.

## 1.0.31 live overlay update

The candidate app compiles successfully with the live view/pane update route. Existing core, preview, viewport, split and Lua bridge regressions passed again using their unchanged-source test binaries. The placement engines (AXTrial, AXAssisted, ScreenProbe, ViewportDetector, PhotoDetector and SplitLayout) are unchanged from 1.0.30. App routing was reviewed for panel identity, module, epoch, mode, generation and host checks; the existing confirmed-module-change dismissal is unchanged.

Live view transitions and menu actions require native acceptance in TESTING.md. No app was launched and no Lightroom interaction was automated. This update does not claim native verification.

## 1.0.32 Grid and view-change dismissal

Testing app built successfully. Swift/Lua regressions passed, including explicit/empty/missing/ambiguous Grid marks and the full view/pane dismissal matrix with preference on/off and no overlay. The config editor test needed temporary-file access after the restricted run failed with Cocoa 512; its unchanged executable then passed.

AXTrial.swift, AXAssisted.swift, ScreenProbe.swift, ViewportDetector.swift and PhotoDetector.swift are unchanged. SplitLayout.swift only adds a dismissal-policy helper; its geometry is unchanged. Native Lightroom Grid marks, incomplete menu behaviour and settings placement remain pending in TESTING.md. No live app interaction was performed, and no personal settings were changed.

## 1.0.32 same-version live-panel follow-up

Rebuilt the candidate without changing its version/build number, as requested. Recompiled split regressions pass the corrected all-layout dismissal matrix (pane changes included). Existing viewport regressions passed again, including panel/background invalidation, missing boundaries, raw AX signature translation and unchanged assisted/pure paths. Placement-engine files are unchanged; the new behaviour routes panel-change evidence to fresh placement rather than applying low-resolution bounds.

Native checks for panel visibility/resize, zoom/pan flicker, stale completions, selected-photo changes and interval-zero behaviour are in TESTING.md and remain unverified. Defaults are off in the shared GUI preference domain. Personal config and main staging are untouched.

## 1.0.32 AX-only policy correction

Replaced the two WIP preferences with default-on axLiveUpdate; no version/build bump. Screenshot background-check functions match commit 922df2c verbatim. AXTrial.swift, AXAssisted.swift, ScreenProbe.swift, ViewportDetector.swift and DetectionConfig.swift match the prior candidate byte-for-byte; no placement calculations/defaults changed. Initial AX placement now records its raw structural signature for later comparison.

Testing build and Swift/Lua suites passed, including the full AX/screenshot × automatic/manual × live on/off × view/pane/panel-change policy matrix and absent overlay. The config-editor test encountered the existing restricted temporary-save Cocoa 512 failure; rerunning that executable with temporary-file access passed. Candidate staging signature and plist verified (1.0.32 / org.local.CameraReference.testing); git diff --check passed. Main and personal settings are untouched. Native acceptance remains in TESTING.md, including menu visibility, first-poll stability, Grid and toolbar changes. No app was launched or Lightroom interaction performed.

### First-level Grid menu correction (same 1.0.32)

The user's saved report showed two Grid entries with missing marks; the second command was identified as Loupe Overlay → Grid. The reader now traverses only AXMenu wrappers beneath View and never enters a command's submenu. Selection-mark interpretation is unchanged. Testing build and recompiled core regressions pass, including Grid mark semantics; staged signature verified. Native confirmation of the direct Grid item's selected mark remains required. Screenshot/AX placement algorithms, settings and version/build are unchanged.

### Menu wording (same 1.0.32)

Renamed the AX-only option to “Update overlay with LrC view (instead of dismiss)” and aligned the user-facing documentation/checklist. Preference key/default and runtime behaviour are unchanged. Testing app rebuilt; this text-only change does not require repeating the previously passed behavioural suites. No merge to main is performed by this update.

### Main merge — 1.0.32

User authorised merging the candidate after testing. Main fast-forwarded to 088b27e; stable release/CameraReference.app rebuilt and staged with org.local.CameraReference, version 1.0.32, verified signature. No source changes beyond the already checked candidate; no repeat behavioural suite needed for the merge. Remaining unchecked native items are preserved in TESTING.md. No push, app launch, installation or DMG.

### Photo-selection usability update on main — same 1.0.32

User explicitly authorised main and no version bump. Stable app built/staged and signature checked. Split/behaviour regressions pass, including an exhaustive AX/screenshot, automatic/manual, overlay on/off, known/unknown/same/changed epoch and update/dismiss selection-policy matrix. Source review confirms existing token/epoch cancellation is retained; automatic refresh adds panel identity, generation/backend/preference and host guards, with no calibration fallback or repeated attempts for a failing selection. No detector or AX geometry changes. Test checklist includes rapid selections, portrait/landscape Fit, export snapshot, failure retention and stale completion dismissal. Native tests remain user-owned; no app launched or personal settings modified.


## 1.0.33 — structure migration stage 2 candidate

2026-11-18, codex/structure-migration. DiagnosticsService now owns report strings, generations/busy state, diagnostic windows/previews, formatting and atomic saving. Transitional AppDelegate adapters keep the existing call graph; ten moved orchestration methods were compared verbatim with 93117d8. Production placement/source/lifecycle implementations and defaults were not changed.

`bash tests/migration/run.sh` passed six groups, including exact report output against a frozen 1.0.32 formatter, disabled saving, same-report save status, overwrite, save failure, preview invalidation and stage 1 real request completion/cache tests. `bash test.sh` passed core/Lua/detection/viewport/reset/preview/capture/split; config-editor encountered the existing sandbox temporary atomic-save error 512, then the same executable passed outside the sandbox. The script stopped before its final harness invocation; the updated harness had passed separately. Optional external crop fixtures were not supplied.

`bash build.sh --testing` and `bash scripts/stage.sh --no-build` succeeded. Staged testing app version 1.0.33, build 57, org.local.CameraReference.testing; strict deep signature and diff whitespace checks passed. No application was launched. Main remains clean at a568c6e and its staged app was untouched. Native report/preview/window behaviour and matched latency comparisons remain unchecked in TESTING.md; automated results are not user acceptance.


## 1.1.3 — migration stage 3 candidate

2026-11-18. User completed stage 2 testing; exact annotations are retained in migration/STAGE-2-ACCEPTANCE.md. User authorised the separate info-overlay fix and stage-number version scheme. Commit 9ba1bdd requires top/bottom strips to align with both host edges within 4 pt; tests cover info overlay with every side-panel visibility combination and top hidden. Existing AX geometry tests passed; offsets and screenshot algorithms unchanged.

Settings/menu extraction: construction text/order and six build/refresh/validation methods compared equivalent to 03cad24 after owner/selector qualification. Preference interpretation/default registration moved without schema changes; menu actions and delegate still target AppDelegate at original update sites. The migration harness passed seven groups, adding preference-preserving default registration and menu order/target/visibility/validation/inferred-pane checks without a status item or live app launch. The initial command-target assertion was corrected to exclude AppKit's own submenu actions, not by changing production behaviour.

Full test.sh passed core/Lua/detection/viewport/reset/preview/capture/split; config-editor hit the known sandbox atomic-save error 512 and passed outside the sandbox. The script stopped before the final harness invocation; the updated harness passed separately. Optional external crop fixtures were not supplied. Testing build and --no-build staging passed: version 1.1.3, build 58, org.local.CameraReference.testing, strict deep signature valid. git diff --check passed. No application was launched and main remains clean at a568c6e. Native acceptance and matched latency measurements are not claimed; see the lean TESTING.md.


## 1.1.3 build 59 — view-menu presentation only

User completed stage 3 testing; exact annotations are preserved in migration/STAGE-3-ACCEPTANCE.md. The follow-up changes only SettingsMenu.swift production code: one root title/icon without checkmark, no submenu for automatically detected Loupe, two available panes for automatic split, all five choices for manual screenshot selection. Unknown inference retains waiting text; manual calibration still hides view controls. selectLayout, update/dismiss policy, polling, preferences and placement are unchanged.

The migration harness passed all seven groups, including root icon/checkmark, submenu membership across all five selections, automatic-to-manual transitions, unknown-module evidence, hidden calibration controls and unchanged action targets. Request/cancellation/cache and report-equivalence checks also passed. Native menu acceptance is pending in the lean TESTING.md; no app launch or Lightroom interaction was performed. Version remains migration step 1.1.3; build 59 distinguishes this presentation revision.


### Build 60 menu presentation correction

User reported missing icons in build 59. Native menu images were still assigned, but the previous inline symbols had been removed; restore those existing symbols alongside the images without claiming a native rendering diagnosis. Automatically inferred split submenus now use Left/Right or Top/Bottom; manual screenshot choices retain full view names. Seven migration test groups passed, including menu labels/icon assignment, state and unchanged action targets. Native appearance remains for user verification. No selection, placement or update/dismiss code changed.


## 1.1.4 — migration stage 4 candidate

2026-11-18. Pure OverlayBehaviourPolicy consolidates geometry, selection, host visibility/movement, module and Grid decisions. Four extracted helper bodies compare equivalent to build 60 after whitespace normalization. AppDelegate call substitutions preserve short-circuit evaluation, guards, timer order and action execution. Compatibility helper entry points remain. Placement calculations and screenshot paths were not changed.

The existing core/Lua/detection/viewport/reset/preview/capture/split suites passed, including new policy tests for unknown evidence, absent overlays and off-screen host translation. Config-editor encountered the known sandbox atomic-save error 512; the same executable passed outside the restriction. Seven migration harness groups passed separately, covering request/cache guards, report equivalence and menu state. Optional external crop fixtures were not supplied.

The authorised Loupe appearance fix disables automatic validation only on the root menu, explicitly retains the disabled version heading and leaves child validation unchanged. Build/stage testing identity: 1.1.4, build 61, org.local.CameraReference.testing; strict deep signature and whitespace checks passed. No app launch or live Lightroom interaction. Main remains clean at a568c6e. Native appearance, behavioural acceptance and matched performance measurements remain pending in TESTING.md and MIGRATION.md.

## 1.1.4 build 62 — full-screen hidden-top correction

2026-11-19. Authorised separately from migration. Core regression tests passed, including synthetic reproductions of the built-in-display side-by-side label rejection and external HP top/bottom geometry. Confirmed full-screen hidden top removes 32 pt before classification; shown top, windowed/unknown, horizontal outer bounds and bottom remain unchanged. All seven migration harness groups passed. No screenshot detector or config values changed.

Testing app build/staging and strict deep signature verification passed; version 1.1.4 build 62 retains the user's migration-stage numbering. Native AXFullScreen availability and actual placement remain for user acceptance; no live AX calls or app launches were performed by the agent. Diagnostics now expose this flag and the applied correction. Main remains untouched.

## 1.1.4 build 63 — configurable full-screen allowance

2026-11-19. Replaced the placement literal with axFullScreenTitleBarAllowancePoints, documented in generated/example config and automatically included by existing missing-key upgrade logic. Classification snapshots carry this value without introducing calibrated placement offsets into view classification. Core regressions and all seven migration groups passed, including default template, custom allowance, zero, invalid range/nonfinite values, and unchanged windowed results. Build/staging, strict deep signature and whitespace checks passed. Main untouched; native appearance/placement acceptance remains pending. Personal config was not directly edited or replaced.

## 1.1.5 build 64 — migration stage 5

2026-11-19. Placement dispatch extracted to PlacementCoordinator.swift (transitional AppDelegate extension); concrete manual/AX/original screenshot/assisted screenshot adapters and global-AppKit UIPlacement introduced in PlacementImplementations.swift. Mechanical comparison to 9c9b231 confirmed eight moved bodies byte-identical and four equivalent after reversing only reviewed adapter substitutions. Original screenshot detector and split scanner, AX geometry, cache eligibility, permissions, completion/timeout guards and diagnostic preview constraints remain unchanged. AX diagnostic source rectangle is preserved without a coordinate round trip.

All eight migration harness groups passed, including new synthetic AX pane/combined/invalid selection and negative-display-coordinate checks, manual translation and floating Fit equivalence. Existing core regression executable rerun passed (its input source files are unchanged by stage 5). Request guards/report-equivalence/menu tests compile the current extracted implementation. No native capture/AX calls or GUI app launch performed; native acceptance and matched latency measurements remain pending. Optional external screenshot fixtures not run.

Testing build/staging succeeded: 1.1.5 build 64, strict deep signature and whitespace checks passed. Main untouched. Stage 4 annotations preserved verbatim in migration/STAGE-4-ACCEPTANCE.md; three bugs/policy questions explicitly deferred to after migration in BACKLOG.md. Stage 6 not started.

## 1.1.6 build 65 — migration stage 6

2026-11-19. Stage 5 user responses (all four checked) preserved verbatim in migration/STAGE-5-ACCEPTANCE.md. PhotoRequestPipeline owns pending request state, bridge transport/polling, cancellation and image cache; immutable PhotoLoadContext carries existing identities. PhotoRequestCoordinator retains request qualification and display/placement completion handling. No new queues, deadlines, permission requests or retries. Existing 50 ms response polling and five-second deadline preserved; cancellation keeps its cache behaviour and ordering.

Mechanical comparison against 1380010 confirms epoch reader and failure bodies unchanged, cache/decode and completion/dispatch bodies equivalent after whitespace/type-alias changes, and cancellation order preserved. Selection monitoring, AX refresh, module reader and hide bodies unchanged. Nine migration groups passed: real transport request bytes/cadence, partial and wrong-token responses, cleanup-before-callback, timeout, replaced timer; existing real async cancellation/token/selection/module rejection, warm cache, preferences, menus, diagnostics and placement adapter tests. Timer tests fire the actual timer callback directly, without waiting five seconds or launching Lightroom. Native load latency and behaviour still require user acceptance; no performance improvement claimed.

Testing build/staging passed for 1.1.6 build 65; strict deep signature/plist and diff checks passed. No GUI launch, Lightroom manipulation or personal config/bridge writes. Main remains unchanged at a568c6e. The four deferred issues remain unfixed; stage 7 not started.

## 1.1.7 build 66 — migration stage 7

2026-11-20. Overlay and floating display state moved to independent concrete owners; app-facing coordination moved to PresentationCoordinator. Mechanical comparison against 9c52e2d confirms all fourteen relocated method bodies byte-identical (including lifecycle trace and title formatting now executed by the owners). Views, placement algorithms/coordinator and photo-completion guards are unchanged. No new timers, captures, AX reads or queues; no latency improvement claimed.

All ten migration groups passed. Added checks exercise the actual forwarding state and dismissal path: overlay identity/suspension clears without affecting floating title/zoom, controller instances are independent, and lifecycle history remains deduplicated and bounded. Existing request freshness/cancellation, transport, load/cache, absent-overlay, report, preference/menu and coordinate tests still pass. Native windows, hover, suspension/order and latency require user testing; no GUI app was launched. Stage 6 user annotations remain in migration/STAGE-6-ACCEPTANCE.md. Five deferred issues remain unfixed.

Testing build/staging completed for 1.1.7 build 66; strict deep signature, plist identity/version and whitespace checks passed. Main remains untouched at a568c6e. Native stage 7 acceptance is pending.

2026-11-20 stage 7 user follow-up: all four native checklist items marked complete. Floating-window hover-text cleanup requested; logged for after migration. Original responses, including feedback about ambiguous test wording, preserved verbatim in migration/STAGE-7-ACCEPTANCE.md. Optional Save was part of a grouped check, so no separate export execution claim is made. No rebuild or version change; stage 8 not started.

## 1.1.8 build 67 — migration stage 8

2026-11-20. LightroomMonitor owns monitoring state, heartbeat/display timers, notification subscriptions and read-only module/foreground/live AX observation. MonitoringCoordinator retains existing eligibility/staleness guards and policy execution in original tick order. No window mutation in the monitor; no additional queued event delivery. Invocation-time view probing, placement, photo requests and calibration timers retain their separate paths.

Mechanical comparison against b9c71cc confirms nine reader/handler bodies and the heartbeat tick body byte-identical. Live AX qualification and completion bodies match exactly around the new optional evidence handoff. The display-change handler retains invalidation, calibration cancellation and the 0.6-second delayed report; only timer ownership changes. OverlayBehaviourPolicy, PresentationCoordinator, placement/photo coordinators, Views and placement algorithms are unchanged.

All eleven migration groups passed. New checks use isolated notification centers and fire actual timer callbacks: 0.2-second heartbeat, synchronous signal order, 0.6-second display debounce, replacement invalidation, no duplicate subscriptions and stop cleanup. The one-shot timer check measures its fire date (its timeInterval does not represent the delay). Existing module freshness/partial-write, stale load/selection/module, cache, placement, presentation, menu and diagnostics tests continue to pass. No live AX/capture calls or GUI app launches were used in these checks. Native ordering, host visibility and responsiveness still require user acceptance; no performance improvement claimed. Six deferred issues remain unfixed. Stage 7 responses remain preserved verbatim; stage 9 not started.

Candidate build/staging completed for 1.1.8 build 67; strict deep signature, version/testing identity and whitespace checks passed. Main remains clean at a568c6e and its staged app was not rebuilt. Native stage 8 acceptance pending.
