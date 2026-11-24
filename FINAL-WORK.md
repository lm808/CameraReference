# Final placement work — audit follow-up

Baseline main: 1.1.10 build 69, commit ab92404. User-accepted source: 1.1.15 build 74, commit 1624d65; documentation-only audit committed separately as a637585. Current candidate: 1.1.16 build 75, fixing the two audit findings. Main remains unchanged.

- [x] Simplify screenshot placement to pixel-validated outer bounds and 50/50 splits; fix wider side search; remove AX-assisted placement while keeping optional AX view detection.
- [x] Add guarded expanded working-area reuse, configurable view/keypad shortcuts and shared selector preparation.
- [x] Add camera-style metadata, default-hidden Developer tools and value-preserving config organization.
- [x] Implement guided AX calibration as six retryable setups/seven selections with pure calculation, countdown, review, backup and explicit Apply.
- [x] Fix calibration alignment, reported Library/Develop screenshot boundaries and overlay-click host activation.
- [x] Preserve exact 1.1.12, 1.1.14 and 1.1.15 test responses; user accepted all final tests on 2026-11-24.
- [x] Audit abstraction boundaries and update current documentation. The audit itself changed no executable code; its two findings are implemented in the subsequent 1.1.16 update.
- [x] Implement shared raw AX evidence and typed permission failure guidance, preserving existing algorithms.
- [ ] Complete the short 1.1.16 native checklist.
- [ ] Merge into main only on explicit instruction. Acceptance is recorded; merge/publishing/packaging have not been performed.

See [boundary audit](docs/BOUNDARY-AUDIT.md), [validation](docs/VALIDATION.md) and [historical planning record](docs/HISTORICAL-NOTES.md). The only current acceptance work is the short 1.1.16 regression checklist; broader environment/edge-case checks remain separate.
