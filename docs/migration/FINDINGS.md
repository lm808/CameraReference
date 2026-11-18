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

## Pre-existing unresolved issues (carry forward, do not fix implicitly)

- Direct Library Grid menu mark reliability requires native confirmation; nested Grid must not match. Preserve unknown handling.
- Original screenshot Library status-text and Develop right-panel-hidden split failures; keep original algorithms unchanged.
- Intermittent off-screen capture padding/metadata inconsistency; keep raw preview and failure evidence.
- Broader toolbar fallback, language/display/hidden-panel edge cases; calibrated geometry remains configurable.
- Retained screenshot-check contribution/cost not established; do not remove checks during migration.

## New findings template

ID / stage / baseline or regression / observed evidence / affected component / proposed resolution / behaviour impact / test / user decision / commit.

No newly confirmed product defect was established during the planning stage. These are migration hazards and existing limitations, not claims that a fix has been made.
