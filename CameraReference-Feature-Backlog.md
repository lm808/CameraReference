# Camera Reference — feature backlog

Updated: 9 November 2026.
Status: 0.6 has user feedback; 0.7 is built and regression-tested, awaiting live acceptance. Historical sections retain their original status; the latest section supersedes them.

## Baseline and existing roadmap

- Current user-tested baseline: Camera Reference 0.4. Earlier 0.2/0.3 builds are retained.
- All future releases should be named **Camera Reference**. Do not rebuild solely for this note.
- Preserve the working version as a baseline and make incremental changes with user-led Lightroom testing.
- Outstanding Fit issue: overlay image is larger than Lightroom's displayed image, likely because of Lightroom padding. Investigate automatic viewport detection and actual image-size matching in V2; reliability remains unverified.
- Later V3: investigate zoom/pan alignment at invocation, without requiring interactive zoom/pan while visible.
- Background is currently explicitly black; neither its colour nor the viewport is automatically detected.

## FR-001 — Embedded camera JPEG extraction

**Status:** authorised and implemented in 0.3; automated tests pass; real CR3/user integration acceptance remains pending. Incremental source-resolution enhancement, not a rewrite.
**Goal:** support RAW-only shooting while retaining direct use of standalone camera JPEGs.
Initial embedded format scope: Canon CR3, with EOS R5 Mark II evidence below. Preserve existing multi-brand standalone support; do not assume embedded tags are universal.

### Setting and priority

User-facing toggle: **Prefer embedded JPEG from RAW** — On / Off.
Default: **Off**. The toggle controls priority only; fallback is always enabled.

| Setting | First source | Fallback | If neither usable |
|---|---|---|---|
| Off | Matching standalone JPEG using existing matching logic | Embedded JPEG from selected CR3 | Report no camera JPEG reference available |
| On | Embedded JPEG from selected CR3, even if standalone exists | Matching standalone JPEG | Report no camera JPEG reference available |

Use a preferred standalone JPEG directly, with no unnecessary copy or ExifTool invocation.
Missing, invalid or unsupported embedded data must trigger fallback, never a crash or RAW modification.
Retain unambiguous standalone matching; do not silently choose among multiple candidates.

### User-supplied evidence (not independently retested)

On an EOS R5 Mark II CR3, the user reports:

- Track1 `JpgFromRaw`: approximately 4.48 MB, image dimensions 8192 × 5464.
- QuickTime `PreviewImage`: approximately 373 KB.
- Extracted `JpgFromRaw` looked indistinguishable from the standalone camera JPEG in their comparison.
- Successful extraction: `exiftool -b -JpgFromRaw "/path/to/IMG_1234.CR3"`.

Prefer `JpgFromRaw` for the R5 Mark II. Do not silently substitute the smaller PreviewImage as an equivalent reference.
Other CR3s and RAW formats require capability checks; unavailable/unsupported extraction falls back gracefully.

### Privacy and resource requirements

- Capture ExifTool's binary stdout directly into memory; decode with macOS image APIs.
- Never write extracted JPEG bytes to disk: no temporary JPEGs in /tmp, TMPDIR, Library/Caches, Pictures, beside the RAW, or elsewhere.
- No persistent extracted-image cache and no retained cache between overlay sessions.
- Release decoded images and extracted data promptly when dismissed or replaced, including cancelled/failed requests.
- Do not persist photo paths, extracted images or image contents in application logs. Keep process stderr/errors out of logs unless sanitised.
- Standalone JPEGs remain read directly without unnecessary copies.
- Scope clarification for implementation review: version 0.2's bridge response file currently retains an encoded original path (it is IPC, not an application log). Audit and explicitly resolve retention/cleanup or use in-memory IPC when designing the privacy behaviour; do not represent the current bridge as path-free. No existing files are changed by this planning note.
- Memory-only means no application-created image files; do not promise control over operating-system virtual-memory behaviour.

### Performance and safety

