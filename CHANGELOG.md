# Changelog

## 1.0 alpha

- Retain overlay state during temporary overview/Space/minimisation suspension; restore to the same unchanged Lightroom window when eligible.
- Allow placed overlays to follow partially off-screen movement with clipping.
- Rename advanced configuration to config.conf with non-destructive migration. GUI preferences/calibration remain in macOS preferences.
- Add native-architecture DMG packaging and a user-local Lightroom bridge installer.
- Replace historical README content with usage/installation documentation; consolidate methods, agent instructions, validation and backlog.

## 0.9.15

- Use Full detection for combined split viewport; scan the bottom inset for side-by-side and left inset for stacked panes.
- Tolerate short divider endpoint gaps. User verified all panes/orientations with sideSearchPercent30.

## 0.9.14

- Attempted split-boundary and overview changes. Split method regressed and was replaced in0.9.15; not a recommended detector baseline.

## 0.9.13

- Add configurable3-second/disabled background checks and lower-resolution validation.
- Follow ordinary Lightroom movement; improve hover/icon handling and menu-guided split search.

## 0.9.10–0.9.12

- Add current-selection RAM image caching and placement reuse.
- Add explicit split menus, independent floating display controls, revised sizing and Lightroom-relative overlay ordering.

## Earlier development

- Introduce read-only JPEG source selection/extraction, explicit export, manual calibration/snapping, single-photo UI-boundary detection and diagnostics.

Detailed findings and accepted results are in docs/VALIDATION.md, not this user-facing log.
