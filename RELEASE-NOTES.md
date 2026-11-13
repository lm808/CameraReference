# Camera Reference Testing 1.0.21

Candidate only; main remains 1.0.15 and bridge 0.5.3. Run this worktree’s staged testing app, not build/.

Opt-in automatic AX view detection now polls every two seconds while Lightroom is active in Library/Develop, independently of screenshot background checking. It updates layout/pane menu choices only on a changed inference, retains the previous view on AX failure, and does not reposition a visible overlay. The first invocation can still initialise inference if no live result exists yet.

With **Save diagnostics after invocation** enabled, fresh window mapping, toolbar structure, child controls and image inspection are collected asynchronously after display and saved to the existing latest.txt file. No manual Refresh AX is required; it remains available. Bounded collection is coalesced and stale invocation/module results are discarded. Existing scan limits still apply and are reported.

Screenshot detector sources, geometry calculations and cache algorithms are unchanged. No personal config changes, installation, launch, DMG or push. Native acceptance remains pending; see TESTING.md.
