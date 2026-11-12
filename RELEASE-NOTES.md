# CameraReference Testing 1.0.12

Main remains at accepted 1.0.6. Run `release/CameraReference Testing.app` (purple T). Shared settings/config and testing identity are unchanged. Bridge remains **0.5.3**.

- Library and Develop remember separate layout/pane selections. Existing Develop values remain in place; Library defaults to Full if unset.
- Off-screen capture uses a short-lived, one-frame stream with reported geometry to remove padding/child extent before detection and snapping. On-screen capture and Full/split detection remain unchanged. Invalid geometry offers calibration rather than guessing coordinates.
- Minimise monitoring also suspends when the presentation shrinks while the logical AX window size stays fixed. This may catch animation before the minimise notification; native timing is not yet verified.

Use TESTING.md for native acceptance. No merge, DMG, installation or live app interaction performed by the agent.