- Extract on demand each time an overlay is requested. Dismissal must not start extraction.
- Keep extraction and decoding off the UI thread; support cancellation and discard stale results.
- Capture stdout/stderr safely, handle missing ExifTool, failed exits, malformed JPEGs and hung processes gracefully. Preserve fallback.
- Measure extraction time and total invoke-to-display latency with real files; optimise process startup only if measurements justify it.
- User expects approximately 4.5 MB extraction to be inexpensive because it reads existing JPEG bytes, not RAW development; latency is still to be measured.
- Read-only ExifTool extraction only: no write arguments, metadata edits, rewriting, intentional timestamp changes, Lightroom catalogue or Develop-setting changes.
- Verify repeated extraction leaves original content unchanged, using before/after hashes and relevant metadata checks. Reading must never intentionally modify the source.

### Delivery sequence (authorised; implemented for 0.3 testing)

1. Separate source selection from overlay rendering; define source results and failures. Test the priority/fallback matrix.
2. Establish on-demand ExifTool extraction to memory and decoding, with limits, cancellation and cleanup. Decide installation/discovery of ExifTool before packaging.
3. Connect the resulting in-memory image to the existing overlay display pipeline; retain configured shortcut, opaque temporary display, positioning and any then-available zoom/pan handling.
4. Validate privacy, RAW integrity, resources and measured latency with user-led Lightroom tests.

This work does not require V3 zoom/pan and must not introduce blending or opacity controls. The user prioritised extraction ahead of automatic alignment and zoom/pan. It is included in the next integration-test release (0.3).

### Acceptance checklist

- [ ] Default Off preserves standalone-first priority.
- [ ] On requests embedded JpgFromRaw first even when a standalone JPEG exists.
- [ ] Fallback works in both directions; unavailable sources produce a clear no-reference message.
- [ ] Preferred available standalone is displayed directly without extraction or copies.
- [ ] Valid embedded JpgFromRaw decodes and displays entirely in application memory.
- [ ] No temporary extracted-image files or persistent/inter-session image cache are created.
- [ ] No photo paths or image data persist in application logs.
- [ ] Repeated extraction does not alter original RAW contents or intentionally alter metadata/timestamps.
- [ ] Dismissal/replacement/cancellation releases extracted data and image resources promptly.
- [ ] Missing/invalid embedded data, unsupported format, missing tool and process errors are handled gracefully.
- [ ] Dismissal does not invoke ExifTool; stale asynchronous results cannot reopen a dismissed overlay.
- [ ] Extraction and display latency are recorded without sensitive paths, and repeated use is acceptable for interactive comparison.
- [ ] Existing standalone matching, overlay toggle and positioning behaviour remain intact.

## FR-002 — Subtle indication that the overlay is visible

**Status:** user authorised the small usability improvements. Version 0.3 implements a menu icon state, thin neutral outline outside the viewport, and a margin label only when space permits. Live visual acceptance remains pending.
**Goal:** make it easy to distinguish the camera reference overlay from Lightroom's RAW view without distracting from the photograph.

Options to discuss (none selected yet):

| Option | Proposed appearance | Tradeoff |
|---|---|---|
| Menu-bar icon state | Outline camera/reference symbol when hidden, filled symbol or small dot when visible | Leaves image comparison untouched; less noticeable and unavailable when the menu bar is hidden |
| Overlay frame | Very thin neutral outline outside the photograph, within the surrounding margin | Visible near the image; may influence the comparison or be lost against some backgrounds |
| Small margin label | Discreet “Camera reference” label in a corner of the surrounding margin | Explicit meaning; adds visible text and requires enough margin |

Chosen initial implementation: outline/filled camera icon plus a one-point neutral external outline. A discreet label is drawn only in empty upper margin. The full-screen indicator therefore does not depend on the menu bar. User can refine the appearance after testing.

Design constraints / future acceptance checks:

- Show the active indication only once the overlay is actually displayed, not merely requested or loading.
- Reset it on all dismissal paths, application switching, display changes and failures; cancellation must not leave a false active state.
- Avoid flashing, pulsing or bright colour near the image. Do not rely on colour alone to distinguish states.
- Any border/label must not obscure image pixels, shrink the photograph or disrupt alignment.
- Consider light/dark menu bars and hidden-menu-bar/full-screen use.
- Preserve existing shortcut and overlay behaviour. Review the visual choice with the user during testing.


## FR-003 — Independent floating reference window

**Status:** explicitly authorised and implemented in 0.3; live testing pending.

- Open through a menu-bar action, independently of the temporary overlay.
- Initially load the current selected RAW's camera JPEG using FR-001 source preference/fallback.
- Keep that photograph fixed when Lightroom's selection changes. Refresh **only on double-click inside
  the existing window**. Re-invoking the menu action only brings an already open window forward.
