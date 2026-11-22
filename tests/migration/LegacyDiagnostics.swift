// Frozen 1.0.32 renderer, from 93117d8, used only for byte-for-byte comparison.
// Do not update alongside the new renderer without an explicit behaviour change.
import AppKit
import ApplicationServices
extension AppDelegate {
    func baselineDiagnosticSections()->[DiagnosticSection] {
        // State-owner aliases only; the frozen formatter below is unchanged.
        let overlayVisibilityStatus=overlayController.overlayVisibilityStatus
        let overlayGeometrySource=overlayController.overlayGeometrySource
        let overlayLifecycleStatus=overlayController.overlayLifecycleStatus
        let overlayMoveCount=overlayController.overlayMoveCount
        let overlayOrderCount=overlayController.overlayOrderCount
        let overlayLevelChangeCount=overlayController.overlayLevelChangeCount
        let lifecycleTrace=overlayController.lifecycleTrace
        let panelCheckStatus=lightroomMonitor.panelCheckStatus
        let heartbeat=folder.appendingPathComponent("heartbeat.txt")
        let attributes=try? FileManager.default.attributesOfItem(atPath:heartbeat.path)
        let date=attributes?[.modificationDate] as? Date
        let age=date.map { "\(max(0,Int(Date().timeIntervalSince($0)))) seconds ago" } ?? "not received"
        let state=(try? String(contentsOf:folder.appendingPathComponent("status.txt"),encoding:.utf8)) ?? "No plugin status received."
        let assistedChecks=0,assistedAXChanges=0,assistedAXFailures=0,assistedPixelChanges=0,assistedPixelFailures=0
        let assistedAXSeconds=0.0,assistedCheckSeconds=0.0,assistedEvidence="No assisted comparison yet."
        return [
            DiagnosticSection(title:"App & permissions",body:"\(versionTitle)\nAccessibility: \(AXIsProcessTrusted() ? "granted":"not granted — request through Inspect Accessibility layout")\nScreen Recording: \(CGPreflightScreenCaptureAccess() ? "granted":"not granted")\nExifTool: \(findExifTool(custom:CameraPreferences.shared.string(forKey:"exiftool")) == nil ? "not found":"available")\nApp: \(Bundle.main.bundleURL.path)\nBundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")\n\(storageStatus)"),
            DiagnosticSection(title:"Accessibility & display map",body:lastAXMapping),
            DiagnosticSection(title:"Saved diagnostics",body:diagnosticSaveStatus),
            DiagnosticSection(title:"Automatic view experiment",body:lastViewDetection),
            DiagnosticSection(title:"Placement method & assisted evidence",body:"Method: \(automaticPlacementMode.title). View detection: \(automaticViewEnabled ? "automatic AX":"menu selection").\nRetained screenshot checks: \(assistedChecks); AX time: \(Int(assistedAXSeconds*1000)) ms; retained capture/check time: \(Int((assistedCheckSeconds-assistedAXSeconds)*1000)) ms.\nAX changes: \(assistedAXChanges); AX unavailable/stale: \(assistedAXFailures).\nPixel boundary changes after unchanged AX: \(assistedPixelChanges); pixel validation failures: \(assistedPixelFailures).\n\(assistedEvidence)\nAll periodic screenshot checks retained for this measurement trial; counters are session-only."),
            DiagnosticSection(title:"AX placement trial",body:lastAXTrial),
            DiagnosticSection(title:"AX toolbar visibility",body:lastAXToolbar),
            DiagnosticSection(title:"Grid view & view-change policy",body:lastGridStatus+"\nAX-only update overlay with LrC view: \(axLiveUpdate). Screenshot modes retain cache-invalidation behaviour."),
            DiagnosticSection(title:"Last result",body:lastResult),
            DiagnosticSection(title:"Last placement failure (retained snapshot)",body:lastPlacementFailure),
            DiagnosticSection(title:"Lightroom bridge",body:"Heartbeat: \(age)\nPlugin status: \(state.trimmingCharacters(in:.whitespacesAndNewlines))"),
            DiagnosticSection(title:"Overlay visibility & minimisation",body:"\(overlayVisibilityStatus)\nGeometry source: \(overlayGeometrySource)\n\(overlayLifecycleStatus)\nMoves: \(overlayMoveCount); ordering changes: \(overlayOrderCount); level changes: \(overlayLevelChangeCount).\n\nEvent history (uptime seconds):\n" + lifecycleTrace.joined(separator:"\n")),
            DiagnosticSection(title:"Placement & capture",body:lastLayout),
            DiagnosticSection(title:"Cache & background checks",body:"Last completed background check (may precede the current invocation):\n"+panelCheckStatus),
            DiagnosticSection(title:"Performance",body:lastTiming)
        ]
    }
}
