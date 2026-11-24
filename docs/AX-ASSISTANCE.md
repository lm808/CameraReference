# Accessibility research findings

Consolidated findings through 1.0.32. These are observations and their implementation consequences, not proof that all Lightroom/macOS versions behave alike. [METHODS.md](METHODS.md) describes current algorithms; [VALIDATION.md](VALIDATION.md) preserves test evidence and user annotations. Earlier investigation proposals and version-by-version notes are archived in [HISTORICAL-NOTES.md](HISTORICAL-NOTES.md).

## What Lightroom exposes

| Evidence | Finding | Current use / limitation |
|---|---|---|
| Lightroom SDK view API | Exported functions included getCurrentModuleName and getSecondaryViewName, but no main-view getter in the inspected runtime. showView changes a view; secondary APIs describe the secondary display. | Bridge supplies module/selection, not main-layout identity. |
| Main AX window children | Initial probes saw 7–9 elements and only an 18×18 title-bar AXImage, not the displayed photograph. | Searching only the main window’s children cannot locate the viewport. |
| AX window list | Lightroom exposes surrounding panels and small controls as separate AX windows. A first-16 limit missed potential host candidates. | Main/focused window is prioritised and geometry verified; broader mapping retains the returned window list within its budget. |
| Panel visibility | Hidden panel rectangles can persist; AXVisible was unsupported in samples. Matched CG alpha=0 supplied hidden-state evidence. | AX placement uses AX plus public window-list opacity, without pixel capture. “AX-only” does not mean every input is an AX attribute. |
| Photo information overlays | Geometry disappeared after resize/window recreation (one sample changed from 34 AX entries to 15). | Not used as stable viewport anchors. |
| Reference/Active label candidates | Geometric pairs survived tested information-overlay changes in both orientations; rectangles describe labels, not whole panes. | Infer orientation; no clear pair on a successful read means single. Failed reads remain unknown. No universal semantic guarantee. |
| Small-window side panels | A 324 pt panel exceeded the old 30% threshold in 1047/900 pt windows. | Replaced percentage-width rejection with side attachment and shape/visibility evidence. Minimum-size native test passed in 1.0.28. |

## Toolbar investigation

A toolbar boundary was not found in the inspected AX hierarchy. Increasing traversal limits was necessary before drawing that limited conclusion: the initial 180-element scans were incomplete. Standalone Develop scans visited 838/866 elements without traversal caps; no dedicated toolbar container was found through the queried relationships. Many attribute failures were unsupported AXSections on sidebar rows; main-window sections read successfully and identified the title-bar image. This is evidence about inspected relationships, not proof that no future Lightroom version can expose a toolbar.

Incidental main-window checkboxes disappeared when the toolbar hid in Develop; Library did not provide a dependable equivalent. Control counts, indices and checkboxes were rejected as production selectors because toolbar contents/version can change.

The View menu was more useful:

- Develop delayed pairs at 16:27/16:30 on 13 November 2026 exposed **Hide Toolbar** when shown and **Show Toolbar** when hidden (65 elements, about 40 ms, no errors).
- Confirmed Library pair at 16:58:23/16:58:49 matched this (103 elements, 50/40 ms, no errors). The earlier 16:55/16:56 pair had uncertain module and is excluded from module-specific conclusions.
- Menu checkmarks were absent. Shortcut T/modifiers 8 supported command identification; generic AgMenu identifiers were not unique. English command titles are currently required.
- Focus transitions sometimes left menus incomplete; one frontmost check disagreed with the user’s observation. Read failure must remain explicit, with configured shown/hidden/lastKnown fallback, not pretend to be measured visibility.

This supports a toolbar **visibility** query, not a height/boundary measurement. Height stays configurable. Grid uses a different first-level menu selection-mark reader and still needs native confirmation; toolbar-title success does not establish Grid-mark reliability.

## Measurements and calibration

13 November, Develop on HP E273q, 2560×1440 at scale 1. Coordinates are global top-left macOS points. Compare UI boundaries, not the additional one-point overlay panel border.

| Report time | Host x,y,w,h | Toolbar | Raw AX bottom | Screenshot bottom |
|---|---|---|---:|---:|
| 13:34:54 | 0,30,2560,1349 | shown | 1228 | 1197 |
| 13:38:21 | 0,30,2560,1349 | hidden | 1228 | 1240 |
| 13:46:11 | 673,113,1823,1165 | shown | 1127 | 1096 |
| 13:47:29 | 673,113,1823,1165 | hidden | 1127 | 1139 |

