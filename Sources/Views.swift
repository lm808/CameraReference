import AppKit

class OverlayPanel: NSPanel {
    // The detector already validates the display bounds. AppKit must not shift the
    // borderless overlay away from its exact image coordinates in full-screen Spaces.
    override func constrainFrameRect(_ frameRect:NSRect,to screen:NSScreen?)->NSRect { frameRect }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
// Diagnostic borders use the production frame constraint without accepting focus.
final class AXTrialPanel:OverlayPanel {
    override var canBecomeKey:Bool { false }
}

func referenceInteractionHint(floating:Bool)->String {
    let drag=floating ? "Drag at Fit: move window. Drag when zoomed: pan.":"Drag: pan."
    return "Scroll: pan. Command-scroll: zoom.\n" + drag + "\nDouble-click: reload photo and Fit. Right-click: image options."
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
    var movesWindowAtFit=false
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
    private var drawingViewport:CGRect { showIndicator ? bounds.insetBy(dx:1,dy:1):bounds }
    override var isOpaque: Bool { true }
    override func acceptsFirstMouse(for event:NSEvent?) -> Bool { true }
    func releaseContent() { zoomChanged=nil; image=nil; exportSnapshot=nil; refresh=nil; save=nil; canSave=nil }
    override func scrollWheel(with event:NSEvent) {
        guard interactive, let image else { return }
        switch scrollIntent(command:event.modifierFlags.contains(.command),precise:event.hasPreciseScrollingDeltas,momentum:!event.momentumPhase.isEmpty) {
        case .ignore: return
        case .pan:
            navigation.move(dx:event.scrollingDeltaX,dy:-event.scrollingDeltaY,image:image.size,fitRect:viewport,viewport:drawingViewport)
        case .zoom:
            navigation.magnify(factor:exp(event.scrollingDeltaY*(event.hasPreciseScrollingDeltas ? 0.01 : 0.1)),at:convert(event.locationInWindow,from:nil),image:image.size,viewport:drawingViewport,fitRect:viewport)
        }
        needsDisplay=true
    }
    override func mouseDown(with event:NSEvent) {
        guard interactive else { return }
        window?.makeFirstResponder(self)
        if movesWindowAtFit && floatingDragMovesWindow(zoom:navigation.zoom,inTitleBar:convert(event.locationInWindow,from:nil).y>=bounds.maxY-32) {
            if event.clickCount==1 { lastDrag=nil;window?.performDrag(with:event);return }
            if convert(event.locationInWindow,from:nil).y>=bounds.maxY-32 { return }
        }
        if event.clickCount == 2 { lastDrag=nil; fit(); refresh?() }
        else { lastDrag=convert(event.locationInWindow,from:nil) }
    }
    override func mouseDragged(with event:NSEvent) {
        guard interactive, let previous=lastDrag, let image else { return }
        let point=convert(event.locationInWindow,from:nil)
        navigation.move(dx:point.x-previous.x,dy:point.y-previous.y,image:image.size,fitRect:viewport,viewport:drawingViewport)
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
        navigation.clamp(image:image.size,fitRect:viewport,viewport:drawingViewport)
        let percentage=imageZoomPercent(image:image.size,viewport:viewport.size,zoom:navigation.zoom,scale:window?.backingScaleFactor ?? 1)
        if abs(percentage-lastZoom)>0.01 { lastZoom=percentage; zoomChanged?(percentage) }
        let fitted=fittedSize(image:image.size,inside:viewport.size)
        let size=CGSize(width:fitted.width*navigation.zoom,height:fitted.height*navigation.zoom)
        let frame=CGRect(x:viewport.midX-size.width/2+navigation.pan.x,y:viewport.midY-size.height/2+navigation.pan.y,width:size.width,height:size.height)
        NSGraphicsContext.saveGraphicsState(); drawingViewport.clip()
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
    private var onClose:(()->Void)?
    init(image:CGImage,title:String="Captured Lightroom",onClose:(()->Void)? = nil) {
        self.onClose=onClose
        super.init()
        let screen=NSScreen.main?.visibleFrame ?? CGRect(x:0,y:0,width:1200,height:800)
        let size=fittedSize(image:CGSize(width:image.width,height:image.height),inside:CGSize(width:screen.width*0.8,height:screen.height*0.8))
        let w=NSWindow(contentRect:CGRect(origin:.zero,size:size),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        w.isReleasedWhenClosed=false;w.delegate=self
        w.collectionBehavior=[.fullScreenAuxiliary];w.appearance=NSAppearance(named:.darkAqua)
        let v=ReferenceView(frame:CGRect(origin:.zero,size:size));v.allowsReferenceActions=false
        v.autoresizingMask=[.width,.height]
        v.image=NSImage(cgImage:image,size:CGSize(width:image.width,height:image.height))
        v.zoomChanged={ [weak w] percent in w?.title=String(format:"%@ — %.1f%% — memory only",title,percent) }
        v.toolTip="Exact captured image. Command-scroll to zoom; drag to pan; double-click to Fit. Close to release."
        w.contentView=v;window=w;view=v;w.center()
        NSApp.activate(ignoringOtherApps:true);w.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification:Notification) { release() }
    private func release() {
        view?.releaseContent();view=nil;window?.contentView=nil;window=nil
        let callback=onClose;onClose=nil;callback?()
    }
    func close() { window?.close();release() }
    deinit { close() }
}

private final class ChromeLabel:NSTextField {
    override func hitTest(_ point:NSPoint)->NSView? { nil }
}
private final class FloatingChrome:NSView {
    override func draw(_ dirtyRect:NSRect) { NSColor.black.withAlphaComponent(0.72).setFill();bounds.fill() }
    override func mouseDown(with event:NSEvent) { if event.clickCount==1 { window?.performDrag(with:event) } }
    override func acceptsFirstMouse(for event:NSEvent?)->Bool { true }
}
func floatingDragMovesWindow(zoom:CGFloat,inTitleBar:Bool)->Bool { inTitleBar || zoom <= 1.0001 }
// Full-size content keeps the photograph stationary while chrome fades over it.
final class FloatingPanel:OverlayPanel {
    private let chrome=FloatingChrome()
    private let caption=ChromeLabel(labelWithString:"")
    private var chromeVisible=false
    private var hoverTimer:Timer?
    override func orderFrontRegardless() { super.orderFrontRegardless();updateHover() }
    private func updateHover() { revealChrome(isVisible && frame.contains(NSEvent.mouseLocation)) }
    override func close() { hoverTimer?.invalidate();hoverTimer=nil;super.close() }
    deinit { hoverTimer?.invalidate() }
    override var title:String { didSet { caption.stringValue=title } }
    func installChrome() {
        titleVisibility = .hidden;titlebarAppearsTransparent=true
        caption.font = .systemFont(ofSize:11,weight:.medium)
        caption.textColor = .white
        caption.drawsBackground=false;caption.lineBreakMode = .byTruncatingMiddle
        caption.alignment = .center
        if let contentView {
            chrome.frame=CGRect(x:0,y:contentView.bounds.height-32,width:contentView.bounds.width,height:32)
            chrome.autoresizingMask=[.width,.minYMargin];contentView.addSubview(chrome)
            caption.frame=CGRect(x:78,y:5,width:max(0,contentView.bounds.width-90),height:22)
            caption.autoresizingMask=[.width];chrome.addSubview(caption)
        }
        chrome.alphaValue=0
        hoverTimer=Timer(timeInterval:0.08,repeats:true) { [weak self] _ in self?.updateHover() }
        RunLoop.main.add(hoverTimer!,forMode:.common)
        for type in [NSWindow.ButtonType.closeButton,.miniaturizeButton,.zoomButton] { standardWindowButton(type)?.alphaValue=0;standardWindowButton(type)?.isEnabled=false }
    }
    func revealChrome(_ visible:Bool) {
        guard chromeVisible != visible else { return };chromeVisible=visible
        NSAnimationContext.runAnimationGroup { context in
            context.duration=0.15
            chrome.animator().alphaValue=visible ? 1:0
            for type in [NSWindow.ButtonType.closeButton,.miniaturizeButton,.zoomButton] {
                standardWindowButton(type)?.isEnabled=visible
                standardWindowButton(type)?.animator().alphaValue=visible ? 1:0
            }
        }
    }
}

// Eager, opaque alpha mask: independent of menu appearance and lazy drawing contexts.
func layoutMenuIcon(_ layout:OverlayLayout)->NSImage {
    let scale:CGFloat=2
    let context=CGContext(data:nil,width:44,height:32,bitsPerComponent:8,bytesPerRow:176,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x:scale,y:scale);context.setStrokeColor(NSColor.black.cgColor);context.setFillColor(NSColor.black.cgColor);context.setLineWidth(1)
    context.stroke(CGRect(x:1.5,y:1.5,width:19,height:13))
    if layout == .full { context.fill(CGRect(x:4,y:4,width:14,height:8)) }
    else {
        if layout.group==1 { context.move(to:CGPoint(x:11,y:2));context.addLine(to:CGPoint(x:11,y:14)) }
        else { context.move(to:CGPoint(x:2,y:8));context.addLine(to:CGPoint(x:20,y:8)) }
        context.strokePath()
        switch layout {
        case .left:context.fill(CGRect(x:4,y:4,width:5,height:8))
        case .right:context.fill(CGRect(x:13,y:4,width:5,height:8))
        case .upper:context.fill(CGRect(x:4,y:10,width:14,height:2))
        default:context.fill(CGRect(x:4,y:4,width:14,height:2))
        }
    }
    let image=NSImage(cgImage:context.makeImage()!,size:CGSize(width:22,height:16));image.isTemplate=true;return image
}

struct DiagnosticSection {
    let title:String
    let body:String
}
func diagnosticReport(_ sections:[DiagnosticSection])->String {
    sections.map { "\($0.title.uppercased())\n\($0.body)" }.joined(separator:"\n\n────────────────────────\n\n")
}
final class DiagnosticsController:NSObject,NSWindowDelegate {
    private var window:NSWindow?
    private let sections:[DiagnosticSection]
    private let chooser=NSPopUpButton(frame:.zero,pullsDown:false)
    private let text=NSTextView()
    private var refreshAction:(()->Void)?
    @objc private func refreshReport() { refreshAction?() }
    init(sections:[DiagnosticSection],refresh:(()->Void)? = nil) {
        self.refreshAction=refresh
        self.sections=sections;super.init()
        let panel=NSWindow(contentRect:CGRect(x:0,y:0,width:760,height:560),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        panel.title="Camera Reference — Bridge diagnostics";panel.isReleasedWhenClosed=false;panel.delegate=self
        let root=NSView();panel.contentView=root
        chooser.addItems(withTitles:["All sections"]+sections.map(\.title));chooser.target=self;chooser.action=#selector(selectSection)
        let copy=NSButton(title:"Copy all",target:self,action:#selector(copyAll))
        let refreshButton=NSButton(title:"Refresh AX",target:self,action:#selector(refreshReport))
        let scroll=NSScrollView();scroll.hasVerticalScroller=true;scroll.borderType = .bezelBorder
        text.isEditable=false;text.isSelectable=true;text.isRichText=false
        text.font=NSFont.monospacedSystemFont(ofSize:12,weight:.regular)
        text.textContainerInset=CGSize(width:12,height:12);text.isVerticallyResizable=true;text.isHorizontallyResizable=false
        text.autoresizingMask=[.width];text.textContainer?.widthTracksTextView=true
        scroll.documentView=text
        for view in [chooser,copy,refreshButton,scroll] as [NSView] { view.translatesAutoresizingMaskIntoConstraints=false;root.addSubview(view) }
        NSLayoutConstraint.activate([
            chooser.leadingAnchor.constraint(equalTo:root.leadingAnchor,constant:16),chooser.topAnchor.constraint(equalTo:root.topAnchor,constant:14),
            chooser.trailingAnchor.constraint(lessThanOrEqualTo:refreshButton.leadingAnchor,constant:-12),
            refreshButton.trailingAnchor.constraint(equalTo:copy.leadingAnchor,constant:-12),refreshButton.centerYAnchor.constraint(equalTo:chooser.centerYAnchor),
            copy.trailingAnchor.constraint(equalTo:root.trailingAnchor,constant:-16),copy.centerYAnchor.constraint(equalTo:chooser.centerYAnchor),
            scroll.topAnchor.constraint(equalTo:chooser.bottomAnchor,constant:12),scroll.leadingAnchor.constraint(equalTo:root.leadingAnchor,constant:16),
            scroll.trailingAnchor.constraint(equalTo:root.trailingAnchor,constant:-16),scroll.bottomAnchor.constraint(equalTo:root.bottomAnchor,constant:-16)
        ])
        panel.minSize=CGSize(width:540,height:340);window=panel;selectSection();panel.center()
        NSApp.activate(ignoringOtherApps:true);panel.makeKeyAndOrderFront(nil)
    }
    @objc private func selectSection() {
        let index=chooser.indexOfSelectedItem
        text.string=diagnosticReport(index>0 ? [sections[index-1]]:sections)
        text.scrollRangeToVisible(NSRange(location:0,length:0))
    }
    @objc private func copyAll() {
        NSPasteboard.general.clearContents();NSPasteboard.general.setString(diagnosticReport(sections),forType:.string)
    }
    func windowWillClose(_ notification:Notification) { window?.contentView=nil;window=nil }
    func close() { window?.close();window=nil }
    deinit { close() }
}
