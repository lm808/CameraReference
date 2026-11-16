# Current implementation methods

Current implementation: 1.0.32. This file describes operative methods. [Research findings](AX-ASSISTANCE.md) distinguishes observations from assumptions; [historical notes](HISTORICAL-NOTES.md) preserves superseded implementations and experiments. [Architecture](ARCHITECTURE.md) maps source ownership and update routing.

## Selection, extraction and Fit

The Lua bridge publishes module and opaque session/selection revisions and answers tokenised selected-file requests. Tokens and END markers reject stale/partial responses. Active-photo observation is guarded, with polling; unavailable trustworthy revision evidence prevents image-cache reuse rather than assuming continuity.

ImageSource selects standalone or embedded JPEG with fallback according to preference. CR3 extraction retains its original ExifTool path. ARW tries JpgFromRaw and PreviewImage, selecting the largest valid JPEG by pixel dimensions. Extraction, orientation and decode are cancellable; RAW data is read-only. One RAM slot holds bytes/image and source/preference fingerprints. Selection changes, including away and back, prevent stale reuse. Floating displays independently retain their image.

Fit is calculated from JPEG aspect ratio inside the UI region with fitInsetPoints (default 18). Per-edge ui/photo choices change overlay extent, not photo Fit. Whole-region zoom/pan bounds remain separate from the original photo frame. Export uses a displayed image’s retained embedded snapshot on explicit request, with destination/replacement checks.

## Manual and automatic routing

Manual placement wins. Accepting a selected backdrop stores region/window/display association and turns automatic placement off; cancelling changes nothing. Clearing region preserves auto/manual preference. Option snapping requires existing Screen Recording permission; otherwise calibration stays free-drag.

Automatic placement chooses AX or Screenshot. AX branches before screenshot cache/capture paths, reads fresh geometry and never falls back to capture. Screenshot independently chooses original or assisted search; AX view inference is a separate option. See the architecture routing diagram.

## Accessibility geometry and view

Panel/label geometry comes from the AX window map, supplemented by matched public CG window opacity. Hidden panels may retain AX rectangles; unsupported AXVisible is not evidence of visibility. Tall side panels are recognised by attachment to exactly one host side, not the rejected percentage-width restriction that broke minimum-size windows.

Visible label-sized rectangles in the expected central relationship suggest Reference/Active and split orientation. They are geometric candidates, not guaranteed semantic pane containers. A successful read without a clear pair assumes single view; read failure stays unknown. Information-overlay rectangles are not anchors because they disappeared after window recreation/resizing in testing.

Raw surrounding panel edges define a combined area; hidden sides use configurable base insets. Signed corrections use **right/up positive, left/down negative**. Vertical shifts are subtracted from top-left Y. Bottom correction accumulates filmstrip state, toolbar height when effectively shown, and +25 pt in Library split views only. Defaults and exact keys are in [CONFIGURATION.md](CONFIGURATION.md). Explicit user values are preserved.

After correcting the combined area, split at 50/50, constrained into the nearby label gap. No independent calibrated divider correction is used. Boundary preview computes the same geometry independently of the selected production pane and can draw both panes. Floating initial size fits the photo into half the combined width and full height.

## Toolbar and Grid evidence

No stable toolbar container/boundary was found in the inspected AX relationships, including exhaustive standalone probes. Incidental checkboxes are not production selectors. A bounded read of Lightroom’s View menu uses **Hide Toolbar** to mean shown and **Show Toolbar** to mean hidden. It reads without opening/acting on menus; English titles are currently required. The budget is 0.5 seconds / 250 elements, with bounded depth. Height remains a configurable measured 43 pt, not an AX measurement.

Unknown toolbar status follows toolbarUnknownFallback: shown, hidden or lastKnown. Last-known state is scoped to Lightroom process/module in RAM; absent history defaults to shown. Diagnostics identify assumptions. Incomplete menus after focus changes are a known limitation.

Grid detection is separate: only the first View-menu level is searched, traversing menu wrappers but not command submenus. A unique Grid/Grid View command with a nonempty selection mark is positive evidence. Loupe Overlay → Grid must never match. Missing/ambiguous marks stay unknown; native confirmation of this reader is still outstanding.

## Original screenshot detection — protected baseline

Full detection generates candidate UI borders in side/top/bottom search ranges and validates whole rectangles using sustained transitions and consistent inner surround. It does not trace the photograph: a candidate must have supporting evidence on all four sides. This can still confuse photo/status-text structure with UI; known Library status-label failures remain unresolved.

sideSearchPercent defaults to 40; explicit user values survive upgrades. No universal adaptive range is claimed. Full UI bounds determine photo Fit. Do not add separate split outer-bound ranking: earlier attempts selected gaps or covered UI.

Splits first use the same Full outer bounds. Side-by-side scans horizontal traces in the **bottom inset margin** for a vertical divider; stacked views scan the **left margin** for a horizontal divider. Multiple traces at 20–80% of the inset tolerate a divider ending short of the edge. Search is central 20–80% of the viewport; thin contrast, matching surround and support on at least half the traces are required. Missing/ambiguous divider evidence offers manual calibration in the original path. Wipe views are unsupported.