The 13:46 result reused accepted cached bounds; others were fresh. The toolbar difference was 43 pt at both sizes. Side scroll-area inner edges agreed with screenshot edges (306/2243 large, 979/2179 smaller), but their bottoms did not change with toolbar visibility. They could not replace toolbar state. Library shown/hidden reports at 15:18/15:20 also measured 1197→1240 while raw filmstrip top stayed 1228.

On 14 November the user designated screenshot-calculated bounds as calibration reference. Library single-view reports 19:44:49–19:49:33 and Develop side-by-side 20:10:30/20:12:29, stacked 20:13:29/20:14:23 supported common shown/hidden edge corrections. Existing personal corrections were accounted for when comparing raw AX, adjusted AX and screenshot bounds. Corrected midpoints differed from pixel dividers by about 0.5 pt, so no independent divider correction was added.

Accepted defaults, using **right/up positive** from raw AX boundaries:

| Component | Correction / base inset (pt) |
|---|---:|
| Left shown / hidden | -17 / -1 |
| Right shown / hidden | +17 / +1 |
| Top shown / hidden | +11 / +1 |
| Filmstrip shown / hidden | -11 / +17 |
| Toolbar shown / hidden | +43 / 0 |
| Library split only | +25 |
| Hidden base insets L/R/T/B | 18 / 18 / 50 / 0 |

Bottom corrections are cumulative. Filmstrip shown with toolbar hidden remains inferred; other bottom combinations were measured. Library split screenshot failure excluded that case from the original calibration; the user subsequently calibrated the extra allowance to 25 pt. It applies only to Library split, not Library single. These are configurable defaults, not universal AX facts; other scales, versions and hidden combinations remain acceptance work. Exact keys are in [CONFIGURATION.md](CONFIGURATION.md).

## Capture and detector findings

Earlier non-maximised displacement came from capture extent/mapping, not something a hard-coded display-width shift should correct. Later intermittent off-screen captures contained padding or inconsistent content scale. Both older 1.0.10 and guarded 1.0.13 failed in supplied cases; this was not established as a simple new-version regression. Successful later captures had matching parent geometry and content scale 1. Restarting Lightroom sometimes cleared the issue; sleep/wake was a user hypothesis, not a confirmed cause. Metadata checks must not block raw diagnostic previews.

Original split outer-bound changes previously regressed placement into UI or tiny gaps. The pre-simplification screenshot method used Full bounds followed by bottom/left margin divider traces; this scanner is retired. The current method validates pixel outer bounds and splits 50/50. Dividers can stop short of the margin edge. Pure Library split failure correlated with Embedded Preview text; removing text by changing photo succeeded, but exact cause/stage is not confirmed.

## How research is used now

| Area | Implemented use | Remaining evidence needed |
|---|---|---|
| Host tracking | AX logical frame cross-checks host geometry | Off-screen/multi-display and lifecycle cases; cannot repair capture pixels |
| AX placement | Surrounding panels, opacity, toolbar menu and calibrated corrections | Scales, sessions, languages and broader layouts |
| View inference | Label geometry, independently optional for Screenshot; always on for AX | Recreated/missing labels and native Grid menu marks |
| Screenshot fallback | Independent pixel outer detection with validated wider side retry | Continued unusual-image/version/display coverage; recorded cases passed through 1.1.15 |
| Split placement | 50/50 within validated pixel outer bounds; no divider scan | Library Embedded Preview/extra bottom space; both orientations |
| Background checks | Existing pixel checks retained; AX panel signature used separately by optional view detection | Sustained cost measurements; no screenshot reduction claimed |
| Diagnostics | Automatic bounded complete reports after invocation when saving enabled | Timing/provenance consistency through rapid changes |

No calibrated AX offsets are applied to screenshot results. The single screenshot fallback needs Screen Recording permission and does not use AX placement hints. Assisted placement was retired in candidate 1.1.11; its findings remain in HISTORICAL-NOTES.md. Current AX placement needs no automatic pixel capture; explicit previews/snapping remain separate.

## Investigation files and retention

- Current findings: this file. Current algorithms/source ownership: METHODS.md and ARCHITECTURE.md.
- Historical proposals/experiments: HISTORICAL-NOTES.md. Test outcomes/user annotations: VALIDATION.md. Remaining work: BACKLOG.md and TESTING.md.
- Explorer source/instructions: tools/AXExplorer/. Built tool: build/AXExplorer/, never release/.
- Seven original toolbar probe reports remain in ignored investigations/ax-reports (about 520 KB). They cover shown/hidden exhaustive scans, immediate/delayed menu pairs and the confirmed Library pair. The uncertain-module pair is retained as such, not evidence for a specific module. Do not commit raw reports.
- Current app reports overwrite CameraReference/Diagnostics/latest.txt under Application Support; they are runtime evidence, not an archive. User-uploaded attachments remain outside the repository; generated build/release files are not research records.

