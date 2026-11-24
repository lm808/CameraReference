# Abstraction-boundary audit — 2026-11-24

Reviewed candidate source at `1624d65` (1.1.15 / build 74), with the branch diff against accepted main `ab92404` (1.1.10 / build 69). This audit covers the final-placement branch: screenshot simplification/reuse, shortcuts, metadata, settings, guided calibration and the latest presentation fixes. It is a source/dependency review, not a new whole-application correctness or performance certification.

The user accepted every 1.1.15 test. Exact annotations are preserved in [1.1.15-TEST-RESPONSE.md](1.1.15-TEST-RESPONSE.md); earlier feature acceptance is in [1.1.14-TEST-RESPONSE.md](1.1.14-TEST-RESPONSE.md). Existing automated evidence is in [VALIDATION.md](VALIDATION.md). No executable, version, staged app or main-branch change was made during this audit.

## Follow-up status — 1.1.16

A1 and A2 are now fixed in code, with all three focused native checks completed in [1.1.16-TEST-RESPONSE.md](1.1.16-TEST-RESPONSE.md). `axRawGeometry` owns the single existing raw panel/layout calculation; `axTrialProposal` applies unchanged corrections/guards to its result; the guide consumes the raw result directly. `ScreenProbeResult.failureReason` carries typed capture failure state, and selection preparation uses that state for guidance. No second classifier or permission-check implementation was introduced. Production AX geometry matched the prior function in 1,728 synthetic cases. The original findings below describe the audited 1.1.15 state and remain as history.

## Conclusion at the time of audit

The principal ownership boundaries are maintained. No blocking cross-backend dependency or new duplicate authoritative state was found in the reviewed paths. Two smaller couplings remain below; they are documented follow-ups, not silently fixed as part of this review. Shared AppDelegate operation state remains the previously documented structural compromise.

## Boundary checks

| Path | Observed implementation | Assessment |
|---|---|---|
| Manual / AX / screenshot routing | PlacementCoordinator resolves manual first; Accessibility returns before screenshot caching/permission/capture. Separate adapters remain in PlacementImplementations. | No implicit AX-to-pixel fallback. |
| Screenshot geometry | ScreenProbe owns capture/conversion; ViewportDetector validates pixel rectangles; splitViewport divides validated bounds equally. No AX panel hints or correction offsets enter this calculation. | Independent fallback preserved. Recent edge/band changes are local to the pixel detector. |
| Optional AX view detection | AppSettings resolves the option; ViewCoordinator/monitor evidence supplies layout. Screenshot calculations consume the selected layout, not AX geometry. | View inference remains separate from placement. |
| Screenshot reuse | PlacementMemory owns stored geometry; ScreenGeometryCache owns raster reuse; AppSettings supplies explicit reuse eligibility; MonitoringCoordinator qualifies results before applying the pure invalidation helper. | No third cache or detector-owned preference reads. Inconclusive retention is limited to expanded reuse. |
| Live policy and stale results | OverlayBehaviourPolicy is pure. Monitoring/View/Placement coordinators preserve request, epoch, module, host, generation and cancellation guards. | Calculations do not directly change overlay lifecycle. Geometry outliving a photo does not permit late photo display. |
| Selection / calibration | CalibrationController returns coordinates/cancellation; shared preparation owns optional snapping capture. AXCalibrationPlan computes offsets; AXCalibrationCoordinator owns evidence, review and config persistence. | No manual-region write or automatic-mode change from guided calibration. Raw-evidence dependency noted in A1. |
| Calibration UI | Countdown and row layout present controls/events only. Local generation checks reject stale guide callbacks; shared preparation still uses controller identity. | No new placement math or duplicated capture loop in the widget. |
| Overlay activation | ReferenceView emits a callback; PresentationCoordinator binds it only to the current overlay and activates Lightroom. Existing foreground observation owns ordering. | No app lookup in the shared view; floating/preview views have no callback; release clears it. |
| Picture style | ImageSource reads optional metadata; LoadedReference and its cache carry it; guarded completions copy it to the displayed ReferenceView. | Menus perform no extraction and do not read global current-selection metadata. |
| Shortcuts | Recorder returns candidate bindings; ShortcutSettings validates/registers/persists; ViewShortcuts dispatches through selectLayout, as the menu does. | Existing update/dismiss policy is reused; keypad aliases do not change invocation bindings. |
| Config / Developer tools | DetectionConfig owns schema/defaults/organization; ConfigEditorDocument validates saves; SettingsActions applies reload/invalidation; SettingsMenu renders visibility. | No second config owner; explicit values retained. |
| Diagnostics | Candidate scores are emitted alongside detector evidence; Diagnostics stores/formats reports and previews. | Diagnostic values do not feed back into production geometry. Human-text dependency in snapping guidance is noted in A2. |