- Resizable, above normal windows, preserving image aspect ratio. No zoom or pan controls and no following
  Lightroom's zoom/pan. No extra keyboard shortcut requested in the final scope.
- Initially fit within half the detected viewing area's width and height. Use calibrated bounds if detection
  is unavailable, or half the usable screen as a last resort. This interprets “half size” as half each linear dimension.
- On refresh preserve position and approximate area, adapting aspect ratio for a different orientation.
- Failed refresh retains the previous image and clearly identifies that it is unchanged.
- Closing releases this view's image. Dismissing the overlay must not close the floating window.
- Works with the active RAW in Develop and Library/Grid; multiple selection means the active/most-selected image.
- Full-screen/Spaces behaviour and visual resizing require user testing.

## FR-004 — Module behaviour and automatic-size investigation

**Status:** authorised. Module dismissal implemented; automatic sizing is experimental in 0.3.

- Overlay remains Develop-only. Dismiss on leaving Develop, app switch, or stale/missing bridge status.
- Floating window remains independent and can fetch the selected RAW from Library/Grid.
- Read-only Accessibility probe accepts only one sufficiently large central AXImage with matching image aspect
  ratio after a complete bounded scan. It does not inspect photo names, window titles, field values or screenshots.
- Opt-in Accessibility permission; experimental detection defaults Off. Retain manual calibration fallback.
- User-triggered diagnostics report role/candidate counts. This enables investigation without controlling the
  user's Lightroom session. No actual accessibility tree has been inspected during development.
- No claim that Lightroom exposes exact photo bounds: AXImage may represent a viewport. Real alignment testing
  is required. Automatic background colour, Reference View pane replacement, zoom and pan remain deferred.

## 0.3 implementation and validation notes

- ExifTool found locally (13.55). Binary JPEG stdout stays in memory. Default user ExifTool config is disabled.
- If JPEG EXIF orientation is absent, a second read-only query retrieves numeric RAW orientation. Invalid or
  absent orientation falls back safely. Do not assume all extracted JPEGs contain their own orientation.
- Diagnostic timings show total time to image-ready and ExifTool execution time; actual RAW latency needs user measurement.
- No extracted-image files or cache. Visible floating-window content remains in memory until refreshed/closed;
  it is intentionally independent of the overlay's lifetime.
- Photo paths are not put in application logs. Existing path IPC is consumed/removed, with abandoned replies
  removed after about 10 seconds while the plugin runs or at its next startup. A crash can leave IPC until restart.
- Automated tests use synthetic fixtures/process stand-ins; actual ExifTool is tested only on an invalid synthetic
  CR3. Real-file hashes, visual colour/orientation, latency, full-screen UI and accessibility remain acceptance tests.
- Existing checklist boxes above are deliberately not marked as fully accepted until the relevant live tests pass.

## FR-005 — Explicitly save the displayed extracted JPEG

**Status:** saving user-tested in 0.4; moved to each picture's context menu in 0.5, awaiting live acceptance.

- Right-click the overlay OR floating picture → Save extracted JPEG. Removed from the menu bar.
- Enabled only for the embedded source actually displayed in that view; standalone source disables it.
- Each visible view holds its own bytes, RAW path and orientation. Changing Lightroom selection or the other
  reference view must not change the export source. No second extraction is performed.
- Save beside that RAW as `<RAW stem>_JpgFromRaw.jpg`; explicit action authorises only this export.
- Confirm existing export replacement; Cancel changes nothing. Reject symbolic/hard links and changed destinations.
- Preserve compressed JPEG bytes; add missing EXIF orientation without recompression. File metadata may differ.
- No automatic image writes, temporary JPEGs or cache. Explicit saves are the exception to FR-001 memory-only policy.
- Release each view's bytes on refresh/close, and release captured save-operation bytes on completion/cancellation.
- Write directly: disk failures may leave an incomplete export. No RAW, standalone JPEG, catalogue or edits are modified.
- Automated tests cover source snapshot independence, menu eligibility, release, metadata and protected write paths.
  User need not construct corrupt photos or unusual disk failures to test these.

## FR-006 — Organise the menu into distinct sections

**Status:** authorised on resume; implemented in 0.4, awaiting user testing.

