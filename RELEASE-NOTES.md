# Camera Reference 1.1.16 — testing candidate

Build 75 resolves the two abstraction-audit findings. Guided calibration now reads shared raw AX geometry before signed correction validation, so unusable correction values cannot block access to otherwise valid calibration evidence. Production placement keeps the same formulas and rejection guards.

Screen capture returns typed failure reasons. Snapping guidance now uses those reasons instead of matching diagnostic sentences. Freehand fallback and the no-prompt policy are unchanged.

Automated checks passed, including 1,728 synthetic comparisons against the previous AX placement function. A short native checklist remains in TESTING.md. The accepted 1.1.15 results are preserved. Main is untouched; no package created.
