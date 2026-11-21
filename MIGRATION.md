# Structure migration — working checklist

**Closure, 2026-11-21:** migration stages and all six deferred fixes are accepted in 1.1.10 / build 69. Documentation cleanup and merge authorised; code/version unchanged. Stage-specific pending statements below are historical. Final evidence is in docs/VALIDATION.md and the preserved 1.1.10 test responses. Matched performance measurements remain uncollected.

Branch: `codex/structure-migration` · worktree: `worktrees/structure-migration`
Baseline: main at `a568c6e`, application 1.0.32. Main and its staged daily-use app remain untouched. Stage 9 delivers candidate 1.1.9; main and its accepted app stay at 1.0.32.

## Contract and priority

Preserve all current user-facing behaviour: options/defaults, menus/text, settings keys, calibration, permissions, placement calculations, fallback decisions, ordering, cancellation, cache reuse and responsiveness. Prioritise automatic Accessibility placement with **Update overlay with LrC view** enabled, the current fresh-install default. Also preserve option-off, manual, floating and screenshot behaviour. Feature freeze: no edge-case fixes, optimisations or added features hidden in refactor commits. Exception explicitly authorised for stage 3: the info-overlay/top-panel classification fix, committed separately as 9ba1bdd.

User acceptance will focus on the migrated app. Existing unresolved edge cases are recorded, not prerequisites for starting migration. Any issue discovered goes in [findings](docs/migration/FINDINGS.md), with evidence and a proposed separate decision. A regression introduced by migration must be corrected before progressing.

Target ownership and the mapping from existing symbols are in [TARGET-STRUCTURE.md](docs/migration/TARGET-STRUCTURE.md). These are proposed components, not claims about code already moved. Current implementation remains documented in docs/ARCHITECTURE.md.

## Stages

- [x] **0 — Baseline and design.** Create separate worktree; inspect routing/timers/state ownership; define component contracts, source-to-target map and risks. Record outstanding issues. No code/build/version changes.
- [x] **1 — Behaviour and performance harness (automated baseline/protocol).** Characterise existing policy and completion guards with focused tests before extraction. Cover fresh/default preferences separately from existing saved settings; normal AX invocation, warm toggle, photo/view/pane/panel updates, option off, module/Grid evidence, suspension and failure retention. Include absent-overlay, unknown evidence and stale completion sequences. Native timing collection remains pending below; do not claim automated tests reproduce macOS behaviour. See [coverage and limitations](docs/migration/BASELINE.md).
- [x] **2 — Diagnostics extraction (user testing complete).** Move report state/formatting, saving and diagnostic-only preview ownership into a concrete component. Preserve automatic post-invocation collection, guards and all current report content. Do not add work before display. Keep production AX observation/placement separate from diagnostic collection even where they share readers.
- [x] **3 — Settings/menu extraction (user testing complete).** Move menu construction and preference access behind a concrete settings/menu owner. Initially retain selectors forwarding to existing actions. Preserve menu update triggers, per-module/pane keys, defaults/migration and hidden/disabled states. Do not change preferences schema or introduce a second store.
- [x] **4 — Behaviour decisions (testing complete; reported issues deferred).** Consolidate existing action helpers and branches into a tested policy. Initially callers execute the decisions exactly as before. Preserve distinctions between manual, pure AX and both screenshot options; do not make the modes more alike. Preserve timer/handler order and evidence freshness rules.
- [x] **5 — Placement dispatch (user testing complete).** Introduce manual, AX, original screenshot and assisted screenshot adapters with a common UI-placement result. Delegate to existing calculations, not rewrites. Keep original detector/split scanner untouched, AX offsets out of screenshot routes, manual first and no AX capture fallback. Preserve cache and calibration decisions at the coordinator boundary. Confirm float combined-area sizing remains identical.
- [x] **6 — Photo request ownership (testing complete; stacking bug logged).** Move bridge/load/cancellation and image-cache ownership into a photo pipeline. Preserve tokens, epochs, 50ms response polling, timeout, cancellation order and refresh-once-per-epoch behaviour. Introduce explicit request context by wrapping existing identities first; do not replace all generation schemes at once.
- [x] **7 — Presentation ownership (user testing complete; hover-text cleanup logged).** Move overlay panel/lifecycle state into OverlayController and floating state into FloatingDisplayController, retaining ReferenceView and geometry helpers. Separate view/panel geometry updates from photo replacement (preserve zoom versus reset Fit). Preserve export snapshot identity, hover behaviour, suspension, ordering and host following.
- [x] **8 — Monitoring ownership (user testing complete).** Move observations into LightroomMonitor with explicit outputs and unknown states. Preserve the existing 0.2s tick order, eligible 2s AX poll, configurable screenshot checks, workspace notifications and foreground cancellation. Policy decides consequences; monitors do not manipulate windows. Avoid introducing queued event delivery or new timer cadence.
- [x] **9 — Consolidation and acceptance (user behaviour testing complete; matched timings outstanding).** Remove replaced forwarding paths and redundant state only after coverage. Review component boundaries, all mode combinations, no extra AX/capture/extraction work, timing and source map. Update methods/agent guide/test list to actual implementation. Merge only after user acceptance; do not push/package automatically.