Separate everyday commands from development testing and developer inspection tools. Keep **Development
testing** and **Developer tools** as distinct sections (or submenus), rather than one combined debug group.

Proposed grouping for review:

| Section | Items |
|---|---|
| Reference | Open floating reference window; Save extracted JPEG…; hide overlay |
| Settings | Source-priority toggle; keyboard shortcut; manual image-region setup; ExifTool location |
| Development testing | Check selected photo; Show last result/timing; experimental automatic image-bounds toggle |
| Developer tools | Inspect Lightroom layout; Bridge diagnostics |
| App | Quit Camera Reference |

- Use clear separators/labels or submenus to reduce visual clutter. Final presentation can be refined later.
- Preserve dynamic command availability, especially FR-005's greyed-out states.
- Separate “cancel region setup” from ordinary overlay dismissal where it makes the menu clearer.
- Keep experimental controls clearly identified until they are validated; move them to ordinary settings
  only when they become supported everyday features.


## 0.4 update — supersedes earlier floating-window sizing/control proposals

- User accepted 0.3 extraction, fallback, cancellation, independent window and restart behaviour.
  The border is sufficient; a missing margin label is acceptable. Real-file hashes and precise latency
  were not supplied, so those checks are not claimed complete.
- Initial size now derives from the aspect-fitted photo: portrait full photo height, landscape half photo
  width. Screen limits apply. Detected bounds are preferred, calibration then screen are fallbacks;
  padding can still affect estimates until exact bounds are available.
- Floating window uses dark appearance. Command-scroll zooms around the pointer; unmodified and inertial
  scrolling are ignored. Drag pans; right-click offers Fit/100% (one photo pixel per display pixel).
  Double-click still refreshes only on demand and resets to Fit. No Lightroom zoom/pan synchronisation.
- FR-005 and FR-006 implemented. Save captures the displayed overlay's bytes/path, writes beside its RAW,
  confirms replacement, rejects links, and adds missing orientation metadata without recompressing JPEG
  scan data. Normal extraction remains memory-only. Explicit exports use no temporary image file;
  write failures can leave an incomplete export. A complete export may differ in EXIF metadata.
- New diagnostic lists main-window bounds, whether focused/main windows match, every AXImage geometry
  (up to 20), and rejection reasons. The conservative acceptance filters remain unchanged. Nine elements
  and one rejected AXImage are insufficient evidence that automatic detection cannot work.
- 0.4 app compiled and automated regression/export tests passed; native UI and real-photo acceptance
  await the user's convenient testing. 0.3 is retained as the working baseline.

## FR-007 — Persistent calibration and full-screen crosshair selection (0.5)

**Status:** implemented; compile/geometry tests pass; native mouse/sleep tests pending.

- Confirmed 0.4 bug: the screen-parameters notification erased calibration after sleep/wake.
- Retain region and display identity/position/dimensions/scale. Suspend use while geometry differs; recover when
  the original display returns. Do not erase stored coordinates on sleep/wake or transient empty display lists.
- Upgrade retains any still-saved rectangle; already erased coordinates require one fresh calibration.
- Temporary transparent, mouse-capturing panels cover displays. Crosshair lines span full screen width/height
  and track the pointer, with a rectangle preview during drag. Lightroom does not receive calibration clicks.
- Drag and release saves a valid region on one display; Escape/right-click cancels and preserves the old region.
  Small/cross-display selections remain in calibration for retry. Input capture exists only during calibration.

## FR-008 — macOS-style shortcut recorder and overlay command (0.5)

**Status:** implemented; native recording/conflict tests pending.

- Click a shortcut field displaying modifier symbols; record a new combination; Save/Cancel and Use Default.
- Temporarily suspend the app's global hotkey while recording, so the recorder can receive that combination.
- Menu switches Show overlay / Hide overlay and displays the configured shortcut; loading can be cancelled via Hide.

## FR-009 — Shared image gestures and refresh (0.5)

**Status:** implemented in one ReferenceView shared by both window forms; maths/routing tests pass.

- Pinch zoom around pointer; Command + precise/two-finger scrolling pans; Command + coarse mouse wheel zooms.
  Plain scrolling and momentum are ignored. Some precise mice take the pan route; detection is delta-based,
  not a claim to identify hardware type. Click-drag also pans.
