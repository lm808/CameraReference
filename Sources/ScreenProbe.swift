import AppKit
import ScreenCaptureKit
import VideoToolbox

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
func inspectScreenLayout(imageSize:CGSize,forCalibration:Bool=false,previewCapture:Bool=false,settings:DetectionConfig=DetectionConfig(),layout:OverlayLayout = .full,maxPixelWidth:CGFloat? = nil) async -> ScreenProbeResult {
    for attempt in 0..<3 {
        let result=await captureStableLayout(imageSize:imageSize,forCalibration:forCalibration,previewCapture:previewCapture,settings:settings,layout:layout,maxPixelWidth:maxPixelWidth)
        if !result.geometryChanged || Task.isCancelled { return result }
        await ScreenGeometryCache.shared.reset()
        if attempt<2 { try? await Task.sleep(nanoseconds:250_000_000) }
    }
    return ScreenProbeResult(candidate:nil,summary:"Lightroom is still moving or resizing. Wait for the transition to finish, then invoke again. Calibration was not changed.",geometryChanged:true)
}
@available(macOS 14.0, *)
func captureStableLayout(imageSize:CGSize,forCalibration:Bool=false,previewCapture:Bool=false,settings:DetectionConfig=DetectionConfig(),layout:OverlayLayout = .full,maxPixelWidth:CGFloat? = nil) async -> ScreenProbeResult {
    guard CGPreflightScreenCaptureAccess() else { return ScreenProbeResult(candidate:nil,summary:"Screen Recording permission is unavailable. No capture taken. Use AX placement or manual calibration.") }
    let probeStarted=ProcessInfo.processInfo.systemUptime
    let ticket=await ScreenGeometryCache.shared.ticket()
    var failureContext="Enumerating Lightroom windows."
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
        guard previewCapture || sameWindowGeometry(originFrame,currentCaptureWindowFrame(window.windowID)) else {
            return ScreenProbeResult(candidate:nil,summary:"Capture window geometry changed.",geometryChanged:true)
        }
        try await Task.sleep(nanoseconds:150_000_000)
        try Task.checkCancellation()
        guard previewCapture || sameWindowGeometry(originFrame,currentCaptureWindowFrame(window.windowID)) else {
            return ScreenProbeResult(candidate:nil,summary:"Waiting for stable window geometry.",geometryChanged:true)
        }
        let display=content.displays.first(where:{ windowCaptureSourceRect(window:originFrame,display:$0.frame) != nil })
        // Keep the accepted display crop. Independent-window capture must use
        // frame metadata to locate its parent pixels; never apply a display-local
        // sourceRect to that filter.
        let filter=display.map { SCContentFilter(display:$0,including:[window]) }
            ?? SCContentFilter(desktopIndependentWindow:window)
        let extent=display?.frame ?? filter.contentRect
        let sourceRect=display.flatMap { windowCaptureSourceRect(window:originFrame,display:$0.frame) }
        let captureMode=display == nil ? (previewCapture ? "window-only filter, raw unvalidated preview (no source crop)":"window-only filter, metadata-normalized parent (no source crop)"):"display-bound window filter, explicit crop"
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
        failureContext="Capture mode: \(captureMode).\nWindow: \(originFrame); filter content rect: \(filter.contentRect).\nRequested output: \(config.width) × \(config.height); filter scale: \(filter.pointPixelScale)."
        let captureStarted=ProcessInfo.processInfo.systemUptime
        let image:CGImage
        let frameDetail:String
        if display == nil {
            let frame=try await WindowCaptureFrame.capture(filter:filter,config:config,window:originFrame,preview:previewCapture)
            image=frame.image;frameDetail=frame.detail
        } else {
            image=try await SCScreenshotManager.captureImage(contentFilter:filter,configuration:config)
            frameDetail="Display-bound crop; frame normalization not needed."
        }
        let captureEnded=ProcessInfo.processInfo.systemUptime
        try Task.checkCancellation()
        guard previewCapture || sameWindowGeometry(originFrame,currentCaptureWindowFrame(window.windowID)) else {
            return ScreenProbeResult(candidate:nil,summary:"Window changed during capture.",geometryChanged:true)
        }
        let movementNote=sameWindowGeometry(originFrame,currentCaptureWindowFrame(window.windowID)) ? "":"Window moved during capture; raw preview retained for diagnosis.\n"
        let captureSummary=movementNote+frameDetail+"\nCapture mode: \(captureMode).\nWindow (top-left points): \(originFrame).\nFilter content rect: \(filter.contentRect).\nCapture extent: \(extent). Source crop: \(cropDescription).\nRequested output: \(config.width) × \(config.height); actual: \(image.width) × \(image.height) pixels; filter scale: \(filter.pointPixelScale).\nChild windows: \(ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion:14,minorVersion:2,patchVersion:0)) ? "included":"system default"). No image saved."
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
        guard let result=await ScreenGeometryCache.shared.inspect(raster,key:"crop:\(captureKey):\(window.windowID):\(window.frame):\(filter.pointPixelScale):\(CGDisplayBounds(CGMainDisplayID()))",ticket:ticket,singlePhoto:true,sideSearchPercent:settings.sideSearchPercent) else {
            return ScreenProbeResult(candidate:nil,summary:"Window/display geometry was invalidated during capture.",geometryChanged:true)
        }
        reused=result.1
        detection=splitViewport(result.0,layout:layout)
        let childMode:String
        if #available(macOS 14.2,*) { childMode="included" } else { childMode="system default" }
        let timing=String(format:"Stage timing: enumerate %.0f ms; stability/config %.0f ms; capture %.0f ms; raster %.0f ms; detector %.0f ms.\n",(enumerationEnded-probeStarted)*1000,(captureStarted-enumerationEnded)*1000,(captureEnded-captureStarted)*1000,(detectionStarted-captureEnded)*1000,(ProcessInfo.processInfo.systemUptime-detectionStarted)*1000)
        let header=timing+frameDetail+"\nCapture mode: \(captureMode).\nCapture extent (top-left): \(extent).\nSource crop (capture-local): \(cropDescription).\nInitial side search (validated retry to 50% if needed): left 0…\(settings.sideSearchPercent)%, right \(100-settings.sideSearchPercent)…100%.\nAnalysis raster: \(raster.width) × \(raster.height).\nChild windows: \(childMode).\nUI-boundary detection (no OCR; no image saved).\nWindow: \(Int(window.frame.width)) × \(Int(window.frame.height)) pt.\nWindow origin (top-left): \(window.frame.origin).\nFilter content rect: \(filter.contentRect).\nPrimary display: \(CGDisplayBounds(CGMainDisplayID())).\nCapture: \(image.width) × \(image.height) pixels.\n"
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
    catch { return ScreenProbeResult(candidate:nil,summary:captureFailureSummary(error,context:failureContext)) }
}

