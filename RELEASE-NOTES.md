# CameraReference Testing 1.0.10

Open **release/CameraReference Testing.app**: purple icon with a large T, distinct executable name, unchanged testing bundle ID. Main’s accepted 1.0.6 app is untouched. Existing preferences/config/bridge remain shared; no new settings folder.

Permission messages now identify the exact app and avoid repeated native requests in one launch. This is a rebuilt, unambiguously named candidate, not a confirmed TCC repair. Ad-hoc signing remains; no permission reset or weakened signing requirement was applied.

First verify Screen Recording for this exact new app and reopen it if requested. Leave stable’s entry intact. If still blocked, report diagnostics before attempting functional tests. The 1.0.9 functional changes are unchanged. No DMG, merge or live interaction by the agent.
