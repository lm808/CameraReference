import AppKit
import ApplicationServices

func fittedSize(image: CGSize, inside bounds: CGSize) -> CGSize {
    guard image.width > 0, image.height > 0, bounds.width > 0, bounds.height > 0 else { return .zero }
    let scale = min(bounds.width / image.width, bounds.height / image.height)
    return CGSize(width: image.width * scale, height: image.height * scale)
}
func isLightroomApp(_ app: NSRunningApplication?) -> Bool {
    app?.bundleIdentifier?.hasPrefix("com.adobe.LightroomClassic") == true || app?.localizedName == "Adobe Lightroom Classic"
}
struct LayoutProbe {
    let imageBounds: NSRect?
    let summary: String
}
// Read-only, bounded investigation: no AX actions, screenshot, titles, values or filenames.
// Only one large AXImage with matching aspect ratio near the window centre is accepted.
// Unknown, cropped and multi-pane layouts fall back to manual calibration.
func probeLightroom(imageSize: CGSize?) -> LayoutProbe {
    guard AXIsProcessTrusted() else { return LayoutProbe(imageBounds: nil, summary: "Accessibility permission is not enabled. Manual calibration remains available.") }
    guard let app = NSWorkspace.shared.runningApplications.first(where: isLightroomApp) else {
        return LayoutProbe(imageBounds: nil, summary: "Lightroom is not running.")
    }
    let application = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(application, 0.08)
    func value(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &result) == .success else { return nil }
        return result
    }
    func rect(_ element: AXUIElement) -> CGRect? {
        guard let position = value(element, kAXPositionAttribute), let size = value(element, kAXSizeAttribute),
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var p = CGPoint.zero, s = CGSize.zero
        guard AXValueGetValue(unsafeBitCast(position, to: AXValue.self), .cgPoint, &p),
              AXValueGetValue(unsafeBitCast(size, to: AXValue.self), .cgSize, &s) else { return nil }
        return CGRect(origin: p, size: s)
    }
    guard let windowValue = value(application, kAXMainWindowAttribute), CFGetTypeID(windowValue) == AXUIElementGetTypeID() else {
        return LayoutProbe(imageBounds: nil, summary: "Lightroom did not expose its main window.")
    }
    let window = unsafeBitCast(windowValue, to: AXUIElement.self)
    guard let windowRect = rect(window) else { return LayoutProbe(imageBounds: nil, summary: "No accessible Lightroom window bounds.") }
    var queue: [(AXUIElement, Int)] = [(window, 0)], cursor = 0
    var images = [CGRect](), counts = [String: Int]()
    var imageDetails = [String]()
    func geometry(_ r: CGRect) -> String { "x=\(Int(r.minX)), y=\(Int(r.minY)), \(Int(r.width)) × \(Int(r.height)) pt" }
    var truncated = false
    let deadline = ProcessInfo.processInfo.systemUptime + 0.8
    while cursor < queue.count && cursor < 350 && ProcessInfo.processInfo.systemUptime < deadline {
        let (node, depth) = queue[cursor]; cursor += 1
        let role = value(node, kAXRoleAttribute) as? String ?? "unknown"
        counts[role, default: 0] += 1
        if role == kAXImageRole {
            if let r = rect(node) {
                var reasons = [String]()
                if r.width <= 200 || r.height <= 150 { reasons.append("too small") }
                if !windowRect.contains(r) { reasons.append("outside main window") }
                if !r.contains(CGPoint(x: windowRect.midX, y: windowRect.midY)) { reasons.append("does not cover window centre") }
                if let imageSize, r.height > 0, abs(r.width/r.height/(imageSize.width/imageSize.height)-1) >= 0.025 { reasons.append("aspect ratio differs from last loaded JPEG") }
                imageDetails.append("AXImage: " + geometry(r) + "; " + (reasons.isEmpty ? "geometry passes" : reasons.joined(separator: ", ")))
                if r.width > 200, r.height > 150, windowRect.contains(r), r.contains(CGPoint(x: windowRect.midX, y: windowRect.midY)), !images.contains(r) { images.append(r) }
            } else { imageDetails.append("AXImage: position or size unavailable") }
        }
        if let children = value(node, kAXChildrenAttribute) as? [AXUIElement], !children.isEmpty {
            if depth < 14 {
                let room = max(0, 350 - queue.count)
                if children.count > room { truncated = true }
                queue.append(contentsOf: children.prefix(room).map { ($0, depth + 1) })
            } else { truncated = true }
        }
    }
    let candidates = images.filter { r in
        guard let imageSize else { return true }
        let expected = imageSize.width / imageSize.height
        return abs(r.width / r.height / expected - 1) < 0.025
    }
    let complete = cursor >= queue.count && !truncated
    let roleSummary = counts.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    let focused = value(application, kAXFocusedWindowAttribute)
    let sameWindow = focused.map { CFEqual($0, window) } ?? false
    let context = "Main window: " + geometry(windowRect) + "\nFocused window matches main: \(sameWindow).\n" + (imageSize == nil ? "No JPEG aspect ratio available; load a reference first.\n" : "Aspect ratio uses the last loaded JPEG.\n")
    let summary = context + "Inspected \(cursor) elements\(complete ? "" : " (scan limit reached)").\n\(roleSummary)\nLarge central image candidates: \(images.count); matching candidates: \(candidates.count).\n" + imageDetails.prefix(20).joined(separator: "\n")
    guard complete, candidates.count == 1, let candidate = candidates.first, imageSize != nil else {
        return LayoutProbe(imageBounds: nil, summary: summary + "\nNo unambiguous image bounds accepted. Using manual calibration.")
    }
    // AX coordinates are top-left global; AppKit coordinates are bottom-left global.
    let primaryHeight = CGDisplayBounds(CGMainDisplayID()).height
    let converted = NSRect(x: candidate.minX, y: primaryHeight - candidate.maxY, width: candidate.width, height: candidate.height)
    return LayoutProbe(imageBounds: converted, summary: summary + "\nExperimental image bounds accepted: \(Int(converted.width)) × \(Int(converted.height)) points.")
}

