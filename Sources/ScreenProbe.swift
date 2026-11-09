import AppKit
import ScreenCaptureKit

struct ScreenProbeResult {
    let candidate:CGRect?
    let summary:String
    var windowID:CGWindowID? = nil
    var geometryChanged=false
    var windowFrame:CGRect? = nil
    var layoutKey:String? = nil
    var split:Bool = false
    var background:[Double] = [0,0,0]
    var snapEdges:[SnapEdge] = []
    var photoFrame:CGRect? = nil
    var previewImage:CGImage? = nil
}
struct EdgeRaster {
    let width: Int, height: Int
    let rgba: [UInt8]
    init(width:Int,height:Int,rgba:[UInt8]) { self.width=width;self.height=height;self.rgba=rgba }
    init?(image:CGImage) {
        let scale=min(1,2560/Double(image.width))
        width=max(1,Int(Double(image.width)*scale)); height=max(1,Int(Double(image.height)*scale))
        guard let c=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,
            space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue), let data=c.data else { return nil }
        c.draw(image,in:CGRect(x:0,y:0,width:width,height:height))
        rgba=Array(UnsafeBufferPointer(start:data.assumingMemoryBound(to:UInt8.self),count:width*height*4))
    }
}

// CG window-list geometry is top-left screen coordinates, matched by exact window ID.
func currentCaptureWindowFrame(_ id:CGWindowID)->CGRect? {
    guard let rows=CGWindowListCopyWindowInfo(.optionIncludingWindow,id) as? [[String:Any]],
          let row=rows.first(where:{($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value==id}),
          let data=row[kCGWindowBounds as String] as? [String:Any] else { return nil }
    return CGRect(dictionaryRepresentation:data as CFDictionary)
}
func sameWindowGeometry(_ a:CGRect?,_ b:CGRect?)->Bool {
    guard let a,let b else { return false }
    return abs(a.minX-b.minX)<0.5 && abs(a.minY-b.minY)<0.5 && abs(a.width-b.width)<0.5 && abs(a.height-b.height)<0.5
}
func appKitRect(_ rect:CGRect,primaryHeight:CGFloat)->CGRect {
    CGRect(x:rect.minX,y:primaryHeight-rect.maxY,width:rect.width,height:rect.height)
}
@available(macOS 14.0, *)
func inspectScreenLayout(imageSize:CGSize,forCalibration:Bool=false,previewCapture:Bool=false,settings:DetectionConfig=DetectionConfig()) async -> ScreenProbeResult {
    for attempt in 0..<3 {
        let result=await captureStableLayout(imageSize:imageSize,forCalibration:forCalibration,previewCapture:previewCapture,settings:settings)
        if !result.geometryChanged || Task.isCancelled { return result }
        await ScreenGeometryCache.shared.reset()
        if attempt<2 { try? await Task.sleep(nanoseconds:250_000_000) }
    }
    return ScreenProbeResult(candidate:nil,summary:"Lightroom is still moving or resizing. Wait for the transition to finish, then invoke again. Calibration was not changed.",geometryChanged:true)
}
@available(macOS 14.0, *)
func captureStableLayout(imageSize:CGSize,forCalibration:Bool=false,previewCapture:Bool=false,settings:DetectionConfig=DetectionConfig()) async -> ScreenProbeResult {
    guard CGPreflightScreenCaptureAccess() else { return ScreenProbeResult(candidate:nil,summary:"Screen Recording permission is required. Use Inspect screen layout again to open permission settings.") }
    let ticket=await ScreenGeometryCache.shared.ticket()
    do {
        let content=try await SCShareableContent.excludingDesktopWindows(true,onScreenWindowsOnly:true)
        let windows=content.windows.filter {
            guard let owner=$0.owningApplication else { return false }
            return (owner.bundleIdentifier.hasPrefix("com.adobe.LightroomClassic") || owner.applicationName=="Adobe Lightroom Classic") && $0.windowLayer==0 && $0.frame.width>600 && $0.frame.height>400
        }.sorted { $0.frame.width*$0.frame.height > $1.frame.width*$1.frame.height }
        guard let window=windows.first else { return ScreenProbeResult(candidate:nil,summary:"No visible Lightroom window suitable for inspection.") }
        guard windows.count==1 || windows[1].frame.width*windows[1].frame.height < window.frame.width*window.frame.height*0.7 else {
            return ScreenProbeResult(candidate:nil,summary:"More than one large Lightroom window is visible. Close the secondary view or dialog before inspecting.")
        }
        let originFrame=window.frame
        guard sameWindowGeometry(originFrame,currentCaptureWindowFrame(window.windowID)) else {
            return ScreenProbeResult(candidate:nil,summary:"Capture window geometry changed.",geometryChanged:true)
        }
        try await Task.sleep(nanoseconds:150_000_000)
        try Task.checkCancellation()
        guard sameWindowGeometry(originFrame,currentCaptureWindowFrame(window.windowID)) else {
            return ScreenProbeResult(candidate:nil,summary:"Waiting for stable window geometry.",geometryChanged:true)
        }
        let filter=SCContentFilter(desktopIndependentWindow:window)
        let config=SCStreamConfiguration()
        let scale=min(max(1,Double(filter.pointPixelScale)),min(6000/window.frame.width,4000/window.frame.height))
        config.width=max(1,Int(window.frame.width*scale)); config.height=max(1,Int(window.frame.height*scale))
        config.showsCursor=false; config.capturesAudio=false; config.ignoreShadowsSingleWindow=true
        if #available(macOS 14.2, *) { config.includeChildWindows=true }
        let image=try await SCScreenshotManager.captureImage(contentFilter:filter,configuration:config)
        try Task.checkCancellation()
        guard sameWindowGeometry(originFrame,currentCaptureWindowFrame(window.windowID)) else {
            return ScreenProbeResult(candidate:nil,summary:"Window changed during capture.",geometryChanged:true)
        }
        if previewCapture {
            return ScreenProbeResult(candidate:nil,summary:"Captured Lightroom window: \(image.width) × \(image.height) pixels. Same capture path as detection/calibration; child windows included on macOS 14.2+. In-memory preview only; closing releases it.",previewImage:image)
        }
        guard let raster=EdgeRaster(image:image) else { return ScreenProbeResult(candidate:nil,summary:"Could not inspect the captured pixels.") }
        if forCalibration {
            let edges=calibrationEdges(in:raster,window:window.frame,primaryHeight:CGDisplayBounds(CGMainDisplayID()).height,config:settings)
            let childMode:String
            if #available(macOS 14.2,*) { childMode="included" } else { childMode="system default (macOS 14.0/14.1)" }
            let summary="Calibration capture: \(image.width) × \(image.height) pixels; child windows: \(childMode).\nEdge segments: \(edges.filter{$0.vertical}.count) vertical, \(edges.filter{!$0.vertical}.count) horizontal.\nMinimum edge fractions V/H: \(settings.verticalSnapFraction)/\(settings.horizontalSnapFraction); snap radius: \(settings.snapDistancePoints) pt.\nOption aligns the full crosshair lines; segments need not meet. No image saved."
            return ScreenProbeResult(candidate:nil,summary:summary,windowID:window.windowID,windowFrame:window.frame,snapEdges:edges)
        }
        guard let (detection,reused)=await ScreenGeometryCache.shared.inspect(raster,key:"\(window.windowID):\(window.frame):\(filter.pointPixelScale):\(CGDisplayBounds(CGMainDisplayID()))",ticket:ticket,singlePhoto:true) else {
            return ScreenProbeResult(candidate:nil,summary:"Window/display geometry was invalidated during capture.",geometryChanged:true)
        }
        let childMode:String
        if #available(macOS 14.2,*) { childMode="included" } else { childMode="system default" }
        let header="Child windows: \(childMode).\nUI-boundary detection (no OCR; no image saved).\nWindow: \(Int(window.frame.width)) × \(Int(window.frame.height)) pt.\nWindow origin (top-left): \(window.frame.origin).\nFilter content rect: \(filter.contentRect).\nPrimary display: \(CGDisplayBounds(CGMainDisplayID())).\nCapture: \(image.width) × \(image.height) pixels.\n"
        var candidate:CGRect?,photoFrame:CGRect?
        var key:String?
        var placementSummary=""
        if let viewport=detection.bounds {
            let sx=window.frame.width/CGFloat(raster.width),sy=window.frame.height/CGFloat(raster.height)
            let ui=CGRect(x:window.frame.minX+viewport.minX*sx,y:window.frame.minY+viewport.minY*sy,width:viewport.width*sx,height:viewport.height*sy)
            func screen(_ r:CGRect)->CGRect { appKitRect(r,primaryHeight:CGDisplayBounds(CGMainDisplayID()).height) }
            if let placed=settings.placement(ui:ui,image:imageSize) {
                candidate=screen(placed.region);photoFrame=screen(placed.photo)
                placementSummary="\nSides L/R/T/B: \(settings.left.rawValue)/\(settings.right.rawValue)/\(settings.top.rawValue)/\(settings.bottom.rawValue). Fit inset: \(settings.fitInsetPoints) pt. Calculated photo: \(placed.photo)."
            } else if !settings.needsPhoto {
                candidate=screen(ui)
            } else {
                placementSummary="\nUI bounds found, but current JPEG dimensions are unavailable. Load the current reference to calculate Photo-bound sides; no guessed region applied."
            }
            key="\(window.windowID):\(window.frame.size):\(viewport):\(settings.key):\(imageSize)"
        }
        return ScreenProbeResult(candidate:candidate,summary:header+(reused ? "Reused viewport; border samples unchanged.\n" : "Searched for UI borders.\n")+detection.summary+placementSummary+"\nFinal overlay region (AppKit): \(candidate.map{String(describing:$0)} ?? "none").\nPhoto frame (AppKit): \(photoFrame.map{String(describing:$0)} ?? "none").",
            windowID:window.windowID,windowFrame:window.frame,layoutKey:key,split:false,background:detection.background,photoFrame:photoFrame)

    } catch is CancellationError { return ScreenProbeResult(candidate:nil,summary:"Screen inspection cancelled.") }
    catch { return ScreenProbeResult(candidate:nil,summary:"Screen inspection failed. Check permission, keep Lightroom visible and try again. No capture was saved.") }
}
