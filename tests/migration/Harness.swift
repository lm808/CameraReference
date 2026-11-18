import AppKit
import ImageIO

// UUID suite/temp directory: never writes the real shared preferences or bridge.
enum MigrationEnvironment {
    static let suite = "org.local.CameraReference.tests.migration.\(UUID().uuidString)"
    static let preferences = UserDefaults(suiteName:suite)!
    static let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    static let bridge = root.appendingPathComponent("Bridge")
    static var loadCompletions = 0 // accessed only on the main actor/queue
}
func expect(_ condition: @autoclosure () -> Bool, _ message:String) {
    if !condition() {
        MigrationEnvironment.preferences.removePersistentDomain(forName:MigrationEnvironment.suite)
        try? FileManager.default.removeItem(at:MigrationEnvironment.root)
        fatalError(message)
    }
}
func writeBridge(_ name:String,_ value:String) throws {
    try value.write(to:MigrationEnvironment.bridge.appendingPathComponent(name),atomically:true,encoding:.utf8)
}
func heartbeat(_ module:String) throws { try writeBridge("heartbeat.txt","Running 0.5.3\n\(module)\nEND\n") }
func selection(_ epoch:String) throws { try writeBridge("selection.txt","\(epoch)\nEND\n") }

@main struct MigrationTests {
    @MainActor static func main() async throws {
        let fm=FileManager.default, prefs=MigrationEnvironment.preferences
        try fm.createDirectory(at:MigrationEnvironment.bridge,withIntermediateDirectories:true)
        defer {
            prefs.removePersistentDomain(forName:MigrationEnvironment.suite)
            try? fm.removeItem(at:MigrationEnvironment.root)
        }
        let app=AppDelegate() // no NSApplication.shared, launch callback, panels or timers started
        expect(app.axPlacementEnabled && app.automaticViewEnabled && app.axLiveUpdate,"Fresh defaults must remain AX, view inference and update enabled")
        for mode in AutomaticPlacementMode.allCases {
            prefs.set(mode.rawValue,forKey:"automaticPlacementMode")
            expect(app.automaticPlacementMode == mode,"Existing saved backend must survive")
        }
        prefs.removeObject(forKey:"automaticPlacementMode")
        prefs.set(false,forKey:"experimentalAXPlacement")
        expect(app.automaticPlacementMode == .screenshot,"Explicit legacy screenshot remains screenshot")
        prefs.removeObject(forKey:"experimentalAXPlacement")
        prefs.set(true,forKey:"useScreenshotDetection")
        for assist in [false,true] { for infer in [false,true] {
            prefs.set(assist,forKey:"screenshotAXAssistance");prefs.set(infer,forKey:"experimentalAutomaticView")
            expect(app.assistedPlacementEnabled == assist && app.automaticViewEnabled == infer,"Independent screenshot choices")
        } }
        prefs.set(false,forKey:"useScreenshotDetection")
        expect(app.automaticViewEnabled,"AX inference cannot be disabled by saved screenshot option")
        prefs.set(false,forKey:"axLiveUpdate")
        expect(!app.axLiveUpdate,"Explicit update-off survives")
        prefs.removeObject(forKey:"axLiveUpdate")
        expect(app.axLiveUpdate,"Unset update option defaults on")
        print("PASS migration: actual AppDelegate fresh/saved preference routing")

        try heartbeat("develop");try selection("A")
        expect(app.currentModule()=="develop" && app.selectionEpoch()=="A","Valid bridge samples")
        try writeBridge("heartbeat.txt","partial")
        expect(app.currentModule()=="develop","Partial heartbeat keeps fresh previous complete sample")
        app.lastModuleSample=("develop",Date(timeIntervalSinceNow:-10))
        expect(app.currentModule()==nil,"Expired previous heartbeat is uncertainty")
        try heartbeat("develop")
        try writeBridge("selection.txt","partial")
        expect(app.selectionEpoch()==nil,"Partial selection never establishes change")
        try selection("A")
        try writeBridge("response-selection.txt","token\nA\nEND\n")
        expect(app.responseEpoch("other")==nil && app.responseEpoch("token")=="A","Response epoch belongs to token")
        print("PASS migration: actual bridge read freshness and partial-write behaviour")

        let context=CGContext(data:nil,width:8,height:6,bitsPerComponent:8,bytesPerRow:32,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(NSColor.red.cgColor);context.fill(CGRect(x:0,y:0,width:8,height:6))
        let jpeg=MigrationEnvironment.root.appendingPathComponent("fixture.jpg")
        let destination=CGImageDestinationCreateWithURL(jpeg as CFURL,"public.jpeg" as CFString,1,nil)!
        CGImageDestinationAddImage(destination,context.makeImage()!,nil)
        expect(CGImageDestinationFinalize(destination),"Synthetic JPEG fixture")

        let raw=MigrationEnvironment.root.appendingPathComponent("fixture.dng")
        try Data("Synthetic paired source; never parsed as RAW".utf8).write(to:raw)
        prefs.set(false,forKey:"preferEmbedded")

        // Main-actor setup/mutation happens before queued load completion can run.
        func begin(_ token:String) throws -> Cancellation {
            try heartbeat("develop");try selection("A")
            try writeBridge("response-selection.txt","\(token)\nA\nEND\n")
            let work=Cancellation()
            app.pending=token;app.pendingModule="develop";app.cancellation=work;app.destination = .check
            app.lastImageSize=nil;app.lastTiming="sentinel"
            app.load(raw.path,token:token,target:.check,work:work,invoked:ProcessInfo.processInfo.systemUptime)
            return work
        }
        func complete(after old:Int) async throws {
            for _ in 0..<500 {
                if MigrationEnvironment.loadCompletions>old { return }
                try await Task.sleep(nanoseconds:10_000_000)
            }
            fatalError("Load completion did not arrive")
        }
        for mutation in ["cancel","dismiss","replace token","selection","module","uncertain module"] {
            let old=MigrationEnvironment.loadCompletions
            let work=try begin(UUID().uuidString)
            switch mutation {
            case "cancel": app.cancelRequest()
            case "dismiss": app.destination = .overlay;app.hide()
            case "replace token": app.pending="newer-request"
            case "selection": try selection("B")
            case "module": try heartbeat("library")
            default:
                try writeBridge("heartbeat.txt","partial")
                app.lastModuleSample=nil
            }
            try await complete(after:old)
            expect(app.lastImageSize==nil && app.lastTiming=="sentinel","Stale completion applied after \(mutation)")
            expect(app.panel==nil && app.floating==nil,"Completion opened a display after \(mutation)")
            if mutation=="replace token" { expect(app.pending=="newer-request","Old completion consumed new request") }
            if mutation=="cancel" || mutation=="dismiss" { expect(work.isCancelled,"Worker cancellation propagated") }
            app.cancelRequest()
        }
        print("PASS migration: real async load rejects cancellation/dismissal/token/selection/module changes")

        // Accepted check-only path runs decode and then a real warm cache hit; never displays UI.
        for round in 0..<2 {
            let old=MigrationEnvironment.loadCompletions
            _=try begin("warm-\(round)")
            try await complete(after:old)
            expect(app.lastImageSize==CGSize(width:8,height:6),"Unchanged request accepts decoded JPEG")
            if round==1 { expect(app.lastTiming.contains("RAM cache hit"),"Warm request must reuse RAM") }
        }
        // Independent photo bytes remain cached when only the request is cancelled.
        app.cancelRequest()
        let old=MigrationEnvironment.loadCompletions
        _=try begin("warm-after-cancel")
        try await complete(after:old)
        expect(app.lastTiming.contains("RAM cache hit"),"Cancellation must not flush selection image cache")
        print("PASS migration: actual load/decode and warm-cache path; no latency claim")

        // Calls exercise early absent-overlay guards, not a duplicated policy model.
        app.checkOverlaySelection("B")
        app.followLiveOverlayView(.left,module:"develop",panelChange:true)
        expect(app.panel==nil && app.pending==nil,"Monitoring must not open an absent overlay")
        app.hide();app.hide()
        expect(app.panel==nil && app.overlayEpoch==nil && !app.overlaySuspended,"Repeated absent dismissal is safe")
        print("PASS migration: off-overlay guards and repeated dismissal")

        // No live Lightroom reads: report permissions are non-prompting preflights.
        // Omit heartbeat timestamp to make exact renderer comparison deterministic.
        try fm.removeItem(at:MigrationEnvironment.bridge.appendingPathComponent("heartbeat.txt"))
        app.lastAXMapping="Synthetic map";app.lastAXToolbar="Synthetic toolbar"
        app.lastPlacementFailure="Retained failure";app.lastTiming="Measured sample"
        app.assistedChecks=3;app.assistedAXSeconds=0.02;app.assistedCheckSeconds=0.05
        for mode in [false,true] {
            prefs.set(mode,forKey:"useScreenshotDetection")
            expect(diagnosticReport(app.diagnosticSections()) == diagnosticReport(app.baselineDiagnosticSections()),"Report must match frozen 1.0.32 formatter")
        }
        let reportURL=MigrationEnvironment.root.appendingPathComponent("Diagnostics/latest.txt")
        var generated=0,failures=0
        func sections()->[DiagnosticSection] { generated += 1;return app.diagnosticSections() }
        app.diagnostics.save(enabled:false,url:reportURL,sections:sections,failure:{ _ in failures += 1 })
        expect(generated==0 && !fm.fileExists(atPath:reportURL.path),"Disabled saving must do no report work")
        app.diagnostics.save(enabled:true,url:reportURL,sections:sections,failure:{ _ in failures += 1 })
        let first=try String(contentsOf:reportURL,encoding:.utf8)
        expect(first.contains(app.diagnosticSaveStatus) && first.contains("Retained failure"),"Saved status and retained failure are included in the same report")
        app.lastResult="Replacement result"
        app.diagnostics.save(enabled:true,url:reportURL,sections:sections,failure:{ _ in failures += 1 })
        let replacement=try String(contentsOf:reportURL,encoding:.utf8)
        expect(replacement == diagnosticReport(app.diagnosticSections()),"Latest report replaces previous content")
        let blocked=MigrationEnvironment.root.appendingPathComponent("not-a-directory")
        try Data().write(to:blocked)
        app.diagnostics.save(enabled:true,url:blocked.appendingPathComponent("latest.txt"),sections:sections,failure:{ _ in failures += 1 })
        expect(failures==1 && generated==2 && app.diagnosticSaveStatus.hasPrefix("Could not save diagnostics:"),"Save failure preserves original error reporting")
        app.axTrialGeneration=7;app.clearAXTrialBorders()
        expect(app.diagnostics.axTrialGeneration==8 && app.axTrialBorders.isEmpty,"Clearing diagnostic borders invalidates late preview work")
        expect(app.diagnostics.lastResult=="Replacement result","Adapter and service share one state owner")
        print("PASS migration: frozen report equivalence, save off/on/replace/failure and preview invalidation")
    }
}