// Both screenshot layouts share the same independently validated outer area.
// The selected view determines orientation; image details never choose a divider.
func detectSplitViewport(in raster:EdgeRaster,layout:OverlayLayout,sideSearchPercent:Double=45)->ViewportDetection {
    splitViewport(detectViewport(in:raster,singlePhoto:true,sideSearchPercent:sideSearchPercent),layout:layout)
}
func splitViewport(_ full:ViewportDetection,layout:OverlayLayout)->ViewportDetection {
    if layout == .full { return full }
    guard let viewport=full.bounds else { return full }
    let pane=layout.pane(in:viewport,vertical:layout.group==1 ? viewport.midX:nil,horizontal:layout.group==2 ? viewport.midY:nil)
    return ViewportDetection(bounds:pane,verticalDivider:nil,horizontalDivider:nil,background:full.background,
        summary:full.summary+"\n50/50 split of validated outer area; selected \(layout.label): \(String(describing:pane)).")
}

// Map the reported content surface to the parent window, excluding compositor
// padding/child extent. All rectangles here are top-left based.
func parentWindowPixelCrop(window:CGRect,screenRect:CGRect,boundingRect:CGRect,scale:CGFloat,imageSize:CGSize)->CGRect? {
    let values=[window.minX,window.minY,window.width,window.height,screenRect.minX,screenRect.minY,screenRect.width,screenRect.height,boundingRect.minX,boundingRect.minY,boundingRect.width,boundingRect.height,scale,imageSize.width,imageSize.height]
    guard values.allSatisfy({$0.isFinite}),window.width>0,window.height>0,screenRect.width>0,screenRect.height>0,
          boundingRect.width>0,boundingRect.height>0,scale>0,
          screenRect.insetBy(dx:-1,dy:-1).contains(window) else { return nil }
    let pixels=CGRect(x:boundingRect.minX*scale,y:boundingRect.minY*scale,width:boundingRect.width*scale,height:boundingRect.height*scale)
    let sx=pixels.width/screenRect.width,sy=pixels.height/screenRect.height
    guard abs(sx/sy-1)<0.01 else { return nil }
    let crop=CGRect(x:pixels.minX+(window.minX-screenRect.minX)*sx,
                    y:pixels.minY+(window.minY-screenRect.minY)*sy,width:window.width*sx,height:window.height*sy).integral
    let surface=CGRect(origin:.zero,size:imageSize)
    guard surface.insetBy(dx:-1,dy:-1).contains(crop) else { return nil }
    return crop.intersection(surface)
}

