# Privacy and data handling

Camera Reference reads the Lightroom selection and a matching JPEG or embedded CR3/ARW JPEG. The bridge exchanges local request/response files; selection responses include the selected source path. Heartbeat and revision files track bridge/module/selection state.

Accessibility automatic placement reads AX geometry/menu state and public window-list metadata without capturing pixels. Screenshot placement and permission-available snapping capture the selected Lightroom window in memory. Screenshot background checks do this periodically while eligible; interval 0 disables them. Screen Recording is requested only when explicit screenshot placement needs it; Accessibility placement, background checks and manual snapping never prompt. The app does not perform OCR or save screenshots. Explicit capture preview is in-memory only.

Extracted JPEG bytes and decoded images may remain in RAM while the same photo is selected. A floating display retains its own reference until closed/reloaded. The app creates no disk image cache. **Save extracted JPEG** is an explicit user action that writes beside the RAW, with replacement confirmation. RAW files, catalogue and Develop settings are not modified.

GUI preferences, calibration and advanced configuration are stored locally. The local bridge directory can contain file paths; diagnostics/export titles may also reveal filenames. Review reports and screenshots before posting them publicly. Do not commit personal config, bridge files or photographs.

There is no app telemetry, analytics or automatic network update mechanism. macOS permissions and security decisions remain managed by the operating system.

Migration preserves unknown files and differing conflicts beside their destination with a .migrated suffix. Old backups from previous versions may contain paths; review them before sharing. Known obsolete protocol files are discarded, not replayed.

Accessibility placement, view/menu inspection and minimise monitoring use read-only Accessibility access. Feature-triggered permission requests are separate from Screen Recording. Diagnostics include geometry, bounded menu command evidence, API status and event timelines; they contain no photo pixels. Optional Save diagnostics after invocation writes a local text report including fresh AX evidence; it does not upload it. A retained capture baseline and latest preview are memory-only and released on close or quit.
