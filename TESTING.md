# Camera Reference 1.0.15 — diagnostic mapping

Run `release/CameraReference.app` (normal icon/name), bridge **0.5.3**. This update only expands diagnostics; accepted 1.0.14 behaviour is unchanged.

- [ ] Choose **Developer tools → Inspect Accessibility layout…**. In the report, find **Accessibility & display map**. Check that AXWindows returned/examined counts and W1…Wn entries are present; unreadable or budget-limited entries must be explicit.
- [ ] Check each display appears with its name/D-number, global bounds, backing scale and mode pixels. Unsupported AXVisible is expected on some objects and does not mean hidden.
- [ ] Dismiss the report, keep Lightroom's window/panels unchanged, and take an original full-display screenshot. Send **Bridge diagnostics → Copy all**, the screenshot and its D-number/name. No need to clear/calibrate regions or change settings.

Continue ordinary edge-case collection separately. Minimise lingering is accepted; off-screen/split intermittency and the deferred Mission Control/module-switch check remain documented in docs/BACKLOG.md and docs/VALIDATION.md.
