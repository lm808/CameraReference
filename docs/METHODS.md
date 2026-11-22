# Current implementation methods

Current candidate implementation: 1.1.10; accepted main remains 1.0.32. This file describes operative methods. [Research findings](AX-ASSISTANCE.md) distinguishes observations from assumptions; [historical notes](HISTORICAL-NOTES.md) preserves superseded implementations and experiments. [Architecture](ARCHITECTURE.md) maps source ownership and update routing.

## Selection, extraction and Fit

The Lua bridge publishes module and opaque session/selection revisions and answers tokenised selected-file requests. Tokens and END markers reject stale/partial responses. Active-photo observation is guarded, with polling; unavailable trustworthy revision evidence prevents image-cache reuse rather than assuming continuity.

ImageSource selects standalone or embedded JPEG with fallback according to preference. CR3 extraction retains its original ExifTool path. ARW tries JpgFromRaw and PreviewImage, selecting the largest valid JPEG by pixel dimensions. Extraction, orientation and decode are cancellable; RAW data is read-only. One RAM slot holds bytes/image and source/preference fingerprints. Selection changes, including away and back, prevent stale reuse. Floating displays independently retain their image.

Fit is calculated from JPEG aspect ratio inside the UI region with fitInsetPoints (default 18). Per-edge ui/photo choices change overlay extent, not photo Fit. Whole-region zoom/pan bounds remain separate from the original photo frame. Export uses a displayed image’s retained embedded snapshot on explicit request, with destination/replacement checks.

## Manual and automatic routing

Manual placement wins. Accepting a selected backdrop stores region/window/display association and turns automatic placement off; cancelling changes nothing. Clearing region preserves auto/manual preference. Option snapping requires existing Screen Recording permission; otherwise calibration stays free-drag. Calibration guidance asks for the desired overlay region and does not derive instructions from a saved view/pane.

Automatic placement chooses AX or Screenshot. AX branches before screenshot cache/capture paths, reads fresh geometry and never falls back to capture. Screenshot uses a single pixel-only detector; AX view inference remains a separate option. See the architecture routing diagram.

## Accessibility geometry and view

Panel/label geometry comes from the AX window map, supplemented by matched public CG window opacity. Hidden panels may retain AX rectangles; unsupported AXVisible is not evidence of visibility. Tall side panels are recognised by attachment to exactly one host side, not the rejected percentage-width restriction that broke minimum-size windows.

Visible label-sized rectangles in the expected central relationship suggest Reference/Active and split orientation. They are geometric candidates, not guaranteed semantic pane containers. A successful read without a clear pair assumes single view; read failure stays unknown. Information-overlay rectangles are not anchors because they disappeared after window recreation/resizing in testing.

Top/bottom strip candidates must align with both horizontal host edges within 4 pt, in addition to the existing width, height and vertical-position checks. This excludes inset info-overlay rectangles that can grow past 90% of host width when both side panels hide. Raw surrounding panel edges define a combined area; hidden sides use configurable base insets. Signed corrections use **right/up positive, left/down negative**. Vertical shifts are subtracted from top-left Y. Bottom correction accumulates filmstrip state, toolbar height when effectively shown, and +25 pt in Library split views only. Defaults and exact keys are in [CONFIGURATION.md](CONFIGURATION.md). Explicit user values are preserved.

After correcting the combined area, split at 50/50, constrained into the nearby label gap. No independent calibrated divider correction is used. Boundary preview computes the same geometry independently of the selected production pane and can draw both panes. Floating initial size fits the photo into half the combined width and full height.

## Toolbar and Grid evidence

No stable toolbar container/boundary was found in the inspected AX relationships, including exhaustive standalone probes. Incidental checkboxes are not production selectors. A bounded read of Lightroom’s View menu uses **Hide Toolbar** to mean shown and **Show Toolbar** to mean hidden. It reads without opening/acting on menus; English titles are currently required. The budget is 0.5 seconds / 250 elements, with bounded depth. Height remains a configurable measured 43 pt, not an AX measurement.

Unknown toolbar status follows toolbarUnknownFallback: shown, hidden or lastKnown. Last-known state is scoped to Lightroom process/module in RAM; absent history defaults to shown. Diagnostics identify assumptions. Incomplete menus after focus changes are a known limitation.

Grid detection is separate: only the first View-menu level is searched, traversing menu wrappers but not command submenus. A unique Grid/Grid View command with a nonempty selection mark is positive evidence. Loupe Overlay → Grid must never match. Missing/ambiguous marks stay unknown; native confirmation of this reader is still outstanding.

## Screenshot detection — independent fallback

Full detection generates candidate UI borders in side/top/bottom search ranges and validates whole rectangles using sustained transitions and consistent inner surround. It does not trace the photograph: all four borders require pixel evidence. Candidate ranking and validation remain unchanged apart from rejecting nonpositive/tiny rectangles before sampling.

sideSearchPercent defaults to 40; explicit user values survive upgrades and define the first search. If no rectangle passes, retry with side ranges reaching the centre (50%), using the same complete validation. Previously this wider result was used only to report a narrow-area failure. Diagnostics now identify when the validated retry supplies placement. Ambiguous or unsupported outer bounds still fail; no AX edges or calibrated offsets participate.

