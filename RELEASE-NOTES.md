# CameraReference 1.0.9 — testing candidate

Main’s accepted 1.0.6 app remains untouched. Candidate release/CameraReference.app is now **Camera Reference Testing**, with a purple icon and separate bundle ID. Its permissions must be granted separately by the user; ad-hoc-signed updates may still need approval. Settings/config and bridge 0.5.2 are shared, so run one copy at a time.

- Bridge diagnostics: six selectable sections, scrollable details and Copy all; timing appears once.
- Remove the standalone monitoring action. Capture tools clearly request Develop when invoked elsewhere.
- Restore off-screen detection and Option-snapping using the no-sourceRect capture that passed preview comparison.
- Prefer logical AX coordinates and wait for resize/restore geometry to settle, targeting the unwanted minimise-cycle movements. Early hiding is not claimed solved.

Follow TESTING.md. No merge, DMG, app launch or live interaction by the agent.
