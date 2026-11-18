# Migration findings and decision log

Record issues/opportunities separately from structural moves. No item here authorises changing user-facing behaviour. Link concrete source/evidence, identify whether pre-existing or introduced, and describe a minimal separate fix and relevant tests. Current edge-case backlog remains ../BACKLOG.md; original research remains ../AX-ASSISTANCE.md.

## Initial inspection

| ID | Finding / evidence | Risk / disposition |
|---|---|---|
| M1 | AppDelegate's 0.2s timer runs cache observation, module handling, host ordering, screenshot checks, AX checks and selection refresh in a fixed sequence. `request` cancels background/screen/request work before opening a tokenised request. | Reordering during extraction could alter scheduling or late-result handling. Preserve execution order first; not a confirmed current bug. |
| M2 | Diagnostics uses generations/busy flags that also gate production reads (`axMappingInProgress`, `savingInvocation`, foreground request guards). | Reporting is not purely passive today. Extract state without removing gating or adding blocking work. Performance opportunity later, not a migration optimisation. |
| M3 | Selection refresh retains an existing panel, retries once per epoch and resets Fit; view/panel refresh preserves image/zoom and can retry. | A generic refresh method could erase these distinctions. Keep distinct operations and tests. No current defect established. |
| M4 | Screen inspection is shared by automatic screenshot placement and explicit diagnostic/calibration actions. | Backend separation must preserve cancellation/permissions and preview behaviour. Do not create two independently running capture owners inadvertently. |
| M5 | Build script explicitly lists Swift inputs; tests also compile explicit subsets. | Register moved files in relevant build/test lists at extraction time. File moves alone are not proof of compilation/link coverage. |

## Stage 1 test boundary

The coordinator currently needs generated test copies to isolate its entry point, bridge/config/preferences and status-bar rendering. The harness preserves completion guards and executes actual async load/decode/cache logic; native panel ownership and live AX completions remain uncovered at this level. Replace these temporary seams as owners become injectable, without creating a second simulated behaviour controller. See BASELINE.md for the coverage matrix. No product bug was established during this stage.

## Pre-existing unresolved issues (carry forward, do not fix implicitly)

- Direct Library Grid menu mark reliability requires native confirmation; nested Grid must not match. Preserve unknown handling.
- Original screenshot Library status-text and Develop right-panel-hidden split failures; keep original algorithms unchanged.
- Intermittent off-screen capture padding/metadata inconsistency; keep raw preview and failure evidence.
- Broader toolbar fallback, language/display/hidden-panel edge cases; calibrated geometry remains configurable.
- Retained screenshot-check contribution/cost not established; do not remove checks during migration.

## New findings template

ID / stage / baseline or regression / observed evidence / affected component / proposed resolution / behaviour impact / test / user decision / commit.

No newly confirmed product defect was established during the planning stage. These are migration hazards and existing limitations, not claims that a fix has been made.

## Stage 2 extraction findings

The report formatter can move without changing its output, but automatic collection remains coupled to `axMappingInProgress`, foreground request IDs and diagnostic generations. Capture preview also shares `startPhotoDetection` cancellation with placement/calibration. Both coordination adapters were moved verbatim, with forwarding accessors into one DiagnosticsService state owner. No new background worker, queue, observation or capture lifetime was introduced. A future cleanup should replace synchronous AppDelegate formatter inputs with snapshots from the extracted owners; doing that before those owners exist would add abstraction without reducing the shared coordination risk. No new product defect was confirmed.
