import AppKit
import ScreenCaptureKit

struct ScreenProbeResult {
    let candidate:CGRect?
    let summary:String
    var windowID:CGWindowID? = nil
    var geometryChanged=false
    var workingAreaTooNarrow=false
    var windowFrame:CGRect? = nil
    var layoutKey:String? = nil
    var split:Bool = false
    var background:[Double] = [0,0,0]
    var snapEdges:[SnapEdge] = []
    var photoFrame:CGRect? = nil
    var uiFrame:CGRect? = nil
    var previewImage:CGImage? = nil
    var displayContainedCapture=false
    var placementUnavailableReason:String? = nil
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

// A display-bound, window-filtered capture uses an explicit display-local crop.
// Do not infer the captured extent from the output bitmap size: window child
// surfaces can extend beyond the parent, especially after a resize.
func windowCaptureSourceRect(window:CGRect, display:CGRect) -> CGRect? {
    guard window.width > 0, window.height > 0, display.contains(window) else { return nil }
    return window.offsetBy(dx:-display.minX,dy:-display.minY)
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
func inspectScreenLayout(imageSize:CGSize,forCalibration:Bool=false,previewCapture:Bool=false,settings:DetectionConfig=DetectionConfig(),layout:OverlayLayout = .full,seed:CGRect? = nil,maxPixelWidth:CGFloat? = nil) async -> ScreenProbeResult {
    for attempt in 0..<3 {
        let result=await captureStableLayout(imageSize:imageSize,forCalibration:forCalibration,previewCapture:previewCapture,settings:settings,layout:layout,seed:seed,maxPixelWidth:maxPixelWidth)
        if !result.geometryChanged || Task.isCancelled { return result }
        await ScreenGeometryCache.shared.reset()
        if attempt<2 { try? await Task.sleep(nanoseconds:250_000_000) }
    }
    return ScreenProbeResult(candidate:nil,summary:"Lightroom is still moving or resizing. Wait for the transition to finish, then invoke again. Calibration was not changed.",geometryChanged:true)
}
@available(macOS 14.0, *)
func captureStableLayout(imageSize:CGSize,forCalibration:Bool=false,previewCapture:Bool=false,settings:DetectionConfig=DetectionConfig(),layout:OverlayLayout = .full,seed:CGRect? = nil,maxPixelWidth:CGFloat? = nil) async -> ScreenProbeResult {
    guard CGPreflightScreenCaptureAccess() else { return ScreenProbeResult(candidate:nil,summary:"Screen Recording permission is required. Use Inspect screen layout again to open permission settings.") }
    let probeStarted=ProcessInfo.processInfo.systemUptime
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
        let enumerationEnded=ProcessInfo.processInfo.systemUptime
        let originFrame=window.frame
        guard sameWindowGeometry(originFrame,currentCaptureWindowFrame(window.windowID)) else {
            return ScreenProbeResult(candidate:nil,summary:"Capture window geometry changed.",geometryChanged:true)
        }
        try await Task.sleep(nanoseconds:150_000_000)
        try Task.checkCancellation()
        guard sameWindowGeometry(originFrame,currentCaptureWindowFrame(window.windowID)) else {
            return ScreenProbeResult(candidate:nil,summary:"Waiting for stable window geometry.",geometryChanged:true)
        }
        let display=content.displays.first(where:{ windowCaptureSourceRect(window:originFrame,display:$0.frame) != nil })
        // User compared 1.0.8's uncropped preview against an on-screen baseline.
        // Preserve this path for off-screen detection and calibration; never set
        // a display-local sourceRect on the independent window filter.
        let filter=display.map { SCContentFilter(display:$0,including:[window]) }
            ?? SCContentFilter(desktopIndependentWindow:window)
        let extent=display?.frame ?? filter.contentRect
        let sourceRect=display.flatMap { windowCaptureSourceRect(window:originFrame,display:$0.frame) }
        let captureMode=display == nil ? "window-only filter, full surface (no source crop)":"display-bound window filter, explicit crop"
        let cropDescription=sourceRect.map(String.init(describing:)) ?? "not set for single-window capture"
        let captureKey="\(captureMode):\(display?.displayID ?? 0):\(extent):\(cropDescription)"
        let config=SCStreamConfiguration()
        if let sourceRect { config.sourceRect=sourceRect }
        config.scalesToFit=true
        config.ignoreShadowsDisplay=true
        let nativeScale=min(max(1,Double(filter.pointPixelScale)),min(6000/window.frame.width,4000/window.frame.height))
        let scale=min(nativeScale,maxPixelWidth.map { Double($0/window.frame.width) } ?? nativeScale)
        config.width=max(1,Int(window.frame.width*scale)); config.height=max(1,Int(window.frame.height*scale))
        config.showsCursor=false; config.capturesAudio=false; config.ignoreShadowsSingleWindow=true
        if #available(macOS 14.2, *) { config.includeChildWindows=true }
        let captureStarted=ProcessInfo.processInfo.systemUptime
        let image=try await SCScreenshotManager.captureImage(contentFilter:filter,configuration:config)
        let captureEnded=ProcessInfo.processInfo.systemUptime
        try Task.checkCancellation()
        guard sameWindowGeometry(originFrame,currentCaptureWindowFrame(window.windowID)) else {
            return ScreenProbeResult(candidate:nil,summary:"Window changed during capture.",geometryChanged:true)
        }
        let captureSummary="Capture mode: \(captureMode).\nWindow (top-left points): \(originFrame).\nFilter content rect: \(filter.contentRect).\nCapture extent: \(extent). Source crop: \(cropDescription).\nRequested output: \(config.width) × \(config.height); actual: \(image.width) × \(image.height) pixels; filter scale: \(filter.pointPixelScale).\nChild windows: \(ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion:14,minorVersion:2,patchVersion:0)) ? "included":"system default"). No image saved."
        if previewCapture {
            return ScreenProbeResult(candidate:nil,summary:captureSummary+"\nIn-memory preview only. Compare complete window corners and panel edges against an on-screen baseline; bitmap dimensions alone do not prove alignment.",windowID:window.windowID,windowFrame:originFrame,previewImage:image,displayContainedCapture:display != nil)
        }
        guard let raster=EdgeRaster(image:image) else { return ScreenProbeResult(candidate:nil,summary:"Could not inspect the captured pixels.") }
        if forCalibration {
            let edges=calibrationEdges(in:raster,window:window.frame,primaryHeight:CGDisplayBounds(CGMainDisplayID()).height,config:settings)
            let childMode:String
            if #available(macOS 14.2,*) { childMode="included" } else { childMode="system default (macOS 14.0/14.1)" }
            let summary="Calibration capture: \(image.width) × \(image.height) pixels; child windows: \(childMode).\nEdge segments: \(edges.filter{$0.vertical}.count) vertical, \(edges.filter{!$0.vertical}.count) horizontal.\nMinimum edge fractions V/H: \(settings.verticalSnapFraction)/\(settings.horizontalSnapFraction); snap radius: \(settings.snapDistancePoints) pt.\nOption aligns the full crosshair lines; segments need not meet. No image saved."
            return ScreenProbeResult(candidate:nil,summary:summary,windowID:window.windowID,windowFrame:window.frame,snapEdges:edges)
        }
        let detectionStarted=ProcessInfo.processInfo.systemUptime
        let detection:ViewportDetection
        let reused:Bool
        if layout == .full {
            guard let result=await ScreenGeometryCache.shared.inspect(raster,key:"crop:\(captureKey):\(window.windowID):\(window.frame):\(filter.pointPixelScale):\(CGDisplayBounds(CGMainDisplayID()))",ticket:ticket,singlePhoto:true,sideSearchPercent:settings.sideSearchPercent) else {
                return ScreenProbeResult(candidate:nil,summary:"Window/display geometry was invalidated during capture.",geometryChanged:true)
            }
            (detection,reused)=result
        } else {
            let sx=CGFloat(raster.width)/window.frame.width,sy=CGFloat(raster.height)/window.frame.height
            let local=seed.map { seed -> CGRect in
                let top=appKitRect(seed,primaryHeight:CGDisplayBounds(CGMainDisplayID()).height)
                return CGRect(x:(top.minX-window.frame.minX)*sx,y:(top.minY-window.frame.minY)*sy,width:top.width*sx,height:top.height*sy)
            }
            detection=detectSplitViewport(in:raster,layout:layout,seed:local,sideSearchPercent:settings.sideSearchPercent,insetPixels:CGSize(width:settings.fitInsetPoints*sx,height:settings.fitInsetPoints*sy))
            reused=false
        }
        let childMode:String
        if #available(macOS 14.2,*) { childMode="included" } else { childMode="system default" }
        let timing=String(format:"Stage timing: enumerate %.0f ms; stability/config %.0f ms; capture %.0f ms; raster %.0f ms; detector %.0f ms.\n",(enumerationEnded-probeStarted)*1000,(captureStarted-enumerationEnded)*1000,(captureEnded-captureStarted)*1000,(detectionStarted-captureEnded)*1000,(ProcessInfo.processInfo.systemUptime-detectionStarted)*1000)
        let header=timing+"Capture mode: \(captureMode).\nCapture extent (top-left): \(extent).\nSource crop (capture-local): \(cropDescription).\nSide search: left 0…\(settings.sideSearchPercent)%, right \(100-settings.sideSearchPercent)…100%.\nAnalysis raster: \(raster.width) × \(raster.height).\nChild windows: \(childMode).\nUI-boundary detection (no OCR; no image saved).\nWindow: \(Int(window.frame.width)) × \(Int(window.frame.height)) pt.\nWindow origin (top-left): \(window.frame.origin).\nFilter content rect: \(filter.contentRect).\nPrimary display: \(CGDisplayBounds(CGMainDisplayID())).\nCapture: \(image.width) × \(image.height) pixels.\n"
        var candidate:CGRect?,photoFrame:CGRect?,uiFrame:CGRect?
        var key:String?
        var placementSummary=""
        if let viewport=detection.bounds {
            let sx=window.frame.width/CGFloat(raster.width),sy=window.frame.height/CGFloat(raster.height)
            let ui=CGRect(x:window.frame.minX+viewport.minX*sx,y:window.frame.minY+viewport.minY*sy,width:viewport.width*sx,height:viewport.height*sy)
            func screen(_ r:CGRect)->CGRect { appKitRect(r,primaryHeight:CGDisplayBounds(CGMainDisplayID()).height) }
            uiFrame=screen(ui)
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
            windowID:window.windowID,workingAreaTooNarrow:detection.workingAreaTooNarrow,windowFrame:window.frame,layoutKey:key,split:false,background:detection.background,photoFrame:photoFrame,uiFrame:uiFrame)

    } catch is CancellationError { return ScreenProbeResult(candidate:nil,summary:"Screen inspection cancelled.") }
    catch { return ScreenProbeResult(candidate:nil,summary:"Screen inspection failed. Check permission, keep Lightroom visible and try again. No capture was saved.") }
}

// Always obtain the combined viewport through the unchanged Full detector.
// A previous pane hint must not substitute different outer bounds.
func detectSplitViewport(in raster:EdgeRaster,layout:OverlayLayout,seed _:CGRect?=nil,sideSearchPercent:Double=45,insetPixels:CGSize=CGSize(width:18,height:18))->ViewportDetection {
    let full=detectViewport(in:raster,singlePhoto:true,sideSearchPercent:sideSearchPercent)
    guard let viewport=full.bounds else { return full }
    let scan=scanInsetDivider(in:raster,viewport:viewport,layout:layout,insetPixels:insetPixels)
    let pane=layout.pane(in:viewport,vertical:layout.group==1 ? scan.position:nil,horizontal:layout.group==2 ? scan.position:nil)
    return ViewportDetection(bounds:pane,verticalDivider:nil,horizontalDivider:nil,background:full.background,summary:full.summary+"\n"+scan.summary+"\nSelected \(layout.label) pane: \(String(describing:pane)).")
}

// Pixel coordinates. Scan only the bottom margin for left/right, left margin for
// upper/lower. Several parallel traces tolerate short divider endpoint gaps.
func scanInsetDivider(in raster:EdgeRaster,viewport:CGRect,layout:OverlayLayout,insetPixels:CGSize)->(position:CGFloat?,summary:String) {
    let vertical=layout.group==1
    let inset=vertical ? insetPixels.height:insetPixels.width
    let name=vertical ? "bottom":"left"
    guard layout != .full,inset.isFinite,inset>=4,viewport.width>0,viewport.height>0 else {
        return (nil,"Configured inset is too small for reliable divider scanning; calibrate manually.")
    }
    func rgb(_ x:Int,_ y:Int)->[Int]? {
        guard x>=0,y>=0,x<raster.width,y<raster.height else { return nil }
        let i=(y*raster.width+x)*4
        return (0..<3).map { Int(raster.rgba[i+$0]) }
    }
    func difference(_ a:[Int],_ b:[Int])->Int { zip(a,b).map { abs($0-$1) }.max()! }
    let start=vertical ? viewport.minX:viewport.minY,end=vertical ? viewport.maxX:viewport.maxY
    let low=Int(start+(end-start)*0.2),high=Int(start+(end-start)*0.8)
    guard high>low else { return (nil,"No interior divider search interval.") }
    let first=max(2,Int(ceil(inset*0.2))),last=Int(floor(inset*0.8))
    guard last>=first else { return (nil,"Inset leaves no usable scan band.") }
    let offsets=Array(Set((0..<12).map { first+(last-first)*$0/11 })).sorted()
    // Width allowance scales with the available inset; wider objects are not thin dividers.
    let flank=max(2,min(8,Int(ceil(inset/6))))
    var supported=[Int]()
    for position in low..<high {
        var hits=0
        for offset in offsets {
            let across=vertical ? Int(viewport.maxY)-1-offset:Int(viewport.minX)+offset
            let c=vertical ? rgb(position,across):rgb(across,position)
            let a=vertical ? rgb(position-flank,across):rgb(across,position-flank)
            let b=vertical ? rgb(position+flank,across):rgb(across,position+flank)
            if let c,let a,let b,difference(a,b)<=6,difference(c,a)>=3,difference(c,b)>=3 { hits+=1 }
        }
        if hits>=max(2,Int(ceil(Double(offsets.count)*0.5))) { supported.append(position) }
    }
    var groups=[[Int]]()
    for position in supported {
        if let last=groups.last?.last,position-last<=2 { groups[groups.count-1].append(position) }
        else { groups.append([position]) }
    }
    let valid=groups.filter { $0.last!-$0.first!<=flank*2 }
    let detail="Full viewport \(viewport); \(name) inset \(inset) raster pixels, offsets \(first)…\(last), \(offsets.count) traces; \(valid.count) thin-line candidates."
    guard valid.count==1,groups.count==1 else { return (nil,detail+" Missing/ambiguous divider; calibrate manually.") }
    return (CGFloat(valid[0].first!+valid[0].last!)/2,detail)
}