## Findings and follow-ups

### A1 — raw calibration evidence depends on corrected placement validity (medium, nonblocking)

`AXCalibrationCoordinator.readEvidence` calls `axTrialProposal` with current settings, zeroing only the full-screen allowance. In `AXTrial.swift`, rawArea is calculated before signed corrections, but the proposal is returned only after corrected-area size and split-divider guards succeed. Consequently extreme but syntactically valid offsets, especially in a small window, can prevent the guide from obtaining otherwise usable raw evidence to repair those offsets.

This is an observation/calculation coupling, not evidence that accepted normal calibration is wrong. A future local change should expose raw panel/layout evidence before correction validation and let production placement apply its own correction guards. Do not duplicate panel classification in the guide or weaken production placement guards. Add synthetic cases with invalid corrected bounds but valid raw bounds, alongside unchanged production results. No change made in this audit.

### A2 — snapping permission guidance depends on diagnostic wording (low)

`CalibrationCoordinator.finishCalibrationPreparation` tests `result.summary.hasPrefix("Screen Recording permission unavailable")`. One `ScreenProbe` path emits "Screen Recording permission is unavailable", while the capture-error path emits the matching wording. If permission becomes unavailable between the coordinator preflight and capture preflight, the freehand selector can omit the specific System Settings guidance. Initial permission-denied handling still uses the direct permission check and works independently.

The result should eventually expose a typed permission/failure reason, with summary text used only for display. This avoids changing UI behaviour accidentally when editing diagnostics. Test both preflight denial and capture-time denial; keep freehand selection and the no-prompt policy unchanged. No change made in this audit.

## Intentional shared dependencies and limits

- `fitInsetPoints` and per-side UI/photo options are shared display/Fit settings. Guided calibration deliberately updates the shared Fit inset, so it can affect AX and screenshot photo fitting; AX-specific corrections still never influence screenshot edge detection. This is an accepted configuration relationship, not backend leakage.
- AppDelegate still holds shared placement/calibration operation IDs and cancellation handles. The guide coordinates those existing handles rather than creating a second selector owner. Any future independent workflow must preserve this lifetime contract.
- Metadata stays in the extraction layer, but its optional extra ExifTool request runs before cold-load completion and has a three-second timeout. Warm loads reuse it. Native tests passed; no measured latency improvement is claimed. Profile before changing scheduling or introducing parallel metadata updates.
- Pixel edge/band checks are heuristics. Passing the reported Library/Develop case does not prove every photo or future Lightroom UI will work. Preserve independent diagnostics and the manual fallback.
- Native acceptance covers the supplied environment. Wider display/language/version and rapid-event coverage remains in BACKLOG.md. Existing generated-source coordinator tests do not prove every timing interleaving.

## Documentation corrections made

Updated current build/acceptance status, source ownership, shared-Fit explanation, screenshot method description, calibration acceptance and backlog. Archived exact test annotations. Removed stale current-tense claims about AX-assisted placement, margin divider scanning, five-step calibration and pending tests that the user has completed; historical evidence remains labelled as history.