Each stage can take several small commits. Dependency reason: tests first; reporting/menu extraction reduces noise; policy precedes moving its execution; placement and request seams precede presentation; timer extraction comes last to avoid changing execution order while owners are moving. If inspection shows a boundary cannot move safely yet, record the dependency here before changing the sequence.

## Completion gate for every stage

1. Record moved symbols/state and the commit; distinguish mechanical moves from later simplification commits.
2. Run relevant automated checks, including cancellation/late-result sequences when orchestration changes. Review diff for defaults, messages, permissions, scheduling or algorithm changes.
3. For this migration round, the user specifies 1.1.<stage>, beginning with stage 3 = 1.1.3; build/stage **only** `release/CameraReference Testing.app` in this worktree, verify plist/signature/diff. No DMG. Planning/docs and test-only stages do not rebuild the application or change its version.
4. Add a short focused native checklist to TESTING.md, preserving existing annotations. Label automated pass and native acceptance separately. Keep existing known defects distinguishable from migration regressions.
5. Compare equivalent display timings/work counts: cold photo, warm same-photo toggle, new selection and view/panel update. Record bridge/load/placement/total separately. Same host/layout/photo/config/diagnostics state; AX-only must not acquire screenshots. Investigate unexplained repeatable slowdown before accepting, rather than inventing a threshold without a baseline.
6. Ask the user to test a coherent checkpoint, not every file move. Leave main usable. Update this checklist and findings as work progresses; never mark native acceptance from unit tests alone.

## Stage record

| Stage | Status | Evidence / native acceptance |
|---|---|---|
| 0 | Design prepared | Clean baseline a568c6e; source-symbol mapping and existing timer/request flow reviewed. Documentation checks only; no app changes or native testing required. |
| 1 | Harness/protocol complete | 2026-11-18: new coordinator tests pass; existing automated suites pass (config-editor required an outside-sandbox rerun for temporary atomic save). No production symbols moved, no application build/version change. Native display timings and window acceptance pending. |
| 2 | Candidate 1.0.33 staged | DiagnosticsService and transitional adapters extracted; ten coordination methods checked verbatim. Frozen report-equivalence, save-path and request tests passed. Full existing suites passed with the config-editor temporary-save sandbox rerun. Testing identity/plist/signature verified. User testing complete; original annotations preserved in docs/migration/STAGE-2-ACCEPTANCE.md. Info-overlay issue is pre-existing and separately authorised for stage 3; no main merge. |
| 3 | Candidate 1.1.3 staged | Settings/menu extraction and separate info-overlay fix (9ba1bdd). Core regression and seven migration groups passed; remaining suites passed with config-editor sandbox rerun. Testing plist/signature verified. User testing complete; menu follow-up accepted except Loupe appearance. |