// Read window geometry only; no UI control, title or screenshot access.
func lightroomWindowFrame() -> CGRect? {
    guard let app=NSWorkspace.shared.runningApplications.first(where:isLightroomApp),
          let windows=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] else { return nil }
    let frames=windows.compactMap { item -> CGRect? in
        guard (item[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value==app.processIdentifier,
              (item[kCGWindowLayer as String] as? NSNumber)?.intValue==0,
              let value=item[kCGWindowBounds as String] as? [String:Any],
              let frame=CGRect(dictionaryRepresentation:value as CFDictionary),frame.width>600,frame.height>400 else { return nil }
        return CGRect(x:frame.minX,y:CGDisplayBounds(CGMainDisplayID()).height-frame.maxY,width:frame.width,height:frame.height)
    }.sorted { $0.width*$0.height > $1.width*$1.height }
    return frames.first
}
func translatedCalibration(_ rect:CGRect,from saved:CGRect,to current:CGRect)->CGRect? {
    guard abs(saved.width-current.width)<1,abs(saved.height-current.height)<1 else { return nil }
    return rect.offsetBy(dx:current.minX-saved.minX,dy:current.minY-saved.minY)
}

// Bounded, read-only menu-state report for view identification research.
// Do not traverse photo controls or log window titles / filenames.
func probeLightroomViewState() -> String {
    guard AXIsProcessTrusted() else { return "Accessibility permission is required for view-state inspection." }
    guard let app=NSWorkspace.shared.runningApplications.first(where:isLightroomApp) else { return "Lightroom is not running." }
    let application=AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(application,0.08)
    func read(_ element:AXUIElement,_ key:String)->CFTypeRef? {
        var value:CFTypeRef?
        guard AXUIElementCopyAttributeValue(element,key as CFString,&value) == .success else { return nil }
        return value
    }
    guard let raw=read(application,kAXMenuBarAttribute),CFGetTypeID(raw)==AXUIElementGetTypeID() else { return "Lightroom exposes no accessible menu bar." }
    let menu=unsafeBitCast(raw,to:AXUIElement.self)
    guard let topMenus=read(menu,kAXChildrenAttribute) as? [AXUIElement],
          let viewMenu=topMenus.first(where:{ (read($0,kAXTitleAttribute) as? String)=="View" }) else {
        return "No accessible English View menu was exposed. No view identity inferred."
    }
    var queue=[(viewMenu,0)],index=0,lines=[String]()
    let deadline=ProcessInfo.processInfo.systemUptime+3
    let words=["reference","before","after","side by side","top","bottom","loupe","split"]
    while index<queue.count,index<500,ProcessInfo.processInfo.systemUptime<deadline {
        let (element,depth)=queue[index];index+=1
        if let title=read(element,kAXTitleAttribute) as? String,
           words.contains(where:{title.lowercased().contains($0)}) {
            let mark=read(element,"AXMenuItemMarkChar") as? String ?? "none"
            let selected=(read(element,kAXSelectedAttribute) as? NSNumber)?.stringValue ?? "unavailable"
            lines.append("\(title): mark=\(mark), selected=\(selected)")
        }
        if depth<8,let children=read(element,kAXChildrenAttribute) as? [AXUIElement] {
            queue.append(contentsOf:children.prefix(100).map{($0,depth+1)})
        }
    }
    return "Read-only Lightroom menu view-state sample. No menu was opened or activated.\n" + (lines.isEmpty ? "No matching view labels exposed. This does not identify the current view." : lines.joined(separator:"\n")) + "\nCompare separate samples in single, Reference and Before/After views. Menu availability alone is not proof of selection."
}

struct HostWindowSnapshot {
    let id:CGWindowID
    let frame:CGRect
    let onScreen:Bool
}
func hostWindowSnapshot(_ id:CGWindowID)->HostWindowSnapshot? {
    guard let rows=CGWindowListCopyWindowInfo(.optionIncludingWindow,id) as? [[String:Any]],
          let row=rows.first(where:{($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value==id}),
          let data=row[kCGWindowBounds as String] as? [String:Any],let frame=CGRect(dictionaryRepresentation:data as CFDictionary) else { return nil }
    let appKit=CGRect(x:frame.minX,y:CGDisplayBounds(CGMainDisplayID()).height-frame.maxY,width:frame.width,height:frame.height)
    let visibleRows=CGWindowListCopyWindowInfo(.optionOnScreenOnly,kCGNullWindowID) as? [[String:Any]]
    let listed=visibleRows.map { $0.contains { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value==id } }
    let visible=listed ?? ((row[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false)
    let alpha=(row[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
    return HostWindowSnapshot(id:id,frame:appKit,onScreen:visible && alpha>0)
}
// Dock can own a permanent full-screen transparent window during ordinary work.
// Its geometry alone is NOT evidence of Mission Control. Require Dock activation
// as well; native .transient suppression remains the primary overview behaviour.
func dockOverviewEvidence(dockIsFrontmost:Bool,coverage:CGFloat)->Bool {
    dockIsFrontmost && coverage>0.65
}
func workspaceOverviewIsVisible()->Bool {
    guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier=="com.apple.dock",
          let dock=NSWorkspace.shared.runningApplications.first(where:{$0.bundleIdentifier=="com.apple.dock"}),
          let rows=CGWindowListCopyWindowInfo(.optionOnScreenOnly,kCGNullWindowID) as? [[String:Any]] else { return false }
    let screens=NSScreen.screens.map { CGRect(x:$0.frame.minX,y:CGDisplayBounds(CGMainDisplayID()).height-$0.frame.maxY,width:$0.frame.width,height:$0.frame.height) }
    return rows.contains { row in
        guard (row[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value==dock.processIdentifier,
              let d=row[kCGWindowBounds as String] as? [String:Any],let frame=CGRect(dictionaryRepresentation:d as CFDictionary) else { return false }
        return screens.contains { screen in
            let overlap=frame.intersection(screen)
            return !overlap.isNull && dockOverviewEvidence(dockIsFrontmost:true,coverage:overlap.width*overlap.height/(screen.width*screen.height))
        }
    }
}

// A failed metadata query is not proof that a window closed.
func hostWindowIsClosed(_ id:CGWindowID)->Bool {
    guard let rows=CGWindowListCopyWindowInfo(.optionAll,kCGNullWindowID) as? [[String:Any]],!rows.isEmpty else { return false }
    return !rows.contains { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value==id }
}
enum OverlayHostAction:Equatable { case retain,suspend,translate(CGPoint) }
func overlayHostAction(saved:CGRect,current:CGRect?,onScreen:Bool,overview:Bool)->OverlayHostAction {
    if overview { return .suspend }
    guard let current else { return .retain }
    if !onScreen { return .suspend }
    return .translate(CGPoint(x:current.minX-saved.minX,y:current.minY-saved.minY))
}

// Keep the last accepted logical host geometry while a resize/restoration
// is in flight. Ordinary same-size movement remains immediate.
struct OverlayGeometrySettler {
    private var pending:CGRect?
    private var since:TimeInterval=0
    mutating func reset() { pending=nil;since=0 }
    mutating func accepts(_ current:CGRect,saved:CGRect,restoring:Bool,now:TimeInterval)->Bool {
        let resized=abs(current.width-saved.width)>=0.5 || abs(current.height-saved.height)>=0.5
        if !restoring && !resized && pending == nil { return true }
        if let pending,sameWindowGeometry(pending,current) {
            if now-since>=0.3 { return true }
        } else { pending=current;since=now }
        return false
    }
}

// Notifications win briefly over lagging AX attributes during animation, but a
// missed restore notification must not leave a retained overlay hidden forever.
func hostMinimizedState(polled:Bool?,notified:Bool?,notificationAge:TimeInterval)->Bool? {
    if notified == true,notificationAge<0.4 { return true }
    return polled ?? notified
}

func accessibilityStatus(_ error:AXError)->String {
    let label:String
    switch error {
    case .success: label="success"
    case .apiDisabled: label="Accessibility API disabled"
    case .cannotComplete: label="cannot complete (app busy or timeout)"
    case .invalidUIElement: label="invalid window element"
    case .attributeUnsupported: label="attribute unsupported"
    case .notificationUnsupported: label="notification unsupported"
    case .notificationAlreadyRegistered: label="already registered"
    case .noValue: label="no value"
    default: label="AX error"
    }
    return "\(label) (\(error.rawValue))"
}

// Do not bind to an arbitrary overlapping child window when geometry is ambiguous.
func uniqueHostFrameMatch(_ frames:[CGRect?],target:CGRect)->Int? {
    let matches=frames.indices.filter { i in
        guard let frame=frames[i] else { return false }
        return abs(frame.minX-target.minX)<2 && abs(frame.minY-target.minY)<2 && abs(frame.width-target.width)<2 && abs(frame.height-target.height)<2
    }
    return matches.count == 1 ? matches[0]:nil
}

// Bounded, read-only AX lifecycle checks when already authorised. No permission
// prompts from the timer; window-list metadata remains the fallback.
final class LightroomHostAccessibility {
    private let application:AXUIElement
    private let host:AXUIElement
    private var observer:AXObserver?
    private var notifiedMinimized:Bool?
    private var notificationTime:TimeInterval=0
    var onMinimized:(()->Void)?
    private(set) var watchesMinimize=false
    private(set) var observerStatus="notifications not attempted"
    private(set) var minimizeAttributeStatus="not read"
    private var miniCount=0,restoreCount=0
    private var eventHistory:[String]=[]
    var diagnostic:String {
        "\(observerStatus); AXMinimized: \(minimizeAttributeStatus); events mini/restore \(miniCount)/\(restoreCount)" + (eventHistory.isEmpty ? "":"\nAX event history (uptime seconds): " + eventHistory.joined(separator:"; "))
    }
    deinit {
        if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(),AXObserverGetRunLoopSource(observer),.commonModes) }
    }
    private func watchMinimize(pid:pid_t) {
        var created:AXObserver?
        let createResult=AXObserverCreate(pid,{ _,_,notification,context in
            guard let context else { return }
            let owner=Unmanaged<LightroomHostAccessibility>.fromOpaque(context).takeUnretainedValue()
            owner.notificationTime=ProcessInfo.processInfo.systemUptime
            if notification as String == kAXWindowMiniaturizedNotification {
                owner.notifiedMinimized=true;owner.miniCount += 1
                owner.eventHistory.append(String(format:"%.3f mini received",owner.notificationTime))
                owner.onMinimized?()
            } else if notification as String == kAXWindowDeminiaturizedNotification {
                owner.notifiedMinimized=false;owner.restoreCount += 1
                owner.eventHistory.append(String(format:"%.3f restore received",owner.notificationTime))
            }
            owner.eventHistory=Array(owner.eventHistory.suffix(8))
        },&created)
        guard createResult == .success,let created else {
            observerStatus="observer creation: " + accessibilityStatus(createResult);return
        }
        let context=Unmanaged.passUnretained(self).toOpaque()
        let mini=AXObserverAddNotification(created,host,kAXWindowMiniaturizedNotification as CFString,context)
        let restore=AXObserverAddNotification(created,host,kAXWindowDeminiaturizedNotification as CFString,context)
        watchesMinimize=mini == .success
        observerStatus="notifications mini: \(accessibilityStatus(mini)); restore: \(accessibilityStatus(restore))"
        // Retain whichever public notification Lightroom supports. Attribute
        // polling still handles a missing restore/minimise notification.
        guard mini == .success || restore == .success else { return }
        observer=created
        CFRunLoopAddSource(CFRunLoopGetMain(),AXObserverGetRunLoopSource(created),.commonModes)
    }
    private static func read(_ element:AXUIElement,_ key:String)->CFTypeRef? {
        var value:CFTypeRef?
        guard AXUIElementCopyAttributeValue(element,key as CFString,&value) == .success else { return nil }
        return value
    }
    private static func element(_ value:CFTypeRef?)->AXUIElement? {
        guard let value,CFGetTypeID(value)==AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value,to:AXUIElement.self)
    }
    private static func frame(_ element:AXUIElement)->CGRect? {
        guard let p=read(element,kAXPositionAttribute),let s=read(element,kAXSizeAttribute),
              CFGetTypeID(p)==AXValueGetTypeID(),CFGetTypeID(s)==AXValueGetTypeID() else { return nil }
        var point=CGPoint.zero,size=CGSize.zero
        guard AXValueGetValue(unsafeBitCast(p,to:AXValue.self),.cgPoint,&point),
              AXValueGetValue(unsafeBitCast(s,to:AXValue.self),.cgSize,&size) else { return nil }
        return CGRect(origin:point,size:size)
    }
    init?(pid:pid_t,hostFrame:CGRect,diagnostic:inout String) {
        guard AXIsProcessTrusted() else {
            diagnostic="Accessibility permission not granted to this app. Use Developer tools → Inspect Accessibility layout… to request access.";return nil
        }
        let app=AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app,0.03)
        var value:CFTypeRef?
        let status=AXUIElementCopyAttributeValue(app,kAXWindowsAttribute as CFString,&value)
        guard status == .success,let windows=value as? [AXUIElement] else {
            diagnostic="AXWindows read: \(accessibilityStatus(status)); no window list";return nil
        }
        let cg=CGRect(x:hostFrame.minX,y:CGDisplayBounds(CGMainDisplayID()).height-hostFrame.maxY,width:hostFrame.width,height:hostFrame.height)
        let deadline=ProcessInfo.processInfo.systemUptime+0.15
        // Public main/focused references are useful when AXWindows contains many
        // Lightroom panels. Verify exact host geometry before using either.
        var priority:[AXUIElement]=[]
        for key in [kAXMainWindowAttribute,kAXFocusedWindowAttribute] {
            if let window=Self.element(Self.read(app,key)),!priority.contains(where:{CFEqual($0,window)}) { priority.append(window) }
        }
        var match:AXUIElement?
        var source="main/focused window"
        for window in priority {
            AXUIElementSetMessagingTimeout(window,0.01)
            if let rect=Self.frame(window),uniqueHostFrameMatch([rect],target:cg) != nil { match=window;break }
        }
        var examined=priority.count
        if match == nil {
            var frames:[CGRect?]=[]
            for window in windows {
                guard ProcessInfo.processInfo.systemUptime<deadline else {
                    diagnostic="AX window search exceeded 150 ms budget; examined \(frames.count) of \(windows.count). No guessed host binding.";return nil
                }
                AXUIElementSetMessagingTimeout(window,0.01)
                frames.append(Self.frame(window))
            }
            examined=frames.count
            // Search all returned frames, largest first, retaining exact geometry
            // and ambiguity checks rather than assuming largest always means host.
            let ranked=frames.indices.sorted { (frames[$0].map{$0.width*$0.height} ?? 0) > (frames[$1].map{$0.width*$0.height} ?? 0) }
            let ordered=ranked.map{frames[$0]}
            guard let index=uniqueHostFrameMatch(ordered,target:cg) else {
                let details=ranked.prefix(8).map { frames[$0].map(String.init(describing:)) ?? "unreadable" }.joined(separator:"; ")
                diagnostic="No unique AX host match. Expected \(cg); examined all \(frames.count) windows. Largest frames: \(details)";return nil
            }
            match=windows[ranked[index]];source="all-window area-ranked search"
        }
        guard let match else { return nil }
        application=app;host=match;AXUIElementSetMessagingTimeout(host,0.03)
        diagnostic="AX host bound via \(source), geometry verified (\(examined) examined; \(windows.count) listed)."
        watchMinimize(pid:pid)
    }
    var layoutFrame:CGRect? {
        guard let rect=Self.frame(host),rect.width>0,rect.height>0 else { return nil }
        return appKitRect(rect,primaryHeight:CGDisplayBounds(CGMainDisplayID()).height)
    }
    var minimized:Bool? {
        var value:CFTypeRef?
        let result=AXUIElementCopyAttributeValue(host,kAXMinimizedAttribute as CFString,&value)
        let polled=(value as? NSNumber)?.boolValue
        minimizeAttributeStatus=accessibilityStatus(result) + "; value " + (polled.map(String.init) ?? "unavailable")
        return hostMinimizedState(polled:polled,notified:notifiedMinimized,
                                  notificationAge:ProcessInfo.processInfo.systemUptime-notificationTime)
    }
    var hasDialog:Bool {
        if let children=Self.read(host,kAXChildrenAttribute) as? [AXUIElement],
           children.prefix(16).contains(where:{Self.read($0,kAXRoleAttribute) as? String == kAXSheetRole}) { return true }
        guard let focused=Self.element(Self.read(application,kAXFocusedWindowAttribute)),!CFEqual(focused,host) else { return false }
        let subrole=Self.read(focused,kAXSubroleAttribute) as? String
        return subrole==kAXDialogSubrole || subrole==kAXSystemDialogSubrole || (Self.read(focused,kAXModalAttribute) as? NSNumber)?.boolValue==true
    }
}

struct LightroomWindowMetadata {
    let id:CGWindowID
    let frame:CGRect // AppKit
    let layer:Int
    let hasTitle:Bool
}
func lightroomWindowMetadata(pid:pid_t)->[LightroomWindowMetadata]? {
    guard let rows=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] else { return nil }
    return rows.compactMap { row in
        guard (row[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value==pid,
              let id=(row[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
              let d=row[kCGWindowBounds as String] as? [String:Any],let r=CGRect(dictionaryRepresentation:d as CFDictionary) else { return nil }
        let frame=CGRect(x:r.minX,y:CGDisplayBounds(CGMainDisplayID()).height-r.maxY,width:r.width,height:r.height)
        return LightroomWindowMetadata(id:id,frame:frame,layer:(row[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0,
                                      hasTitle:!(row[kCGWindowName as String] as? String ?? "").isEmpty)
    }
}
// New titled, substantial Lightroom windows above the host can be non-modal
// dialogs such as View Options. Existing child panes and redraw surfaces do not
// trigger this fallback; no titles or photo paths are retained in diagnostics.
func hasNewLightroomDialog(windows:[LightroomWindowMetadata],host:CGWindowID,baseline:Set<CGWindowID>)->Bool {
    guard let index=windows.firstIndex(where:{$0.id==host}) else { return false }
    return windows[..<index].contains { window in
        !baseline.contains(window.id) && window.hasTitle && window.layer>=0 && window.layer<=Int(CGWindowLevelForKey(.modalPanelWindow)) && window.frame.width>=180 && window.frame.height>=100
    }
}
func hostIsPresentationThumbnail(_ frame:CGRect)->Bool {
    // Lightroom's editing window cannot normally resize this small; this is
    // animation/thumbnail geometry, not a new photo viewport to follow.
    frame.width<300 || frame.height<180
}

// A stable AX layout with a smaller, proportionately scaled CG presentation is
// animation evidence. Movement/off-screen clipping alone is never sufficient.
func hostPresentationIsShrinking(reported:CGRect,logical:CGRect,saved:CGRect)->Bool {
    guard logical.width>0,logical.height>0,
          abs(logical.width-saved.width)<2,abs(logical.height-saved.height)<2,
          reported.width>0,reported.height>0,
          logical.width-reported.width>2,logical.height-reported.height>2 else { return false }
    let sx=reported.width/logical.width,sy=reported.height/logical.height
    return abs(sx-sy)<0.025
}

// Explicit diagnostic only: these reports never feed placement or monitoring.
func mappingRect(_ rect:CGRect)->String {
    String(format:"(%.3f, %.3f, %.3f, %.3f)",rect.minX,rect.minY,rect.width,rect.height)
}
struct AXMappingRow {
    let index:Int
    let frame:CGRect?
    let details:String
}
func formatAXMappingRows(_ rows:[AXMappingRow])->String {
    rows.map { row in
        let duplicates=rows.filter { $0.index<row.index && row.frame != nil && $0.frame==row.frame }.map { "W\($0.index)" }
        return "W\(row.index): rect=\(row.frame.map(mappingRect) ?? "unavailable"); \(row.details)" + (duplicates.isEmpty ? "":"; same rectangle as "+duplicates.joined(separator:", "))
    }.joined(separator:"\n")
}
// Called on main so NSScreen names/backing scales come from one UI snapshot.
func displayMappingReport()->String {
    let primary=CGMainDisplayID()
    var lines=["DISPLAY MAP", "AX/CG coordinates: global top-left points; x right, y down. Rectangles are (x, y, width, height).", "Display IDs identify this snapshot; no serial numbers are collected."]
    for (index,screen) in NSScreen.screens.enumerated() {
        guard let id=(screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else { continue }
        let bounds=CGDisplayBounds(id),mode=CGDisplayCopyDisplayMode(id)
        let pixels=mode.map { "\($0.pixelWidth) × \($0.pixelHeight)" } ?? "unavailable"
        lines.append("D\(index+1): \(screen.localizedName); id=\(id); primary=\(id==primary); built-in=\(CGDisplayIsBuiltin(id) != 0)")
        lines.append("  global top-left bounds=\(mappingRect(bounds)); backing scale=\(screen.backingScaleFactor); mode pixels=\(pixels); rotation=\(CGDisplayRotation(id)); mirrors display=\(CGDisplayMirrorsDisplay(id))")
        lines.append("  AppKit bottom-left frame=\(mappingRect(screen.frame)); usable frame=\(mappingRect(screen.visibleFrame))")
    }
    lines.append("Send the original full-display screenshot and its D-number/name. Screenshot pixel dimensions establish the final point-to-pixel scale.")
    return lines.joined(separator:"\n")
}
func accessibilityMappingReport(evidence: ((CGRect,[AXTrialWindow])->Void)? = nil)->String {
    let started=Date(),start=ProcessInfo.processInfo.systemUptime
    var lines=["AX WINDOW MAP", "Snapshot started: \(ISO8601DateFormatter().string(from:started))", "Read-only: no titles, filenames, control values or screenshots collected."]
    guard AXIsProcessTrusted() else { return (lines+["Accessibility permission unavailable."]).joined(separator:"\n") }
    guard let app=NSWorkspace.shared.runningApplications.first(where:isLightroomApp) else { return (lines+["Lightroom is not running."]).joined(separator:"\n") }
    let application=AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(application,0.05)
    func read(_ element:AXUIElement,_ key:String)->(CFTypeRef?,AXError) {
        var value:CFTypeRef?
        let status=AXUIElementCopyAttributeValue(element,key as CFString,&value)
        return (value,status)
    }
    func element(_ value:CFTypeRef?)->AXUIElement? {
        guard let value,CFGetTypeID(value)==AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value,to:AXUIElement.self)
    }
    func field(_ node:AXUIElement,_ key:String)->String {
        let (value,status)=read(node,key)
        guard status == .success else { return "unavailable [\(accessibilityStatus(status))]" }
        if let text=value as? String { return text }
        if let number=value as? NSNumber { return number.boolValue ? "true":"false" }
        return "unavailable"
    }
    func frame(_ node:AXUIElement)->(CGRect?,String) {
        let (p,ps)=read(node,kAXPositionAttribute), (s,ss)=read(node,kAXSizeAttribute)
        guard let p,let s,CFGetTypeID(p)==AXValueGetTypeID(),CFGetTypeID(s)==AXValueGetTypeID() else {
            return (nil,"position=\(accessibilityStatus(ps)), size=\(accessibilityStatus(ss))")
        }
        var origin=CGPoint.zero,size=CGSize.zero
        guard AXValueGetValue(unsafeBitCast(p,to:AXValue.self),.cgPoint,&origin),AXValueGetValue(unsafeBitCast(s,to:AXValue.self),.cgSize,&size) else { return (nil,"unreadable AX position/size types") }
        return (CGRect(origin:origin,size:size),"geometry available")
    }
    let main=element(read(application,kAXMainWindowAttribute).0),focused=element(read(application,kAXFocusedWindowAttribute).0)
    let mainBefore=main.flatMap { frame($0).0 }
    lines.append("Main window rect: \(mainBefore.map(mappingRect) ?? "unavailable"); app hidden=\(field(application,kAXHiddenAttribute))")
    let (listed,listStatus)=read(application,kAXWindowsAttribute)
    guard let windows=listed as? [AXUIElement],listStatus == .success else {
        return (lines+["AXWindows unavailable: \(accessibilityStatus(listStatus))"]).joined(separator:"\n")
    }
    // CG visibility is evidence from a different API, not inferred AX visibility.
    let cgRows=(CGWindowListCopyWindowInfo(.optionAll,kCGNullWindowID) as? [[String:Any]])?.filter {
        ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value==app.processIdentifier
    }
    func cgFrame(_ row:[String:Any])->CGRect? {
        guard let data=row[kCGWindowBounds as String] as? [String:Any] else { return nil }
        return CGRect(dictionaryRepresentation:data as CFDictionary)
    }
    var rows:[AXMappingRow]=[],examined=0
    let deadline=ProcessInfo.processInfo.systemUptime+4
    for (index,node) in windows.enumerated() {
        guard ProcessInfo.processInfo.systemUptime<deadline else {
            rows.append(AXMappingRow(index:index+1,frame:nil,details:"not read: four-second inspection budget reached"));continue
        }
        AXUIElementSetMessagingTimeout(node,0.025)
        let (rect,geometryStatus)=frame(node)
        let matching=(cgRows ?? []).filter { row in
            guard let rect,let candidate=cgFrame(row) else { return false }
            return abs(rect.minX-candidate.minX)<2 && abs(rect.minY-candidate.minY)<2 && abs(rect.width-candidate.width)<2 && abs(rect.height-candidate.height)<2
        }.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.stringValue }
        let detail="role=\(field(node,kAXRoleAttribute)); subrole=\(field(node,kAXSubroleAttribute)); main=\(main.map{CFEqual($0,node)} ?? false); focused=\(focused.map{CFEqual($0,node)} ?? false); minimized=\(field(node,kAXMinimizedAttribute)); AXVisible=\(field(node,"AXVisible")); \(geometryStatus); matching CG IDs=\(matching.isEmpty ? "none":matching.joined(separator:","))"
        rows.append(AXMappingRow(index:index+1,frame:rect,details:detail));examined += 1
    }
    lines.append("AXWindows returned \(windows.count); examined \(examined). Every returned entry is listed, including unreadable/unexamined entries; duplicates preserved.")
    lines.append(formatAXMappingRows(rows))
    lines.append("CG WINDOW MAP (Lightroom only; top-left points; onScreen is not proof of being unobscured)")
    if let cgRows {
        for row in cgRows {
            let id=(row[kCGWindowNumber as String] as? NSNumber)?.stringValue ?? "unknown"
            let visible=(row[kCGWindowIsOnscreen as String] as? NSNumber).map{String($0.boolValue)} ?? "unknown"
            lines.append("CG \(id): rect=\(cgFrame(row).map(mappingRect) ?? "unavailable"); onScreen=\(visible); layer=\((row[kCGWindowLayer as String] as? NSNumber)?.stringValue ?? "unknown"); alpha=\((row[kCGWindowAlpha as String] as? NSNumber)?.stringValue ?? "unknown")")
        }
    } else { lines.append("CG window metadata unavailable; Screen Recording permission can affect this supplementary list.") }
    let mainAfter=main.flatMap { frame($0).0 }
    if let host=mainBefore, mainAfter==mainBefore, examined==windows.count, cgRows != nil {
        let evidenceRows=rows.compactMap { row -> AXTrialWindow? in
            guard let rect=row.frame else { return nil }
            let matches=(cgRows ?? []).filter { cgFrame($0)==rect }
            let visible=matches.contains { (($0[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 0)>0 && ($0[kCGWindowLayer as String] as? NSNumber)?.intValue==0 }
            return AXTrialWindow(frame:rect,visible:visible)
        }
        evidence?(host,evidenceRows)
    }
    lines.append("Main window after scan: \(mainAfter.map(mappingRect) ?? "unavailable"); unchanged=\(mainBefore != nil && mainBefore==mainAfter).")
    lines.append(String(format:"Snapshot elapsed: %.0f ms. AXVisible may be unsupported; unknown never means hidden.",(ProcessInfo.processInfo.systemUptime-start)*1000))
    return lines.joined(separator:"\n")
}

// Explicit diagnostic refresh only: inspect children of ALL exposed windows, not just main.
// No AX actions, titles, values, descriptions or filenames are read.
func accessibilityControlReport()->String {
    guard AXIsProcessTrusted() else { return "Accessibility permission unavailable; controls not inspected." }
    guard let app=NSWorkspace.shared.runningApplications.first(where:isLightroomApp) else { return "Lightroom is not running." }
    let application=AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(application,0.02)
    func read(_ node:AXUIElement,_ key:String)->CFTypeRef? {
        var result:CFTypeRef?
        guard AXUIElementCopyAttributeValue(node,key as CFString,&result) == .success else { return nil }
        return result
    }
    func frame(_ node:AXUIElement)->CGRect? {
        guard let p=read(node,kAXPositionAttribute),let s=read(node,kAXSizeAttribute),CFGetTypeID(p)==AXValueGetTypeID(),CFGetTypeID(s)==AXValueGetTypeID() else { return nil }
        var point=CGPoint.zero,size=CGSize.zero
        guard AXValueGetValue(unsafeBitCast(p,to:AXValue.self),.cgPoint,&point),AXValueGetValue(unsafeBitCast(s,to:AXValue.self),.cgSize,&size) else { return nil }
        return CGRect(origin:point,size:size)
    }
    guard let windows=read(application,kAXWindowsAttribute) as? [AXUIElement] else { return "AX window list unavailable." }
    var queue:[(AXUIElement,String,Int)]=[],seen:[AXUIElement]=[]
    func enqueue(_ node:AXUIElement,_ parent:String,_ depth:Int) {
        guard !seen.contains(where:{ CFEqual($0,node) }) else { return }
        seen.append(node);queue.append((node,parent,depth))
    }
    if let main=read(application,kAXMainWindowAttribute),CFGetTypeID(main)==AXUIElementGetTypeID() { enqueue(unsafeBitCast(main,to:AXUIElement.self),"main",0) }
    for (i,node) in windows.enumerated() { enqueue(node,"AXWindows[\(i)]",0) }
    let started=ProcessInfo.processInfo.systemUptime,deadline=started+2
    var cursor=0,lines=[String](),limited=false,toolbarCount=0
    while cursor<queue.count && cursor<500 && ProcessInfo.processInfo.systemUptime<deadline {
        let (node,parent,depth)=queue[cursor],id="E\(cursor)";cursor += 1
        AXUIElementSetMessagingTimeout(node,0.02)
        let role=read(node,kAXRoleAttribute) as? String ?? "unknown"
        let subrole=read(node,kAXSubroleAttribute) as? String ?? "—"
        let bounds=frame(node).map { String(describing:$0) } ?? "unavailable"
        if role==kAXToolbarRole { toolbarCount += 1 }
        lines.append("\(id) parent=\(parent) depth=\(depth) \(role)/\(subrole) frame=\(bounds)")
        if let children=read(node,kAXChildrenAttribute) as? [AXUIElement],!children.isEmpty {
            if depth<12 {
                for child in children {
                    if queue.count>=500 { limited=true;break }
                    enqueue(child,id,depth+1)
                }
            } else { limited=true }
        }
    }
    limited = limited || cursor<queue.count
    return "Collected: \(Date())\nTop-left global points. E numbers are local to this report.\n\(windows.count) window roots; \(cursor) unique elements; \(limited ? "INCOMPLETE: budget/depth/node limit":"complete exposed child traversal").\nAXToolbar roles: \(toolbarCount). Absence does not prove the toolbar is hidden.\nElapsed: \(Int((ProcessInfo.processInfo.systemUptime-started)*1000)) ms.\n"+lines.joined(separator:"\n")
}

// Focused structural probe: main window and shallow related elements first.
// Query only public AX attributes. Never read control values, titles or descriptions.
func accessibilityToolbarReport()->String {
    guard AXIsProcessTrusted(),let app=NSWorkspace.shared.runningApplications.first(where:isLightroomApp) else { return "Toolbar probe unavailable: permission or Lightroom missing." }
    let application=AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(application,0.02)
    var errors=0
    func read(_ node:AXUIElement,_ key:String)->(CFTypeRef?,AXError) {
        var value:CFTypeRef?
        let status=AXUIElementCopyAttributeValue(node,key as CFString,&value)
        if status != .success && status != .attributeUnsupported && status != .noValue { errors += 1 }
        return (value,status)
    }
    func elements(_ raw:CFTypeRef?)->[AXUIElement] {
        guard let raw else { return [] }
        if CFGetTypeID(raw)==AXUIElementGetTypeID() { return [unsafeBitCast(raw,to:AXUIElement.self)] }
        return raw as? [AXUIElement] ?? []
    }
    func rect(_ node:AXUIElement)->CGRect? {
        guard let p=read(node,"AXPosition").0,let s=read(node,"AXSize").0,CFGetTypeID(p)==AXValueGetTypeID(),CFGetTypeID(s)==AXValueGetTypeID() else { return nil }
        var point=CGPoint.zero,size=CGSize.zero
        guard AXValueGetValue(unsafeBitCast(p,to:AXValue.self),.cgPoint,&point),AXValueGetValue(unsafeBitCast(s,to:AXValue.self),.cgSize,&size) else { return nil }
        return CGRect(origin:point,size:size)
    }
    guard let main=elements(read(application,"AXMainWindow").0).first else { return "Main AX window unavailable." }
    let before=rect(main),started=ProcessInfo.processInfo.systemUptime
    var nodes:[AXUIElement]=[],queue:[(AXUIElement,Int,String)]=[],lines=[String](),cursor=0,limited=false
    func add(_ node:AXUIElement,_ depth:Int,_ via:String)->String {
        if let index=nodes.firstIndex(where:{ CFEqual($0,node) }) { return "T\(index)" }
        guard nodes.count<180 else { limited=true;return "not queued (limit)" }
        let id="T\(nodes.count)";nodes.append(node);queue.append((node,depth,via));return id
    }
    // AXSections may contain dictionaries, not just an array of AX elements.
    // Record structure and element references only; never dump text/value payloads.
    func sections(_ raw:CFTypeRef?)->(description:String,links:[(AXUIElement,String)]) {
        var descriptions=[String](),links=[(AXUIElement,String)](),visited=0
        func walk(_ value:Any,_ path:String,_ depth:Int) {
            guard visited<80,depth<=4 else { descriptions.append("\(path): structure limit");return }
            visited += 1
            let cf=value as CFTypeRef
            if CFGetTypeID(cf)==AXUIElementGetTypeID() {
                links.append((unsafeBitCast(cf,to:AXUIElement.self),path));descriptions.append("\(path): AX element");return
            }
            if let dictionary=value as? [String:Any] {
                descriptions.append("\(path): dictionary keys=[\(dictionary.keys.sorted().joined(separator:", "))]")
                for key in dictionary.keys.sorted().prefix(24) { walk(dictionary[key]!,path+"."+key,depth+1) }
            } else if let array=value as? [Any] {
                descriptions.append("\(path): array count=\(array.count)")
                for (index,item) in array.prefix(24).enumerated() { walk(item,path+"[\(index)]",depth+1) }
            } else {
                descriptions.append("\(path): non-element payload omitted (CF type \(CFGetTypeID(cf)))")
            }
        }
        if let raw { walk(raw,"AXSections",0) } else { descriptions.append("AXSections: no payload") }
        return (descriptions.joined(separator:"; "),links)
    }
    _=add(main,0,"main")
    for (node,path) in sections(read(main,"AXSections").0).links { _=add(node,1,"main."+path) }
    // Prioritise main content before catalogue/sidebar descendants consume the budget.
    for key in ["AXChildren","AXContents","AXVisibleChildren"] {
        for node in elements(read(main,key).0) { _=add(node,1,"main.\(key)") }
    }
    for node in elements(read(application,"AXWindows").0) { _=add(node,0,"AXWindows") }
    while cursor<queue.count && ProcessInfo.processInfo.systemUptime-started<2 {
        let (node,depth,via)=queue[cursor],id="T\(cursor)";cursor += 1
        AXUIElementSetMessagingTimeout(node,0.02)
        let role=read(node,"AXRole").0 as? String ?? "unknown"
        let bounds=rect(node)
        lines.append("\(id) via=\(via) role=\(role) frame=\(bounds.map { String(describing:$0) } ?? "unavailable")")
        var rawNames:CFArray?
        let namesStatus=AXUIElementCopyAttributeNames(node,&rawNames)
        let names=(rawNames as? [String] ?? []).sorted()
        lines.append("  supported attributes (\(namesStatus.rawValue)): \(names.joined(separator:", "))")
        // AXHidden is normally application-level; unsupported on a control is unknown.
        for key in ["AXHidden","AXVisible"] {
            let (value,status)=read(node,key)
            let flag:String
            if let value,CFGetTypeID(value)==CFBooleanGetTypeID() { flag=CFBooleanGetValue(unsafeBitCast(value,to:CFBoolean.self)) ? "true":"false" }
            else { flag="unknown" }
            lines.append("  \(key)=\(flag), status=\(status.rawValue)")
        }
        let (parentRaw,parentStatus)=read(node,"AXParent")
        if let parent=elements(parentRaw).first {
            let parentRole=read(parent,"AXRole").0 as? String ?? "unknown"
            let parentFrame=rect(parent)
            let parentID=parentRole == "AXApplication" ? "application":add(parent,min(depth+1,3),"\(id).AXParent")
            lines.append("  actual AXParent=\(parentID) role=\(parentRole) frame=\(parentFrame.map { String(describing:$0) } ?? "unavailable")")
        } else { lines.append("  AXParent unavailable, status=\(parentStatus.rawValue)") }
        let (sectionRaw,sectionStatus)=read(node,"AXSections")
        let sectionInfo=sections(sectionRaw)
        var sectionIDs=[String]()
        if depth<2 {
            for (element,path) in sectionInfo.links { sectionIDs.append(add(element,depth+1,id+"."+path)) }
        }
        lines.append("  AXSections: status=\(sectionStatus.rawValue), refs=\(sectionIDs.joined(separator:",")); \(sectionInfo.description)\(depth<2 ? "":"; descendants not traversed (shallow probe)")")
        for key in ["AXChildren","AXContents","AXVisibleChildren","AXToolbarButton"] {
            let (raw,status)=read(node,key),related=elements(raw)
            var ids=[String]()
            if depth<2 {
                for child in related { ids.append(add(child,depth+1,"\(id).\(key)")) }
            }
            lines.append("  \(key): status=\(status.rawValue), elements=\(related.count)\(depth<2 ? ", refs="+ids.joined(separator:","):", descendants not traversed (shallow probe)")")
        }
    }
    let after=rect(main)
    return "Collected: \(Date())\nFocused toolbar probe; top-left global points; no text/value reads.\nHost before: \(String(describing:before)); after: \(String(describing:after)); unchanged=\(before != nil && before==after).\nExamined \(cursor)/\(queue.count); capped=\(limited || cursor<queue.count); unexpected read errors=\(errors); elapsed \(Int((ProcessInfo.processInfo.systemUptime-started)*1000)) ms.\nShallow related-element traversal only; no claim of exhaustive AX coverage. AXToolbarButton is a title-bar toggle when provided, not toolbar bounds. Unsupported visibility is unknown.\n"+lines.joined(separator:"\n")
}