- Context menu Fit/100% and Reload. Double-click either image reloads current Lightroom selection and resets Fit.
- Independent of Lightroom zoom/pan. Overlay re-invocation starts Fit. Floating view does not follow selection.
- Save available in both context menus; each visible embedded reference now retains its own original bytes.
- User confirmed existing 0.4 sizing, floating controls, export and menu generally OK; new gestures require tests.

## FR-010 — Screen-based UI detection and permission flow (0.5 experiment)

**Status:** one-shot diagnostic/proposal implemented; real recognition and alignment unverified.

- User's AX report exposes correct main window (2560 × 1349 pt) but only an 18 × 18 AXImage icon at x81/y36.
- Investigate stable Lightroom UI anchors rather than distinguish black photo content from black background.
- macOS 14+ ScreenCaptureKit single Lightroom-window capture, local Vision OCR, whitelisted UI labels and
  conservative long neutral separator checks. Initially English Navigator/Histogram and visible side panels.
- Developer tools → Inspect screen layout; permission requested on explicit use. If unavailable/previously
  requested, explain and offer System Settings. Manual calibration remains usable without permissions.
- Same feature-triggered approach for Accessibility inspection; no startup permission-prompt loop.
- Capture stays in memory; no screenshot files, arbitrary OCR text or photo paths in reports/logs. No audio.
- Candidate is a viewing-area proposal, NOT exact photo bounds. Preview in calibration layer, Return to accept,
  drag to adjust, Escape to cancel. Never silently replace calibration or apply on each overlay invocation.
- Lightroom's own Fit means whole RAW visible; distinct from our reference view's Fit. Crop, hidden panels,
  other languages, padding and differing layouts still require investigation.
- Synthetic raster tests cover candidate finding and rejection of missing anchors/uniform/ambiguous layouts.
  No user screenshot was captured and no Lightroom control was exercised during development.

## 0.5 delivery status

App compiled and regression/interaction/export tests passed; no app launched or installed. Unchanged 0.4
Lua bridge included for fresh installs only. Existing 0.3/0.4 bridge works: no Lightroom plugin reinstall.
See bundled TESTING.md for user-led native interaction and screen-experiment checks.

## 0.5.1 feedback and patch

- User accepted drag calibration, Apple-menu Sleep/wake retention and shortcut interface in 0.5.
- Add translucent blue fill to the selected calibration rectangle; retain the full-screen crosshairs and input capture.
- Restore Command-scroll zoom for all devices. Latest user steering: pinch zoom and ordinary two-finger pan on
  trackpad, without a modifier for panning. No Command–Shift mapping. Precise unmodified scroll pans; coarse
  unmodified wheel and momentum remain ignored. Some touch mice also emit precise scrolling events.
- Floating title shows the actual JPEG filename for standalone references, or the RAW filename for embedded
  references. Keep the displayed filename while refreshing or on failure; do not persist it in preferences/logs.
- Successful explicit saves display a dark confirmation badge for three seconds. Floating badge stays inside
  its window; overlay badge uses its view or former position if dismissed during save while Lightroom remains
  frontmost. Cancelled or failed saves never display success. Filename is shown in the transient confirmation.
- Rename preference exactly to **Prefer RAW-embedded JPEG**; existing stored value and fallback rules unchanged.
- User's screen report: 2560 × 1349 pt, no UI anchors. Exact cause unconfirmed. Previous parser rejected grouped
  OCR lines; now matches whitelisted whole words with word bounds, explicitly preserves small text, retains
  display-pixel capture resolution within a cap, and reports capture pixels plus OCR text-region count.
- Deterministic source, export, interaction, shared-view and Lua tests pass. Added filename, grouped-label and
  message expiry/reset coverage. Native visual behaviour remains user-tested only after release.
- Optional synthetic OCR runtime test failed locally with Foundation._GenericObjCError.nilError, including a
  CPU retry; no OCR accuracy success is claimed. CPU retry was not retained. Separate test-ocr.sh reports an
  unavailable runtime with exit 2; no screenshot or user photo is involved. Real screen detection remains experimental.
- No Lightroom plugin change/reinstall. Previous versions remain intact.

## 0.6 — Image-first photo-region detection

**Status:** implemented at user request; synthetic/regression tests pass; real Lightroom test pending.

- Replaces OCR/label gating with direct CPU pixel analysis. No Vision service or UI language dependency.
- Developer tools → Find photo region (experimental) reads the CURRENT selected RAW via the existing bridge,
  loads the reference for its oriented aspect ratio, and captures one Lightroom window in memory.