| 4 | Candidate 1.1.4 staged | Pure OverlayBehaviourPolicy extracted; original callers retain guards and execution order. Four original helper bodies checked equivalent. Core/split and seven migration groups passed; config-editor passed outside the temporary-save restriction. Loupe normal appearance corrected; native testing and timings pending. |

| 5 | Candidate 1.1.5 build 64 staged | Twelve coordinator methods extracted; eight exact bodies and four adapter-only substitutions verified. Eight migration groups and existing core regressions passed; plist/signature checked. User marked all four stage 5 checks passed; annotations preserved in STAGE-5-ACCEPTANCE.md. Deferred issues remain. |

| 6 | Candidate 1.1.6 build 65 staged | Pipeline owns request state/transport/cache; immutable load context preserves existing identities. Nine migration groups passed, including real transport timer cases and stale-load guards. User completed all four checks on 2026-11-20; floating-display stacking bug logged. Responses preserved in STAGE-6-ACCEPTANCE.md. |

| 7 | Candidate 1.1.7 build 66 staged | Independent presentation owners and transitional coordinator; fourteen relocated bodies byte-identical. Ten migration groups passed; staged signature/plist checked. User completed all four checks on 2026-11-20; hover-text cleanup logged. Annotations preserved in STAGE-7-ACCEPTANCE.md. |

| 8 | Candidate 1.1.8 build 67 staged | Monitor owns observations, subscriptions and timing; coordinator retains existing policy/guards. Eleven migration groups passed; strict signature/plist checked. User completed all four checks on 2026-11-20 with no new issue annotations; responses preserved in STAGE-8-ACCEPTANCE.md. |

| 9 | Candidate 1.1.9 build 68 staged | Removed 42 storage aliases; grouped 24 action methods; 85 method bodies equivalent after owner qualification. Full regression suites and eleven migration groups passed (config-editor required unrestricted temporary-save retry). Signature/plist checked. Final native acceptance and timings pending. |

- [ ] Collect matched native before/after timing samples using the baseline protocol before accepting migrated performance. No timing samples have been collected by this stage.

Stages 2–8 user testing is complete; responses and exceptions are preserved in their acceptance files. Stage 9 code consolidation is complete, with final native acceptance and matched timing evidence pending. Existing unresolved issues remain in the findings/backlog. The sections below record each stage’s implementation at its handoff; the current source map is docs/ARCHITECTURE.md and the final boundary review is docs/migration/FINAL-REVIEW.md.

### Stage 2 ownership boundary

`Sources/Diagnostics.swift` now contains DiagnosticsService (report strings, save/collection generations, reporting window, capture previews/baseline and AX border ownership), the report formatter and atomic saving. Transitional AppDelegate accessors keep one state owner and unchanged call sites. The coordination adapters for reporting, complete AX collection, border trials, capture preview and explicit inspection are colocated there, retaining their original guards, weak/strong captures and dispatch order. They still use the shared production capture task and bounded AX readers; they do not create new capture or observation owners. No scheduling or algorithm simplification is part of this stage.

The formatter temporarily reads AppDelegate state synchronously. Replace that input with owner snapshots as the later owners are extracted; do not introduce eager report generation before display. Native candidate acceptance remains separate from automated report-equivalence and request-guard checks.

### Stage 3 ownership boundary

AppSettings owns mode/default preference interpretation and startup registration/migration against the existing CameraPreferences.shared domain. SettingsMenuController owns menu construction, item references, titles, enablement/visibility and validation. AppDelegate remains the action target and menu delegate; forwarding accessors preserve existing update triggers. Contextual calibration keys, shortcut registration, selection/placement actions and their ordering remain with their current owners until later stages. No new preference schema, caching, polling or event delivery is introduced.

The separately authorised AX fix requires strip candidates to align with both host horizontal edges (the same <4 pt edge tolerance used for side panels), preventing the inset info-overlay window from masquerading as a top panel when sides hide. Existing size/position filters and all offsets remain. Screenshot algorithms are unchanged.

### Stage 3 presentation follow-up

