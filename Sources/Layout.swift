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
    return HostWindowSnapshot(id:id,frame:appKit,onScreen:(row[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false)
}
// Public window-list metadata only. Dock's screen-sized presentation surfaces
// cover Mission Control/Exposé (and Launchpad); ordinary Dock strips do not.
// Native .transient suppression remains the primary overview behaviour.
func workspaceOverviewIsVisible()->Bool {
    guard let dock=NSWorkspace.shared.runningApplications.first(where:{$0.bundleIdentifier=="com.apple.dock"}),
          let rows=CGWindowListCopyWindowInfo(.optionOnScreenOnly,kCGNullWindowID) as? [[String:Any]] else { return false }
    let screens=NSScreen.screens.map { CGRect(x:$0.frame.minX,y:CGDisplayBounds(CGMainDisplayID()).height-$0.frame.maxY,width:$0.frame.width,height:$0.frame.height) }
    return rows.contains { row in
        guard (row[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value==dock.processIdentifier,
              let d=row[kCGWindowBounds as String] as? [String:Any],let frame=CGRect(dictionaryRepresentation:d as CFDictionary) else { return false }
        return screens.contains { screen in
            let overlap=frame.intersection(screen)
            return !overlap.isNull && overlap.width*overlap.height>screen.width*screen.height*0.65
        }
    }
}

enum OverlayHostAction:Equatable { case suspend,discard,translate(CGPoint) }
func overlayHostAction(saved:CGRect,current:CGRect?,onScreen:Bool,overview:Bool)->OverlayHostAction {
    if overview { return .suspend }
    guard let current else { return .discard }
    if !onScreen { return .suspend }
    guard abs(saved.width-current.width)<0.5,abs(saved.height-current.height)<0.5 else { return .discard }
    return .translate(CGPoint(x:current.minX-saved.minX,y:current.minY-saved.minY))
}
