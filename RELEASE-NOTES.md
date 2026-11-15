# Camera Reference 1.0.30 — candidate

Detection controls now live in Settings. Choose Accessibility or Screenshot; screenshot mode has independent AX view detection and AX-assisted placement options. Manual placement takes precedence. View menus use Loupe View and Reference View names.

Calibration instructions wrap and explain optional Screen Recording for snapping. Capture permission errors are clearer. With automatic diagnostic saving enabled, placement failures are saved before the calibration dialog and retained separately from later successes.

AX-assisted screenshot placement adds a raw-panel top boundary check, limited tolerance for bottom status labels, and a 50/50 split only inside a validated outer area when divider detection fails. These candidate fixes need native testing.

AX-only placement geometry and the original screenshot detector are unchanged. Pure screenshot failures associated with Library status text remain under investigation. Off-screen capture instability is not claimed fixed.

Main's accepted 1.0.28 app is unchanged. No DMG packaged.
