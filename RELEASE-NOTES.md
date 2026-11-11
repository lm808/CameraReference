# CameraReference 1.0.1

Staged development update; no new DMG was created. Run release/CameraReference.app and reload bridge 0.5.2.

- Keep the displayed overlay open through resize, panel detection failure and bridge/module uncertainty. Such changes invalidate future placement only. Temporary host hiding/overview suspension restores the existing image; explicit dismissal or confirmed host closure closes it.
- Correct false overview detection: a full-screen Dock surface alone is insufficient evidence.
- Consolidate Application Support under CameraReference with Bridge and Plugins subfolders, preserving explicit settings and conflicting files without duplicate legacy directories.
- Default new settings to sideSearchPercent 30 and all four bounds ui.
- Maintain an incremental release/ staging payload; package only on request.

Stop old bridge copies before upgrade. See INSTALL.md in release/ or docs/INSTALL.md in the repository. Native overview and migration acceptance remain in TESTING.md. Ad-hoc signed, not notarised; licensing remains undecided.
