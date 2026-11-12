# CameraReference Testing 1.0.11

Main remains at accepted 1.0.6. Run release/CameraReference Testing.app (purple T). Settings/config remain shared; Library and Develop calibration keys are separate within the same preferences file.

- Library and Develop supported; other modules rejected with an explicit message. Use Library Loupe for photo alignment.
- Overlay dismisses on module changes; pending work is cancelled and placement re-detected. Existing floating display stays independent.
- AX host lookup checks main/focused window references, then all returned windows within a time budget, verifying geometry rather than taking the first 16.

**Manually update/reload the included bridge to 0.5.3** before Library testing. Protocol remains compatible with stable 1.0.6. Native Library placement/AX matching require acceptance; AX viewport inference and 50/50 split fallback are deferred. No DMG, merge, installation or live interaction by the agent.
