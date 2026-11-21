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
        // Geometry adapters are read-free; test both target-pane and combined
        // floating requests with translated and negative display coordinates.
        for origin in [CGPoint.zero,CGPoint(x:-1080,y:-480),CGPoint(x:587,y:47)] {
            let panes=[CGRect(x:origin.x+20,y:origin.y+40,width:400,height:600),CGRect(x:origin.x+420,y:origin.y+40,width:400,height:600)]
            let proposal=AXTrialProposal(host:CGRect(origin:origin,size:CGSize(width:900,height:700)),panes:panes,layout:"Side-by-side",summary:"")
            for mode:OverlayLayout in [.full,.left,.right,.upper] {
                let original=axSelectedArea(proposal,layout:mode)
                let adapted=AXPlacement.selectedArea(proposal,layout:mode,primaryHeight:1440)
                expect(adapted?.topLeft == original,"AX selection retains exact top-left rectangle")
                expect(adapted?.placement.areaAppKit == original.map { appKitRect($0,primaryHeight:1440) },"AX conversion identical for pane/combined/invalid selection")
                if let ui=adapted?.placement.areaAppKit {
                    expect(floatingPhotoSize(viewport:ui.size,image:CGSize(width:6000,height:4000),settings:DetectionConfig()) == floatingPhotoSize(viewport:original!.size,image:CGSize(width:6000,height:4000),settings:DetectionConfig()),"Floating combined-area Fit unchanged")
                }
            }
            let saved=CGRect(x:0,y:0,width:900,height:700),current=CGRect(origin:origin,size:saved.size)
            expect(ManualPlacement.translate(panes[0],from:saved,to:current)?.areaAppKit == translatedCalibration(panes[0],from:saved,to:current),"Manual translation forwards original geometry")
        }
        expect(UIPlacement(probe:ScreenProbeResult(candidate:nil,summary:"failure")) == nil,"Failed probe never invents UI geometry")
        print("PASS migration: placement adapters preserve AX pane/combined coordinates, manual translation and floating Fit")
        // Exercise real transport via manually fired timers: no five-second wait,
        // no application/Lightroom launch and no production bridge directory.
        let transportFolder=MigrationEnvironment.root.appendingPathComponent("transport")
        try fm.createDirectory(at:transportFolder,withIntermediateDirectories:true)
        let transport=PhotoRequestPipeline(folder:transportFolder)
        for target:Destination in [.overlay,.window,.check,.detect] {
            try transport.writeRequest(token:"request",target:target)
            let written=try String(contentsOf:transportFolder.appendingPathComponent("request.txt"),encoding:.utf8)
            expect(written == "request\n"+(target == .detect ? "check":target.rawValue),"Bridge request bytes unchanged")
        }
        var responses=0,timeouts=0
        func responseFile(_ text:String) throws { try text.write(to:transportFolder.appendingPathComponent("response.txt"),atomically:true,encoding:.utf8) }
        transport.pending="poll"
        transport.poll(token:"poll",deadline:Date().addingTimeInterval(5),onResponse:{ response in
            responses += 1
            expect(response.success && response.value=="x","Transport preserves decoded response")
            expect(transport.timer==nil,"Timer cleared before callback")
            expect(!fm.fileExists(atPath:transportFolder.appendingPathComponent("request.txt").path) && !fm.fileExists(atPath:transportFolder.appendingPathComponent("response.txt").path),"IPC removed before callback")
        },onTimeout:{ timeouts += 1 })
        expect(transport.timer!.timeInterval==0.05,"Polling cadence preserved")
        try responseFile("poll\nOK\n78");transport.timer!.fire()
        expect(responses==0 && timeouts==0,"Partial response ignored")
        try responseFile("other\nOK\n78\nEND\n");transport.timer!.fire()
        expect(responses==0 && timeouts==0,"Wrong token ignored")
        try responseFile("poll\nOK\n78\nEND\n");transport.timer!.fire()
        expect(responses==1 && timeouts==0,"Matching response delivered exactly once")
        transport.poll(token:"poll",deadline:.distantPast,onResponse:{ _ in fatalError("Unexpected response") },onTimeout:{ timeouts += 1;transport.cancel() })
        transport.timer!.fire()
        expect(timeouts==1 && transport.timer==nil && transport.pending==nil,"Timeout cancellation clears transport")
        transport.pending="old"
        transport.poll(token:"old",deadline:.distantPast,onResponse:{ _ in responses += 1 },onTimeout:{ timeouts += 1 })
        let oldTimer=transport.timer!;transport.pending="new";oldTimer.fire()
        expect(!oldTimer.isValid && transport.pending=="new" && timeouts==1,"Old timer cannot consume replacement request")
        let cancelledWork=Cancellation();transport.cancellation=cancelledWork;transport.destination = .overlay
        transport.cancel()
        expect(cancelledWork.isCancelled && transport.cancellation==nil && transport.destination==nil,"Cancellation reaches worker and clears state")
        print("PASS migration: pipeline request bytes, polling cadence, partial/wrong-token response, cleanup, timeout and replacement")
        // Isolated centers exercise actual subscription delivery and timers without
        // subscribing to the live workspace or invoking any native AX/capture calls.
        let monitor=LightroomMonitor(folder:MigrationEnvironment.bridge)
        let workspaceCenter=NotificationCenter(),applicationCenter=NotificationCenter()
        var events:[LightroomMonitor.Event]=[]
        monitor.start(workspaceCenter:workspaceCenter,applicationCenter:applicationCenter) { events.append($0) }
        expect(monitor.moduleTimer?.timeInterval==0.2,"Heartbeat cadence remains 0.2 seconds")
        monitor.moduleTimer?.fire()
        workspaceCenter.post(name:NSWorkspace.didActivateApplicationNotification,object:nil)
        workspaceCenter.post(name:NSWorkspace.activeSpaceDidChangeNotification,object:nil)
        applicationCenter.post(name:NSApplication.didChangeScreenParametersNotification,object:nil)
        expect(events == [.tick,.foregroundChanged,.spaceChanged,.displaysChanged],"Monitor signals arrive synchronously in source order")
        monitor.scheduleDisplayCheck()
        let oldDisplayTimer=monitor.displayTimer!
        expect(abs(oldDisplayTimer.fireDate.timeIntervalSinceNow-0.6)<0.1,"Display check debounce remains 0.6 seconds")
        monitor.scheduleDisplayCheck()
        expect(!oldDisplayTimer.isValid,"Repeated display change replaces the pending check")
        monitor.displayTimer?.fire()
        expect(events.last == .displayCheckSettled,"Display settle timer emits evidence rather than manipulating windows")
        let oldTick=monitor.moduleTimer!
        monitor.start(workspaceCenter:workspaceCenter,applicationCenter:applicationCenter) { events.append($0) }
        expect(!oldTick.isValid,"Restart replaces the heartbeat timer")
        events=[]
        workspaceCenter.post(name:NSWorkspace.didActivateApplicationNotification,object:nil)
        expect(events == [.foregroundChanged],"Restart does not duplicate subscriptions")
        monitor.stop();events=[]
        workspaceCenter.post(name:NSWorkspace.activeSpaceDidChangeNotification,object:nil)
        applicationCenter.post(name:NSApplication.didChangeScreenParametersNotification,object:nil)
        expect(events.isEmpty && monitor.moduleTimer==nil && monitor.displayTimer==nil,"Stopped monitor removes timers and subscriptions")
        let unknown=LightroomMonitor.AXEvidence(grid:nil,proposal:nil,hints:nil)
        expect(unknown.grid==nil && unknown.proposal==nil && unknown.hints==nil,"Unavailable evidence stays unknown")
        print("PASS migration: monitor event order, timer cadence, display debounce, restart and teardown")

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
            expect(app.screenshotAXDismissEnabled == infer,"Screenshot dismiss policy depends on inference, not assistance")
        } }
        prefs.set(false,forKey:"useScreenshotDetection")
        expect(app.automaticViewEnabled,"AX inference cannot be disabled by saved screenshot option")
        expect(!app.screenshotAXDismissEnabled,"Screenshot fallback policy never replaces Accessibility live policy")
        prefs.set(false,forKey:"axLiveUpdate")
        expect(!app.axLiveUpdate,"Explicit update-off survives")
        prefs.removeObject(forKey:"axLiveUpdate")
        expect(app.axLiveUpdate,"Unset update option defaults on")
        print("PASS migration: actual AppDelegate fresh/saved preference routing")

        try heartbeat("develop");try selection("A")
        expect(app.currentModule()=="develop" && app.selectionEpoch()=="A","Valid bridge samples")
        try writeBridge("heartbeat.txt","partial")
        expect(app.currentModule()=="develop","Partial heartbeat keeps fresh previous complete sample")
        app.lightroomMonitor.lastModuleSample=("develop",Date(timeIntervalSinceNow:-10))
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
            app.pending=token;app.photoRequests.pendingModule="develop";app.cancellation=work;app.destination = .check
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
                app.lightroomMonitor.lastModuleSample=nil
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

        // Presentation ownership must not couple dismissal to the independent float,
        // or leave a second copy of the host/selection state in the coordinator.
        app.floatingController.floatingTitle="Independent photo"
        app.floatingController.floatingZoom=125
        app.overlayController.overlayEpoch="displayed-selection"
        app.overlayController.livePanelSignature="displayed-panels"
        app.overlayController.displayedOverlayLayout = .right
        app.overlayController.overlaySuspended=true
        app.hide()
        expect(app.overlayController.overlayEpoch==nil && app.overlayController.livePanelSignature==nil && app.overlayController.displayedOverlayLayout==nil && !app.overlayController.overlaySuspended,"Dismissal clears owned displayed identity and suspension")
        expect(app.floatingController.floatingTitle=="Independent photo" && app.floatingController.floatingZoom==125,"Overlay dismissal leaves independent floating state intact")
        app.overlayController.lifecycleTrace=[];app.overlayController.lastLifecycleEvent=""
        for n in 0..<15 { app.recordLifecycle("event \(n)");app.recordLifecycle("event \(n)") }
        expect(app.overlayController.lifecycleTrace.count==12 && app.overlayController.lifecycleTrace.first!.hasSuffix("event 3") && app.overlayController.lifecycleTrace.last!.hasSuffix("event 14"),"Lifecycle history retains deduplication and bounded order")
        expect(OverlayController().overlayEpoch==nil && FloatingDisplayController().floatingTitle=="Camera Reference","Presentation owners do not share instance state")
        print("PASS migration: presentation ownership, independent floating state, dismissal and lifecycle history")

        // Calls exercise early absent-overlay guards, not a duplicated policy model.
        app.checkOverlaySelection("B")
        app.followLiveOverlayView(.left,module:"develop",panelChange:true)
        expect(app.panel==nil && app.pending==nil,"Monitoring must not open an absent overlay")
        app.hide();app.hide()
        expect(app.panel==nil && app.overlayController.overlayEpoch==nil && !app.overlayController.overlaySuspended,"Repeated absent dismissal is safe")
        print("PASS migration: off-overlay guards and repeated dismissal")

        // No live Lightroom reads: report permissions are non-prompting preflights.
        // Omit heartbeat timestamp to make exact renderer comparison deterministic.
        try fm.removeItem(at:MigrationEnvironment.bridge.appendingPathComponent("heartbeat.txt"))
        app.lastAXMapping="Synthetic map";app.lastAXToolbar="Synthetic toolbar"
        app.lastPlacementFailure="Retained failure";app.lastTiming="Measured sample"
        app.assistedChecks=3;app.assistedAXSeconds=0.02;app.assistedCheckSeconds=0.05
        for mode in [false,true] {
            prefs.set(mode,forKey:"useScreenshotDetection")
            expect(diagnosticReport(app.diagnosticSections()) == diagnosticReport(app.baselineDiagnosticSections()).replacingOccurrences(of:"Screenshot modes retain cache-invalidation behaviour.",with:"Screenshot with AX view detection dismisses on confirmed photo/view/pane/panel changes and Grid. Without AX view detection, existing cache-invalidation behaviour is retained."),"Report matches frozen formatter except the approved screenshot policy description")
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

        // Build menus without creating a status item, launching NSApplication,
        // invoking actions, or touching Lightroom. The targets remain AppDelegate.
        prefs.set(true,forKey:"migrated03") // avoid reading an external legacy suite
        let libraryFull="library."+regionPreferenceKey("automaticBounds",layout:.full)
        prefs.set(false,forKey:libraryFull)
        app.settings.registerAndMigrate()
        expect(!prefs.bool(forKey:libraryFull),"Registering defaults preserves explicit Library preference")
        for layout in OverlayLayout.allCases where layout != .full {
            expect(prefs.bool(forKey:"library."+regionPreferenceKey("automaticBounds",layout:layout)),"Library defaults registered for every pane")
        }
        try heartbeat("develop")
        let menu=app.menus.build()
        let settingsMenu=menu.items.first { $0.title=="Settings" }!.submenu!
        expect(settingsMenu.items.last?.title=="Advanced settings…","Advanced settings remains last")
        let titles=settingsMenu.items.filter { !$0.isSeparatorItem }.map(\.title)
        expect(Array(titles.prefix(6)) == ["Keyboard shortcuts…","Prefer RAW-embedded JPEG","Choose ExifTool…","Auto-detect viewing area","Set overlay region…","Clear overlay region setting"],"Settings order and titles unchanged")
        func verifyTargets(_ menu:NSMenu) {
            for item in menu.items {
                if item.submenu == nil && item.action != nil { expect(item.target === app,"Actions still target AppDelegate") }
                if let child=item.submenu { verifyTargets(child) }
            }
        }
        verifyTargets(menu)
        let developerMenu=menu.items.first { $0.title=="Developer tools" }!.submenu!
        expect(developerMenu.items.contains { $0.title=="Show AX placement preview" && $0.action == #selector(AppDelegate.toggleAXTrial) },"Accepted AX preview is directly accessible in Developer tools")
        expect(!developerMenu.items.contains { $0.title=="Experimental features" },"Empty experimental submenu is removed")
        for screenshot in [false,true] { for automatic in [false,true] {
            prefs.set(screenshot,forKey:"useScreenshotDetection")
            prefs.set(automatic,forKey:app.regionKey("automaticBounds"))
            app.updateDetectionMenu()
            expect(app.liveUpdateItem!.isHidden==screenshot,"AX live option visible only in Accessibility")
            expect(app.viewToggleItem!.isHidden == !screenshot && app.assistedToggleItem!.isHidden == !screenshot,"Screenshot options visible only in Screenshot")
            expect(app.liveUpdateItem!.isEnabled == (automatic && !screenshot),"AX option enablement unchanged")
            expect(app.viewToggleItem!.isEnabled == (automatic && screenshot),"Screenshot option enablement unchanged")
            expect(app.screenshotToggleItem!.isEnabled==automatic,"Manual placement disables method submenu")
            expect(app.validateMenuItem(app.liveUpdateItem!) == (automatic && !screenshot),"Validation agrees with enabled state")
        } }
        prefs.set(true,forKey:app.regionKey("automaticBounds"));prefs.set(false,forKey:"useScreenshotDetection")
        app.lightroomMonitor.detectedLayoutModule="develop";app.lightroomMonitor.detectedLayout = .left
        app.updateLayoutMenu()
        expect(menu.items.first?.isEnabled == false,"Version heading remains disabled")
        let root=app.menus.layoutRoot!
        func visibleChoices()->[String] { root.submenu?.items.filter { !$0.isHidden }.map(\.title) ?? [] }
        expect(root.title=="◧  Reference View (Left)" && root.state == .off,"Root shows pane without checkmark")
        expect(root.image === app.layoutItems[.left]!.image,"Root uses selected pane icon")
        expect(visibleChoices()==["◧  Left","◨  Right"],"Auto side-by-side offers two panes")
        expect(app.layoutItems[.left]!.state == .on,"Detected pane checked in submenu")
        for mode in OverlayLayout.allCases {
            app.lightroomMonitor.detectedLayout=mode;app.updateLayoutMenu()
            expect(root.state == .off && root.image === app.layoutItems[mode]!.image,"Each root icon follows selection without a tick")
            if mode == .full { expect(root.title=="▣  Loupe View" && root.submenu==nil && root.action==nil && root.isEnabled && !menu.autoenablesItems,"Automatic Loupe is normal but has no submenu/action") }
            else { expect(visibleChoices().count==2,"Automatic split has two choices") }
        }
        app.lightroomMonitor.detectedLayoutModule="library";app.updateLayoutMenu()
        expect(root.title=="View detected on next invocation" && root.submenu==nil && root.image==nil,"Unknown view does not imply confirmed selection")
        prefs.set(true,forKey:"useScreenshotDetection");prefs.set(false,forKey:"experimentalAutomaticView")
        let expectedTitles=["▣  Loupe View","◧  Reference View (Left)","◨  Reference View (Right)","⬒  Reference View (Top)","⬓  Reference View (Bottom)"]
        for mode in OverlayLayout.allCases {
            app.overlayLayout=mode; prefs.set(true,forKey:app.regionKey("automaticBounds"));app.updateLayoutMenu()
            expect(visibleChoices()==expectedTitles && root.title==app.layoutItems[mode]!.title,"Manual screenshot selection always offers all five")
            expect(root.state == .off && app.layoutItems[mode]!.state == .on,"Only child selection checked")
        }
        prefs.set(false,forKey:app.regionKey("automaticBounds"));app.updateLayoutMenu()
        expect(root.isHidden && app.menus.layoutSeparator!.isHidden,"Manual calibration keeps view menu hidden")
        verifyTargets(menu)
        print("PASS migration: settings defaults, menu order/targets, mode/manual visibility and inferred pane states")
    }
}