- Detect sustained candidate boundaries, form large central rectangles, validate exterior uniformity/interior
  variation, require at least three supported edges and agreement with the reference aspect ratio. Infer one
  blended edge from the ratio. Reject similarly plausible competing rectangles.
- Found bounds target the photograph, not the entire viewport. Preview in the crosshair selector; Return accepts,
  drag adjusts, Escape cancels. No background change to saved calibration and no per-shortcut auto-apply yet.
- Tests find synthetic landscape/portrait photos against black/grey/white, with hidden panels and one blended edge,
  within four raster pixels. UI-only/flat/mismatched-ratio/two-photo scenes rejected. CGImage coordinate conversion tested.
- Detector-only positive fixture timing approximately 11–19 ms in optimised build; excludes screenshot/bridge/decode.
- Real photographs, crops, unusual layouts and exact alignment remain unverified. Aspect-based inference may mistake
  empty background for part of a cropped image; use uncropped RAW at Lightroom Fit and inspect the preview.
- Screenshots and image analysis remain memory-only. No native apps controlled/launched during development.
- 0.5.1 retained; unchanged Lightroom plugin remains compatible. No plugin reinstall required.

## 0.7 — UI-boundary detection, reuse and manual fallback

**Status:** app built/ad-hoc signed; automated regression and screenshot-fixture checks pass. No live app installation or control during development. User testing remains required.

- User priority: automatic viewing-area detection and predictable manual fallback. Lightroom zoom/pan matching is deferred.
- Replace photo-edge dependence with long UI-border detection. Sample uniform surround colour rather than assume black; Fit landscape/portrait JPEGs into the same detected pane.
- Supplied screenshot recognised at x244–1794, y95–957 of 2048×1102. Fixed early rejection of the right UI border caused by minor colour variations. This is fixture evidence, not proof of all layouts or pixel-perfect Fit alignment.
- Initial 16 pt Fit inset remains an assumption to test. No arbitrary offset correction is applied to photo edges.
- Cached outer bounds are reused after checking border samples; changes to window geometry, panels/background trigger a new search. Internal divider checks still run. Capture occurs on invocation only; no continuous screenshots and no image files/caches.
- Split detection targets the actual left/upper pane; asks once per detected split layout/session whether it is Reference view, because Before/After can look similar. No view switching. Current selected RAW supplies the JPEG, regardless of Lightroom's pinned reference image.
- Current plugin reports module only. No supported main-view getter was established; do not claim a documented Reference-view query. Plugin unchanged and compatible with existing installs.
- Find viewing area now runs without requesting/extracting a JPEG. Added a 12-second capture watchdog, cancellation status and stale-result rejection. Removed cancellation solely due to transient foreground-app changes. Real first-run stall cause remains unconfirmed; user retest required.
- Automatic overlay detection stays explicitly enabled through Development testing. No dependable region: offer Calibrate / Cancel. Choosing calibration switches to manual mode to prevent repeated prompts. Re-enable automatic detection to retry. Preview corrections can override the same detected layout in automatic mode.
- Manual calibration now records window geometry, follows window movement and suspends on resize without erasing saved coordinates. Sleep/wake retention preserved. Older records need a fresh calibration to acquire window metadata. Explicit manual mode cannot notice panel/single/split changes without recalibration.
- Floating title shows live physical-pixel zoom percentage alongside source filename. 100% remains one image pixel per display pixel; gestures and resize update the value.
- Existing extraction, exports, shared gestures, menu and shortcut behaviour retained. Tests include source/process/export/ownership/Lua, new UI raster cases, reuse/invalidation and window-relative calibration.

### Remaining after 0.7

- User acceptance of actual capture timeout/recovery, automatic placement, hidden panels/full-screen, Reference pane selection and exact Fit margins.
- Make mode detection and manual-fallback recovery more automatic if reliable UI/SDK signals become available; avoid repeated questions.
- Floating zoom title and native pinch/pan acceptance; multi-display behaviour.
- Real-file extraction latency and RAW-integrity checks not yet supplied; synthetic checks do not replace these.
- Later: Lightroom zoom/pan matching and format-specific embedded JPEG support beyond CR3. Standalone pairing already supports other cameras.

