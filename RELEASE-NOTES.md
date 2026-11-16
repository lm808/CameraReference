# Camera Reference 1.0.32

Accessibility mode now has one **Update overlay with LrC view** option, default on. An open overlay follows photo selection, view, pane and panel changes; with that option off, those changes dismiss it. Confirmed Library Grid selection and module changes dismiss. Native Grid selection-mark reliability remains to be verified. An off overlay never reopens automatically. Failed AX placement retains the current overlay.

Screenshot backup modes retain their earlier behaviour: optional AX view inference updates menus, background checks invalidate cache only, and explicit menu view/pane selection dismisses. The update option appears only for Accessibility; the two AX screenshot options appear only for Screenshot.

Detection controls now live in Settings. Choose Accessibility or Screenshot; screenshot mode has independent AX view detection and AX-assisted placement options. Manual placement takes precedence. View menus use Loupe View and Reference View names.

Calibration instructions wrap and explain optional Screen Recording for snapping. Capture permission errors are clearer. With automatic diagnostic saving enabled, placement failures are saved before the calibration dialog and retained separately from later successes.

AX-assisted screenshot placement adds a raw-panel top boundary check, limited tolerance for bottom status labels, and a 50/50 split only inside a validated outer area when divider detection fails. These candidate fixes need native testing.

AX-only placement geometry and the original screenshot detector are unchanged. Pure screenshot failures associated with Library status text remain under investigation. Off-screen capture instability is not claimed fixed.

Merged into main at the user’s request. No DMG packaged.

Same-version usability update: photo selection follows the AX update option. Enabled refreshes the existing overlay to the selected JPEG at Fit; disabled dismisses. Failed refresh retains the prior photo. Screenshot and manual behaviour are unchanged.