@available(macOS 14.0, *)
// Mutable completion state is protected by lock; window is immutable.
private final class WindowCaptureFrame:NSObject,SCStreamOutput,SCStreamDelegate,@unchecked Sendable {
    typealias Frame=WindowFrameImage
    private let lock=NSLock()
    private var outcome:Result<Frame,Error>?
    private var continuation:CheckedContinuation<Frame,Error>?
    private let window:CGRect
    private let preview:Bool
    init(window:CGRect,preview:Bool) { self.window=window;self.preview=preview }
    private func finish(_ result:Result<Frame,Error>) {
        lock.lock()
        guard outcome == nil else { lock.unlock();return }
        outcome=result;let waiting=continuation;continuation=nil
        lock.unlock();waiting?.resume(with:result)
    }
    func cancel() { finish(.failure(CancellationError())) }
    func wait() async throws -> Frame {
        try await withTaskCancellationHandler(operation:{
            try await withCheckedThrowingContinuation { waiting in
                lock.lock()
                if let result=outcome { lock.unlock();waiting.resume(with:result);return }
                continuation=waiting;lock.unlock()
                DispatchQueue.global().asyncAfter(deadline:.now()+3) { [weak self] in
                    self?.finish(.failure(NSError(domain:"CameraReference.Capture",code:1,userInfo:[NSLocalizedDescriptionKey:"No complete window capture frame arrived within 3 seconds."])))
                }
            }
        },onCancel:{ self.cancel() })
    }
    func stream(_ stream:SCStream,didStopWithError error:Error) { finish(.failure(error)) }
    func stream(_ stream:SCStream,didOutputSampleBuffer sampleBuffer:CMSampleBuffer,of type:SCStreamOutputType) {
        guard type == .screen,sampleBuffer.isValid else { return }
        lock.lock();let done=outcome != nil;lock.unlock();guard !done else { return }
        let attachments=CMSampleBufferGetSampleAttachmentsArray(sampleBuffer,createIfNecessary:false) as? [[SCStreamFrameInfo:Any]]
        let info=attachments?.first ?? [:]
        if !preview {
            guard let status=info[.status] as? Int,status==SCFrameStatus.complete.rawValue else { return }
        }
        guard let buffer=sampleBuffer.imageBuffer else { return }
        func rect(_ key:SCStreamFrameInfo)->CGRect? {
            guard let dict=info[key] as? [String:Any] else { return nil }
            return CGRect(dictionaryRepresentation:dict as CFDictionary)
        }
        let bounds=rect(.boundingRect),screen=rect(.screenRect),content=rect(.contentRect)
        let scale=(info[.scaleFactor] as? NSNumber)?.doubleValue
        let detail="Expected parent: \(window).\nFrame screen rect: \(String(describing:screen)); bounding rect: \(String(describing:bounds)); content rect: \(String(describing:content)); scale: \(String(describing:scale)); content scale: \(String(describing:info[.contentScale])).\nPixel buffer: \(CVPixelBufferGetWidth(buffer)) × \(CVPixelBufferGetHeight(buffer))."
        func fail(_ reason:String) {
            finish(.failure(NSError(domain:"CameraReference.Capture",code:2,userInfo:[NSLocalizedDescriptionKey:reason+"\n"+detail])))
        }
        var converted:CGImage?
        let conversionStatus=VTCreateCGImageFromCVPixelBuffer(buffer,options:nil,imageOut:&converted)
        guard conversionStatus==noErr,let image=converted else {
            fail("Pixel-buffer conversion failed (OSStatus \(conversionStatus)).");return
        }
        do {
            let prepared=try prepareWindowFrame(image:image,window:window,screen:screen,bounds:bounds,scale:scale.map { CGFloat($0) },preview:preview)
            finish(.success(Frame(image:prepared.image,detail:detail+"\n"+prepared.detail)))
        } catch { fail(error.localizedDescription) }
    }

