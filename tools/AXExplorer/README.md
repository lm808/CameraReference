# AX Explorer 1.0.0

Standalone, read-only Lightroom Accessibility investigation. It does not link CameraReference app code, capture the screen, activate Lightroom, change settings or perform AX actions. The app is not rebuilt. No Screen Recording permission is needed.

## Start

Double-click the staged `release/AXExplorer/Explore.command` (opens Terminal), or run `release/AXExplorer/AXExplorer` from Terminal. Type `permission` if access has not been granted, follow System Settings, then `refresh`. macOS may attribute permission to Terminal or the executable. Do not remove existing CameraReference permissions. If access remains unavailable, restart the explorer. No automatic permission prompt on startup.

## First toolbar comparison

1. Set Library Loupe with toolbar shown. Run `refresh`, then `clear` and `note Library toolbar shown`.
2. Run `node main`, then `scan main`. Save with `save library-toolbar-shown`.
3. If broader exploration is needed, `windows` lists panel roots. Identify branches by their role/frame and inspect with `node N12` (example ID only). Use `skip N12` only after confirming that branch is a sidebar. Skip removes descendants from scans, not from explicit inspection commands.
4. `scan` explores the application/windows with those skips. `limits 2000 10 8` increases limits without recompiling. Every report states scan limits reached, skipped/depth-limited nodes and queued unexplored IDs. Absence in a partial scan does not prove absence in AX.
5. Hide only the toolbar. Run `clear`, `note Library toolbar hidden`, `node main`, `scan main`, and `save library-toolbar-hidden`. Ask the agent to compare reports. Use `refresh` if Lightroom restarted or references became invalid; it resets IDs and skips.

Reports are saved only on `save`, with unique filenames in `~/Library/Application Support/CameraReference/Diagnostics/AXExplorer/`. They accumulate until you delete them; they do not overwrite the app's `latest.txt`. No screenshot or photo is saved. Reports include identifiers, geometry, roles, attribute names, section dictionary paths, your notes and error codes; titles/descriptions/control values are omitted. Review before sharing.

## Commands

`help` lists all commands. `children N`, `sections N`, `node N`, `scan N`, `skip N`, `unskip N`, `skips`, `windows`, `refresh`, `limits COUNT DEPTH SEC`, `clear`, `note TEXT`, `save LABEL`, `quit`.

IDs and recorded routes describe this session only. Do not use child indices as stable production selectors. Read errors can mean stale elements; repeat after refresh. AXSections dictionaries are traversed for element references, not printed wholesale. Scan is breadth-first, sections before children, with a 30 ms timeout per AX message, a configurable scan deadline and node/depth limits. Individual relationship payloads are bounded to 2,000 values/depth six; registry to 20,000 IDs. Time ceilings are best effort (an in-flight AX message may finish after the deadline).

## Build and validation

From the candidate worktree: `bash scripts/build-ax-explorer.sh`. It builds/stages only this tool under ignored build/release folders; no main app build, installation or launch. `release/AXExplorer/AXExplorer --self-test` checks argument validation and safe filenames without live AX calls. Native permission/traversal acceptance is performed by the user.
