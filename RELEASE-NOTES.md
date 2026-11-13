# Camera Reference Testing 1.0.22

Candidate only; main remains 1.0.15 and bridge 0.5.3.

Automatic toolbar diagnostics now inspect AXSections, including dictionary/array structure and referenced accessible elements. Main-window section elements are prioritised before sidebar descendants. Reports omit text/value payloads and retain bounded traversal with limits reported.

This is a diagnostic-only change. Existing screenshot detection, live view inference, placement, settings and cache behaviour are unchanged. No installation, launch, packaging or push. See TESTING.md for the toolbar shown/hidden comparison.
