# AX Explorer 1.0.6

Standalone, read-only Lightroom Accessibility investigation. It does not link CameraReference app code, capture the screen, activate Lightroom, change settings or perform AX actions. The app is not rebuilt. No Screen Recording permission is needed.

## Start

Double-click the staged `build/AXExplorer/Explore.command` (opens Terminal), or run `build/AXExplorer/AXExplorer` from Terminal. Type `permission` if access has not been granted, follow System Settings, then `refresh`. macOS may attribute permission to Terminal or the executable. Do not remove existing CameraReference permissions. If access remains unavailable, restart the explorer. No automatic permission prompt on startup.

## Observe the failed title-bar ordering (overlay ON)

`titlebar-order-after 10` waits ten seconds, then observes for fifteen seconds, approximately every 0.2s. It never creates/reorders windows, activates apps, or changes placement. It follows the main window's named close and zoom buttons, requires their shared AXGroup parent in confirmed full screen, and matches that group's exact reported bounds to Lightroom CG windows. Zero or multiple matches are inconclusive. It logs the on-screen front-to-back list and reference-window relationships, opacity, level and overlap. Unlike the earlier all-window snapshot, this list has documented front-to-back ordering. Reads are sequential, not atomic; per-sample timestamps and focus/deadline status expose transitions.

For the focused test, leave the existing testing app running with the overlay **on**, float and AX preview **off**, and Lightroom in macOS full screen with its top panel hidden. Restart the explorer to load 1.0.6 (not the main app). Run:

```text
refresh
clear
note Overlay on title-bar ordering failure
titlebar-order-after 10
```

Immediately switch to Lightroom and start the app's existing **Developer tools → Record window ordering (5-second delay)…** command. Close the menu and return to Lightroom. Hold the native title bar revealed for about ten seconds, move the pointer away for three seconds, then reveal it again for ten seconds. Wait thirty seconds from the explorer command before returning to Terminal. Save:

```text
save fullscreen-titlebar-order
```

Tell the agent that both reports are saved and whether the title bar remained covered. The explorer records actual ordering and semantic identity; the app recorder records attempted actions. Comparing their wall-clock timestamps can distinguish missed identification, an ineffective call, and a later reversal (within sampling resolution). No result yet proves which process causes a reversal; window-group behaviour and cross-application ordering remain hypotheses. This command reads public AX/CG metadata only and requires no Screen Recording permission.

## Full-screen title-bar investigation

`titlebar-after 10` waits ten seconds, verifies Lightroom is frontmost, then reads fresh main/window references, named close/minimize/zoom/full-screen/title/proxy elements and their parent/window/top-level links. It records roles, subroles, identifiers, available attribute names, frames and errors, plus Lightroom-only CG metadata before/after. It does not infer a title bar from shape, open menus, press controls, request Screen Recording, or read titles/control values. CG IDs and AX node IDs are distinct; matching is deliberately left for analysis.

Run the testing app normally if desired, but turn its overlay and float **off** for this probe so they cannot obscure the title bar. Set Lightroom to macOS full screen, with its top panel hidden. Then in this explorer:

```text
refresh
clear
limits 200 4 8
note Full screen title bar hidden
titlebar-after 10
```

Return to Lightroom within ten seconds. Keep the pointer away from the screen top and wait **20 seconds from issuing the command** before returning to Terminal. Then:

```text
note Full screen title bar revealed
titlebar-after 10
```

Return to Lightroom, move to the screen top and keep the native title bar revealed for the full 20 seconds. Do not click its traffic-light buttons or open a menu. Return to Terminal and save both readings:

```text
save fullscreen-titlebar-controls-pair
```

If either read reports skipped, partial, a time/element limit, or focus changed, retain the report so we can assess it; do not treat missing evidence as absence. This is a bounded targeted traversal, not a full application scan. Depth is capped at four; `limits` controls node/time budgets. The main app, its build/version and placement are untouched.

## Delayed toolbar reading

Use `toolbar-after 10` to give yourself ten seconds to switch to Lightroom. Leave View closed and Lightroom active. The explorer does not activate any application: it waits, verifies Lightroom is frontmost, then reads. If Lightroom is not active it skips the read and reports unknown. Immediate and delayed readings report focus before and after; missing menus also mean unknown. Delay can be 1–60 seconds, default ten; `toolbar-after 10 MENU-TITLE` supports localized menu titles. Ctrl-C exits the explorer if you need to cancel the wait.

