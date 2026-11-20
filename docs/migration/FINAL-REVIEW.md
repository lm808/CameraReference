# Migration consolidation review — stage 9

2026-11-20 · candidate 1.1.9 build 68 · accepted main remains a568c6e / 1.0.32.

## What is now implemented

Concrete state owners exist for photo requests/cache, Lightroom monitoring, overlay and floating presentation, menus, settings interpretation and diagnostics. Pure update/dismiss/retain/suspend decisions are in OverlayBehaviourPolicy. Manual, Accessibility, original screenshot and assisted screenshot calculations have separate adapters. Coordinators preserve the original order of evidence checks and effects.

Stage 9 removes 42 temporary storage aliases, with direct owner-qualified access instead. Twenty-four action methods move to ViewCoordinator, CalibrationCoordinator, SettingsActions and ExportCoordinator. main.swift contains composition, native startup/shutdown/hotkeys, invocation entry points, contextual region preferences and shared operation state. The current file-by-file map is in ../ARCHITECTURE.md.

## Explicit retained boundaries

Coordinator files are AppDelegate extensions, not independent service objects. This retains NSMenu/NSWindow selector targets, weak callback identity and existing cancellation order. Request-handle and panel/view aliases remain for local optional bindings; diagnostic/menu adapters remain for app-facing actions. They do not create duplicate state.

Placement memory, screen-inspection task/ID/timeout, calibration transaction and invocation-view probe identity remain on composition. Foreground placement, capture preview and calibration deliberately share cancellation semantics. Separating these stores or replacing generations with one state machine would be another behaviour-sensitive change, not necessary for this consolidation. The original target's separate AppCoordinator/CalibrationCoordinator objects are therefore implemented as a shared composition surface with focused coordinator files, rather than new back-referencing objects.

## Routing and policy audit

| Path | Placement / view source | Existing behaviour retained |
|---|---|---|
| Manual | Saved region/calibration wins before automatic backend | No automatic AX live following; accepted selection turns auto off; cancellation preserves settings |
| Accessibility, update enabled | Fresh AX geometry and mandatory AX view inference | View/pane/panel geometry updates retain photo/zoom; photo changes refresh at Fit; no automatic pixel capture/fallback |
| Accessibility, update disabled | Same placement algorithm | Qualified view/pane/panel/photo changes dismiss |
| Original screenshot, inference off | Saved view selection; original pixel bounds/divider | Explicit pane selection dismisses; background checks invalidate future placement only |
| Original screenshot, inference on | AX supplies view; original pixel placement | Inference changes menus without adding AX live placement policy |
| Assisted screenshot, inference off/on | Raw hints guide independent pixel search; view selection remains independent | Calibrated AX offsets stay out; existing guarded capture/background checks retained |
| Floating window | Existing manual/backend initial sizing and independent photo snapshot | Refresh/zoom/title, export identity, hover and existing ordering unchanged |

Positive qualified Grid evidence and confirmed module changes keep their existing scope. Unknown heartbeat/view/host evidence is not promoted to a confirmed change. Off overlays never open from monitoring. Existing generation/token/module/selection/panel/host checks still reject late results.

## Equivalence and performance review

Against stage 8 commit 25e4a2f, all 85 coordinator method bodies match after reversing direct owner qualification. Policy, concrete owners, timer scheduling, worker queues, placement algorithms, image extraction and config defaults are unchanged by stage 9. The frozen diagnostic formatter remains unchanged; only local aliases were added so its old names read current owners in tests.

No new AX read, capture, extraction, disk write, dispatch queue or prerequisite before showing the overlay. Bridge polling remains 50 ms with a five-second deadline; maintenance 0.2 seconds; eligible AX view polling two seconds; display debounce 0.6 seconds; screenshot checks use existing config. Source equivalence is not a native latency measurement. Matched baseline/candidate timings remain pending under BASELINE.md; no speed-up claim.

## Validation and acceptance status

Core/source/export/navigation/cache tests, Lua bridge stand-ins, detection/viewport/reset/preview/capture/split/config-editor tests and eleven migration groups pass. The config-editor temporary atomic-save check required rerunning outside the filesystem restriction, as in earlier stages. Optional external screenshot-crop fixtures were not supplied. No live AX/capture or GUI automation was performed.

Stages 2–8 user responses remain preserved in their acceptance files. Stage 9 final native acceptance is pending in ../../TESTING.md. All six deferred bugs/policy items remain in ../BACKLOG.md, including both stacking issues, preview constraints, screenshot view-change policy, calibration wording and floating hover text. No new issue was identified by this consolidation review. Do not merge, rebuild main or declare the migrated candidate accepted solely from automated checks.
