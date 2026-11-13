# AX Explorer 1.0.4

Standalone, read-only Lightroom Accessibility investigation. It does not link CameraReference app code, capture the screen, activate Lightroom, change settings or perform AX actions. The app is not rebuilt. No Screen Recording permission is needed.

## Start

Double-click the staged `build/AXExplorer/Explore.command` (opens Terminal), or run `build/AXExplorer/AXExplorer` from Terminal. Type `permission` if access has not been granted, follow System Settings, then `refresh`. macOS may attribute permission to Terminal or the executable. Do not remove existing CameraReference permissions. If access remains unavailable, restart the explorer. No automatic permission prompt on startup.

## Delayed reading (1.0.2)

Use `toolbar-after 10` to give yourself ten seconds to switch to Lightroom. Leave View closed and Lightroom active. The explorer does not activate any application: it waits, verifies Lightroom is frontmost, then reads. If Lightroom is not active it skips the read and reports unknown. Immediate and delayed readings report focus before and after; missing menus also mean unknown. Delay can be 1–60 seconds, default ten; `toolbar-after 10 MENU-TITLE` supports localized menu titles. Ctrl-C exits the explorer if you need to cancel the wait.

For the comparison: `refresh`, `note Develop toolbar shown`, `toolbar-after 10`; switch to Lightroom before the delay ends. Wait a few seconds beyond the delay before returning to Terminal. Repeat with `note Develop toolbar hidden` and `toolbar-after 10`, returning to Lightroom and pressing T before the reading. Save both with `save develop-toolbar-menu-delayed-pair`. Ensure Lightroom's normal menu headings have recovered first; if they are still missing, the result is inconclusive. No need to open View to prime it.

## Toolbar menu state (1.0.1)

Quit the previous explorer and reopen the staged Explore.command. After `refresh`, run `toolbar` with Lightroom's toolbar shown. It reads the View menu without opening it or selecting anything. Return to Lightroom, press T, return to the explorer and run `toolbar` again. Do not open View between readings. Use `note toolbar shown` / `note toolbar hidden` to label each reading, then `save develop-toolbar-menu-pair` (or Library).

The command reports candidate title, shortcut/modifiers, checkmark, enabled state, identifier, errors and traversal limits. Hide Toolbar suggests visible; Show Toolbar suggests hidden. Enabled state alone does not indicate visibility; absent/multiple candidates and unfamiliar titles remain inconclusive. Titles are an experimental signal until freshness is verified. Run in both Library and Develop.

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

From the candidate worktree: `bash scripts/build-ax-explorer.sh`. It builds/stages only this tool under ignored build/release folders; no main app build, installation or launch. `build/AXExplorer/AXExplorer --self-test` checks argument validation and safe filenames without live AX calls. Native permission/traversal acceptance is performed by the user.

Report location is derived from the executable location, not the shell working directory. The build/AXExplorer location resolves to the worktree. A copy outside those folders saves in ax-reports beside that executable. Existing reports were moved out of Application Support; reopen Explorer 1.0.4 before saving more reports. The main app’s Diagnostics/latest.txt remains runtime state in Application Support.
