# Camera Reference Testing 1.0.21 — live AX and complete reports

Use this worktree’s staged `release/CameraReference Testing.app`; quit stable first. Main stays 1.0.15; bridge stays 0.5.3. Native acceptance pending.

- [ ] Enable **Experimental features → Automatically detect Lightroom view**. Without invoking an overlay, switch single/side-by-side/stacked views while Lightroom is active. Within about two seconds (plus AX read time), reopen the menu: only relevant pane choices appear. Leave the layout unchanged: no recurring menu changes.
- [ ] Choose right/bottom panes, change layouts and return: the choices persist independently. Disable automatic view detection: the saved explicit menu selection returns.
- [ ] Leave an overlay visible while changing Lightroom layout: it stays where it was. Dismiss/reinvoke to use the newly inferred layout. Existing detector still determines actual bounds.
- [ ] Set screenshot background interval to zero temporarily: live AX view detection still operates. Restore your previous value. Switch apps: polling pauses; return to Lightroom: it resumes. Missing permission/read failure retains previous inference without prompting in the background.
- [ ] Enable **Save diagnostics after invocation** and invoke. Wait for collection to finish, then ask the agent to read `~/Library/Application Support/CameraReference/Diagnostics/latest.txt`. AX toolbar structure, controls/parents and image inspection now have fresh data without Refresh AX. Check with preview on and off, and floating display.
- [ ] Rapidly invoke/dismiss/reinvoke or change modules during collection. Old collections must not overwrite the newer invocation’s report. Check a failed invocation also saves fresh diagnostics. Disabled saving produces no automatic deep scan or file writes.
- [ ] With both experiments off, confirm ordinary screenshot Full/split placement, manual calibration and repeated toggles remain usable.

For the toolbar investigation: Library Loupe, toolbar shown, invoke and wait for the saved report; tell the agent to check before hiding the toolbar and repeating. Manual Refresh AX remains optional. All geometry adjustments can stay zero.
