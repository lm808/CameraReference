import AppKit

// Geometry independent of native windows, shared by both presentation styles.
struct ImageNavigation {
    var zoom: CGFloat = 1
    var pan = CGPoint.zero
    mutating func reset() { zoom = 1; pan = .zero }
    mutating func clamp(image: CGSize, viewport: CGSize) {
        let rect=CGRect(origin:.zero,size:viewport)
        clamp(image:image,fitRect:rect,viewport:rect)
    }
    mutating func clamp(image:CGSize,fitRect:CGRect,viewport:CGRect) {
        let fit=fittedSize(image:image,inside:fitRect.size)
        func limit(_ offset:CGFloat,center:CGFloat,half:CGFloat,low:CGFloat,high:CGFloat)->CGFloat {
            let minimum=high-center-half,maximum=low-center+half
            // Keep original Fit alignment on axes where the image remains
            // smaller than the drawing region; otherwise permit edge-to-edge pan.
            return minimum<=maximum ? min(maximum,max(minimum,offset)):0
        }
        pan.x=limit(pan.x,center:fitRect.midX,half:fit.width*zoom/2,low:viewport.minX,high:viewport.maxX)
        pan.y=limit(pan.y,center:fitRect.midY,half:fit.height*zoom/2,low:viewport.minY,high:viewport.maxY)
    }
    mutating func magnify(factor: CGFloat, at point: CGPoint, image: CGSize, viewport: CGRect, fitRect:CGRect? = nil) {
        guard factor.isFinite, factor > 0 else { return }
        let fit=fitRect ?? viewport,previous=zoom
        zoom = min(64,max(0.05,zoom*factor))
        pan.x = point.x-fit.midX-(point.x-fit.midX-pan.x)*zoom/previous
        pan.y = point.y-fit.midY-(point.y-fit.midY-pan.y)*zoom/previous
        clamp(image:image,fitRect:fit,viewport:viewport)
    }
    mutating func move(dx: CGFloat, dy: CGFloat, image: CGSize, viewport: CGSize) {
        let rect=CGRect(origin:.zero,size:viewport)
        move(dx:dx,dy:dy,image:image,fitRect:rect,viewport:rect)
    }
    mutating func move(dx:CGFloat,dy:CGFloat,image:CGSize,fitRect:CGRect,viewport:CGRect) {
        pan.x += dx; pan.y += dy;clamp(image:image,fitRect:fitRect,viewport:viewport)
    }
}

enum ScrollIntent: Equatable { case ignore, pan, zoom }
func scrollIntent(command: Bool, precise: Bool, momentum: Bool) -> ScrollIntent {
    guard !momentum else { return .ignore }
    if command { return .zoom }
    return precise ? .pan : .ignore
}

struct DisplayGeometry: Codable, Equatable {
    let id: UInt32
    let x: Double, y: Double, width: Double, height: Double, scale: Double
    var frame: CGRect { CGRect(x:x,y:y,width:width,height:height) }
    init(id: UInt32, frame: CGRect, scale: Double) {
        self.id=id; x=frame.minX; y=frame.minY; width=frame.width; height=frame.height; self.scale=scale
    }
}
func currentDisplays() -> [DisplayGeometry] {
    NSScreen.screens.map {
        DisplayGeometry(id: ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0,
                        frame: $0.frame, scale: $0.backingScaleFactor)
    }
}
func calibratedRegionIsUsable(_ region: CGRect, savedDisplay: DisplayGeometry?, current: [DisplayGeometry]) -> Bool {
    guard region.width > 100, region.height > 100 else { return false }
    if let savedDisplay { return current.contains(savedDisplay) && savedDisplay.frame.contains(region) }
    return current.contains { $0.frame.contains(region) }
}

struct ExportSnapshot {
    let raw: URL
    let bytes: Data
    let orientation: UInt32?
    var destination: URL { raw.deletingLastPathComponent().appendingPathComponent(raw.deletingPathExtension().lastPathComponent + "_JpgFromRaw.jpg") }
}

// Choose empty top/bottom or side margin; never draw over image pixels.
func referenceLabelRect(viewport:CGRect,imageFrame:CGRect,labelSize:CGSize)->CGRect? {
    let visible=imageFrame.intersection(viewport)
    guard !visible.isNull else { return nil }
    let margin:CGFloat=8
    let regions=[CGRect(x:viewport.minX,y:visible.maxY,width:viewport.width,height:viewport.maxY-visible.maxY),
                 CGRect(x:viewport.minX,y:viewport.minY,width:viewport.width,height:visible.minY-viewport.minY),
                 CGRect(x:viewport.minX,y:viewport.minY,width:visible.minX-viewport.minX,height:viewport.height),
                 CGRect(x:visible.maxX,y:viewport.minY,width:viewport.maxX-visible.maxX,height:viewport.height)]
    guard let area=regions.first(where:{$0.width>=labelSize.width+2*margin && $0.height>=labelSize.height+8}) else { return nil }
    return CGRect(x:area.minX+margin,y:area.maxY-4-labelSize.height,width:labelSize.width,height:labelSize.height)
}

// AppKit may round borderless frames to whole points, even on Retina displays.
// This policy applies only to final panel placement, never capture stability.
func overlayPlacementIsAcceptable(requested:CGRect, actual:CGRect) -> Bool {
    let pairs = [(requested.minX,actual.minX),(requested.minY,actual.minY),
                 (requested.maxX,actual.maxX),(requested.maxY,actual.maxY),
                 (requested.width,actual.width),(requested.height,actual.height)]
    return requested.width > 0 && requested.height > 0 && actual.width > 0 && actual.height > 0 &&
        pairs.allSatisfy { $0.0.isFinite && $0.1.isFinite && abs($0.0-$0.1) <= 1.000001 }
}