All split choices use exactly the same Full outer detection, then divide its width or height equally. The view/pane comes from manual selection or optional AX view inference, never from divider pixels. No divider scan, seeded pane override or unvalidated midpoint fallback remains. Existing point-space Fit margins apply after pane selection; capture normalisation and cache/background-check policies remain. No AX Library correction is copied into screenshot geometry. Wipe/unequal layouts are unsupported. Native Library extra-bottom-space and Embedded Preview cases remain focused acceptance checks.

AX-assisted placement and its menu/adapter/pixel validator are removed in 1.1.11. Legacy saved assisted placement resolves to Screenshot; an explicit current method choice takes precedence. The obsolete assistance boolean is ignored. AX view-detection preference is preserved independently. AXPanelState retains the prior structural signature solely for existing view/panel-change monitoring, not pixel placement. No screenshot operation reads those signatures for geometry.

## Capture and coordinate safety

AX/CG/ScreenCaptureKit use global top-left points; AppKit uses bottom-left points. Convert once using the primary-display relationship; distinguish points, capture pixels and downsampled analysis pixels. Apply point insets via actual per-axis raster scales. Panel rounding is handled through the actual content view, not a false strict equality with the requested frame.

Wholly on-screen capture uses a display-bound selected-window/children filter with explicit display-local crop. Off-screen/spanning capture uses an independent-window stream without sourceRect. Frame metadata maps the parent into the bitmap before cropping/normalisation; missing, inconsistent, distorted or out-of-buffer geometry is rejected. The stream stops after success/error/cancellation, with a three-second frame timeout.

Intermittent oversized/padded capture surfaces remain unresolved. AX logical bounds cannot prove a bitmap’s scale/origin or repair a distorted capture. Raw capture previews stay available even when placement rejects geometry; previews are not proof of valid placement. All pixels remain in RAM.

## Caches, monitoring and visible-overlay policy

JPEG caching is separate from screenshot PlacementMemory (host, size, epoch, layout, config and surround). Repeated valid screenshot toggles skip capture; movement translates bounds. Resize, changed source/mode/config or context invalidate reuse. AX reads fresh geometry rather than using screenshot placement memory.

Eligible screenshot background checks default to every three seconds in Library/Develop, use a 1280px capture and compare boundaries with 4 pt tolerance. Foreground work cancels them; off-screen/spanning hosts pause them. They invalidate future reuse, not current display geometry. Interval zero disables only this capture loop. Assisted checks retain all scheduled pixels and count AX changes/failures, pixel changes with unchanged AX, validation failures and elapsed cost. Measurements are insufficient to remove them yet.

Pure AX automatic overlays use **Update overlay with LrC view** (default on). View/pane/panel changes recalculate geometry while preserving image/zoom; photo selection reloads into the same panel at Fit with a new export snapshot. Off dismisses on those changes. Failed refresh retains the reference; one attempt per selection epoch avoids retry storms. Grid positive evidence and confirmed module changes dismiss. Nothing opens an off overlay. Screenshot with AX view detection now matches Accessibility with updating off: confirmed photo/view/pane/panel changes dismiss; positive Library Grid dismisses and blocks invocation. Missing evidence retains the overlay. Screenshot with inference off, manual and floating behaviour are unchanged. Screenshot placement is independent of AX geometry; optional view inference does not alter its pixel boundaries. The screenshot AX poll requires current panel/host/backend identity. A fresh invocation seeds raw panel evidence; toolbar read failures do not count as changes. No calibrated geometry is used for this dismissal policy. Background pixel checks still invalidate reuse only.

Live AX polling is approximately two seconds, separate from the 0.2-second bridge/window maintenance timer. Completion guards check relevant request/generation, panel, host, module, epoch, backend and preferences. Missing heartbeat/epoch or failed detection is uncertainty, not a dismissal signal.

## Window ordering and suspension

The overlay is nonactivating. For windowed or unknown full-screen state it floats while Lightroom is active, avoiding click-induced flicker. Confirmed AXFullScreen uses normal-level relative ordering above its host so native system/titlebar controls can remain above it; the last explicit reading is retained through temporary read failures for the same bound host. This full-screen ordering correction is a candidate awaiting native verification. Other app activation lowers the overlay to normal level above its host so other windows can cover it. Overlay/AX-preview front-order requests go below an already visible same-level floating window, without raising that window. Avoid redundant ordering/frame updates. Movement follows known host geometry, including partial off-screen clipping; do not constrain the overlay back onto a display.

Minimise/overview/Space suspension retains content for restoration after settling. Confirmed closure, module change or explicit dismissal releases it; AX update policy additionally handles view/panel/selection changes. Public window-list heuristics and transient flags cannot guarantee perfect overview animation tracking. Brief minimise linger is accepted; native lifecycle tests remain essential.

## Diagnostics, storage and delivery

Diagnostics consolidates host/display maps, opacity, label candidates, toolbar state/provenance, raw/adjusted bounds, errors, cache and timings. Optional saving automatically collects bounded AX evidence after invocation and atomically replaces Diagnostics/latest.txt in the canonical CameraReference support folder. Failure snapshots precede calibration prompts. Deep child/AXSections exploration belongs to AXExplorer, built under build/AXExplorer with explicit reports in ignored investigations/ax-reports.

GUI settings use the shared macOS preference domain; advanced config uses config.conf with metadata caching. Missing defaults are appended, never substituted over explicit values. Old spaced support contents merge only after old writers stop; preserve differing conflicts. Build output stays in build/, changed staged components in release/, explicit requested packages in dist/. No screenshot, personal config or generated binary belongs in Git.
