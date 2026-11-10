import AppKit

final class OverlayPanel: NSPanel {
    // The detector already validates the display bounds. AppKit must not shift the
    // borderless overlay away from its exact image coordinates in full-screen Spaces.
    override func constrainFrameRect(_ frameRect:NSRect,to screen:NSScreen?)->NSRect { frameRect }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
// The same image view handles gestures, drawing, refresh and export for both windows.
final class ReferenceView: NSView, NSMenuItemValidation {
    override init(frame:NSRect) {
        super.init(frame:frame)
        allowedTouchTypes = [.indirect]
        wantsRestingTouches = false
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var acceptsFirstResponder:Bool { true }
    override var needsPanelToBecomeKey:Bool { true }
    var image: NSImage? { didSet { navigation.reset(); clearToast(); needsDisplay=true } }
    var exportSnapshot: ExportSnapshot?
    var save: ((ExportSnapshot) -> Void)?
    var canSave: (() -> Bool)?
    var refresh: (() -> Void)?
    var backgroundColour=NSColor.black
    var zoomChanged: ((Double)->Void)?
    private var lastZoom: Double = -1
    var allowsReferenceActions=true
    var showIndicator=false
    var interactive=true
    var navigation=ImageNavigation()
    private var lastDrag:CGPoint?
    private(set) var toast: String?
    private var toastTimer: Timer?
    func showToast(_ message:String, duration:TimeInterval=3) {
        toastTimer?.invalidate(); toast=message; needsDisplay=true
        toastTimer=Timer.scheduledTimer(withTimeInterval:duration,repeats:false) { [weak self] _ in self?.clearToast() }
    }
    func clearToast() { toastTimer?.invalidate(); toastTimer=nil; toast=nil; needsDisplay=true }
    deinit { toastTimer?.invalidate() }
    var imageViewport:CGRect?
    private var viewport: CGRect { imageViewport ?? (showIndicator ? bounds.insetBy(dx:1,dy:1) : bounds) }
    override var isOpaque: Bool { true }
    override func acceptsFirstMouse(for event:NSEvent?) -> Bool { true }
    func releaseContent() { zoomChanged=nil; image=nil; exportSnapshot=nil; refresh=nil; save=nil; canSave=nil }
    override func scrollWheel(with event:NSEvent) {
        guard interactive, let image else { return }
        switch scrollIntent(command:event.modifierFlags.contains(.command),precise:event.hasPreciseScrollingDeltas,momentum:!event.momentumPhase.isEmpty) {
        case .ignore: return
        case .pan:
            navigation.move(dx:event.scrollingDeltaX,dy:-event.scrollingDeltaY,image:image.size,viewport:viewport.size)
        case .zoom:
            navigation.magnify(factor:exp(event.scrollingDeltaY*(event.hasPreciseScrollingDeltas ? 0.01 : 0.1)),at:convert(event.locationInWindow,from:nil),image:image.size,viewport:viewport)
        }
        needsDisplay=true
    }
    override func magnify(with event:NSEvent) {
        guard interactive, let image else { return }
        navigation.magnify(factor:max(0.01,1+event.magnification),at:convert(event.locationInWindow,from:nil),image:image.size,viewport:viewport)
        needsDisplay=true
    }
    override func mouseDown(with event:NSEvent) {
        guard interactive else { return }
        window?.makeFirstResponder(self)
        if event.clickCount == 2 { lastDrag=nil; fit(); refresh?() }
        else { lastDrag=convert(event.locationInWindow,from:nil) }
    }
    override func mouseDragged(with event:NSEvent) {
        guard interactive, let previous=lastDrag, let image else { return }
        let point=convert(event.locationInWindow,from:nil)
        navigation.move(dx:point.x-previous.x,dy:point.y-previous.y,image:image.size,viewport:viewport.size)
        lastDrag=point; needsDisplay=true
    }
    override func mouseUp(with event:NSEvent) { lastDrag=nil }
    override func menu(for event:NSEvent) -> NSMenu? {
        guard interactive, image != nil else { return nil }
        let menu=NSMenu()
        for (title,action) in [("Fit",#selector(fit)),("100% (one image pixel per display pixel)",#selector(actualPixels)),("Reload selected photo",#selector(reload))] {
            if action == #selector(reload) && !allowsReferenceActions { continue }
            let item=NSMenuItem(title:title,action:action,keyEquivalent:""); item.target=self; menu.addItem(item)
        }
        guard allowsReferenceActions else { return menu }
        menu.addItem(.separator())
        let item=NSMenuItem(title:"Save extracted JPEG…",action:#selector(saveImage),keyEquivalent:"")
        item.target=self; menu.addItem(item)
        return menu
    }
    func validateMenuItem(_ item:NSMenuItem) -> Bool {
        if item.action == #selector(saveImage) { return image != nil && exportSnapshot != nil && (canSave?() ?? true) }
        return image != nil
    }
    @objc func saveImage() { if let exportSnapshot, canSave?() ?? true { save?(exportSnapshot) } }
    @objc func reload() { fit(); refresh?() }
    @objc func fit() { navigation.reset(); needsDisplay=true }
    @objc func actualPixels() {
        guard let image else { return }
        let fitted=fittedSize(image:image.size,inside:viewport.size)
        guard fitted.width>0 else { return }
        navigation.zoom=image.size.width/(fitted.width*(window?.backingScaleFactor ?? 1))
        navigation.pan = .zero; needsDisplay=true
    }
    override func draw(_ dirtyRect:NSRect) {
        backgroundColour.setFill(); bounds.fill()
        guard let image else { return }
        navigation.clamp(image:image.size,viewport:viewport.size)
        let percentage=imageZoomPercent(image:image.size,viewport:viewport.size,zoom:navigation.zoom,scale:window?.backingScaleFactor ?? 1)
        if abs(percentage-lastZoom)>0.01 { lastZoom=percentage; zoomChanged?(percentage) }
        let fitted=fittedSize(image:image.size,inside:viewport.size)
        let size=CGSize(width:fitted.width*navigation.zoom,height:fitted.height*navigation.zoom)
        let frame=CGRect(x:viewport.midX-size.width/2+navigation.pan.x,y:viewport.midY-size.height/2+navigation.pan.y,width:size.width,height:size.height)
        NSGraphicsContext.saveGraphicsState(); viewport.clip()
        image.draw(in:frame,from:.zero,operation:.copy,fraction:1,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.high])
        NSGraphicsContext.restoreGraphicsState()
        if let toast { drawToast(toast,in:bounds) }
        if showIndicator {
            NSColor(white:0.48,alpha:1).setStroke()
            let outline=NSBezierPath(rect:bounds.insetBy(dx:0.5,dy:0.5)); outline.lineWidth=1; outline.stroke()
            let label="Camera reference" as NSString
            let attributes:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:10,weight:.medium),.foregroundColor:NSColor(white:0.6,alpha:1)]
            let size=label.size(withAttributes:attributes)
            if let box=referenceLabelRect(viewport:bounds.insetBy(dx:1,dy:1),imageFrame:frame,labelSize:size) {
                label.draw(in:box,withAttributes:attributes)
            }
        }
    }
}


func drawToast(_ text:String,in bounds:CGRect) {
    let style=NSMutableParagraphStyle(); style.alignment = .center; style.lineBreakMode = .byTruncatingMiddle
    let attributes:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:13,weight:.medium),.foregroundColor:NSColor.white,.paragraphStyle:style]
    let label=text as NSString
    let width=min(max(0,bounds.width-24),label.size(withAttributes:attributes).width+28)
    let box=CGRect(x:bounds.midX-width/2,y:bounds.maxY-54,width:width,height:34)
    NSColor.black.withAlphaComponent(0.85).setFill(); NSBezierPath(roundedRect:box,xRadius:8,yRadius:8).fill()
    label.draw(in:box.insetBy(dx:12,dy:8),withAttributes:attributes)
}