## AX-assisted screenshot search — separate experiment

AXAssisted.swift uses raw visible-panel hints to narrow pixel search ranges (±64 pt horizontally, ±128 pt vertically, clipped to the raster). These are uncertainty bands, not calibrated AX edge corrections. ScreenProbe accepts hints only for matching captured host geometry; nil/stale hints preserve original routing. Pixel evidence determines all four final edges.

Inconclusive guidance falls back to the original outer search, with an assisted-only raw side-panel header check rejecting bounds above the structural top (4 pt sampling tolerance). Its separate validator tolerates at most two compact bottom-surround interruptions, each at most six of forty samples, with at least 75% bottom support. Left/right/top require 90%; distributed transitions are still required. This models Library status labels, but native validation remains pending.

Only after outer-area validation does the existing divider scan run. Assisted mode alone may use a 50/50 fallback when it cannot find a divider. Failed outer validation never permits this fallback. ViewportDetector and the original split scanner remain unchanged. Guided results do not populate the original detector’s internal cache.

## Capture and coordinate safety

AX/CG/ScreenCaptureKit use global top-left points; AppKit uses bottom-left points. Convert once using the primary-display relationship; distinguish points, capture pixels and downsampled analysis pixels. Apply point insets via actual per-axis raster scales. Panel rounding is handled through the actual content view, not a false strict equality with the requested frame.

Wholly on-screen capture uses a display-bound selected-window/children filter with explicit display-local crop. Off-screen/spanning capture uses an independent-window stream without sourceRect. Frame metadata maps the parent into the bitmap before cropping/normalisation; missing, inconsistent, distorted or out-of-buffer geometry is rejected. The stream stops after success/error/cancellation, with a three-second frame timeout.

Intermittent oversized/padded capture surfaces remain unresolved. AX logical bounds cannot prove a bitmap’s scale/origin or repair a distorted capture. Raw capture previews stay available even when placement rejects geometry; previews are not proof of valid placement. All pixels remain in RAM.

## Caches, monitoring and visible-overlay policy

JPEG caching is separate from screenshot PlacementMemory (host, size, epoch, layout, config and surround). Repeated valid screenshot toggles skip capture; movement translates bounds. Resize, changed source/mode/config or context invalidate reuse. AX reads fresh geometry rather than using screenshot placement memory.

Eligible screenshot background checks default to every three seconds in Library/Develop, use a 1280px capture and compare boundaries with 4 pt tolerance. Foreground work cancels them; off-screen/spanning hosts pause them. They invalidate future reuse, not current display geometry. Interval zero disables only this capture loop. Assisted checks retain all scheduled pixels and count AX changes/failures, pixel changes with unchanged AX, validation failures and elapsed cost. Measurements are insufficient to remove them yet.

Pure AX automatic overlays use **Update overlay with LrC view** (default on). View/pane/panel changes recalculate geometry while preserving image/zoom; photo selection reloads into the same panel at Fit with a new export snapshot. Off dismisses on those changes. Failed refresh retains the reference; one attempt per selection epoch avoids retry storms. Grid positive evidence and confirmed module changes dismiss. Nothing opens an off overlay. Screenshot modes retain menu inference/cache invalidation only; explicit menu view/pane changes dismiss. Manual/floating selection behaviour is unchanged.

Live AX polling is approximately two seconds, separate from the 0.2-second bridge/window maintenance timer. Completion guards check relevant request/generation, panel, host, module, epoch, backend and preferences. Missing heartbeat/epoch or failed detection is uncertainty, not a dismissal signal.

## Window ordering and suspension

The overlay is nonactivating and floating only while Lightroom is active, avoiding click-induced flicker. Other app activation lowers it to normal level above its host so other windows can cover it. Avoid redundant ordering/frame updates. Movement follows known host geometry, including partial off-screen clipping; do not constrain the overlay back onto a display.

Minimise/overview/Space suspension retains content for restoration after settling. Confirmed closure, module change or explicit dismissal releases it; AX update policy additionally handles view/panel/selection changes. Public window-list heuristics and transient flags cannot guarantee perfect overview animation tracking. Brief minimise linger is accepted; native lifecycle tests remain essential.

## Diagnostics, storage and delivery

Diagnostics consolidates host/display maps, opacity, label candidates, toolbar state/provenance, raw/adjusted bounds, errors, cache and timings. Optional saving automatically collects bounded AX evidence after invocation and atomically replaces Diagnostics/latest.txt in the canonical CameraReference support folder. Failure snapshots precede calibration prompts. Deep child/AXSections exploration belongs to AXExplorer, built under build/AXExplorer with explicit reports in ignored investigations/ax-reports.

GUI settings use the shared macOS preference domain; advanced config uses config.conf with metadata caching. Missing defaults are appended, never substituted over explicit values. Old spaced support contents merge only after old writers stop; preserve differing conflicts. Build output stays in build/, changed staged components in release/, explicit requested packages in dist/. No screenshot, personal config or generated binary belongs in Git.
