# Camera Reference Testing 1.0.24

Candidate only; stable main remains 1.0.15 and bridge 0.5.3.

Adds an experimental AX-only placement switch, subordinate to Automatic viewing area. Manual placement still takes precedence. AX mode reads fresh geometry and never falls back to screenshots; background placement captures are disabled. Explicit capture previews and calibration edge snapping remain available. The existing screenshot detector is unchanged. AX boundary preview remains a separate option.

V2 config contains calibrated shown/hidden edge offsets, cumulative filmstrip/toolbar corrections, and a separate Library allowance (default 25 pt, calibrated by the user). Signed offsets use right/up positive. Legacy settings are retained; new defaults are appended without replacing personal settings. Both preview and AX placement use v2 values. JPEG RAM caching remains unchanged.

See TESTING.md for pending native acceptance. No packaged release was created.
