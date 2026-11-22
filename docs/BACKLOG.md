# Outstanding work

Current source: accepted 1.1.10 / build 69. Migration and its six deferred fixes are complete; wider checks below remain separate. [TESTING.md](../TESTING.md) holds the actionable checklist; [research findings](AX-ASSISTANCE.md) and [validation](VALIDATION.md) retain evidence.

## Screenshot backup modes

- Candidate 1.1.11: validate pixel-only 50/50 splits and wider side search with optional AX view detection on/off.
- Determine the cause of pure screenshot Library split failures associated with Embedded Preview text, and Develop side-by-side with the right panel hidden. Fix only after establishing the failed stage and separate authorisation.
- AX-assisted placement is removed in candidate 1.1.11. Confirm Library status labels and extra bottom space do not corrupt the independent outer rectangle; malformed capture surfaces remain separate.
- Measure elapsed cost and sustained overhead of retained background pixel checks before reducing or removing them. Assisted-only comparison counters have been retired.

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

AX placement, view inference and configurable corrections are implemented. Guided manual-selector AX recalibration is the next separate step. Pinch was deliberately removed in favour of Command-scroll. Historical development tasks belong in HISTORICAL-NOTES.md, not here.

## Migration closure — 2026-11-21

All six deferred items are accepted: floating hover text, full-screen title-bar visibility, AX preview frame constraints, screenshot-with-AX dismissal policy, generic calibration instructions, and floating-window stacking. Final title-bar clipping tests passed; the small reveal delay is accepted. See [validation](VALIDATION.md) and [original test response](migration/1.1.10-CLIPPING-TEST-RESPONSE.md). Superseded attempts are archived in [historical notes](HISTORICAL-NOTES.md).

Matched pre/post-migration latency measurements were not collected; no performance improvement claim is made. The generated-source migration test harness remains useful regression protection; replacing it with direct component construction is future test-infrastructure work, not a release blocker.