User authorised a single current-view root item with matching icon and no root checkmark. Automatic Loupe has no submenu; detected split views offer two panes; screenshot without AX view inference offers all five choices. Unknown inference retains the existing waiting text, and manual calibration still hides view controls. Only SettingsMenu.swift presentation changes; selectLayout, inference, placement and update/dismiss actions remain unchanged. Stage 4 is implemented; native acceptance is pending.

### Stage 4 ownership boundary

OverlayBehaviourPolicy in Sources/OverlayBehaviour.swift owns pure geometry-change, photo-selection, host visibility/movement, module-change, explicit-selection and positive-Grid decisions. Existing helper entry points delegate to it for compatibility. Callers still qualify observations with the original backend, epoch, host, module, pending-request and visibility guards, and execute actions in the original order. No unified event queue, timer, read or new state was introduced. A geometry adjust retains image/zoom; a photo adjust refreshes at Fit; host suspension is distinct from dismissal. Screenshot cache invalidation and calibration/floating execution remain unchanged.

The separately requested presentation change enables known Loupe's actionless root item. Automatic validation is disabled only for the root menu (whose actionable entries already always validated true); child menu validation remains unchanged. Stage 5 has not started.

### Stage 4 authorised follow-up — build 62

User requested only the macOS full-screen hidden-top correction. AXFullScreen now qualifies removal of the windowed 32 pt allowance before shared AX classification/placement. This is separate from the policy extraction; no stage 5 work. Stage version remains 1.1.4, build 62. Existing checklist annotations are retained; focused full-screen checks appended. Native acceptance pending.

Build 63 replaces the fixed full-screen allowance with `axFullScreenTitleBarAllowancePoints` (default 32, range 0...200 macOS points; 0 disables). It is a calibrated value supported by the recorded reports, not an AX boundary measurement. The file-driven advanced editor exposes it; config generation and missing-key upgrades preserve existing values. Both AX classification and placement use it, while screenshot geometry and windowed placement are unchanged.

### Stage 5 ownership boundary

PlacementCoordinator.swift groups the existing AppDelegate placement methods as a transitional extension, preserving one state owner and all completion/cancellation/timeout guards. PlacementImplementations.swift contains ManualPlacement, AXPlacement, ScreenshotPlacement and AssistedScreenshotPlacement adapters plus UIPlacement (global AppKit UI rectangle). Original probe metadata and precomputed screenshot photo/candidate rectangles remain intact; AX retains original top-left geometry for diagnostics and converts once. Floating requests still use the combined area; manual/cache/permissions/failure prompts remain at the coordinator boundary. No new queue or preference schema. Photo pipeline and presentation owners will replace transitional AppDelegate access in later stages.

Stage 4 annotations are preserved in docs/migration/STAGE-4-ACCEPTANCE.md. User explicitly deferred full-screen stacking, diagnostic-border constraints and screenshot view-change policy until after migration; logged in docs/BACKLOG.md. None are fixed here. Candidate 1.1.5 build 64; stage 6 has not started.

### Stage 6 ownership boundary

PhotoRequestPipeline.swift owns bridge transport, pending token/destination/module, cancellation, response timer, invocation time, refresh target identity and SelectionImageCache. It has no AppDelegate reference and performs no window or placement operations. PhotoLoadContext captures existing identities rather than introducing a replacement generation. Selection/response epoch readers and the load/cache worker moved with their existing semantics. Polling remains 50 ms, deadline five seconds; callbacks stay on the existing timer/main queue and decode remains on the user-initiated worker queue.

PhotoRequestCoordinator.swift retains request qualification, UI reporting and load completion/dispatch as a transitional AppDelegate extension. Accessors forward old call sites to the single pipeline state owner. All late-result/module/selection/refresh guards remain in their original order. Cancellation still invalidates view probes first, then worker/state/timer/files, then menu update; independent image cache survives. No extraction, placement, monitoring, display or error policy changes. Stage 5 annotations preserved verbatim in docs/migration/STAGE-5-ACCEPTANCE.md. Candidate 1.1.6 build 65; stage 6 user testing subsequently completed.

