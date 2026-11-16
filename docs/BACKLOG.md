# Outstanding work

Current state: 1.0.32 on main. Daily use is accepted by the user; this does not imply every deferred native test has passed. [TESTING.md](../TESTING.md) holds the actionable checklist; [research findings](AX-ASSISTANCE.md) and [validation](VALIDATION.md) retain evidence.

## Screenshot backup modes

- Validate all combinations of AX-assisted placement and AX view detection, preserving the original pure screenshot path.
- Determine the cause of pure screenshot Library split failures associated with Embedded Preview text, and Develop side-by-side with the right panel hidden. Fix only after establishing the failed stage and separate authorisation.
- Validate assisted raw-header rejection, bottom-label tolerance and midpoint fallback within validated outer bounds; these do not fix malformed capture surfaces.
- Measure contribution, elapsed cost and sustained overhead of retained background pixel checks before reducing or removing them.

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

AX placement, view inference, configurable corrections and assisted search are already implemented; they are not future feature proposals. Pinch was deliberately removed in favour of Command-scroll. Historical development tasks belong in HISTORICAL-NOTES.md, not here.
