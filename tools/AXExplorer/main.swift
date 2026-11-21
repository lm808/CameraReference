import AppKit
import ApplicationServices

// Standalone read-only investigation. No actions, attribute writes, capture or app activation.
let version = "1.0.5"
let relationships = ["AXSections", "AXChildren", "AXContents", "AXVisibleChildren", "AXChildrenInNavigationOrder"]
let scalars: Set<String> = ["AXRole", "AXSubrole", "AXIdentifier", "AXHidden", "AXVisible", "AXEnabled", "AXFocused", "AXMain", "AXMinimized", "AXModal", "AXFullScreen"]
struct Budget {
    var limit = 1000
    var depth = 8
    var seconds = 5.0
}
func parseBudget(_ args: [String]) -> Budget? {
    guard args.count == 3, let n = Int(args[0]), let d = Int(args[1]), let t = Double(args[2]),
          (1...10000).contains(n), (0...30).contains(d), t.isFinite, (0.1...30).contains(t) else { return nil }
    return Budget(limit:n, depth:d, seconds:t)
}
func safeLabel(_ label: String) -> String {
    let s = String(label.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" ? String($0) : "_" }.joined().prefix(80))
    return s.isEmpty ? "report" : s
}
func reportDirectory(executable:URL) -> URL {
    let folder=executable.deletingLastPathComponent()
    let staging=folder.deletingLastPathComponent()
    if folder.lastPathComponent=="AXExplorer",["release","build"].contains(staging.lastPathComponent) {
        return staging.deletingLastPathComponent().appendingPathComponent("investigations/ax-reports",isDirectory:true)
    }
    // If copied elsewhere, keep probe data beside the executable, never in app support.
    return folder.appendingPathComponent("ax-reports",isDirectory:true)
}
func toolbarDelay(_ value:String) -> Double? {
    guard let seconds=Double(value),seconds.isFinite,(1...60).contains(seconds) else { return nil }
    return seconds
}
func toolbarState(_ title: String) -> String {
    switch title.trimmingCharacters(in:.whitespacesAndNewlines).lowercased() {
    case "hide toolbar": return "visible (inferred from Hide Toolbar command)"
    case "show toolbar": return "hidden (inferred from Show Toolbar command)"
    default: return "unknown; inspect raw title/checkmark (no assumption from enabled state)"
    }
}
func toolbarCandidate(_ title:String,_ shortcut:String,_ modifiers:Int?) -> Bool {
    title.lowercased().contains("toolbar") || (shortcut.lowercased()=="t" && modifiers==8)
}
// Public semantic links only; never read window titles or invoke controls.
let titlebarControlLinks=["AXCloseButton","AXMinimizeButton","AXZoomButton","AXFullScreenButton","AXTitleUIElement","AXProxy"]
let titlebarContainerLinks=["AXParent","AXWindow","AXTopLevelUIElement"]
func titlebarWindowRows(_ rows:[[String:Any]],pid:pid_t)->String {
    rows.enumerated().compactMap { index,row -> String? in
        guard (row[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value==pid else { return nil }
        func value(_ key:CFString)->String { row[key as String].map { String(describing:$0) } ?? "unknown" }
        let frame=(row[kCGWindowBounds as String] as? [String:Any]).flatMap { CGRect(dictionaryRepresentation:$0 as CFDictionary) }
        return "CG index=\(index) id=\(value(kCGWindowNumber)) layer=\(value(kCGWindowLayer)) alpha=\(value(kCGWindowAlpha)) onScreen=\(value(kCGWindowIsOnscreen)) frame=\(frame.map { String(describing:$0) } ?? "unknown")"
    }.joined(separator:"\n")
}
if CommandLine.arguments.contains("--self-test") {
    precondition(parseBudget(["1000","8","5"]) != nil)
    for args in [["0","8","5"],["1000","31","5"],["1000","8","nan"],["1000","8","31"]] { precondition(parseBudget(args) == nil) }
    precondition(safeLabel("../../toolbar shown") == "______toolbar_shown")
    precondition(reportDirectory(executable:URL(fileURLWithPath:"/repo/release/AXExplorer/AXExplorer")).path == "/repo/investigations/ax-reports")
    precondition(reportDirectory(executable:URL(fileURLWithPath:"/repo/build/AXExplorer/AXExplorer")).path == "/repo/investigations/ax-reports")
    precondition(reportDirectory(executable:URL(fileURLWithPath:"/other/AXExplorer")).path == "/other/ax-reports")
    precondition(toolbarDelay("10") == 10)
    for value in ["0","61","nan","inf","oops"] { precondition(toolbarDelay(value) == nil) }
    precondition(toolbarState("Hide Toolbar").hasPrefix("visible"))
    precondition(toolbarState("Show Toolbar").hasPrefix("hidden"))
    precondition(toolbarState("Show/Hide Toolbar").hasPrefix("unknown"))
    precondition(toolbarCandidate("Other language","t",8))
    precondition(!toolbarCandidate("Other action","t",0))
    let probeRows:[[String:Any]]=[
        [kCGWindowNumber as String:7,kCGWindowOwnerPID as String:42,kCGWindowName as String:"PRIVATE",kCGWindowAlpha as String:0],
        [kCGWindowNumber as String:8,kCGWindowOwnerPID as String:43]]
    let probeText=titlebarWindowRows(probeRows,pid:42)
    precondition(probeText.contains("id=7") && probeText.contains("alpha=0"))
    precondition(!probeText.contains("PRIVATE") && !probeText.contains("id=8"))
    precondition(titlebarControlLinks.contains("AXCloseButton") && titlebarContainerLinks.contains("AXWindow"))
    print("PASS: title-bar metadata privacy/owner filtering; toolbar classification, explorer limits and safe report labels; no live AX calls.")
    exit(0)
}

final class Explorer {
    var nodes = [AXUIElement]()
    var paths = [String]()
    var skipped = Set<Int>()
    var budget = Budget()
    var transcript = "AX Explorer \(version)\nCoordinates: global top-left points. No screenshots or control values. Toolbar command reads menu titles only.\n"
    var pid: pid_t?
    var mainID: Int?
    var partial = false
    var deadline = Double.greatestFiniteMagnitude
    var relationEntries = 0
    var relationClipped = false
    func emit(_ text: String) { print(text); transcript += text + "\n" }
    func read(_ node: AXUIElement, _ key: String) -> (CFTypeRef?, AXError) {
        guard ProcessInfo.processInfo.systemUptime < deadline else { partial = true; return (nil,.cannotComplete) }
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(node,key as CFString,&value)
        return (value,status)
    }
    func add(_ node: AXUIElement, _ path: String) -> Int? {
        if let n = nodes.firstIndex(where:{ CFEqual($0,node) }) { return n }
        guard nodes.count < 20000 else { partial = true; return nil }
        AXUIElementSetMessagingTimeout(node,0.03)
        nodes.append(node); paths.append(path)
        return nodes.count - 1
    }
    func rect(_ node: AXUIElement) -> CGRect? {
        guard let p=read(node,"AXPosition").0, let s=read(node,"AXSize").0,
              CFGetTypeID(p)==AXValueGetTypeID(), CFGetTypeID(s)==AXValueGetTypeID() else { return nil }
        var point=CGPoint.zero,size=CGSize.zero
        guard AXValueGetValue(unsafeBitCast(p,to:AXValue.self),.cgPoint,&point),
              AXValueGetValue(unsafeBitCast(s,to:AXValue.self),.cgSize,&size) else { return nil }
        return CGRect(origin:point,size:size)
    }
    func summary(_ id: Int) -> String {
        let role=read(nodes[id],"AXRole").0 as? String ?? "unknown"
        return "N\(id) \(role) frame=\(rect(nodes[id]).map{String(describing:$0)} ?? "unavailable")\(skipped.contains(id) ? " [branch skipped]":"") via=\(paths[id])"
    }
    // Traverse nested section dictionaries without dumping their string payloads.
    func links(_ raw: CFTypeRef?, _ path: String) -> [(AXUIElement,String)] {
        relationEntries=0; relationClipped=false
        var result=[(AXUIElement,String)]()
        func walk(_ v: Any,_ p: String,_ depth: Int) {
            guard relationEntries<2000,depth<=6,ProcessInfo.processInfo.systemUptime<deadline else { relationClipped=true;return }
            relationEntries += 1
            let cf=v as CFTypeRef
            if CFGetTypeID(cf)==AXUIElementGetTypeID() { result.append((unsafeBitCast(cf,to:AXUIElement.self),p));return }
            if let d=v as? [String:Any] {
                for key in d.keys.sorted() { walk(d[key]!,p+"."+key,depth+1) }
            } else if let a=v as? [Any] {
                for (i,item) in a.enumerated() { walk(item,p+"[\(i)]",depth+1);if relationClipped { break } }
            }
        }
        if let raw { walk(raw,path,0) }
        return result
    }
    func related(_ id: Int,_ key: String) -> [Int] {
        let (raw,status)=read(nodes[id],key)
        let found=links(raw,key)
        var ids=[Int]()
        for (element,path) in found {
            if let n=add(element,"N\(id)."+path) { ids.append(n) }
        }
        if relationClipped { partial=true }
        emit("N\(id).\(key): status=\(status.rawValue); refs=\(ids.map{"N\($0)"}.joined(separator:","))\(relationClipped ? "; payload traversal capped":"")")
        return ids
    }
    func refresh() {
        guard AXIsProcessTrusted() else { emit("Accessibility not granted. Use 'permission', grant access in System Settings, then 'refresh'. No Screen Recording permission needed.");return }
        guard let app=NSWorkspace.shared.runningApplications.first(where:{ $0.bundleIdentifier?.hasPrefix("com.adobe.LightroomClassic") == true || $0.localizedName == "Adobe Lightroom Classic" }) else { emit("Lightroom is not running.");return }
        nodes=[];paths=[];skipped=[];mainID=nil;pid=app.processIdentifier
        let root=AXUIElementCreateApplication(app.processIdentifier)
        _=add(root,"application")
        emit("\nREFRESH \(Date()) pid=\(app.processIdentifier). IDs and skips reset; earlier transcript retained.")
        mainID=related(0,"AXMainWindow").first
        _=related(0,"AXFocusedWindow")
        let windows=related(0,"AXWindows")
        for id in windows { emit(summary(id)) }
        if let mainID { emit("Main window: N\(mainID)") }
    }
    func inspect(_ id: Int) {
        emit(summary(id))
        var names: CFArray?
        let status=AXUIElementCopyAttributeNames(nodes[id],&names)
        emit("Attributes status=\(status.rawValue): \((names as? [String] ?? []).sorted().joined(separator:", "))")
        for key in scalars.sorted() {
            let (value,status)=read(nodes[id],key)
            emit("  \(key): \(value.map{String(describing:$0)} ?? "unavailable") [\(status.rawValue)]")
        }
        _=related(id,"AXParent")
        for key in relationships { _=related(id,key) }
    }
    func scan(_ root: Int) {
        let start=ProcessInfo.processInfo.systemUptime
        deadline=start+budget.seconds;partial=false
        defer { deadline=Double.greatestFiniteMagnitude }
        let before=mainID.flatMap{rect(nodes[$0])}
        var queue=[(root,0)],visited=Set<Int>(),cursor=0,depthStops=[Int](),pruned=[Int]()
        // Breadth-first traversal prioritises roots and direct section relationships.
        while cursor<queue.count, visited.count<budget.limit, ProcessInfo.processInfo.systemUptime<deadline {
            let (id,depth)=queue[cursor];cursor += 1
            guard visited.insert(id).inserted else { continue }
            emit(summary(id))
            if skipped.contains(id) { pruned.append(id);continue }
            if depth>=budget.depth { depthStops.append(id);continue }
            for key in relationships {
                for n in related(id,key) where !visited.contains(n) { queue.append((n,depth+1)) }
            }
            if id==0 { for n in related(id,"AXWindows") where !visited.contains(n) { queue.append((n,depth+1)) } }
        }
        let timedOut=ProcessInfo.processInfo.systemUptime>=deadline
        deadline=Double.greatestFiniteMagnitude
        let after=mainID.flatMap{rect(nodes[$0])}
        let remaining=Set(queue.dropFirst(cursor).map{$0.0}).subtracting(visited).sorted()
        emit("SCAN END examined=\(visited.count), elapsed=\(String(format:"%.2f",ProcessInfo.processInfo.systemUptime-start))s, timeLimit=\(timedOut), elementLimit=\(!remaining.isEmpty && visited.count>=budget.limit), partialPayload=\(partial)")
        emit("Unexplored queued nodes: \(remaining.map{"N\($0)"}.joined(separator:","))\nDepth-limited nodes: \(depthStops)\nExplicitly pruned nodes: \(pruned)")
        emit("Host before=\(String(describing:before)); after=\(String(describing:after)); unchanged=\(before != nil && before==after). IDs are session-local, not stable selectors.")
    }
    func delayedTitlebar(_ args:[String]) {
        guard args.count<=1,let seconds=toolbarDelay(args.first ?? "10") else { emit("Use titlebar-after [SECONDS], 1–60 seconds.");return }
        guard let pid,!nodes.isEmpty else { emit("Run refresh first.");return }
        emit("Title-bar probe in \(seconds)s. Switch to Lightroom and hold the desired title-bar state. Keep it steady until delay + \(budget.seconds)s has elapsed. No actions or screenshots.")
        fflush(stdout);Thread.sleep(forTimeInterval:seconds)
        guard AXIsProcessTrusted(),NSWorkspace.shared.frontmostApplication?.processIdentifier==pid else {
            emit("TITLEBAR skipped: Accessibility unavailable or Lightroom not frontmost. No visibility conclusion.");return
        }
        let start=ProcessInfo.processInfo.systemUptime
        deadline=start+budget.seconds;partial=false
        defer {
            let timedOut=ProcessInfo.processInfo.systemUptime>=deadline
            deadline=Double.greatestFiniteMagnitude
            emit("TITLEBAR END elapsed=\(String(format:"%.2f",ProcessInfo.processInfo.systemUptime-start))s timeLimit=\(timedOut) partial=\(partial) frontmostAfter=\(NSWorkspace.shared.frontmostApplication?.processIdentifier==pid). Missing/partial evidence is inconclusive.")
        }
        emit("TITLEBAR \(Date()) pid=\(pid); semantic controls and ancestors; no geometry classification. IDs remain session-local.")
        func cg(_ phase:String) {
            emit("CG \(phase): optionAll API order (not asserted stacking order)")
            if let rows=CGWindowListCopyWindowInfo([.optionAll,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] {
                emit(titlebarWindowRows(rows,pid:pid))
            } else { emit("CG unavailable") }
        }
        cg("before")
        let root=AXUIElementCreateApplication(pid)
        guard let rootID=add(root,"titlebar.application") else { partial=true;return }
        let main=related(rootID,"AXMainWindow")
        let windows=related(rootID,"AXWindows")
        var queue=(main+windows).map { ($0,0) },seen=Set<Int>(),cursor=0
        while cursor<queue.count,seen.count<budget.limit,ProcessInfo.processInfo.systemUptime<deadline {
            let (id,depth)=queue[cursor];cursor += 1
            guard seen.insert(id).inserted else { continue }
            emit(summary(id))
            var names:CFArray?
            let status=AXUIElementCopyAttributeNames(nodes[id],&names)
            emit("N\(id) attributes status=\(status.rawValue): \((names as? [String] ?? []).sorted().joined(separator:", "))")
            for key in scalars.sorted() {
                let (value,result)=read(nodes[id],key)
                emit("N\(id).\(key)=\(value.map { String(describing:$0) } ?? "unavailable") status=\(result.rawValue)")
            }
            guard depth<min(budget.depth,4) else { partial=true;continue }
            let role=read(nodes[id],"AXRole").0 as? String
            // Do not walk unrelated sidebar children or the application's full tree.
            let keys=(role=="AXWindow" ? titlebarControlLinks:[]) + titlebarContainerLinks
            for key in keys {
                for child in related(id,key) where child != rootID && !seen.contains(child) { queue.append((child,depth+1)) }
            }
        }
        if cursor<queue.count { partial=true }
        emit("TITLEBAR examined=\(seen.count) remaining=\(queue.count-cursor); controls may remain attached to the main AX window even when drawn in separate CG chrome.")
        cg("after")
    }

    func delayedToolbar(_ args:[String]) {
        guard let seconds=toolbarDelay(args.first ?? "10") else { emit("Use toolbar-after SECONDS [MENU-TITLE], with 1–60 seconds.");return }
        guard let pid,!nodes.isEmpty else { emit("Run refresh first.");return }
        let menu=args.count>1 ? args.dropFirst().joined(separator:" "):"View"
        emit("Reading toolbar menu in \(seconds) seconds. Switch to Lightroom now; leave its menus closed. Ctrl-C cancels the explorer.")
        fflush(stdout)
        Thread.sleep(forTimeInterval:seconds)
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else {
            emit("DELAYED TOOLBAR \(Date()): Lightroom is not frontmost; reading skipped. Visibility unknown. Retry toolbar-after when ready.");return
        }
        toolbar(menu)
    }
    func toolbar(_ menuTitle:String) {
        guard let pid,!nodes.isEmpty else { emit("Run refresh first.");return }
        guard NSRunningApplication(processIdentifier:pid)?.isTerminated == false else { emit("Lightroom process ended; run refresh.");return }
        guard AXIsProcessTrusted() else { emit("Accessibility unavailable; use permission then refresh.");return }
        let frontmostBefore=NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
        let start=ProcessInfo.processInfo.systemUptime
        deadline=start+budget.seconds;partial=false
        defer {
            deadline=Double.greatestFiniteMagnitude
            let frontmostAfter=NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
            emit("Lightroom frontmost: before=\(frontmostBefore), after=\(frontmostAfter). \(frontmostBefore && frontmostAfter ? "Active at both samples; menu freshness still requires comparison.":"Focus was not confirmed at both samples; do not rely on this reading as a live visibility state.")")
        }
        var failures=0
        func query(_ node:AXUIElement,_ key:String)->(CFTypeRef?,AXError) {
            AXUIElementSetMessagingTimeout(node,0.03)
            let result=read(node,key)
            if result.1 != .success && result.1 != .attributeUnsupported && result.1 != .noValue { failures += 1 }
            return result
        }
        func children(_ node:AXUIElement,_ key:String)->[AXUIElement] {
            let (raw,status)=query(node,key)
            if status != .success { emit("Menu relationship \(key): status=\(status.rawValue)") }
            let result=links(raw,key).map{$0.0}
            partial = partial || relationClipped
            return result
        }
        func string(_ node:AXUIElement,_ key:String)->String { query(node,key).0 as? String ?? "" }
        func quoted(_ value:String)->String { String(reflecting:String(value.prefix(240))) }
        emit("TOOLBAR MENU READ \(Date()); menu=\(quoted(menuTitle)); read-only; no menu opening or actions.")
        let before=mainID.flatMap{rect(nodes[$0])}
        let bars=children(nodes[0],"AXMenuBar")
        let top=bars.flatMap{children($0,"AXChildren")}
        let named=top.map{($0,string($0,"AXTitle"))}
        let matches=named.filter{$0.1.caseInsensitiveCompare(menuTitle) == .orderedSame}
        guard matches.count==1 else {
            emit("Toolbar visibility unknown: expected one matching menu; found \(matches.count). Available menu titles: \(named.map{quoted($0.1)}.joined(separator:", ")). For another language use toolbar MENU-TITLE.");return
        }
        var queue=[(matches[0].0,0)],seen=[AXUIElement](),cursor=0,candidates=0,depthStops=0
        while cursor<queue.count,seen.count<budget.limit,ProcessInfo.processInfo.systemUptime<deadline {
            let (node,depth)=queue[cursor];cursor += 1
            if seen.contains(where:{CFEqual($0,node)}) { continue }
            seen.append(node)
            let role=string(node,"AXRole")
            if role=="AXMenuItem" {
                let title=string(node,"AXTitle")
                let (charRaw,charStatus)=query(node,"AXMenuItemCmdChar")
                let char=charRaw as? String ?? ""
                let (modsRaw,modsStatus)=query(node,"AXMenuItemCmdModifiers")
                let mods=(modsRaw as? NSNumber)?.intValue
                if toolbarCandidate(title,char,mods) {
                    candidates += 1
                    emit("Candidate \(candidates): title=\(quoted(title)); title-derived state=\(toolbarState(title))")
                    emit("  shortcut=\(quoted(char)) [\(charStatus.rawValue)]; modifiers=\(mods.map{String($0)} ?? "unavailable") [\(modsStatus.rawValue)] (8 means no Command modifier)")
                    for key in ["AXMenuItemMarkChar","AXEnabled","AXIdentifier"] {
                        let (raw,status)=query(node,key)
                        let rendered=raw.map{quoted(String(describing:$0))} ?? "unavailable"
                        emit("  \(key)=\(rendered) [\(status.rawValue)]")
                    }
                }
            }
            if depth>=budget.depth { depthStops += 1;continue }
            for child in children(node,"AXChildren") { queue.append((child,depth+1)) }
        }
        let timedOut=ProcessInfo.processInfo.systemUptime>=deadline
        deadline=Double.greatestFiniteMagnitude
        let after=mainID.flatMap{rect(nodes[$0])}
        emit("TOOLBAR END candidates=\(candidates), examined=\(seen.count), elapsed=\(String(format:"%.2f",ProcessInfo.processInfo.systemUptime-start))s, timeLimit=\(timedOut), queuedRemaining=\(queue.count-cursor), depthStops=\(depthStops), partialPayload=\(partial), readErrors=\(failures)")
        emit("Host before=\(String(describing:before)); after=\(String(describing:after)). No candidate or multiple candidates is inconclusive. Menu state freshness must be tested with the menu closed.")
    }
    func save(_ label: String) {
        let directory=reportDirectory(executable:URL(fileURLWithPath:CommandLine.arguments[0]).standardizedFileURL.resolvingSymlinksInPath())
        let stamp=ISO8601DateFormatter().string(from:Date()).replacingOccurrences(of:":",with:"-")
        let file=directory.appendingPathComponent("\(stamp)-\(safeLabel(label))-\(UUID().uuidString.prefix(6)).txt")
        do {
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            try transcript.write(to:file,atomically:true,encoding:.utf8)
            emit("Saved: \(file.path)")
        } catch { emit("Save failed: \(error.localizedDescription)") }
    }
    func run() {
        emit("AX Explorer \(version) — read-only. Type help. No permission prompt until 'permission'.")
        emit("Default scan budget: 1000 elements, depth 8, 5 seconds. Run 'refresh' to connect.")
        while true {
            print("ax> ",terminator:"");fflush(stdout)
            guard let line=readLine() else { return }
            let parts=line.split(whereSeparator:{$0.isWhitespace}).map(String.init)
            guard let cmd=parts.first else { continue }
            transcript += "\n> \(line)\n"
            let raw=parts.count>1 ? parts[1]:""
            let id=raw=="main" ? mainID:Int(raw.hasPrefix("N") ? String(raw.dropFirst()):raw)
            switch cmd {
            case "quit","exit": return
            case "help": emit("""
refresh                 Connect/reconnect; list Lightroom windows; reset IDs/skips
windows                 Refresh AXWindows list (same session IDs)
toolbar [MENU-TITLE]    Read toolbar command in View menu, without opening it
titlebar-after [SEC]     Delayed semantic title-bar controls/parents and CG metadata
toolbar-after [SEC] [MENU-TITLE]  Wait (default 10s), then read only if Lightroom is active
node N                  Role, frame, safe attributes, parent and relationships
children N              List direct children
sections N              Follow AXSections (including nested dictionaries)
scan [N|main]           Bounded tree scan; default application N0
skip N / unskip N       Prune/unprune this node wherever reached during scans
skips                   Show pruning list
limits COUNT DEPTH SEC  Adjust without recompiling (max 10000 / 30 / 30)
note TEXT               Add test conditions to report
save LABEL              Save report under the development worktree’s investigations/ax-reports
clear                   Start a new report; keeps current IDs and skips
permission              Request Accessibility access; then use refresh
quit                    Exit (save first if wanted)
No actions or attribute writes. Only toolbar command reads menu titles; other text/values omitted.
""")
            case "permission":
                let options=[kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary
                emit("Accessibility granted: \(AXIsProcessTrustedWithOptions(options)). If unchanged, check System Settings for this executable or Terminal; restart explorer if necessary.")
            case "refresh": refresh()
            case "toolbar": toolbar(parts.count>1 ? parts.dropFirst().joined(separator:" "):"View")
            case "titlebar-after": delayedTitlebar(Array(parts.dropFirst()))
            case "toolbar-after": delayedToolbar(Array(parts.dropFirst()))
            case "limits":
                if let next=parseBudget(Array(parts.dropFirst())) { budget=next;emit("Limits: \(next.limit) elements, depth \(next.depth), \(next.seconds)s") }
                else { emit("Use limits COUNT DEPTH SEC: 1–10000, 0–30, 0.1–30.") }
            case "save": save(parts.dropFirst().joined(separator:" "))
            case "note": emit("NOTE \(Date()): "+parts.dropFirst().joined(separator:" "))
            case "clear": transcript="AX Explorer \(version)\nNew report: \(Date())\n";emit("Report cleared. Current IDs/skips retained: \(skipped.sorted())")
            case "skips": emit("Skipped branches: \(skipped.sorted())")
            default:
                guard !nodes.isEmpty else { emit("Run refresh first.");continue }
                let target=(cmd=="scan" && raw.isEmpty) || cmd=="windows" ? 0:id
                guard let n=target,n>=0,n<nodes.count else { emit("Unknown ID. Use an N-number from this session, or main.");continue }
                switch cmd {
                case "windows": for child in related(0,"AXWindows") { emit(summary(child)) }
                case "node": inspect(n)
                case "children","sections": for child in related(n,cmd=="children" ? "AXChildren":"AXSections") { emit(summary(child)) }
                case "skip": skipped.insert(n);emit("Will skip descendants of N\(n). Explicit node/children commands still work.")
                case "unskip": skipped.remove(n);emit("Unskipped N\(n).")
                case "scan": scan(n)
                default: emit("Unknown command. Type help.")
                }
            }
        }
    }
}
Explorer().run()
