# Camera Reference 1.0.27

Run release/CameraReference.app on main. Automated checks and user acceptance are separate. Prior test annotations are preserved verbatim in docs/VALIDATION.md.

## This update

- [ ] Search Advanced settings by name and comment (case-insensitive). Edit a filtered row, clear/change search and verify the edit remains on the correct row. Save/Cancel and external-edit protection still work.
- [ ] Plain name = value config retains your active values; no obsolete v1 entries or # AX: prefixes remain. Open config file still works from the editor.
- [ ] File-driven rows: close the editor, add a supported setting that is currently absent to config.conf, reopen; its row appears without modifying editor code. Do not add duplicate keys.
- [ ] toolbarUnknownFallback accepts shown, hidden and lastKnown. When AX cannot read toolbar state, diagnostics show the chosen fallback; lastKnown uses prior state for the same module/process, or shown without history.
- [ ] Library's additional +25 pt applies only to split views. Confirm usual overlay/float and screenshot/manual paths remain usable after promotion.

## Deferred to-dos — do not remove until resolved

- [ ] Investigate small-window AX prediction covering visible side panels.
- [ ] Investigate screenshot detection failure in Develop side-by-side with the right panel hidden; regression status unknown.
- [ ] Broader AX edge-case testing during normal use: panel combinations, both split orientations/panes, window sizes and displays. Record diagnostics for failures.
