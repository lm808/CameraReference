# Camera Reference Testing 1.0.23

Use this worktree's release/CameraReference Testing.app; quit stable first. Main stays 1.0.15. These tests are pending native acceptance. Enable AX preview and Save diagnostics after invocation. Existing numeric geometry adjustments can remain zero.

- [ ] Library Loupe and Develop: show/hide toolbar, invoking after each change. Diagnostics should say fresh shown/hidden. The preview uses the corresponding configured bottom offset; zero offsets intentionally leave the raw bottom unchanged.
- [ ] Repeat at a smaller window size, with filmstrip hidden, and after switching away/back. Missing menu/permission/focus evidence must say **assumed shown**, not confirmed hidden. No stale toolbar state should be reused.
- [ ] Diagnostics retain host/display coordinates, full window/panel map, opacity/visibility evidence, labels, inferred view, raw/adjusted pane bounds and toolbar read failures. No exhaustive child/AXSections dump. Reports save automatically after invocation.
- [ ] Single and both split layouts: coloured preview borders remain separate from actual placement. Live view experiment updates only on change; switching it off restores explicit selection.
- [ ] Experiments off: existing screenshot Full/split placement, manual placement and repeated toggles remain unchanged. Toolbar assumptions must never change actual overlay bounds.
- [ ] AX Explorer launches from build/AXExplorer/Explore.command when needed; reports save in investigations/ax-reports. No explorer exists in release/.
