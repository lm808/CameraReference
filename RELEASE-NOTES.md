# Camera Reference 1.1.11 — testing candidate

Screenshot mode now uses one independent pixel detector. Valid outer areas split 50/50 according to the selected view. If the initial side-search zone finds no valid rectangle, the detector retries to the centre and accepts only a fully validated result.

AX-assisted placement is removed. Existing assisted choices use Screenshot; optional AX view detection retains its separate setting and dismissal behaviour. AX-only placement/live updates, manual calibration and capture permission handling are unchanged. Recalibration is deferred to the next step.

Native checks are in TESTING.md. Main remains accepted 1.1.10 build 69; this candidate is 1.1.11 build 70. No package created.
