# Camera Reference 1.1.15 — user-accepted candidate

Build 74 addresses calibration row alignment, overlay-click focus, and screenshot boundary selection. Calibration uses explicit instruction/button/status columns. Clicking an overlay activates Lightroom; its existing lifecycle brings both forward, with no new stacking workaround.

Screenshot detection checks the outside of candidate UI borders and preserves plain surround bands when an equally supported outer boundary exists. This targets photo/internal edges being selected as working-area boundaries. The reported Library ambiguity and Develop top-edge error passed native retesting. Candidate rectangles and scores are now included in diagnostics.

AX placement and calibration calculations are unchanged. The user passed all focused 1.1.15 checks on 2026-11-24. Exact 1.1.14 and 1.1.15 test annotations are preserved. Main and its staged daily-use app remain untouched. No package created.
