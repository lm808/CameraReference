# Camera Reference 1.0.29 — candidate

Adds a three-way automatic-placement selector: AX only, AX-assisted screenshot and Pure screenshot. View detection remains separate. Fresh settings default to AX, while existing choices are preserved.

The assisted mode uses raw panel edges to guide pixel searches, with no calibrated AX offsets. Pixel validation and margin divider scanning determine placement; inconclusive hints fall back to the original search. Background screenshot checks remain enabled and measured during the trial.

Native acceptance is pending. Main's accepted 1.0.28 app is unchanged. No DMG packaged.
