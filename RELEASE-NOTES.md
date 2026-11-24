# Camera Reference 1.1.13 — testing candidate

Build 72 retains successful screenshot working areas after inconclusive background checks when expanded reuse is on. Confirmed geometry changes and explicit clearing still invalidate; reuse-off and AX placement algorithms are unchanged.

Guided AX calibration now uses one window with six independently retryable setups and seven rectangle selections. It adds full-screen allowance and photo Fit inset to the ten boundary corrections. A cancellable countdown hides before snapping capture; conflicts identify the affected setups. Review all values before Apply, which backs up the config. No manual-region or placement-mode changes.

Overlay and floating context menus show the camera-recorded Picture Style (Canon CR3/C-RAW) or Creative Style/Look (Sony ARW). Missing metadata is nonfatal and shown as Unavailable. Metadata stays with the displayed photo and its cache entry.

Developer tools is hidden by default: enable showDeveloperTools in Settings → Advanced settings. Config defaults and generation are grouped consistently. Existing values/comments survive organization, with a backup beside config.conf.

Native acceptance is pending. Main and its staged daily-use app remain untouched. No package created.
