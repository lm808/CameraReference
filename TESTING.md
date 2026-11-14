# Camera Reference 1.0.29

Run release/CameraReference Testing.app in worktrees/ax-assisted-screenshot-detection. Main remains 1.0.28. Automated checks and user acceptance are separate. Prior test annotations are preserved verbatim in docs/VALIDATION.md.

## This update

- [ ] Select each automatic placement method in Developer tools → Experimental features. Switching method does not dismiss the visible overlay. Manual placement still takes precedence, and AX view detection remains independent.
- [ ] AX-assisted: Full, both split orientations and each pane; show/hide each panel and toolbar; resize to minimum. Compare against Pure screenshot. Collect diagnostics for disagreement.
- [ ] Repeat overlay/float invocation on the same image. Check cache reuse and the assisted evidence counters after internal layout changes. Leave retained screenshot checks enabled for this trial.
- [ ] Pure screenshot and AX-only still behave as before; AX-only reports background capture disabled. AX preview remains independently selectable.

## Carried forward

- [ ] Search Advanced settings by name and comment (case-insensitive). Edit a filtered row, clear/change search and verify the edit remains on the correct row. Save/Cancel and external-edit protection still work.
- [ ] Plain name = value config retains your active values; no obsolete v1 entries or # AX: prefixes remain. Open config file still works from the editor.
- [ ] File-driven rows: close the editor, add a supported setting that is currently absent to config.conf, reopen; its row appears without modifying editor code. Do not add duplicate keys.
- [ ] toolbarUnknownFallback accepts shown, hidden and lastKnown. When AX cannot read toolbar state, diagnostics show the chosen fallback; lastKnown uses prior state for the same module/process, or shown without history.
- [ ] Library's additional +25 pt applies only to split views. Confirm usual overlay/float and screenshot/manual paths remain usable after promotion.

## Deferred to-dos — do not remove until resolved

User confirmed minimum-window AX placement works on 1.0.28.

- [ ] Extend small-window testing with each side hidden, then return to a large window.
- [ ] Investigate screenshot detection failure in Develop side-by-side with the right panel hidden; regression status unknown.
- [ ] Broader AX edge-case testing during normal use: panel combinations, both split orientations/panes, window sizes and displays. Record diagnostics for failures.
