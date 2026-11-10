# Camera Reference 0.9.14 — focused tests

Quit the old app, open `build/CameraReference.app`, confirm0.9.14. Bridge0.5.0 is unchanged. Prior acceptance/results are in VALIDATION.md.

## Split placement

Use Lightroom Fit and matching app layout selection. Clear region in auto mode before each fresh-detection check.

- [ ] Portrait side-by-side: Left covers the full left pane and Right the full right pane—no tiny photograph or central-gap overlay.
- [ ] Landscape side-by-side: repeat Left/Right on several images. Earlier failures remain a regression target even where0.9.13 sometimes worked.
- [ ] Above-and-below: Upper/Lower select full panes for portrait and landscape photos.
- [ ] Leave each correct overlay visible at least10 seconds with `panelCheckIntervalSeconds = 3`. It should not vanish with unchanged panels. If it does, copy Developer tools → Bridge diagnostics immediately; the rejection reason and before/after bounds are recorded.
- [ ] Hide/show a Lightroom panel: background checks still invalidate genuinely changed placement. Clear region remains the immediate fallback; manual calibration still uses the selected backdrop.
- [ ] Wrong orientation/no supported divider falls back to calibration. Very narrow split areas may also require calibration. Full single-photo alignment remains unchanged.

## Mission Control / Exposé

- [ ] With an overlay visible, enter Mission Control or App Exposé: no separate/orphan overlay floating over thumbnails. Exit to the same Lightroom window: check correct visibility/alignment.
- [ ] Repeat with another app in front, a floating display open, fullscreen Lightroom and a Space switch. Ordinary app switching still lets other windows cover the overlay; movement follows Lightroom. Resize/Space safeguards must still prevent stale placement.

## Remaining checks

- [ ] Repeated toggles still report RAM/placement hits and skip capture; compare with0.9.13's148ms.
- [ ] Set panel interval6, verify resumed monitoring; set0, verify no periodic capture, then restore3. Check idle overhead.

Failures: include selected layout/pane, Bridge diagnostics, and a screenshot with overlay dismissed but window/panels unchanged. For disappearance, copy diagnostics before another invocation overwrites the evidence.