Raw evidence is retained because it supports these findings. No photographs, personal configs or permission data are copied into tracked documentation. Future cleanup should remove reproducible scratch output, not sole copies of observations or user test annotations.


## Info-overlay strip false match — 1.1.3 candidate

On 2026-11-18, a 1058 × 808 pt host exposed a visible 1022 × 167 pt info window inset by 18 pt. Both side panels hidden made it pass the former >90%-width strip filter, lowering raw top from 167 to 324. Showing either side narrowed the info rectangle and avoided the false match; showing both also worked. The authorised fix additionally requires both horizontal host edges to align within 4 pt. Regression fixtures cover all side combinations and top hidden; native candidate verification remains pending. Existing calibrated offsets and screenshot algorithms are unchanged.

## Full-screen hidden top (2026-11-19)

Reports at 2026-11-18 23:10:44 UTC (built-in display) and 2026-11-19 09:59:43 UTC (HP) exposed a fixed windowed hidden-top inset in native full screen. The 32 pt excess also rejected side-by-side labels outside the 25 pt top tolerance; top/bottom classification succeeded but upper geometry was shortened. Build 62 reads the main AX window AXFullScreen flag and removes 32 pt from the hidden-top base only on a positive result, before label classification. Signed user offsets still apply. Shown top, false/unknown state and screenshot geometry remain unchanged. The native flag and applied adjustment are reported; native acceptance remains pending. Synthetic fixtures cover both observed hosts and split orientations.

Build 63 replaces the fixed full-screen allowance with `axFullScreenTitleBarAllowancePoints` (default 32, range 0...200 macOS points; 0 disables). It is a calibrated value supported by the recorded reports, not an AX boundary measurement. The file-driven advanced editor exposes it; config generation and missing-key upgrades preserve existing values. Both AX classification and placement use it, while screenshot geometry and windowed placement are unchanged.

## Accepted title-bar identification and presentation clipping

The paired 2026-11-21 22:46 recordings identified the correct title-bar window but still showed the overlay above it during repeated below-window attempts. These attempts are removed from production. The normal full-screen window level and successful floating-reference initialization fix remain.

Production now uses the close/zoom controls’ shared AXGroup to establish a unique same-PID CG bounds match, then follows that CG ID across animation. The all-window metadata list includes the retracted, alpha-zero bar. Unknown evidence retains the previous clip; explicit hidden evidence or leaving full screen clears it. No pixel capture, new calibrated dimensions or placement changes are involved.

Only in confirmed macOS full screen, overlapping overlay content is masked from its top through the title bar’s lower edge. The mask includes photo, border and label; window frame, image viewport and navigation transform stay fixed. AX preview borders share this mask; floating references do not. Native reveal/hide, unchanged image geometry, title-bar controls and windowed/float regression tests passed on 2026-11-21. The slight polling delay is accepted. Explorer evidence and tools remain separate under investigations/ and build/AXExplorer/.

## Historical guided recalibration implementation (1.1.12 candidate)

The initial 1.1.12 candidate offered a five-step manual measurement guide. It uses the existing rectangle selector and raw AX metadata, with confirmed toolbar visibility and stable-state checks. Calculations, validation and file persistence are separate from production placement; the accepted formulas/defaults are unchanged until the user explicitly applies reviewed replacements. See METHODS.md for the cumulative offset equations and README.md for the workflow. The guide does not infer a toolbar rectangle from AX and does not resolve the documented AX evidence limitations. Native testing is pending.

## Current guided recalibration — introduced in 1.1.13

The guide now measures effective boundaries directly with six independently retryable setups, plus the actual photo rectangle in setup 1. It recovers the existing ten corrections, the macOS full-screen hidden-top allowance, and the shared Fit inset. Fixed hidden base values are not redundant additional measurements; their corrections absorb effective-boundary changes. See METHODS.md for equations and TESTING.md for native acceptance. Pixel edges support explicit Option-snapping only; AX-only production placement remains capture-free and its mathematics is unchanged.

## Acceptance and boundary audit — 2026-11-24

The six-setup/seven-selection guide, Apply, full-screen/Fit results and layout corrections passed native tests through 1.1.15. Pure screenshot Library/Develop failure and top-edge reproductions also passed after pixel-only validation changes. Earlier dated “pending” statements describe the investigation at that time; current evidence is in VALIDATION.md and the archived 1.1.14/1.1.15 responses. This acceptance does not establish universal Lightroom/version/display support.

The [boundary audit](BOUNDARY-AUDIT.md) identified raw calibration metadata depending on production correction guards. In 1.1.16 the shared axRawGeometry classifier returns evidence independently, and production axTrialProposal still enforces the existing correction guards. No calibrated offsets enter screenshot detection.
