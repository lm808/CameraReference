import AppKit
import ApplicationServices

/// Observations and scheduling only: never manipulates windows or decides policy.
/// Mutable state is main-thread owned; readLiveAX captures only value inputs on
/// the existing utility queue and delivers evidence on the main queue.
final class LightroomMonitor {
    enum Event { case tick, foregroundChanged, spaceChanged, displaysChanged, displayCheckSettled }
    struct AXEvidence {
        // nil distinguishes unavailable/not requested from a successful false/no-pair read.
        let grid:(selected:Bool?,report:String)?
        let proposal:AXTrialProposal?
        let hints:AXPanelState?
    }
    let folder:URL
    private(set) var moduleTimer:Timer?
    private(set) var displayTimer:Timer?
    private var subscriptions:[(NotificationCenter,NSObjectProtocol)]=[]
    private var receive:((Event)->Void)?
    var observedWindowFrame:CGRect?
    var hasObservedWindow=false
    var lastModuleSample: (String, Date)?
    var observedModule:String?
    var workspaceOverview=false
    var invocationPanelHints:AXPanelState?
    var detectedLayout:OverlayLayout?
    var detectedLayoutModule:String?
    var liveViewBusy=false
    var nextLiveViewCheck:TimeInterval=0
    var liveViewGeneration=0
    var panelCheckTask:Task<Void,Never>?
    var panelCheckID:UUID?
    var nextPanelCheck:TimeInterval=0
    var panelCheckStatus="Panel boundaries not yet checked in background."

    init(folder:URL) { self.folder=folder }
    func start(workspaceCenter:NotificationCenter,applicationCenter:NotificationCenter = .default,receive:@escaping (Event)->Void) {
        stop()
        self.receive=receive
        moduleTimer=Timer.scheduledTimer(withTimeInterval:0.2,repeats:true) { [weak self] _ in self?.receive?(.tick) }
        if let moduleTimer { RunLoop.main.add(moduleTimer,forMode:.common) }
        for (center,name,event) in [
            (workspaceCenter,NSWorkspace.didActivateApplicationNotification,Event.foregroundChanged),
            (workspaceCenter,NSWorkspace.activeSpaceDidChangeNotification,Event.spaceChanged),
            (applicationCenter,NSApplication.didChangeScreenParametersNotification,Event.displaysChanged)
        ] {
            let token=center.addObserver(forName:name,object:nil,queue:nil) { [weak self] _ in self?.receive?(event) }
            subscriptions.append((center,token))
        }
    }
    func scheduleDisplayCheck() {
        displayTimer?.invalidate()
        displayTimer=Timer.scheduledTimer(withTimeInterval:0.6,repeats:false) { [weak self] _ in self?.receive?(.displayCheckSettled) }
    }
    func stop() {
        moduleTimer?.invalidate();moduleTimer=nil
        displayTimer?.invalidate();displayTimer=nil
        for (center,token) in subscriptions { center.removeObserver(token) }
        subscriptions=[];receive=nil
    }
    deinit { stop() }
    func currentModule() -> String? {
        let url = folder.appendingPathComponent("heartbeat.txt")
        if let a = try? FileManager.default.attributesOfItem(atPath: url.path),
           let date = a[.modificationDate] as? Date, Date().timeIntervalSince(date) < 3,
           let text = try? String(contentsOf: url, encoding: .utf8) {
            let lines = text.components(separatedBy: "\n")
            if lines.count == 4, lines[2] == "END" { lastModuleSample = (lines[1], date) }
        }
        // A read can overlap a tiny heartbeat write. Keep the last complete sample until stale.
        guard let (module, date) = lastModuleSample, Date().timeIntervalSince(date) < 3 else { return nil }
        return module
    }
    func isLightroom() -> Bool {
        let app = NSWorkspace.shared.frontmostApplication
        return app?.bundleIdentifier?.hasPrefix("com.adobe.LightroomClassic") == true || app?.localizedName == "Adobe Lightroom Classic"
    }

    func readLiveAX(module:String?,axMode:Bool,checkPanels:Bool,checkGrid:Bool=false,fallback:String,viewSettings:DetectionConfig,completion:@escaping (AXEvidence)->Void) {
        DispatchQueue.global(qos:.utility).async {
            let grid=(axMode || checkGrid) ? accessibilityGridReading(module:module):nil
            let toolbarReading=checkPanels ? accessibilityToolbarReading(fallback:fallback,module:module):nil
            // AX placement retains its configured fallback. Screenshot dismissal
            // requires actual toolbar evidence; unavailable is not a panel change.
            let toolbar=axMode ? (toolbarReading?.effectiveState ?? "unknown"):toolbarReading?.shown.map { $0 ? "shown":"hidden" }
            var proposal:AXTrialProposal?,hints:AXPanelState?
            _=accessibilityMappingReport { host,windows,fullScreen in
                proposal=axTrialProposal(host:host,windows:windows,settings:viewSettings,fullScreen:fullScreen)
                if checkPanels,let toolbar { hints=AXPanelState(host:host,visibleFrames:windows.filter(\.visible).map(\.frame),toolbar:toolbar) }
            }
            let evidence=AXEvidence(grid:grid,proposal:proposal,hints:hints)
            DispatchQueue.main.async { completion(evidence) }
        }
    }
}
