# Outstanding work

Current candidate: user-accepted 1.1.15 / build 74. Main remains 1.1.10 / build 69 until a separately authorised merge. Migration and its six deferred fixes are complete; wider checks below remain separate. [TESTING.md](../TESTING.md) holds the actionable checklist; [research findings](AX-ASSISTANCE.md) and [validation](VALIDATION.md) retain evidence.

## Screenshot fallback

- The 50/50 split/search-zone changes, optional AX view detection, cache reuse and reported Library/Develop boundary fixes passed the recorded native tests through 1.1.15. Prior divider-trace failures are historical evidence, not an outstanding request to restore the retired scanner.
- Continue collecting genuinely new ambiguous/wrong outer-bound cases, including unusual panel widths, status text and image content. Preserve candidate scores and coordinate context before changing heuristics. Malformed/off-screen capture surfaces remain a separate issue.
- Measure elapsed cost and sustained overhead of retained background pixel checks before reducing or removing them. AX-assisted placement and its comparison counters are retired.

## Boundary-audit follow-ups (not implemented)

- **A1 — medium:** expose raw AX panel/layout evidence independently of corrected-placement validity. The guide currently obtains rawArea only when axTrialProposal passes corrected bounds/divider guards, so extreme valid offsets can block repair in a small window. Preserve production guards and avoid duplicating classification. See [audit](BOUNDARY-AUDIT.md#a1--raw-calibration-evidence-depends-on-corrected-placement-validity-medium-nonblocking).
- **A2 — low:** replace diagnostic-string matching for snapping permission guidance with a typed result. Capture preflight and capture-error paths currently use different wording; a permission change during preparation may omit guidance while retaining freehand selection. Preserve the no-prompt policy. See [audit](BOUNDARY-AUDIT.md#a2--snapping-permission-guidance-depends-on-diagnostic-wording-low).

## Continued native use and edge cases

- Confirm direct View → Grid selection marks are available and reliable; nested Loupe Overlay → Grid must not match.
- Exercise AX photo/view/pane/panel updates and dismiss policy through rapid selection, module changes, failed loads and explicit dismissal.
- Validate toolbarUnknownFallback modes, hidden-panel combinations, both split orientations/panes, display scales and multi-display configurations. Minimum-size AX placement passed in 1.0.28; broader coverage remains.
- Collect intermittent off-screen padded/oversized capture evidence via diagnostics and raw previews. Restarting Lightroom has helped; cause and general fix remain unknown.
- Retain working movement/other-app covering and minimise/overview/Space restoration. Brief minimise linger is accepted; no early-command interception is planned.
- Check Lightroom/macOS version and language sensitivity of AX label/menu assumptions and geometry defaults.

## Maintenance and distribution

- Reduce AppDelegate coordination complexity incrementally; centralise policy and add event-sequence tests before structural changes. See ARCHITECTURE.md.
- Verify installation/upgrades without losing explicit config, calibration or settings. Test DMG only when packaging is requested.
- Decide licensing (author deferred), Developer ID signing/notarisation and publisher identity.
- Validate both architectures and supported macOS/Lightroom versions; builds currently target the native architecture. Add CI/release automation when the environment is agreed.

## Possible later features

- Additional RAW formats/Sony samples and cropped RAW/JPEG aspect handling.
- Better screenshot placement across unusual panel widths without personal side-search tuning.

AX placement, view inference and configurable corrections are implemented. Guided manual-selector AX recalibration, including Apply/full-screen/Fit validation, is accepted through 1.1.14/1.1.15. Pinch was deliberately removed in favour of Command-scroll. Historical development tasks belong in HISTORICAL-NOTES.md, not here.

## Migration closure — 2026-11-21

All six deferred items are accepted: floating hover text, full-screen title-bar visibility, AX preview frame constraints, screenshot-with-AX dismissal policy, generic calibration instructions, and floating-window stacking. Final title-bar clipping tests passed; the small reveal delay is accepted. See [validation](VALIDATION.md) and [original test response](migration/1.1.10-CLIPPING-TEST-RESPONSE.md). Superseded attempts are archived in [historical notes](HISTORICAL-NOTES.md).

Matched pre/post-migration latency measurements were not collected; no performance improvement claim is made. The generated-source migration test harness remains useful regression protection; replacing it with direct component construction is future test-infrastructure work, not a release blocker.

## Final branch acceptance — 2026-11-24

[1.1.14 annotations](1.1.14-TEST-RESPONSE.md) passed settings/config migration, CR3/C-RAW/ARW metadata, reuse and guided calibration, with row alignment still outstanding. [1.1.15 annotations](1.1.15-TEST-RESPONSE.md) passed the alignment, exact Library/Develop screenshot cases, cache/panel/layout regressions, overlay-click activation and unchanged AX behaviour. Broader camera-model, platform and timing coverage above is not implied by these passes.
