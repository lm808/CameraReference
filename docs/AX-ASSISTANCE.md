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
