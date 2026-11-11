# Privacy and data handling

Camera Reference reads the Lightroom selection and a matching JPEG or embedded CR3 JPEG. The bridge exchanges local request/response files; selection responses include the selected source path. Heartbeat and revision files track bridge/module/selection state.

Automatic placement and snapping capture the selected Lightroom window in memory. Background checks do this periodically while eligible; interval 0 disables them. The app does not perform OCR or save screenshots. Explicit capture preview is in-memory only.

Extracted JPEG bytes and decoded images may remain in RAM while the same photo is selected. A floating display retains its own reference until closed/reloaded. The app creates no disk image cache. **Save extracted JPEG** is an explicit user action that writes beside the RAW, with replacement confirmation. RAW files, catalogue and Develop settings are not modified.

GUI preferences, calibration and advanced configuration are stored locally. The local bridge directory can contain file paths; diagnostics/export titles may also reveal filenames. Review reports and screenshots before posting them publicly. Do not commit personal config, bridge files or photographs.

There is no app telemetry, analytics or automatic network update mechanism. macOS permissions and security decisions remain managed by the operating system.

Migration preserves unknown files and differing conflicts beside their destination with a .migrated suffix. Old backups from previous versions may contain paths; review them before sharing. Known obsolete protocol files are discarded, not replayed.