private final class SaveToastView:NSView {
    var message=""
    override func hitTest(_ point:NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect:NSRect) { drawToast(message,in:bounds) }
}
// If an overlay is dismissed during saving, briefly show confirmation at its old position.
// This panel is nonactivating and ignores clicks; it is not a recreated photograph overlay.
final class SaveToastController {
    private var panel:NSPanel?
    private var timer:Timer?
    func show(_ message:String,in region:CGRect) {
        close()
        let frame=CGRect(x:region.minX,y:region.maxY-70,width:region.width,height:70)
        let p=OverlayPanel(contentRect:frame,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        p.backgroundColor = .clear; p.isOpaque=false; p.hasShadow=false; p.ignoresMouseEvents=true
        p.level = .floating; p.hidesOnDeactivate=false; p.isReleasedWhenClosed=false
        p.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]
        let view=SaveToastView(frame:CGRect(origin:.zero,size:frame.size)); view.message=message
        p.contentView=view; panel=p; p.orderFrontRegardless()
        timer=Timer.scheduledTimer(withTimeInterval:3,repeats:false) { [weak self] _ in self?.close() }
    }
    func close() { timer?.invalidate(); timer=nil; panel?.orderOut(nil); panel=nil }
    deinit { close() }
}


// Explicit diagnostic preview; no save/export route or screenshot retention after closing.
final class CapturePreviewController:NSObject,NSWindowDelegate {
    private var window:NSWindow?
    private var view:ReferenceView?
    init(image:CGImage) {
        super.init()
        let screen=NSScreen.main?.visibleFrame ?? CGRect(x:0,y:0,width:1200,height:800)
        let size=fittedSize(image:CGSize(width:image.width,height:image.height),inside:CGSize(width:screen.width*0.8,height:screen.height*0.8))
        let w=NSWindow(contentRect:CGRect(origin:.zero,size:size),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        w.isReleasedWhenClosed=false;w.delegate=self
        w.collectionBehavior=[.fullScreenAuxiliary];w.appearance=NSAppearance(named:.darkAqua)
        let v=ReferenceView(frame:CGRect(origin:.zero,size:size));v.allowsReferenceActions=false
        v.autoresizingMask=[.width,.height]
        v.image=NSImage(cgImage:image,size:CGSize(width:image.width,height:image.height))
        v.zoomChanged={ [weak w] percent in w?.title=String(format:"Captured Lightroom — %.1f%% — memory only",percent) }
        v.toolTip="Exact captured image. Command-scroll or pinch to zoom; drag to pan; double-click to Fit. Close to release."
        w.contentView=v;window=w;view=v;w.center()
        NSApp.activate(ignoringOtherApps:true);w.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification:Notification) { release() }
    private func release() { view?.releaseContent();view=nil;window?.contentView=nil;window=nil }
    func close() { window?.close();release() }
    deinit { close() }
}
