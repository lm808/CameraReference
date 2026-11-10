# Overlay latency investigation — 10 November 2026

Measured on the user's Mac with an optimised Swift benchmark, 10 repetitions of each stage. The supplied screenshots were cropped to their recorded Lightroom windows; no live screenshot was taken. These are CPU-stage measurements, not end-to-end overlay latency.

| Stage | 1392×888 pt window | 900×702 pt window |
|---|---:|---:|
| Raster, first | 57.1 ms | 18.6 ms |
| Raster, median | 1.5 ms | 0.9 ms |
| Fresh detector, median | 71.1 ms | 44.1 ms |
| Cached validation, median | 0.1 ms | 0.1 ms |

The bridge sleeps 150 ms between checks; companion response polling is 50 ms. Capture deliberately waits 150 ms for stable window geometry, before ScreenCaptureKit work. Those are configured intervals, not measured end-to-end delays. Embedded extraction starts ExifTool on demand; its cost is unknown for the user's current photo/storage.

0.9.8 reports bridge, load/decode (including extraction), capture/detection total and total-to-panel timings in Bridge diagnostics. Within successful capture diagnostics it also reports enumeration, stability/configuration, capture, raster and detector stages. No paths or pixels are logged. Total-to-panel is not a GPU presentation timestamp. Opening another diagnostic replaces some samples: copy after invoking the overlay.

Next evidence: first invocation and two repeated invocations of the same photo, plus standalone versus embedded if convenient. Use measurements to select the optimisation. Do not remove stability guards, introduce persistent JPEG caching or guess that detector time dominates. Potential next steps are reducing repeated ScreenCaptureKit enumeration/setup, overlapping independent bridge/capture work with generation checks, or addressing ExifTool startup if measurements justify it.

Reproduce CPU benchmark: compile tests/performance/main.swift with the same sources used for capture-tests and -O. Pass the larger supplied screenshot path, or the 900×702 screenshot followed by `small`. Fixtures are external and not committed.

## User's 0.9.8 live samples

Totals: 1061, 1020, 1070 ms. Bridge: 78, 87, 105 ms. JPEG load: 689, 691, 717 ms, including extraction: 269, 281, 300 ms. Capture/detection: 290, 224, 229 ms. Loading dominates; the remaining ~410–420 ms is not yet attributed to decode versus failed standalone lookup. All samples show extraction, so no confirmed standalone comparison is available.

0.9.9 removes eager file-property prefetch for every RAW-folder entry and only inspects matching filenames, preserving ambiguity and regular-file checks. New stage timings identify failed source attempts, lookup, standalone decode and embedded decode/orientation overhead. This is a targeted low-risk change; no live speedup is claimed before retesting. No reduced decode resolution or persistent image cache was added.

## 0.9.9 live feedback and 0.9.10 cache

User measurements: first embedded total 821 ms (bridge 56, load 409 including extraction 312, capture/detection 334); repeated totals 690 and 711 ms (load 396/373, extraction 295/274, capture 223/219); standalone total 637 ms (bridge 153, lookup 13, decode 198, capture 245). These are different invocation samples, not a controlled cold benchmark. Extraction now dominates the repeated embedded load. The user explicitly authorised retaining one selected photo in RAM, superseding the prior no-between-invocations cache requirement. 0.9.10 implements this with selection-revision and file/preference validation. No cache-hit live timing is claimed yet.

## 0.9.11 — skip capture on repeated toggles

User 0.9.10 sample: bridge 195 ms, RAM load 5 ms, capture/detection 219 ms, total 451 ms. Manual sample: bridge 84 ms, RAM load 5 ms, total 115 ms. These are different bridge latencies, not a controlled benchmark. 0.9.11 reuses the detected UI area only with matching selection epoch, window identity/size, layout and config; movement translates it. File metadata revalidation and bridge round-trip remain. Config metadata is checked without rereading unchanged text. No measured 0.9.11 latency claim yet. Internal panel changes require clearing the region until an inexpensive reliable signal is established.

## 0.9.12

User 0.9.11 first sample: bridge179 ms, load849 ms (extract294, decode/orientation556), capture321, total1364. Repeats: total178/184 ms, bridge151/152, RAM load6; capture skipped. These confirm repeated-path improvement but first-load cost varies. New panel checks run off the invocation path at most every1.5 seconds while Lightroom is active and automatic placement is cached, and are cancelled on foreground work. This trades periodic idle capture/CPU cost for automatic panel-change detection; speed and power acceptance must be measured. No 0.9.12 timing claim yet.

## 0.9.13

Background interval defaults3s (20 checks/min maximum), zero disables; captures capped1280px, full placement unchanged. On user's small-window screenshot, five-run median fresh detector47.16ms at1800px versus33.57ms at1280px, bounds agree within1pt. No claim for live capture/battery cost. Diagnostic background duration includes setup/stability/capture/detection. Geometry timer stays0.2s without screenshots; float-only pointer sampling80ms replaces competing hover events.
