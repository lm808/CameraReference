import AppKit

// Shared by preview and the opt-in AX backend; screenshot geometry never uses these offsets.
func axTrialHostMatches(proposedTopLeft:CGRect, actualAppKit:CGRect, primaryHeight:CGFloat)->Bool {
    let converted=CGRect(x:proposedTopLeft.minX,y:primaryHeight-proposedTopLeft.maxY,width:proposedTopLeft.width,height:proposedTopLeft.height)
    return abs(converted.minX-actualAppKit.minX)<2 && abs(converted.minY-actualAppKit.minY)<2 && abs(converted.width-actualAppKit.width)<2 && abs(converted.height-actualAppKit.height)<2
}
struct AXTrialWindow {
    let frame:CGRect
    let visible:Bool
}
struct AXTrialProposal {
    let host:CGRect
    let panes:[CGRect]
    let layout:String
    let summary:String
}
func axTrialProposal(host:CGRect, windows:[AXTrialWindow], settings:DetectionConfig = DetectionConfig(), module:String? = nil)->AXTrialProposal? {
    guard host.width>200,host.height>200 else { return nil }
    let visible=windows.filter(\.visible).map(\.frame).filter { host.contains($0) && $0 != host }
    // Panel widths stay roughly fixed as Lightroom shrinks. Require a tall
    // rectangle attached to exactly one side, not a percentage-width cutoff.
    let sides=visible.filter {
        let onLeft=abs($0.minX-host.minX)<4,onRight=abs($0.maxX-host.maxX)<4
        return $0.height>host.height*0.5 && $0.width>0 && onLeft != onRight
    }
    let leftPanel=sides.filter { abs($0.minX-host.minX)<4 }.map(\.maxX).max()
    let rightPanel=sides.filter { abs($0.maxX-host.maxX)<4 }.map(\.minX).min()
    let strips=visible.filter { $0.width>host.width*0.9 && $0.height<host.height*0.25 }
    let topPanel=strips.filter { $0.midY<host.minY+host.height*0.25 }.map(\.maxY).max()
    let bottomPanel=strips.filter { $0.midY>host.minY+host.height*0.75 }.map(\.minY).min()
    var left=leftPanel ?? host.minX+settings.axBaseHiddenLeftInsetPoints
    var right=rightPanel ?? host.maxX-settings.axBaseHiddenRightInsetPoints
    var top=topPanel ?? host.minY+settings.axBaseHiddenTopInsetPoints
    var bottom=bottomPanel ?? host.maxY-settings.axBaseHiddenBottomInsetPoints
    guard right-left>100,bottom-top>100 else { return nil }
    var area=CGRect(x:left,y:top,width:right-left,height:bottom-top)
    // Observed label-size family. Geometry/opacity only, not session IDs or text.
    let labels=Array(Set(visible.filter { (50...160).contains($0.width) && (15...40).contains($0.height) }.map { NSStringFromRect($0) })).map { NSRectFromString($0) }
    var horizontal=false,vertical=false,notes=[String](), splitX=area.midX,splitY=area.midY
    var gapXRange:ClosedRange<CGFloat>?,gapYRange:ClosedRange<CGFloat>?
    for a in labels { for b in labels where a != b {
        let gapX=b.minX-a.maxX,gapY=b.minY-a.maxY
        if abs(a.minY-b.minY)<2 && (0...6).contains(gapX) && abs(a.minY-top)<25 && abs((a.maxX+b.minX)/2-area.midX)<area.width*0.1 { horizontal=true;gapXRange=a.maxX...b.minX;splitX=min(max(area.midX,a.maxX),b.minX) }
        if abs(a.maxX-b.maxX)<2 && (0...6).contains(gapY) && abs(a.maxX-right)<25 && abs((a.maxY+b.minY)/2-area.midY)<area.height*0.1 { vertical=true;gapYRange=a.maxY...b.minY;splitY=min(max(area.midY,a.maxY),b.minY) }
    } }
    let layout=horizontal != vertical ? (horizontal ? "Side-by-side":"Above-and-below"):"Single view"
    if horizontal && vertical { notes.append("Conflicting label pairs; assumed single view.") }
    if !horizontal && !vertical { notes.append("No clear central label pair; assumed single view.") }
    if splitX != area.midX || splitY != area.midY { notes.append("50/50 midpoint adjusted into the central label gap; raw outer bounds need correction.") }
    let rawArea=area
    let leftShift=leftPanel == nil ? settings.axHiddenLeftOffsetPoints:settings.axShownLeftOffsetPoints
    let rightShift=rightPanel == nil ? settings.axHiddenRightOffsetPoints:settings.axShownRightOffsetPoints
    let topShift=topPanel == nil ? settings.axHiddenTopOffsetPoints:settings.axShownTopOffsetPoints
    let filmstripShift=bottomPanel == nil ? settings.axFilmstripHiddenOffsetPoints:settings.axFilmstripShownOffsetPoints
    let toolbarShift=settings.axToolbarState == "hidden" ? 0:settings.axToolbarHeightPoints
    let libraryShift=module == "library" && layout != "Single view" ? settings.axLibraryBottomOffsetPoints:0
    left += leftShift;right += rightShift
    top -= topShift;bottom -= filmstripShift+toolbarShift+libraryShift
    notes.append("Signed offsets (right/up positive): L \(leftShift), R \(rightShift), T \(topShift); bottom filmstrip \(filmstripShift) + toolbar \(toolbarShift) + Library \(libraryShift).")
    notes.append("Panel evidence L/R/T/B: \(leftPanel != nil)/\(rightPanel != nil)/\(topPanel != nil)/\(bottomPanel != nil). Missing panels use configured base hidden insets.")
    guard right-left>100,bottom-top>100 else { return nil }
    area=CGRect(x:left,y:top,width:right-left,height:bottom-top)
    if let gap=gapXRange { splitX=min(max(area.midX,gap.lowerBound),gap.upperBound) } else { splitX=area.midX }
    if let gap=gapYRange { splitY=min(max(area.midY,gap.lowerBound),gap.upperBound) } else { splitY=area.midY }
    guard layout != "Side-by-side" || (splitX>left && splitX<right),
          layout != "Above-and-below" || (splitY>top && splitY<bottom) else { return nil }
    let panes:[CGRect]
    if layout == "Side-by-side" {
        panes=[CGRect(x:left,y:top,width:splitX-left,height:area.height),CGRect(x:splitX,y:top,width:right-splitX,height:area.height)]
    } else if layout == "Above-and-below" {
        panes=[CGRect(x:left,y:top,width:area.width,height:splitY-top),CGRect(x:left,y:splitY,width:area.width,height:bottom-splitY)]
    } else { panes=[area] }
    let summary="AX trial: \(layout). Top-left global points.\nHost: \(host)\nRaw combined area: \(rawArea)\nAdjusted area: \(area)\nProposed panes: \(panes)\nVisible label candidates: \(labels)\n"+notes.joined(separator:"\n")+"\nAX config corrections applied. Toolbar annotation: \(settings.axToolbarState) (effective preview state; see toolbar diagnostics). No menu layout/pane preference used."
    return AXTrialProposal(host:host,panes:panes,layout:layout,summary:summary)
}
final class AXTrialBorder:NSView {
    let tint:NSColor
    let label:String
    init(size:CGSize,tint:NSColor,label:String) { self.tint=tint;self.label=label;super.init(frame:CGRect(origin:.zero,size:size)) }
    required init?(coder:NSCoder) { fatalError() }
    override func draw(_ dirtyRect:NSRect) {
        tint.setStroke();let path=NSBezierPath(rect:bounds.insetBy(dx:2,dy:2));path.lineWidth=3;path.stroke()
        (label as NSString).draw(at:CGPoint(x:8,y:bounds.height-25),withAttributes:[.font:NSFont.boldSystemFont(ofSize:14),.foregroundColor:tint,.backgroundColor:NSColor.black])
    }
}

// Backend selection is deliberately outside the existing screenshot detector.
enum PlacementBackend { case manual, screenshot, accessibility }
func placementBackend(automatic:Bool,axOnly:Bool)->PlacementBackend {
    automatic ? (axOnly ? .accessibility:.screenshot):.manual
}
func axSelectedArea(_ proposal:AXTrialProposal,layout:OverlayLayout)->CGRect? {
    if layout == .full { return proposal.panes.reduce(CGRect.null){$0.union($1)} }
    guard proposal.panes.count==2,
          (layout.group==1 && proposal.layout=="Side-by-side") || (layout.group==2 && proposal.layout=="Above-and-below") else { return nil }
    return proposal.panes[(layout == .right || layout == .lower) ? 1:0]
}
