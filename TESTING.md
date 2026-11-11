# Camera Reference 0.9.15 — split placement only

Quit the old app, open `build/CameraReference.app`, confirm **0.9.15**. Bridge **0.5.0** is unchanged. Other tests are deferred as requested; prior results are in VALIDATION.md.

Use Lightroom Fit and matching app layout. Keep the configured Fit inset at its working value (default 18 points). Clear region in auto mode before fresh-detection comparisons.

- [ ] In Lightroom side-by-side, select **Full** in the app: the combined viewport still covers both pictures correctly.
- [ ] Select **Side-by-side → Left**, then **Right**. Repeat with portrait and landscape photos: correct full pane, no tiny picture/gap placement or surrounding Lightroom UI.
- [ ] In Lightroom above-and-below, check Full first, then **Upper** and **Lower**, with portrait and landscape photos. No UI above/below is covered.
- [ ] Leave each correct split overlay visible for 10 seconds through background checks. It should remain stable while panels are unchanged.
- [ ] If detection lacks a divider in the selected margin, it offers calibration rather than guessing. Manual placement remains usable.

If a split fails but Full works, copy **Developer tools → Bridge diagnostics** immediately. Include layout/pane and screenshot with overlay dismissed without changing the window. For disappearance, copy diagnostics before another invocation overwrites the evidence. Diagnostics now show Full viewport, scanned margin, pixel inset, trace offsets/count and candidate count.