### Stage 7 ownership boundary

OverlayController owns the displayed panel, host binding, lifecycle/suspension state, geometry settler, displayed layout/module/selection/panel identity and lifecycle counters/history. FloatingDisplayController independently owns its panel/view and title/zoom state. PresentationCoordinator retains the original app-facing guards, callbacks and action ordering, forwarding state to the sole owner for each display. No additional timer, queue, capture or AX read is introduced.

Fourteen presentation/lifecycle methods were relocated; lifecycle history and floating-title formatting now execute on their owners. Cross-component coordination stays in an AppDelegate extension until the monitoring/composition stages. Existing geometry-only updates and image replacement remain separate: view/panel updates preserve zoom, photo replacement resets Fit. ReferenceView, exports, placement algorithms, preview constraints and stacking policy are unchanged. The five deferred bugs/policy items are not fixed here.

Candidate 1.1.7 build 66. Stage 6 annotations already preserved verbatim in STAGE-6-ACCEPTANCE.md. Stage 7 user testing is complete; annotations preserved in STAGE-7-ACCEPTANCE.md. Matched performance samples remain pending; stage 8 had not started at that handoff.

### Stage 8 ownership boundary

LightroomMonitor owns heartbeat/display timers, workspace/application subscriptions, module freshness/window observation state, live AX polling state and background-check task identity. It delivers synchronous tick/foreground/Space/display-change events, and optional AX evidence on the original utility-to-main queue handoff. A missing module/proposal/Grid mark remains unknown, not a confirmed view change. No native window mutation occurs in the monitor.

MonitoringCoordinator applies the existing OverlayBehaviourPolicy and executes actions with the original eligibility/staleness guards. Policy decisions were migrated in stage 4; evidence qualification and effects remain coordinator responsibilities. Nine reader/handler bodies and the heartbeat tick body are byte-identical to stage 7; live AX qualification/completion are unchanged around the explicit evidence handoff. Screenshot background eligibility, capture, result guards and invalidation stay together in this transitional coordinator. The monitor owns their task identity; it does not start capture independently.

The timer remains 0.2 seconds, eligible AX polling 2 seconds, display-check debounce 0.6 seconds, and screenshot checking uses the existing config. Notification callbacks remain synchronous on the posting thread, with no extra queue. The two existing main/utility queue boundaries are not combined into a new event loop. Subscriptions and timers now have an explicit stop/replacement lifecycle. No placement, update/dismiss, preview, export or permission policy changes. Six deferred issues remain unfixed.

Candidate 1.1.8 build 67; stage 8 user testing complete, with responses preserved in STAGE-8-ACCEPTANCE.md. Stage 7 annotations remain preserved in STAGE-7-ACCEPTANCE.md. Stage 9 had not started at that handoff.

### Stage 9 consolidation and acceptance boundary

Removed 42 temporary storage-forwarding properties; state reads/writes name their concrete owners. Retained request-handle and panel aliases for local optional bindings, and native menu/diagnostic adapters. Grouped 24 unchanged action methods into ViewCoordinator, CalibrationCoordinator, SettingsActions and ExportCoordinator. main.swift is now composition/startup/shortcuts/invocation/contextual region access and shared operation state (275 lines rather than 631 at stage 8). No new independent coordinator object, event bus, store or timing boundary.

Source comparison against 25e4a2f verifies all 85 coordinator method bodies identical after reversing owner qualification. Shared capture/calibration/placement cancellation identities deliberately remain on composition; final boundaries and rationale are documented in docs/migration/FINAL-REVIEW.md. All six deferred issues stay open. Stage 8 responses remain preserved in STAGE-8-ACCEPTANCE.md.

Candidate 1.1.9 build 68. Final native acceptance and matched timing evidence remain pending. No merge authorised by starting this stage; main and its accepted app remain untouched.

2026-11-20: user completed all four 1.1.9 checks without new annotations; preserved in docs/migration/STAGE-9-ACCEPTANCE.md. Backlog fixes authorised next. Main/merge remain separate; matched timing samples are still outstanding.
