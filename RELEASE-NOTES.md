# Camera Reference 1.0 alpha 2

This is a testing release, not a claim of complete native acceptance.

Main changes: retain/restore overlays through temporary overview transitions, allow off-screen clipping, migrate advanced config to config.conf, and provide a drag-to-Applications DMG with bridge installer. Bridge 0.5.1 is required. GUI settings and calibration retain the existing preference domain.

Known working placement uses `sideSearchPercent = 30` on the author's setup. The default remains 45 for compatibility with narrow-window cases. Migration preserves existing values. Split detection remains the accepted Full-plus-bottom/left-inset method.

Priority acceptance: off-screen movement, Mission Control/App Exposé return, minimisation/Space handling, config migration and installed-app/bridge launch. See TESTING.md in the repository.

Distribution is native-architecture, ad-hoc signed and not notarised. macOS may block downloaded copies; see docs/INSTALL.md in the repository or INSTALL.md in the disk image. Licensing is not yet selected. No automatic updates, private API or permission-reset procedure is included.

This update consolidates support files into Camera Reference. **Reload bridge 0.5.1 before use**; older bridges use the former path and will time out. The old folder is archived inside Backups once inactive; existing config and plugin settings are preserved. See docs/CONFIGURATION.md in the repository for migration details.
