# Camera Reference Testing 1.0.18

Candidate only: run `release/CameraReference Testing.app` in the AX investigation worktree. Bridge remains 0.5.3. Stable main/release remains 1.0.15. Quit one app before running the other; settings are shared.

Developer tools now groups capture/bridge actions and provides one Diagnostics window, including Refresh AX and Copy all. Optional **Show AX placement preview** adds click-through green/purple borders after normal placement. Both split panes are drawn; layout is inferred from visible label geometry independently of the production layout menu. No clear pair means single view. Information-overlay rectangles and session-specific IDs are not used.

The estimate uses visible surrounding panels, window-edge insets for hidden panels, and a nominal midpoint constrained into the central label gap. It is deliberately uncorrected for toolbar/margin differences. It never supplies placement to the current detector.

Optional **Copy diagnostics after invocation** replaces the clipboard with reports as invocation status updates, then with the completed AX report. Both options default off. Accessibility inspection does not capture screenshots; existing Screen Recording features are unchanged. No detection-backend switch, DMG, install or push.

1.0.18 explicitly orders the diagnostic border panels onscreen and reports their actual frames/visibility. Please verify that outlines now appear; live confirmation is pending.

The preview host check now converts AX top-left coordinates to AppKit before comparison. This fixes the reported “host changed or does not match overlay host” rejection for an unchanged window.
