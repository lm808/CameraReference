# Camera Reference 0.9.13 — current tests

Quit the previous app, open `build/CameraReference.app`, confirm **0.9.13**. Bridge **0.5.0** is unchanged. Mark `[x]` for pass and add notes to failures. Earlier acceptance and timing history is summarised in VALIDATION.md.

## Fixes

- [ ] Auto mode: layout diagrams/symbols are visible beside Full, Side-by-side, Above-and-below and each pane. Manual mode hides that section; existing manual placement still works.
- [ ] Popup dialogs show the camera app icon. Reopen macOS Privacy settings and check its icon (do not reset permissions).
- [ ] Open a floating photo with the cursor already inside its eventual frame: title/controls appear. Moving across photo/title/controls causes no flicker. Leaving anywhere fades them out; re-entering reveals them.
- [ ] Title-bar drag moves a zoomed float; photo drag pans. At Fit, photo drag moves it. Cmd-scroll/pan, initial portrait/landscape sizing and close/reload remain correct.
- [ ] Move Lightroom with overlay visible: overlay follows without new capture or dismissal (up to0.2s lag). Resize/minimise/Space changes still use safeguards. Other apps cover the overlay naturally; it stays above Lightroom without stealing focus.

## Background checks and speed

Settings → Edit config file: `panelCheckIntervalSeconds = 3` is added to existing configs. Save changes; values0...3600 are supported.

- [ ] Default3: with auto placement cached and Lightroom active, change an internal panel; wait about4s. Background check invalidates placement; next invocation redetects correctly. Bridge diagnostics show1280px check timing.
- [ ] Set0: panel checks stop, while ordinary overlay detection, manual calibration, window movement/resize tracking and JPEG RAM reuse still work. After internal-panel changes, Clear region forces fresh detection without changing auto/manual preference.
- [ ] Set6: checks resume at the longer interval without restarting. Return to3. Manual mode/other foreground apps have no background captures. Watch for false invalidations or idle CPU impact.
- [ ] Repeated same-photo toggles show RAM and placement cache hits, with capture skipped. Compare with0.9.12's197ms. No overlay animation; legacy `overlayAnimation` booleans remain harmless.

Repeated timing:

Background check timing / idle CPU observations:

## Split auto — priority new testing

Choose matching layouts in Lightroom and the app. Enable Automatic viewing area; Clear region before testing fresh detection. Use Fit zoom. Full mode remains the regression baseline.

- [ ] Side-by-side → Left then Right: fresh detection uses vertical divider evidence and fits the chosen pane, for landscape and portrait photos.
- [ ] Above-and-below → Upper then Lower: fresh detection uses horizontal divider evidence and fits the chosen pane.
- [ ] Switch between Full and split selections: no old pane placement reused; Full alignment remains correct.
- [ ] With no divider of the selected orientation, detection offers calibration rather than guessing. Wipe layouts remain unsupported. Manual calibration still selects the chosen UI backdrop at its actual window-relative position.

For split failures, provide diagnostics and a screenshot with the overlay dismissed, retaining the same window/panel arrangement. Background changes are periodic, not immediate; Clear region remains the immediate fallback.
