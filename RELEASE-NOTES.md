# CameraReference Testing 1.0.13

Run `release/CameraReference Testing.app`. Main stays at accepted **1.0.6**, bridge at **0.5.3**. Shared settings and identities are unchanged.

This diagnostic update fixes the swallowed error that prevented investigation of off-screen capture. Bridge diagnostics now preserves the original error domain/code, underlying cause and capture context. Frame failures identify conversion, missing metadata, rejected geometry or crop failure. Capture-preview timing no longer appends to an earlier invocation.

**Off-screen placement is not yet fixed.** Repeat one failing invocation and send Copy all as described in TESTING.md. Capture geometry and detection are unchanged. The user accepted brief minimise lingering; no additional input monitoring or lifecycle changes were added. No merge or DMG.