## 0.7.1 — Resampled UI-border regression and clearer failure reports

- User's live 0.7 capture at 2560×1349 reported missing top/bottom boundaries. The old message incorrectly said a viewport was detected and displayed an unused Fit inset.
- Reproduced a separate but potentially related defect by cropping/resampling the supplied screenshot to those capture dimensions: a faint photo-edge fringe was accepted at x2057 instead of the right UI boundary at x2242.
- Tightened vertical border contrast to reject that fringe. Added several window-crop/resampling fixture variants with exact expected horizontal bounds. This does not establish the cause of the unseen failing live frame.
- Failure reports list accepted left/right and top/bottom candidates; distinguish a search from successful detection; omit the Fit inset when no area is accepted.
- Focused user retest: same failing layout, Find viewing area, preview without adjustment. If it still fails, obtain the full report and screenshot of that same layout.
- No plugin changes, no native Lightroom control and no installation. Existing 0.7 remains available.

## 0.7.2 — Option-held snapping and clear-region command

**Status:** app builds and full regression suite passes; native interaction acceptance pending. No app installed/launched.

- Free calibration by default; hold Option to snap horizontal/vertical coordinates independently to nearby sustained edges within 8 screen points. Highlight selected edges cyan. Release Option for free movement; fixed first corner remains fixed. Top hint includes Option and Esc; proposal hint also includes Return.
- Prepare local edge segments from one in-memory Lightroom-window capture before showing calibration. macOS 14+/Screen Recording permission required for snapping, but free selection remains usable if unavailable or preparation exceeds 3 seconds. No screenshot files/cache. Local edge assistance is independent of whole-viewport recognition and may include photo boundaries.
- Remove Cancel region setup menu item. Esc remains the normal cancellation method.
- Add Settings → Clear all region data: dismiss overlay; cancel pending load, detection and calibration; clear manual geometry/display/window keys, overrides, last automatic proposal, boundary samples and split confirmations. Preserve shortcut/source/ExifTool settings and automatic toggle; floating image remains open.
- Cache generation tickets reject pre-reset capture results. New captures start from empty geometry; clearing needs no Terminal command or restart.
- New tests cover modifier gating, axis/radius/segment behaviour, screen coordinate conversion, clearing only region preferences and stale-capture rejection. Existing extraction/export/gesture/Lua/geometry tests pass.
- User requested lower usage: short updates, one issue per iteration, reuse screenshot fixtures and focus tests while developing, full regressions before release.

### Next priority: automatic detection only

- Confirmed live 0.7.1 failure: accepted x16/x2544 outer rails with visible side panels, top candidate32 and no bottom candidates; user confirms layout matches their screenshot without the overlay.
- Do not call this fixed by 0.7.2. Investigate complete rectangles jointly, validating side candidates against top/bottom and uniform surround rather than choosing side borders first.
- Use both existing screenshots; do not request the same screenshot again. The latest screenshot includes the narrow overlay, so avoid treating that overlay's boundaries as Lightroom UI.

## 0.8 — Complete UI rectangles and broader manual snapping

**Status:** built and regression-tested; both supplied screenshot fixtures pass. Live outer-rail failure requires user retest.

- User accepted 0.7.2 snapping/reset. Requested panel-edge snapping for selecting photo top/bottom with panel-to-panel lateral bounds, and a Camera reference label in horizontal empty margins too.
- Manual edge extraction now accepts lower contrast (4 channel levels) and shorter sustained segments (24 pt). Option-only activation and 8 pt attraction radius unchanged; additional photo details may also qualify.
- Label placement checks empty top/bottom and left/right margins and never draws over image pixels. It is omitted when no margin fits the horizontal text.
- Automatic detection evaluates complete rectangles from multiple candidate lines. Requires distributed edge evidence on all four sides and a consistent inner surround; no side pair is accepted before top/bottom validation.
- Handles nested header rails within the same surround colour; distinguishes a flat dark photograph interior with a different colour from the larger UI surround. Refines selected strokes to the background boundary. Rejects competing non-nested rectangles.
- Original screenshot and scaled 2560×1349 crop variants pass. Latest screenshot with narrow overlay passes at x242–1801, y45–912 in its 2048×1055 grid; detector-only analysis about55 ms locally. This is not an untouched live failing capture, so do not claim native acceptance yet.
- Synthetic weak-inner-border/strong-outer-rail test passes, alongside dark/coloured/hidden/split/cache tests. Added short low-contrast panel snapping and margin-label placement tests. Full previous source/export/interaction/reset/Lua suite passes.
- Prior clear command, stale-generation rejection and calibration retention are preserved. No plugin changes or app installation/control. The provisional16 pt Fit inset and unsynchronised zoom/pan remain.
- User retest: clear all region data, enable automatic detection, run Find viewing area in the same failed layout and inspect before manual correction. Then test landscape/portrait overlay and panel snapping. Keep next iterations focused on auto detection.

