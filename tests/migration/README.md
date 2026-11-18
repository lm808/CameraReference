# Migration characterisation harness

Run `bash tests/migration/run.sh` from this worktree. This compiles the existing AppDelegate and supporting production sources into a command-line test executable, **without launching the application or invoking live AX/capture**. It uses a synthetic 8×6 JPEG paired with a dummy RAW filename (no RAW parsing), a UUID temporary bridge directory and an isolated preferences suite. Temporary test data/preferences are cleaned up.

`prepare.py` writes ignored source copies under build/migration-tests. Test seams remove the application entry point, redirect the bridge/config/preferences, omit status-bar rendering in report(), and count entry into load completion. Exact source matches fail closed if a seam moves. The production guard expressions and execution bodies are unchanged. No production file is edited. The harness does not call launch, live placement, display, permission or monitor scheduling APIs.

This is temporary test infrastructure, not the target application architecture. As injectable ownership boundaries emerge, replace the generated-copy seams with direct construction against those boundaries. Do not relax a failing seam match silently.

Coverage distinguishes actual coordinator execution from helper tests. See docs/migration/BASELINE.md. This harness does **not** prove native window ordering, retained image/zoom in a real panel, AX menu availability, screenshot accuracy, timer fairness or end-to-end display latency. Those stay in focused native comparisons; do not mistake check-only JPEG timings for time to visible overlay.

Stage 2 also compares the new formatter against a frozen 1.0.32 renderer, checks saving disabled/enabled/overwrite/failure and preview-generation invalidation. Permission status is read through non-prompting preflights only; no Lightroom AX inspection or capture is performed. The report seam now resides in the generated Diagnostics.swift adapter.

Stage 3 constructs menus without a status item or app launch and checks titles/order, application action targets (excluding AppKit submenu actions), backend/manual visibility, validation, inferred pane state and preference default preservation. AppSettings uses the same isolated shared domain as the coordinator in this harness.
