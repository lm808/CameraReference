# Preserve the structure when changing behaviour

This contract applies equally to human developers and coding agents. The migration was intended to make behaviour changes local and reviewable, not merely distribute a large implementation across more files. Read this alongside [ARCHITECTURE.md](ARCHITECTURE.md), [METHODS.md](METHODS.md) and [AGENTS.md](../AGENTS.md) before changing a logical path.

## Responsibilities are boundaries

| Responsibility | Correct home | Must not acquire |
|---|---|---|
| Observe Lightroom | Layout/AX readers, LightroomMonitor | Overlay mutations, config writes, guesses disguised as confirmed evidence |
| Decide what an observation means for the overlay | OverlayBehaviourPolicy | Timers, AX/capture calls, preferences or NSWindow operations |
| Qualify evidence and execute the decision | MonitoringCoordinator/ViewCoordinator | Copied placement algorithms or a second source of policy |
| Calculate placement | Specific AX or screenshot implementation | Permission prompts, menu updates, overlay lifecycle decisions |
| Route placement | PlacementCoordinator | Backend-specific mathematics or implicit fallback between AX and screenshots |
| Display the result | Overlay/Floating owners and PresentationCoordinator | AX calibration, pixel detection, selection inference |
| Collect a region selection | CalibrationController/CalibrationView | Saving a manual region, disabling automatic placement, calculating offsets |
| Interpret manual selection | CalibrationCoordinator | Guided offset calculations |
| Interpret calibration measurements | AXCalibrationCoordinator + pure AXCalibrationPlan | Manual-region/preferences changes or modifications to production placement formulas |
| Record shortcuts | ShortcutRecorder | View switching or behaviour decisions |
| Apply shortcut settings / dispatch view actions | ShortcutSettings/ViewShortcuts | Duplicate selection policy; dispatch through the same action as the menu |
| Persist configuration | DetectionConfig/ConfigEditorDocument, called by the workflow | Silent default replacement, overwritten external edits, diagnostic feedback into placement |
| Report evidence | Diagnostics | Decisions that change production placement or displayed content |

The same selection UI is deliberately reused by two workflows. It returns a rectangle or cancellation. Its caller decides whether to save a manual region or collect a calibration measurement. A custom instruction string is presentation input, not a workflow mode flag.

## Honest inputs, explicit results

A parameter must mean what its name says. Never pass “Screenshot mode” into a flag named “AX view detection” just because it produces the wanted branch. Model the actual policy input; update focused tests. Photo-selection dismissal and AX view/panel inference are separate capabilities.

Unknown evidence is not false, a confirmed change, a hidden toolbar or a closed window. Preserve existing identity, epoch, module, generation and cancellation guards. Coordinate types/comments must distinguish capture pixels, top-left global points and AppKit points. Image Fit, the pan boundary, overlay frame and presentation clipping are different quantities.

Do not reuse an unrelated flag to block a new operation. Give the workflow its own state and cancellation token. Keep one owner for each state; do not create a mirrored cache or visibility field to avoid a dependency.

## Extend an existing seam before adding abstractions

A new UI action should call the existing coordinator action. A new event should produce evidence for the behaviour policy. A detector improvement belongs in that detector. A new RAW type belongs in image extraction. Share neutral utilities and typed results, not backend assumptions.

Coordinators still share AppDelegate composition and some operation state. This retained compromise is documented; it is not permission to access every state owner from every file. Do not add protocols, a general event bus, new timers or a cross-mode state machine merely for symmetry. If a clean change genuinely requires a new boundary, explain it and preserve behaviour with focused checks.

## Review each change

1. Name the user-visible change and the unaffected paths before editing.
2. Identify the policy, calculation, observation, UI and persistence owners involved. If a rule appears in multiple places, decide who owns it rather than copying it.
3. Check cold invocation, cache reuse and background/live paths. A local formula may have several callers. Keep coordinate transforms and stale-result guards explicit.
4. Test the changed policy as a truth table or pure calculation where possible; use coordinator checks for dispatch and cancellation. Test neighbouring modes for unintended changes.
5. Review the diff for dishonest flags, extra mode conditionals, duplicated calculations, new side effects in pure functions, or new reads/writes in UI widgets.
6. Update the current architecture/method docs when responsibilities or behaviour change. Preserve user test annotations. Automated tests do not establish native acceptance.

Keep independent work in separate commits. Calibration, screenshot corrections and unrelated fixes should be individually reviewable. Never merge a candidate into main before user acceptance. Do not combine a structural cleanup with an unrequested policy change.

## Accepted audit and known seams

See [BOUNDARY-AUDIT.md](BOUNDARY-AUDIT.md) for the 1.1.15 review and its two open findings. Prefer raw observation results independent of corrected-placement success. Pass typed failure/permission reasons across layers rather than testing diagnostic sentences. Keep shared Fit settings explicitly distinguished from backend-specific AX corrections. Overlay input may emit an activation request; the presentation coordinator activates the host and the existing lifecycle owns ordering.