## 0.8.1 — Full-crosshair snapping and capture diagnosis

**Status:** built/ad-hoc signed; regression and screenshot tests pass. Live capture acceptance pending.

- Option snapping now projects detected horizontal/vertical segments across the current display. The segments need not intersect or lie beside the pointer along their length. Free movement remains the default; the calibration hint explains Option alignment.
- The supplied cropped pane screenshot already exposes the left panel border and thin upper line to the 0.8 edge extractor. Added that fixture check and disconnected-segment snapping tests; no further threshold adjustment is justified by this image.
- Capture explicitly includes child windows on macOS 14.2+. This may explain the difference between supplied screenshots and native results, but remains an unconfirmed hypothesis.
- Developer tools → Preview captured Lightroom window… displays the exact in-memory capture, before detection/resampling, with zoom/pan and no save or reference-reload actions. Closing releases the image. Clear all region data also closes it; diagnostic state does not retain its pixels.
- Automatic detector thresholds/rectangle selection unchanged. The first focused user test is whether the preview contains the pane and thin upper line. Then retry Option calibration and Find viewing area in that same layout.
- Source/export/interaction/Lua/detection/reset regressions pass, including preview action/release tests and all three supplied screenshot fixtures. No app installed/launched, no Lightroom interaction, and no plugin reinstall required.

## 0.9 — Single-photo UI bounds and reloadable detection configuration

**Status:** implemented; build and regression checks passed, live acceptance pending. User confirmed 0.8.1 capture matches Lightroom and pane snapping works, but short edges make snapping too busy. Live automatic failure was ambiguous internal dividers.

- Scope narrowed to single-picture Develop at Fit. Production detector accepts the validated outer UI rectangle without searching for internal dividers. Reference/BeforeAfter support deferred; module status is available but no supported main-view getter established. No plugin changes or automatic Lightroom view switching.
- Each side independently chooses ui or photo. Defaults left/right ui, top/bottom photo. Photo rectangle calculated by fitting current oriented JPEG into UI bounds minus minimum inset. Its position/scale remains fixed across asymmetric side choices; no contrast-based photo-edge tracing. Cropped RAW/JPEG aspect differences remain a limitation.
- fitInsetPoints default18: screenshot viewport y95–957, photo y109–944 gives about13–14 screenshot pixels. Assuming2048px screenshot represents2560pt width yields roughly16–18pt. Scale assumption remains unverified; no Adobe-defined inset found. Value is configurable.
- Settings → Open detection configuration opens commented plain-text detection.conf under ~/Library/Application Support/Camera Reference. Reload on each detection/calibration, no restart; invalid settings give an alert and preserve last valid configuration in the current process (defaults after restart). Unknown/duplicate keys and out-of-range values rejected. Clear region data preserves config.
- Exposed left/right/top/bottom, fitInsetPoints, vertical/horizontalSnapFraction (default0.25 of window), snapDistancePoints8, snapGapPoints4 and snapContrast4. Option-only full-crosshair alignment retained. Long segments replace the short24pt criterion.
- Find viewing area loads the current selected JPEG for correct aspect ratio; may perform read-only in-memory extraction. Does not use a stale previous-photo aspect ratio. Capture and image bytes remain memory-only except explicit existing JPEG export.
- Tests pass for all16 side combinations in both orientations, single-photo clutter/divider bypass, live config reload/invalid retention, proportional snapping, and previous source/export/gesture/Lua/reset/preview behaviour. Supplied screenshots are local fixtures only. No installation, native app launch or Lightroom control performed.
- Focused user test: single photo at Fit, clear region data, enable auto, Find viewing area; then compare landscape/portrait alignment, side options and stricter/looser snapping. No need to repeat unrelated features. Automatic detection and inset accuracy still require live acceptance.
