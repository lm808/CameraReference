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
