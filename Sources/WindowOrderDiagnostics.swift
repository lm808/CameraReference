import AppKit

// Opt-in, bounded recording. No screenshots, AX reads, activation or window mutations.
// Main-thread sampling preserves the order of AppKit state and our ordering actions.
final class WindowOrderRecorder {
    private var timer:Timer?
    private var observers:[NSObjectProtocol]=[]
    private(set) var active=false
    private(set) var entries:[String]=[]
    private var started:TimeInterval=0
    private var sample:(()->String)?
    private var completion:((String)->Void)?
    static let delay:TimeInterval=5
    static let duration:TimeInterval=15
    static let interval:TimeInterval=0.1

    func start(sample:@escaping ()->String,completion:@escaping (String)->Void) {
        guard !active else { return }
        active=true;entries=[];started=ProcessInfo.processInfo.systemUptime
        self.sample=sample;self.completion=completion
        entries.append("Window ordering trace — \(ISO8601DateFormatter().string(from:Date()))\n5-second preparation, then 15 seconds sampled every 0.1 seconds. Actual elapsed timestamps are authoritative.\nCG rows: API-returned order, global top-left points. Snapshot list uses optionAll. AppKit frames/pointer: global bottom-left points.\nNo images, window titles, filenames or keystrokes collected. All owners included; absent rows/attributes are not evidence of invisibility.\n")
        for name in [NSWindow.didBecomeKeyNotification,NSWindow.didResignKeyNotification,NSWindow.didBecomeMainNotification,NSWindow.didResignMainNotification] {
            observers.append(NotificationCenter.default.addObserver(forName:name,object:nil,queue:.main) { [weak self] note in
                guard let w=note.object as? NSWindow else { return }
                self?.event("\(note.name.rawValue) id=\(w.windowNumber) level=\(w.level.rawValue)")
            })
        }
        event("armed")
        let timer=Timer(timeInterval:Self.interval,repeats:true) { [weak self] _ in self?.tick() }
        self.timer=timer;RunLoop.main.add(timer,forMode:.common)
    }
    func tick(now:TimeInterval=ProcessInfo.processInfo.systemUptime) {
        guard active else { return }
        let elapsed=now-started
        guard elapsed>=Self.delay else { return }
        if elapsed>=Self.delay+Self.duration { finish();return }
        event("SNAPSHOT\n"+(sample?() ?? "unavailable"))
    }
    func event(_ text:@autoclosure ()->String) {
        guard active,entries.count<4000 else { return }
        entries.append(String(format:"\n+%.3fs ",ProcessInfo.processInfo.systemUptime-started)+text())
    }
    private func finish() {
        event("recording complete")
        let result=entries.joined(separator:"\n"),callback=completion
        stop();entries=[];callback?(result)
    }
    func stop() {
        timer?.invalidate();timer=nil
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers=[];sample=nil;completion=nil;active=false
    }
    deinit { stop() }

    static func rows(_ rows:[[String:Any]])->String {
        rows.enumerated().map { index,row in
            func value(_ key:CFString)->String { row[key as String].map { String(describing:$0) } ?? "unknown" }
            let rect=(row[kCGWindowBounds as String] as? [String:Any]).flatMap { CGRect(dictionaryRepresentation:$0 as CFDictionary) }
            let owner=value(kCGWindowOwnerName).replacingOccurrences(of:"\n",with:" ")
            return "rank=\(index) id=\(value(kCGWindowNumber)) pid=\(value(kCGWindowOwnerPID)) owner=\(owner) level=\(value(kCGWindowLayer)) onScreen=\(value(kCGWindowIsOnscreen)) alpha=\(value(kCGWindowAlpha)) bounds=\(rect.map { String(describing:$0) } ?? "unknown")"
        }.joined(separator:"\n")
    }
}

extension AppDelegate {
    @objc func recordWindowOrdering() {
        let recorder=diagnostics.windowOrdering
        guard !recorder.active else { report("Window ordering recording already running; finishes 20 seconds after starting.");return }
        let stamp=ISO8601DateFormatter().string(from:Date()).replacingOccurrences(of:":",with:"-")
        let directory=diagnosticSaveURL.deletingLastPathComponent().appendingPathComponent("WindowOrdering")
        let url=directory.appendingPathComponent("window-order-\(stamp)-\(UUID().uuidString.prefix(8)).txt")
        let header="\(versionTitle)\nApp: \(Bundle.main.bundleURL.path)\nPID: \(ProcessInfo.processInfo.processIdentifier)\n"
        recorder.start(sample:{ [weak self] in self?.windowOrderSnapshot() ?? "App unavailable" },completion:{ [weak self] result in
            DispatchQueue.global(qos:.utility).async {
                let message:String
                do {
                    try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
                    try (header+result).write(to:url,atomically:true,encoding:.utf8)
                    message="Window ordering saved: \(url.path)"
                } catch { message="Window ordering save failed: \(error.localizedDescription)" }
                DispatchQueue.main.async { self?.report(message) }
            }
        })
        report("Window ordering: starts in 5 seconds, records for 15 seconds. Return to Lightroom and reproduce the issue. Saves under Diagnostics/WindowOrdering.")
    }
    private func windowOrderSnapshot()->String {
        func state(_ label:String,_ window:NSWindow?)->String {
            guard let w=window else { return "\(label): none" }
            let floating=(w as? NSPanel).map { String($0.isFloatingPanel) } ?? "n/a"
            return "\(label): id=\(w.windowNumber) level=\(w.level.rawValue) visible=\(w.isVisible) key=\(w.isKeyWindow) main=\(w.isMainWindow) floatingPanel=\(floating) alpha=\(w.alphaValue) frame=\(w.frame) collection=\(w.collectionBehavior.rawValue) parent=\(w.parent?.windowNumber.description ?? "none")"
        }
        let front=NSWorkspace.shared.frontmostApplication
        var lines=["frontmost pid=\(front?.processIdentifier.description ?? "unknown") app=\(front?.localizedName ?? "unknown"); pointer=\(NSEvent.mouseLocation); buttons=\(NSEvent.pressedMouseButtons)",
                   state("overlay",panel),state("floating",floating),
                   "Title-bar clip: \(overlayController.titlebarClipStatus); top=\(panel?.titlebarClipHeight ?? 0)",
                   "host id=\(overlayController.overlayHost?.id.description ?? "none"); cached AX: \(overlayController.overlayAccessibility?.diagnostic ?? "unavailable")",
                   "policy status (not verified stacking): \(overlayController.overlayVisibilityStatus)"]
        lines += axTrialBorders.map { state("AX border",$0) }
        if let rows=CGWindowListCopyWindowInfo([.optionAll,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] {
            lines.append(WindowOrderRecorder.rows(rows))
        } else { lines.append("CG window list unavailable") }
        return lines.joined(separator:"\n")
    }
}
