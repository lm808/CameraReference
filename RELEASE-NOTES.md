# Camera Reference 1.0.29 — candidate

Adds Use screenshot detection with independent AX-assisted placement and AX view detection options. AX-only always detects the view. Fresh settings default to AX, while existing choices are preserved.

The assisted mode uses raw panel edges to guide pixel searches, with no calibrated AX offsets. Pixel validation and margin divider scanning determine placement; inconclusive hints fall back to the original search. Background screenshot checks remain enabled and measured during the trial.

Screen Recording is never requested. Missing permission disables capture/snapping gracefully; manual calibration remains available.

Native acceptance is pending. Main's accepted 1.0.28 app is unchanged. No DMG packaged.
