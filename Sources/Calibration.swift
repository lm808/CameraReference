import AppKit

private final class CalibrationPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
private final class CalibrationView: NSView {
    var snapRadius:CGFloat=8
    var snapEdges=[SnapEdge]()
    var activeEdges=[SnapEdge]()
    var cursorPoint: CGPoint?
    var anchor: CGPoint?
    var selection: CGRect?
    var finish: ((CGRect) -> Void)?
    var cancel: (() -> Void)?
    var track: NSTrackingArea?
    var hint = "Drag to select the viewing area. Hold ⌥ Option to align crosshair lines with edges. Esc cancels."
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    override func updateTrackingAreas() {
        if let track { removeTrackingArea(track) }
        track = NSTrackingArea(rect: bounds, options: [.activeAlways,.mouseMoved,.mouseEnteredAndExited,.cursorUpdate,.inVisibleRect], owner: self)
        addTrackingArea(track!); super.updateTrackingAreas()
    }
    override func cursorUpdate(with event: NSEvent) { NSCursor.crosshair.set() }
    override func mouseEntered(with event: NSEvent) { mouseMoved(with:event) }
    override func mouseExited(with event: NSEvent) { if anchor == nil { cursorPoint = nil; needsDisplay = true } }
    override func mouseMoved(with event: NSEvent) {
        let raw=convert(event.locationInWindow,from:nil)
        let snapped=snappedPosition(raw,edges:snapEdges,enabled:event.modifierFlags.contains(.option),radius:snapRadius)
        cursorPoint=snapped.point;activeEdges=snapped.edges
        NSCursor.crosshair.set(); needsDisplay=true
    }
    override func flagsChanged(with event:NSEvent) {
        guard let window else { return }
        let raw=convert(window.convertPoint(fromScreen:NSEvent.mouseLocation),from:nil)
        let snapped=snappedPosition(raw,edges:snapEdges,enabled:event.modifierFlags.contains(.option),radius:snapRadius)
        cursorPoint=snapped.point;activeEdges=snapped.edges
        if let anchor { selection=CGRect(x:min(anchor.x,snapped.point.x),y:min(anchor.y,snapped.point.y),width:abs(anchor.x-snapped.point.x),height:abs(anchor.y-snapped.point.y)) }
        needsDisplay=true
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeKey(); window?.makeFirstResponder(self)
        mouseMoved(with:event); anchor=cursorPoint; selection=nil
    }
    override func mouseDragged(with event: NSEvent) {
        mouseMoved(with:event)
        guard let anchor, let point=cursorPoint else { return }
        selection=CGRect(x:min(anchor.x,point.x), y:min(anchor.y,point.y), width:abs(point.x-anchor.x),height:abs(point.y-anchor.y))
    }
    override func mouseUp(with event: NSEvent) {
        mouseDragged(with:event); anchor=nil
        guard let r=selection, r.width>100, r.height>100, bounds.contains(r) else {
            selection=nil; hint="Select over 100 × 100 points on one display. Hold ⌥ Option to snap. Esc cancels."; needsDisplay=true; return
        }
        finish?(r)
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { cancel?() }
        else if event.keyCode == 36, let selection { finish?(selection) }
    }
    override func rightMouseDown(with event: NSEvent) { cancel?() }
    override func scrollWheel(with event: NSEvent) {} // Never forward calibration gestures to Lightroom.
    override func magnify(with event: NSEvent) {}
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill(); bounds.fill(using:.copy)
        // A nearly transparent full-screen view owns hit-testing, even over Lightroom controls.
        NSColor.black.withAlphaComponent(0.015).setFill(); bounds.fill()
        if let selection {
            NSColor.systemBlue.withAlphaComponent(0.18).setFill(); selection.fill()
        }
        let lines=NSBezierPath()
        if let p=cursorPoint {
            lines.move(to:CGPoint(x:bounds.minX,y:p.y)); lines.line(to:CGPoint(x:bounds.maxX,y:p.y))
            lines.move(to:CGPoint(x:p.x,y:bounds.minY)); lines.line(to:CGPoint(x:p.x,y:bounds.maxY))
        }
        if let selection { lines.appendRect(selection) }
        NSColor.black.withAlphaComponent(0.85).setStroke(); lines.lineWidth=3; lines.stroke()
        NSColor.white.withAlphaComponent(0.9).setStroke(); lines.lineWidth=1; lines.stroke()
        NSColor.systemCyan.setStroke()
        for edge in activeEdges {
            let path=NSBezierPath();path.lineWidth=2
            path.move(to:edge.vertical ? CGPoint(x:edge.coordinate,y:edge.start):CGPoint(x:edge.start,y:edge.coordinate))
            path.line(to:edge.vertical ? CGPoint(x:edge.coordinate,y:edge.end):CGPoint(x:edge.end,y:edge.coordinate));path.stroke()
        }
        let label=hint as NSString
        let attributes: [NSAttributedString.Key:Any] = [.font:NSFont.systemFont(ofSize:14),.foregroundColor:NSColor.white]
        let size=label.size(withAttributes:attributes)
        let box=CGRect(x:bounds.midX-size.width/2-12,y:bounds.maxY-65,width:size.width+24,height:34)
        NSColor.black.withAlphaComponent(0.85).setFill(); NSBezierPath(roundedRect:box,xRadius:8,yRadius:8).fill()
        label.draw(at:CGPoint(x:box.minX+12,y:box.minY+9),withAttributes:attributes)
    }
}
final class CalibrationController {
    private var panels=[NSPanel]()
    private var escapeMonitor: Any?
    var completed: ((CGRect?) -> Void)?
    var snapRadius:CGFloat=8
    func start(proposal: CGRect? = nil,edges:[SnapEdge]=[],snapAvailable:Bool=true) {
        for screen in NSScreen.screens {
            let p=CalibrationPanel(contentRect:screen.frame,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
            p.level = .screenSaver; p.isOpaque=false; p.backgroundColor = .clear
            p.hasShadow=false; p.hidesOnDeactivate=false; p.isReleasedWhenClosed=false
            p.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]; p.acceptsMouseMovedEvents=true
            let v=CalibrationView(frame:CGRect(origin:.zero,size:screen.frame.size))
            v.snapRadius=snapRadius
            v.snapEdges=edges.filter { edge in
                edge.vertical ? (edge.coordinate>=screen.frame.minX && edge.coordinate<=screen.frame.maxX && edge.end>=screen.frame.minY && edge.start<=screen.frame.maxY) : (edge.coordinate>=screen.frame.minY && edge.coordinate<=screen.frame.maxY && edge.end>=screen.frame.minX && edge.start<=screen.frame.maxX)
            }.map { edge in
                SnapEdge(vertical:edge.vertical,coordinate:edge.coordinate-(edge.vertical ? screen.frame.minX:screen.frame.minY),start:edge.start-(edge.vertical ? screen.frame.minY:screen.frame.minX),end:edge.end-(edge.vertical ? screen.frame.minY:screen.frame.minX))
            }
            if !snapAvailable { v.hint="Drag to select the viewing area. Snapping unavailable this time; selection remains free. Esc cancels." }
            if let proposal, screen.frame.contains(proposal) {
                v.selection=proposal.offsetBy(dx:-screen.frame.minX,dy:-screen.frame.minY)
                v.hint=snapAvailable ? "Proposed area — Return accepts; drag to adjust. Hold ⌥ Option to snap. Esc cancels." : "Proposed area — Return accepts; drag to adjust. Snapping unavailable. Esc cancels."
            }
            v.finish = { [weak self, weak p] rect in
                guard let self, let p else { return }; self.finish(p.convertToScreen(rect))
            }
            v.cancel = { [weak self] in self?.finish(nil) }
            p.contentView=v; panels.append(p); p.orderFrontRegardless()
            if screen.frame.contains(NSEvent.mouseLocation) {
                v.cursorPoint=CGPoint(x:NSEvent.mouseLocation.x-screen.frame.minX,y:NSEvent.mouseLocation.y-screen.frame.minY)
                p.makeKey(); p.makeFirstResponder(v)
            }
        }
        if let proposal, let panel=panels.first(where:{$0.frame.contains(proposal)}), let view=panel.contentView {
            panel.makeKey(); panel.makeFirstResponder(view)
        }
        escapeMonitor=NSEvent.addLocalMonitorForEvents(matching:.keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.finish(nil); return nil }; return event
        }
        NSCursor.crosshair.set()
    }
    func finish(_ region: CGRect?) {
        let callback=completed; completed=nil; close(); callback?(region)
    }
    func close() {
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }; escapeMonitor=nil
        for p in panels { p.orderOut(nil); p.close() }; panels.removeAll(); NSCursor.arrow.set()
    }
    deinit { close() }
}
