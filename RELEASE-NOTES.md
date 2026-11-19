# Camera Reference 1.1.6 — testing candidate

Stage 6 moves photo request state, bridge transport, cancellation and image-cache ownership into PhotoRequestPipeline. Request qualification, reporting and late-result guards remain at the coordinator boundary. Polling, deadlines, extraction, cache validation, display routing and current user-facing behaviour are preserved.

The four logged bugs/policy items remain deferred until after migration. Main is untouched. Native acceptance is pending; see TESTING.md. Quit the previous app before opening the testing app.