    static func capture(filter:SCContentFilter,config:SCStreamConfiguration,window:CGRect,preview:Bool) async throws -> Frame {
        let output=WindowCaptureFrame(window:window,preview:preview)
        config.queueDepth=1;config.pixelFormat=kCVPixelFormatType_32BGRA
        let stream=SCStream(filter:filter,configuration:config,delegate:output)
        try stream.addStreamOutput(output,type:.screen,sampleHandlerQueue:DispatchQueue(label:"CameraReference.window-frame"))
        do {
            try Task.checkCancellation()
            try await stream.startCapture()
            let frame=try await output.wait()
            try? await stream.stopCapture()
            try Task.checkCancellation()
            return frame
        } catch {
            output.cancel();try? await stream.stopCapture();throw error
        }
    }
}

// Preserve the cause across the outer capture boundary; never replace a geometry
// or stream error with an unsupported permission diagnosis. No userInfo dump.
func capturePermissionDenied(_ error:Error)->Bool {
    var current:NSError?=error as NSError
    for _ in 0..<3 {
        guard let item=current else { break }
        if item.domain=="com.apple.ScreenCaptureKit.SCStreamErrorDomain" && item.code == -3801 { return true }
        current=item.userInfo[NSUnderlyingErrorKey] as? NSError
    }
    return false
}
func captureFailureSummary(_ error:Error,context:String)->String {
    var lines=[capturePermissionDenied(error) ? "Screen Recording permission unavailable. No capture could be taken. Manual calibration remains available without snapping. Enable Screen Recording in macOS System Settings to use capture features.":"Screen inspection failed.",context]
    var current: NSError? = error as NSError
    for _ in 0..<3 {
        guard let item=current else { break }
        lines.append("\(item.domain) (\(item.code)): \(item.localizedDescription)")
        current=item.userInfo[NSUnderlyingErrorKey] as? NSError
    }
    lines.append("No capture was saved.")
    return lines.joined(separator:"\n")
}

struct WindowFrameImage { let image:CGImage;let detail:String }
// Preview is evidence, never placement input. Preserve every captured pixel even
// if metadata is absent or contradictory. Placement still requires normalization.
func prepareWindowFrame(image:CGImage,window:CGRect,screen:CGRect?,bounds:CGRect?,scale:CGFloat?,preview:Bool) throws -> WindowFrameImage {
    if preview {
        return WindowFrameImage(image:image,detail:"RAW PREVIEW: geometry validation bypassed; no crop or normalization. Not approved for placement.")
    }
    func failure(_ message:String)->NSError {
        NSError(domain:"CameraReference.Capture",code:2,userInfo:[NSLocalizedDescriptionKey:message])
    }
    guard let bounds,let screen,let scale else { throw failure("Required frame geometry metadata is missing.") }
    guard let crop=parentWindowPixelCrop(window:window,screenRect:screen,boundingRect:bounds,scale:scale,imageSize:CGSize(width:image.width,height:image.height)) else {
        throw failure("Window capture geometry rejected: parent containment, scale consistency or pixel-buffer bounds check failed.")
    }
    guard let normalized=image.cropping(to:crop) else { throw failure("Parent image crop failed at \(crop).") }
    return WindowFrameImage(image:normalized,detail:"Parent pixel crop: \(crop); surface: \(image.width) × \(image.height); normalized: \(normalized.width) × \(normalized.height).")
}
