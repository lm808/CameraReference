# Camera Reference Testing 1.0.20 — AX investigation

Run this worktree’s `release/CameraReference Testing.app` with bridge 0.5.3. Quit the stable app first; settings are shared. Main and its staged 1.0.15 app remain unchanged. Live acceptance is pending.

First: with **Save diagnostics after invocation** enabled, use **Diagnostics → Refresh AX** in Library Loupe with toolbar shown. Tell the agent to check the report before hiding the toolbar and refreshing again. The new **AX toolbar structure** section reports supported attributes, actual parents and alternative containment relationships. No overlay invocation is needed for this structural test. Repeat in Develop only if the Library comparison is inconclusive. Manual Refresh AX is still required in this build.

Start with automatic view detection **off**, AX preview **on**, and all AX config numbers **zero**.

- [ ] Enable **Developer tools → Save diagnostics after invocation**. Invoke; confirm `~/Library/Application Support/CameraReference/Diagnostics/latest.txt` updates and the clipboard remains untouched. Disable: subsequent invocations do not overwrite it. Diagnostics → Copy all remains available.
- [ ] In single view with all surrounding panels visible, invoke and screenshot the green outline. Use **Diagnostics → Refresh AX**; this also updates the saved report when saving is enabled. Ask the agent to read it before the next case overwrites it.
- [ ] Hide only Lightroom’s bottom toolbar (T), repeat the screenshot and Refresh AX. Then show it, make the window smaller, and repeat. Keep module/display/panel visibility otherwise unchanged. These reports test whether a toolbar container or its controls expose a reliable boundary.
- [ ] Through **Edit config file**, change one `# AX:` number, retaining the prefix. Start with `axToolbarState = shown` and `axToolbarShownBottomOffsetPoints = -31`. Reinvoke: only the coloured outline changes, not the normal photo placement. Restore zero afterwards. Existing personal values remain intact; older stable builds ignore these comment directives.
- [ ] Enable **Experimental features → Automatically detect Lightroom view**. Invoke in single, side-by-side and stacked views; menu offers the inferred view’s panes. Change pane and reinvoke; its preference persists separately for each orientation/module. No clear label pair means single view. Turning the experiment off restores the saved manual menu selection.
- [ ] With automatic view detection enabled, calibrate a region successfully: manual placement still uses that region. Cancel calibration: prior mode/region retained. With the experiment off, check ordinary Full/split placement and repeat toggles.
- [ ] Rapidly toggle/cancel during AX collection; change modules; minimise/restore; move the window. No late overlay or orphan coloured border. Permission/read failure is reported rather than classified as single view.

Save only text diagnostics; no screenshots or photograph files are automatically written. Geometry offsets remain a preview experiment, not an AX replacement for capture placement.
