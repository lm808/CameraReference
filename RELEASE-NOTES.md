# Camera Reference Testing 1.0.19

Candidate in the AX investigation worktree: `release/CameraReference Testing.app`. Bridge stays 0.5.3. Main/daily-use 1.0.15 is unchanged. Quit one app before using the other; settings are shared.

Developer tools now groups the AX preview and new automatic-view toggle under **Experimental features**. Automatic view detection samples visible AX label geometry at each automatic overlay invocation, selects single/side-by-side/stacked layout and remembers the preferred pane per orientation/module. No clear pair means single view; read failures remain explicit failures. It defaults off. The existing capture detector still calculates actual placement.

AX preview geometry has zero-default edge/inset adjustments, with observed suggestions in trailing config comments. Keep the `# AX:` prefix when editing: it lets the testing app read the setting while older stable apps ignore it. Missing settings are appended without replacing existing preferences. Toolbar state is explicitly annotated as unknown/shown/hidden until direct detection is established.

Diagnostics → Refresh AX now includes bounded traversal of all exposed windows’ child controls, frame coordinates and parent links. No control text or values are read. **Save diagnostics after invocation** replaces automatic clipboard copying and atomically replaces `~/Library/Application Support/CameraReference/Diagnostics/latest.txt`; Refresh AX also updates it when enabled. The former automatic-copy preference carries forward to saving; manual Copy all remains available. No image is saved.

See TESTING.md for the short toolbar investigation and acceptance checks. No detection-backend switch, DMG, installation or push. Native acceptance remains pending.
