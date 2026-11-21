# Camera Reference 1.1.10 — testing candidate

Post-migration fixes address AX preview frame constraints, generic calibration guidance and clearer hover instructions. Candidate window-ordering changes keep overlays below full-screen system controls and below an existing floating window. These require native verification; placement calculations and config offsets are unchanged.

Screenshot with AX view detection now matches Accessibility with updating off: confirmed photo/view/pane/panel changes dismiss; positive Library Grid dismisses and blocks invocation. Missing evidence retains the overlay. Screenshot with inference off, manual and floating behaviour are unchanged. AX-assisted placement remains independent; no placement algorithms or calibrated offsets change. Main is untouched. Use TESTING.md for the focused checks and quit the previous app before starting this candidate.

Native-test follow-up (same version/build): corrected ordering for full-screen Lightroom companion windows, independently elevated floating reference with explicit Exposé participation, AX preview directly under Developer tools, and the requested three-line gesture tooltip. Only reported checklist issues addressed; native ordering checks remain pending.

Diagnostic-only follow-up, still 1.1.10/69: Developer tools can record window ordering after a five-second delay for fifteen seconds. This investigates the unresolved title-bar and floating-reference failures; it does not fix or change their behaviour. See TESTING.md.
