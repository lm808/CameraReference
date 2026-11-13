# Camera Reference Testing 1.0.20

Diagnostic-only update in the AX investigation worktree. Main remains 1.0.15; bridge stays 0.5.3. Run the staged `release/CameraReference Testing.app`, quitting the stable app first.

Diagnostics → Refresh AX now includes **AX toolbar structure**: supported attribute names, actual AXParent geometry, AXContents/AXVisibleChildren relationships and explicit visibility-read statuses. A bounded shallow probe prioritises the main window and its controls before sidebar/catalogue descendants consume the budget. It does not assume checkbox absence proves toolbar visibility, or claim that a toolbar boundary has been found.

Screenshot detector, placement, caching, personal config and existing experimental view behaviour are unchanged. Live view polling and automatic deep diagnostics are not part of this focused investigation update. Native evidence is still required; see TESTING.md.
