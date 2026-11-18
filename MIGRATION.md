# Structure migration — working checklist

Branch: `codex/structure-migration` · worktree: `worktrees/structure-migration`
Baseline: main at `a568c6e`, application 1.0.32. Main and its staged daily-use app remain untouched. This branch starts with planning only; no migrated executable is available yet.

## Contract and priority

Preserve all current user-facing behaviour: options/defaults, menus/text, settings keys, calibration, permissions, placement calculations, fallback decisions, ordering, cancellation, cache reuse and responsiveness. Prioritise automatic Accessibility placement with **Update overlay with LrC view** enabled, the current fresh-install default. Also preserve option-off, manual, floating and screenshot behaviour. Feature freeze: no edge-case fixes, optimisations or added features hidden in refactor commits.

User acceptance will focus on the migrated app. Existing unresolved edge cases are recorded, not prerequisites for starting migration. Any issue discovered goes in [findings](docs/migration/FINDINGS.md), with evidence and a proposed separate decision. A regression introduced by migration must be corrected before progressing.

Target ownership and the mapping from existing symbols are in [TARGET-STRUCTURE.md](docs/migration/TARGET-STRUCTURE.md). These are proposed components, not claims about code already moved. Current implementation remains documented in docs/ARCHITECTURE.md.

## Stages

- [x] **0 — Baseline and design.** Create separate worktree; inspect routing/timers/state ownership; define component contracts, source-to-target map and risks. Record outstanding issues. No code/build/version changes.
- [ ] **1 — Behaviour and performance harness.** Characterise existing policy and completion guards with focused tests before extraction. Cover fresh/default preferences separately from existing saved settings; normal AX invocation, warm toggle, photo/view/pane/panel updates, option off, module/Grid evidence, suspension and failure retention. Include absent-overlay, unknown evidence and stale completion sequences. Record baseline timings using existing diagnostics during user testing; do not claim automated tests reproduce macOS behaviour.
- [ ] **2 — Diagnostics extraction.** Move report state/formatting, saving and diagnostic-only preview ownership into a concrete component. Preserve automatic post-invocation collection, guards and all current report content. Do not add work before display. Keep production AX observation/placement separate from diagnostic collection even where they share readers.
- [ ] **3 — Settings/menu extraction.** Move menu construction and preference access behind a concrete settings/menu owner. Initially retain selectors forwarding to existing actions. Preserve menu update triggers, per-module/pane keys, defaults/migration and hidden/disabled states. Do not change preferences schema or introduce a second store.
- [ ] **4 — Behaviour decisions.** Consolidate existing action helpers and branches into a tested policy. Initially callers execute the decisions exactly as before. Preserve distinctions between manual, pure AX and both screenshot options; do not make the modes more alike. Preserve timer/handler order and evidence freshness rules.
- [ ] **5 — Placement dispatch.** Introduce manual, AX, original screenshot and assisted screenshot adapters with a common UI-placement result. Delegate to existing calculations, not rewrites. Keep original detector/split scanner untouched, AX offsets out of screenshot routes, manual first and no AX capture fallback. Preserve cache and calibration decisions at the coordinator boundary. Confirm float combined-area sizing remains identical.
- [ ] **6 — Photo request ownership.** Move bridge/load/cancellation and image-cache ownership into a photo pipeline. Preserve tokens, epochs, 50ms response polling, timeout, cancellation order and refresh-once-per-epoch behaviour. Introduce explicit request context by wrapping existing identities first; do not replace all generation schemes at once.
- [ ] **7 — Presentation ownership.** Move overlay panel/lifecycle state into OverlayController and floating state into FloatingDisplayController, retaining ReferenceView and geometry helpers. Separate view/panel geometry updates from photo replacement (preserve zoom versus reset Fit). Preserve export snapshot identity, hover behaviour, suspension, ordering and host following.
- [ ] **8 — Monitoring ownership.** Move observations into LightroomMonitor with explicit outputs and unknown states. Preserve the existing 0.2s tick order, eligible 2s AX poll, configurable screenshot checks, workspace notifications and foreground cancellation. Policy decides consequences; monitors do not manipulate windows. Avoid introducing queued event delivery or new timer cadence.
- [ ] **9 — Consolidation and acceptance.** Remove replaced forwarding paths and redundant state only after coverage. Review component boundaries, all mode combinations, no extra AX/capture/extraction work, timing and source map. Update methods/agent guide/test list to actual implementation. Merge only after user acceptance; do not push/package automatically.

Each stage can take several small commits. Dependency reason: tests first; reporting/menu extraction reduces noise; policy precedes moving its execution; placement and request seams precede presentation; timer extraction comes last to avoid changing execution order while owners are moving. If inspection shows a boundary cannot move safely yet, record the dependency here before changing the sequence.

## Completion gate for every stage

1. Record moved symbols/state and the commit; distinguish mechanical moves from later simplification commits.
2. Run relevant automated checks, including cancellation/late-result sequences when orchestration changes. Review diff for defaults, messages, permissions, scheduling or algorithm changes.
3. For delivered code updates, increment patch per AGENTS.md; build/stage **only** `release/CameraReference Testing.app` in this worktree, verify plist/signature/diff. No DMG. Planning/docs stages do not rebuild or change version.
4. Add a short focused native checklist to TESTING.md, preserving existing annotations. Label automated pass and native acceptance separately. Keep existing known defects distinguishable from migration regressions.
5. Compare equivalent display timings/work counts: cold photo, warm same-photo toggle, new selection and view/panel update. Record bridge/load/placement/total separately. Same host/layout/photo/config/diagnostics state; AX-only must not acquire screenshots. Investigate unexplained repeatable slowdown before accepting, rather than inventing a threshold without a baseline.
6. Ask the user to test a coherent checkpoint, not every file move. Leave main usable. Update this checklist and findings as work progresses; never mark native acceptance from unit tests alone.

## Stage record

| Stage | Status | Evidence / native acceptance |
|---|---|---|
| 0 | Design prepared | Clean baseline a568c6e; source-symbol mapping and existing timer/request flow reviewed. Documentation checks only; no app changes or native testing required. |

The next implementation step is stage 1. Later stages are planned, not started by this document.
