# Camera Reference 1.0 alpha — acceptance tests

Quit the old app, open the new build or installed copy, and confirm **1.0 alpha** in its menu. Bridge **0.5.0** is unchanged. Keep your working `sideSearchPercent = 30`. `[x]` or `[x ]` means pass; add a brief note for failures.

## Window behaviour (priority)

- [ ] Show an overlay; move Lightroom partly beyond each screen edge and back. The overlay follows and remains aligned without being dismissed.
- [ ] Enter Mission Control and App Exposé. No separate overlay over thumbnails; exit to the same Lightroom window and the overlay returns aligned without another shortcut.
- [ ] Repeat with another app in front. Other windows cover the overlay normally; returning to Lightroom restores its normal ordering.
- [ ] Minimise/restore Lightroom and switch Spaces away/back. An unchanged host restores; closing Lightroom, changing photo while suspended, or resizing must not restore stale content.
- [ ] Repeat relevant movement/overview checks with fullscreen Lightroom and a floating display open. The floating display remains independent.

## Installation and settings

- [ ] Install the app using the DMG's Applications shortcut. If moving the bridge, use its installer then Add in Lightroom Plug-in Manager and disable the old entry. Confirm heartbeat and ExifTool availability.
- [ ] Existing GUI settings, shortcuts and calibration survive. Edit config file opens `~/Library/Application Support/Camera Reference/config.conf`; old detection.conf remains a backup and your values are preserved.
- [ ] If config.conf already exists, it wins over detection.conf. An invalid edit reports an error and retains the last valid in-memory settings.

## Brief regression check

- [ ] Full and all four split panes still align for portrait/landscape at Fit. Leave one visible through several background checks.
- [ ] Repeated overlay toggles on the same photo report RAM/placement reuse. Change an internal Lightroom panel and wait for the configured check interval: placement refreshes.
- [ ] Manual calibration disables auto. Clear region preserves the current auto/manual preference. Floating display size, hover title bar, dragging at Fit and Cmd-scroll still work.

For failure, copy **Developer tools → Bridge diagnostics** before invoking again. Record the action, layout/pane and whether the overlay returned on its own. A screenshot with the host unchanged helps distinguish wrong placement from incorrect visibility. Automated evidence and historical results are in docs/VALIDATION.md.
