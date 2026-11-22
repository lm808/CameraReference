# Final usability candidate — 1.1.12 / build 71

Prior notes are preserved in docs/1.1.11-TEST-RESPONSE.md. Run only the candidate staged app; main is unchanged.

- [ ] Screenshot: Library Compare at minimum and larger window sizes, panels shown/hidden, both pane choices, portrait/landscape photos and Embedded Preview text. Bounds must exclude the header and both toolbar rows. Repeat in Develop and Loupe.
- [ ] Screenshot: change photo with AX view detection OFF, then ON. A visible overlay dismisses; an off overlay stays off. No unexpected dismissal on unknown selection evidence.
- [ ] Switch Left/Right or Top/Bottom within the same screenshot split. Correct opposite pane and Fit; repeat after resize/panel changes so stale bounds cannot be reused.
- [ ] Without recording permission: explicit screenshot placement requests access; AX placement and free manual calibration do not. Do not change the stable app’s permission entry.
- [ ] Shortcuts: existing J overlay/F floating bindings; Control+Option+Command+8/4/6/2/5 view choices. In automatic views only matching panes apply; manual Screenshot view selection permits all five. Menu shows assignments. Check Lightroom does not also react.
- [ ] Keyboard settings: clear a binding, Save a waiting/empty recording, leave another untouched, reject duplicates, Cancel changes, restart to check persistence. Existing overlay update/dismiss behaviour must match menu selection.
- [ ] AX-only regression: live on/off, floating display, manual selection, full-screen clipping unchanged.

Guided calibration (Developer tools):

- [ ] Complete the five prompted windowed cases, selecting the **combined** working area rather than the photo or one pane. Review the proposed signed values against your current config. No config changes before Apply.
- [ ] Cancel a measurement, retry, close/reopen, and restart. Manual region and auto/manual choice must remain unchanged. Wrong module/view/panels/toolbar or changed window during selection must reject the measurement.
- [ ] Apply: verify a backup is reported, comments and unrelated settings survive, and no recording permission is requested. Editing the config externally during the guide must block Apply.
- [ ] Verify resulting AX placement in Loupe, Left/Right and Top/Bottom, panel shown/hidden cases and a resized window. Full-screen allowance is deliberately not recalibrated.
