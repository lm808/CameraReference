# Stage 1 — behaviour and performance baseline

Baseline production code: a568c6e / app 1.0.32. Stage 1 adds tests/documentation only. No source, config default, app version, staging or personal settings change. Tests use temporary bridge files/preferences and a synthetic JPEG paired with a dummy RAW filename; no Lightroom interaction, capture, AX request or app launch.

## Coverage and its limits

| Contract | Executable evidence | What still needs native evidence |
|---|---|---|
| New settings choose Accessibility, AX inference, update on; saved choices preserved | New migration harness calls actual AppDelegate getters with isolated preference combinations, including legacy and four screenshot combinations | Launch-time seeding/menu presentation (launch callback deliberately not run) |
| Bridge unknown/partial data is not a confirmed change | Actual currentModule, selectionEpoch and responseEpoch readers with valid/partial/stale files; existing module helper tests | Live bridge write timing and observer reliability |
| Cancellation/selection/module changes cannot accept stale loads | Actual asynchronous load completion after cancelRequest, hide with overlay destination, token replacement, selection change, confirmed/unknown module change | Existing real-panel replacement and AX completion guards need injectable seams or native tests |
| Same-photo repeated load is fast through RAM reuse | Actual successful check-only load/decode, repeated load hits RAM, request cancellation preserves image cache | Time to visible overlay and fresh AX read cost |
| Off overlay stays off | Actual early guards in checkOverlaySelection/followLiveOverlayView, repeated absent hide | Live timer integration and real suspended overlay restoration |
| View/pane/panel and selection action choices | Existing exhaustive matrices in tests/split/main.swift call production action helpers for backend/manual/update/open/unknown combinations | Applying actions to visible windows; exact preservation of zoom/image/export |
| Manual/AX/screenshot routing and geometry | Existing core, split, capture, viewport and reset tests | Permissions, real panel visibility, full/split on each display |
| Grid unknown versus selected and module changes | Existing core tests use real menu-selection/module helpers | Direct menu marks and native Grid reliability remain unresolved |
| Suspension/restore/movement | Existing core tests exercise host action and geometry settler helpers | No claim that helper tests reproduce Dock/Mission Control animation |

Tests intentionally do not replace the application with a second simulated controller. Untestable orchestration remains explicitly uncovered until extraction introduces a narrow seam. Preserve these gaps in stage reviews rather than marking every lifecycle sequence verified.

## Native comparison protocol (not yet collected)

Use the accepted stable app for the before samples, and later the candidate for after samples; only one runs at a time. Keep photo, source preference, Lightroom module/layout/panels, host geometry, display scale, config and diagnostics settings identical. Do not edit personal settings for an automated baseline. The user performs all live interactions.

Record the existing Diagnostics Performance and Placement sections. For each case gather 5 representative samples; distinguish first extraction from warm reuse. Compare median and range plus work performed, not one fastest run. Retain the app/commit identity and whether diagnostic saving was enabled. Raw reports remain ignored/local; record anonymised numbers here when available.

| Case | Expected work | Before / after |
|---|---|---|
| First overlay on a newly selected RAW | Bridge + extraction/decode + AX placement | Pending / pending |
| Repeated toggle, unchanged photo/layout | Bridge + RAM hit + AX placement; no automatic capture | Pending / pending |
| Selection refresh while AX overlay on | New selected image at Fit in existing panel | Pending / pending |
| View/pane/panel update while AX overlay on | Geometry update, same image/zoom; no re-extraction | Pending / pending |
| Floating open/reload | Existing independent-image/sizing behaviour | Pending / pending |

Current diagnostic timing does not necessarily expose end-to-end duration for every live update. Mark that unavailable rather than inferring it from invocation timing. Adding production instrumentation is a separate reviewed step if needed. Old conversation timings used different backends/geometry and are not a matched baseline.

Accept no unexplained repeatable slowdown or extra extraction/capture/read work. Do not set arbitrary millisecond thresholds before collecting noise/range. Background scheduling remains unchanged during migration; measure under equivalent idle/foreground conditions.

## Run record

2026-11-18, production baseline a568c6e:

- `bash tests/migration/run.sh`: passed all five groups (preferences, bridge freshness, stale async completions, decode/cache, absent-overlay guards).
- `bash test.sh`: core, Lua, detection, viewport, reset, preview, capture and split suites passed. The config-editor executable hit sandbox error 512 during temporary atomic save; rerunning that same executable outside the sandbox passed both groups. The script stopped at that error before its final migration invocation; that unchanged harness had passed separately as above. Optional external crop images were not supplied.
- `git diff --check`: passed. Production Sources/, config/, build and staging scripts unchanged against a568c6e; main remains clean at a568c6e.

Native timing and real-window acceptance remain pending. Stage 1 establishes the harness and protocol; it does not certify a migrated app (none exists yet). No newly confirmed product defect was found. The initial synthetic fixture was corrected to use a paired RAW filename because the existing loader intentionally rejects direct JPEG selection.