For the comparison: `refresh`, `note Develop toolbar shown`, `toolbar-after 10`; switch to Lightroom before the delay ends. Wait a few seconds beyond the delay before returning to Terminal. Repeat with `note Develop toolbar hidden` and `toolbar-after 10`, returning to Lightroom and pressing T before the reading. Save both with `save develop-toolbar-menu-delayed-pair`. Ensure Lightroom's normal menu headings have recovered first; if they are still missing, the result is inconclusive. No need to open View to prime it.

## Toolbar evidence and immediate inspection

Prefer the delayed comparison above so Lightroom remains frontmost during the read. `toolbar` is an immediate diagnostic command; a focus/menu failure is unknown, not a hidden toolbar. Neither command opens View or selects an item.

The command reports candidate title, shortcut/modifiers, checkmark, enabled state, identifier, errors and traversal limits. Hide Toolbar suggests visible; Show Toolbar suggests hidden. Enabled state alone does not indicate visibility; absent/multiple candidates and unfamiliar titles remain inconclusive. Shown/hidden title pairs were verified in the sampled Library and Develop sessions; freshness, localization and other versions remain limitations. See [consolidated findings](../../docs/AX-ASSISTANCE.md).

Default menu title is English `View`; `toolbar MENU-TITLE` selects a localized menu. A localized toolbar item can be found by its unmodified T shortcut, but its title is not automatically translated. Generic tree scans still omit titles. This command reads menu titles only (not photo names or control values), and logs only candidates or top-level menu names if View cannot be found.

## Tree comparison

1. Set Library Loupe with toolbar shown. Run `refresh`, then `clear` and `note Library toolbar shown`.
2. Run `node main`, then `scan main`. Save with `save library-toolbar-shown`.
3. If broader exploration is needed, `windows` lists panel roots. Identify branches by their role/frame and inspect with `node N12` (example ID only). Use `skip N12` only after confirming that branch is a sidebar. Skip removes descendants from scans, not from explicit inspection commands.
4. `scan` explores the application/windows with those skips. `limits 2000 10 8` increases limits without recompiling. Every report states scan limits reached, skipped/depth-limited nodes and queued unexplored IDs. Absence in a partial scan does not prove absence in AX.
5. Hide only the toolbar. Run `clear`, `note Library toolbar hidden`, `node main`, `scan main`, and `save library-toolbar-hidden`. Ask the agent to compare reports. Use `refresh` if Lightroom restarted or references became invalid; it resets IDs and skips.

Reports are saved only on `save`, with unique filenames in the development worktree’s ignored `investigations/ax-reports/` folder. They accumulate until you delete them; they do not overwrite the app's `latest.txt`. No screenshot or photo is saved. Reports include identifiers, geometry, roles, attribute names, section dictionary paths, your notes and error codes; titles/descriptions/control values are omitted except the explicit toolbar menu command described above. Review before sharing.

## Commands

`help` lists all commands, including `toolbar [MENU-TITLE]`. `children N`, `sections N`, `node N`, `scan N`, `skip N`, `unskip N`, `skips`, `windows`, `refresh`, `limits COUNT DEPTH SEC`, `clear`, `note TEXT`, `save LABEL`, `quit`.

IDs and recorded routes describe this session only. Do not use child indices as stable production selectors. Read errors can mean stale elements; repeat after refresh. AXSections dictionaries are traversed for element references, not printed wholesale. Scan is breadth-first, sections before children, with a 30 ms timeout per AX message, a configurable scan deadline and node/depth limits. Individual relationship payloads are bounded to 2,000 values/depth six; registry to 20,000 IDs. Time ceilings are best effort (an in-flight AX message may finish after the deadline).

## Build and validation

From the development worktree: `bash scripts/build-ax-explorer.sh`. It builds/stages only this tool under ignored build/AXExplorer only (never release/); no main app build, installation or launch. `build/AXExplorer/AXExplorer --self-test` checks argument validation and safe filenames without live AX calls. Native permission/traversal acceptance is performed by the user.

Report location is derived from the executable location, not the shell working directory. The build/AXExplorer location resolves to the worktree. A copy outside those folders saves in ax-reports beside that executable. Original probes are retained in investigations/ax-reports; their findings and uncertain cases are indexed in docs/AX-ASSISTANCE.md. Keep raw evidence out of Git. The main app’s Diagnostics/latest.txt remains runtime state in Application Support.
