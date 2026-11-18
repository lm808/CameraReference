# View-menu presentation check — 1.1.3, build 59

Quit the previous testing app before opening the updated one. Main remains untouched. [Completed stage 3 annotations](docs/migration/STAGE-3-ACCEPTANCE.md) are preserved separately.

- [ ] **Automatic view detection:** root shows the current view/pane and correct icon, without a checkmark. Loupe has no submenu; Left/Right and Top/Bottom each offer only their two panes, with the selected pane checked.
- [ ] **Screenshot without AX view detection:** root shows the selected view/pane; its submenu always offers all five choices, including when Loupe is selected.
- [ ] **Selection behaviour unchanged:** with an overlay on, AX pane selection updates it when “Update overlay with LrC view” is on, or dismisses it when off. Manual screenshot view/pane selection dismisses. With an overlay off, selecting a choice leaves it off.

This update changes menu presentation only. Automated checks do not replace these native checks.
