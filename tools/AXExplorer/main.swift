import AppKit
import ApplicationServices

// Standalone read-only investigation. No actions, attribute writes, capture or app activation.
let version = "1.0.0"
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
if CommandLine.arguments.contains("--self-test") {
    precondition(parseBudget(["1000","8","5"]) != nil)
    for args in [["0","8","5"],["1000","31","5"],["1000","8","nan"],["1000","8","31"]] { precondition(parseBudget(args) == nil) }
    precondition(safeLabel("../../toolbar shown") == "______toolbar_shown")
    print("PASS: explorer limits and safe report labels; no live AX calls.")
    exit(0)
}

final class Explorer {
    var nodes = [AXUIElement]()
    var paths = [String]()
    var skipped = Set<Int>()
    var budget = Budget()
    var transcript = "AX Explorer \(version)\nCoordinates: global top-left points. No screenshots, titles or control values.\n"
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
    func save(_ label: String) {
        let directory=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/CameraReference/Diagnostics/AXExplorer",isDirectory:true)
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
node N                  Role, frame, safe attributes, parent and relationships
children N              List direct children
sections N              Follow AXSections (including nested dictionaries)
scan [N|main]           Bounded tree scan; default application N0
skip N / unskip N       Prune/unprune this node wherever reached during scans
skips                   Show pruning list
limits COUNT DEPTH SEC  Adjust without recompiling (max 10000 / 30 / 30)
note TEXT               Add test conditions to report
save LABEL              Save accumulated report under CameraReference/Diagnostics/AXExplorer
clear                   Start a new report; keeps current IDs and skips
permission              Request Accessibility access; then use refresh
quit                    Exit (save first if wanted)
No actions or attribute writes. Titles, descriptions and control values are omitted.
""")
            case "permission":
                let options=[kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary
                emit("Accessibility granted: \(AXIsProcessTrustedWithOptions(options)). If unchanged, check System Settings for this executable or Terminal; restart explorer if necessary.")
            case "refresh": refresh()
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
