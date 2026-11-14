import Foundation
import CoreGraphics

// Experimental, isolated from ViewportDetector.swift. Raw AX edges constrain
// search intervals only. All displayed borders must have pixel evidence.
struct AXScreenHints {
    let host:CGRect
    let edges:[CGFloat] // L/R/T/B, global top-left points; no calibrated offsets.
    let signature:String
    init?(host:CGRect,visibleFrames:[CGRect],toolbar:String) {
        guard host.width>200,host.height>200 else { return nil }
        let visible=visibleFrames.filter { host.contains($0) && $0 != host }
        let sides=visible.filter {
            $0.height>host.height*0.5 && $0.width>0 &&
            ((abs($0.minX-host.minX)<4) != (abs($0.maxX-host.maxX)<4))
        }
        let strips=visible.filter { $0.width>host.width*0.9 && $0.height<host.height*0.25 }
        edges=[sides.filter { abs($0.minX-host.minX)<4 }.map(\.maxX).max() ?? host.minX,
               sides.filter { abs($0.maxX-host.maxX)<4 }.map(\.minX).min() ?? host.maxX,
               strips.filter { $0.midY<host.minY+host.height*0.25 }.map(\.maxY).max() ?? host.minY,
               strips.filter { $0.midY>host.minY+host.height*0.75 }.map(\.minY).min() ?? host.maxY]
        guard edges[1]>edges[0],edges[3]>edges[2] else { return nil }
        self.host=host
        // Host position deliberately excluded: translation does not change layout.
        let panels=(sides+strips).map { NSStringFromRect($0.offsetBy(dx:-host.minX,dy:-host.minY)) }.sorted()
        signature="\(host.size):\(panels):toolbar=\(toolbar)"
    }
    func ranges(width:Int,height:Int)->[ClosedRange<Int>] {
        let sx=CGFloat(width)/host.width,sy=CGFloat(height)/host.height
        return edges.enumerated().map { index,edge in
            let vertical=index<2,scale=vertical ? sx:sy
            let centre=(edge-(vertical ? host.minX:host.minY))*scale
            // Generous uncertainty bands, not placement corrections. The bottom
            // includes unreported toolbar and Library space; hidden top includes title/header.
            let radius:CGFloat=(vertical ? 64:128)*scale
            let limit=(vertical ? width:height)-3
            let low=max(2,min(limit,Int(centre-radius)))
            return low...max(low,min(limit,Int(centre+radius)))
        }
    }
}

func detectAXAssistedViewport(in raster:EdgeRaster,hints:AXScreenHints,layout:OverlayLayout,settings:DetectionConfig)->ViewportDetection {
    let full=guidedViewport(in:raster,ranges:hints.ranges(width:raster.width,height:raster.height))
    guard let viewport=full.bounds else {
        let fallback=layout == .full ? detectViewport(in:raster,singlePhoto:true,sideSearchPercent:settings.sideSearchPercent):detectSplitViewport(in:raster,layout:layout,sideSearchPercent:settings.sideSearchPercent,insetPixels:CGSize(width:settings.fitInsetPoints*CGFloat(raster.width)/hints.host.width,height:settings.fitInsetPoints*CGFloat(raster.height)/hints.host.height))
        return ViewportDetection(bounds:fallback.bounds,verticalDivider:fallback.verticalDivider,horizontalDivider:fallback.horizontalDivider,background:fallback.background,summary:"AX-assisted guided search inconclusive; original screenshot fallback.\n"+full.summary+"\n"+fallback.summary,workingAreaTooNarrow:fallback.workingAreaTooNarrow)
    }
    if layout == .full {
        return ViewportDetection(bounds:viewport,verticalDivider:nil,horizontalDivider:nil,background:full.background,summary:"AX-assisted raw panel search; pixel-validated borders.\nSearch bands L/R/T/B (raster): \(hints.ranges(width:raster.width,height:raster.height)).\n"+full.summary)
    }
    let scan=scanInsetDivider(in:raster,viewport:viewport,layout:layout,insetPixels:CGSize(width:settings.fitInsetPoints*CGFloat(raster.width)/hints.host.width,height:settings.fitInsetPoints*CGFloat(raster.height)/hints.host.height))
    let pane=layout.pane(in:viewport,vertical:layout.group==1 ? scan.position:nil,horizontal:layout.group==2 ? scan.position:nil)
    return ViewportDetection(bounds:pane,verticalDivider:nil,horizontalDivider:nil,background:full.background,summary:"AX-assisted raw panel search; pixel-validated borders and divider.\n"+full.summary+"\n"+scan.summary)
}

// Frozen evidence checks from the accepted Full detector. Keep this experimental
// search independent: do not change the original detector when tuning assistance.
private func guidedViewport(in raster: EdgeRaster, ranges:[ClosedRange<Int>]) -> ViewportDetection {
    let w=raster.width, h=raster.height
    let knownBounds:CGRect?=nil
    func failure(_ reason:String) -> ViewportDetection {
        ViewportDetection(bounds:nil,verticalDivider:nil,horizontalDivider:nil,background:[0,0,0],summary:reason)
    }
    guard w>=320,h>=240,raster.rgba.count==w*h*4 else { return failure("Capture is too small to identify UI borders.") }
    func rgb(_ x:Int,_ y:Int)->[Double] {
        let i=(max(0,min(h-1,y))*w+max(0,min(w-1,x)))*4
        return (0..<3).map { Double(raster.rgba[i+$0]) }
    }
    func distance(_ a:[Double],_ b:[Double])->Double { zip(a,b).map { abs($0-$1) }.max()! }
    func representative(_ samples:[[Double]])->([Double],Double) {
        let median=(0..<3).map { channel in samples.map { $0[channel] }.sorted()[samples.count/2] }
        return (median,Double(samples.filter { distance($0,median)<=6 }.count)/Double(samples.count))
    }
    // Generate alternatives, then validate complete rectangles. Never commit to outer rails first.
    func candidates(vertical:Bool,low:Int,high:Int)->[Int] {
        let along=vertical ? h:w
        var scored=[(Int,Double)]()
        for i in low..<high {
            var a=[[Double]](),b=[[Double]]()
            for j in 0..<48 {
                let p=Int(Double(along)*(vertical ? (0.15+0.65*Double(j)/47):(0.33+0.34*Double(j)/47)))
                a.append(vertical ? rgb(i-1,p):rgb(p,i-1));b.append(vertical ? rgb(i,p):rgb(p,i))
            }
            let (ca,ua)=representative(a),(cb,ub)=representative(b)
            let changed=Double(zip(a,b).filter { distance($0,$1)>=3 }.count)/48
            if max(ua,ub)>=0.85 && changed>=0.55 && distance(ca,cb)>=3 {
                scored.append((i,changed+max(ua,ub)+min(24,distance(ca,cb))/24))
            }
        }
        scored.sort { $0.1==$1.1 ? (low==2 ? $0.0>$1.0:$0.0<$1.0):$0.1>$1.1 }
        var chosen=[Int]()
        for (i,_) in scored where !chosen.contains(where:{abs($0-i)<=2}) {
            chosen.append(i);if chosen.count==12 { break }
        }
        return chosen.sorted()
    }
    func rectangleScore(_ r:CGRect)->Double? {
        guard r.width>12,r.height>12 else { return nil }
        let corners=[rgb(Int(r.minX)+4,Int(r.minY)+4),rgb(Int(r.maxX)-5,Int(r.minY)+4),rgb(Int(r.minX)+4,Int(r.maxY)-5),rgb(Int(r.maxX)-5,Int(r.maxY)-5)]
        guard corners.allSatisfy({distance($0,corners[0])<=8}) else { return nil }
        var sides=[[[Double]]]()
        for side in 0..<4 {
            var samples=[[Double]]()
            for j in 0..<40 {
                let f=0.03+0.94*Double(j)/39
                let x=Int(r.minX+r.width*f),y=Int(r.minY+r.height*f)
                switch side {
                case 0:samples.append(rgb(Int(r.minX)+4,y))
                case 1:samples.append(rgb(Int(r.maxX)-5,y))
                case 2:samples.append(rgb(x,Int(r.minY)+4))
                default:samples.append(rgb(x,Int(r.maxY)-5))
                }
            }
            sides.append(samples)
        }
        let (background,_)=representative(sides.flatMap{$0})
        let support=sides.map { Double($0.filter { distance($0,background)<=8 }.count)/40 }
        guard support.min()!>=0.90 else { return nil }
        // All four lines must have distributed transition evidence over their actual span.
        var strengths=[Double]()
        for side in 0..<4 {
            var hits=0
            for j in 0..<40 {
                let f=0.03+0.94*Double(j)/39
                let x=Int(r.minX+r.width*f),y=Int(r.minY+r.height*f)
                var d=0.0
                for offset in -1...1 {
                    if side<2 { let i=Int(side==0 ? r.minX:r.maxX)+offset;d=max(d,distance(rgb(i-1,y),rgb(i,y))) }
                    else { let i=Int(side==2 ? r.minY:r.maxY)+offset;d=max(d,distance(rgb(x,i-1),rgb(x,i))) }
                }
                if d>=3 { hits+=1 }
            }
            strengths.append(Double(hits)/40)
        }
        guard strengths.min()!>=0.70 else { return nil }
        return support.reduce(0,+)/4 + strengths.reduce(0,+)/4
    }
    let left:Int,right:Int,top:Int,bottom:Int
    var searchReport="Cached outer bounds validated."
    if let knownBounds,rectangleScore(knownBounds) != nil {
        left=Int(knownBounds.minX);right=Int(knownBounds.maxX);top=Int(knownBounds.minY);bottom=Int(knownBounds.maxY)
    } else {
        // Fixed-width side panels occupy more of a narrow window. Search up
        // to the centre on each side; complete-rectangle validation still
        // rejects panel controls and photograph details.
        let ls=candidates(vertical:true,low:ranges[0].lowerBound,high:ranges[0].upperBound+1)
        let rs=candidates(vertical:true,low:ranges[1].lowerBound,high:ranges[1].upperBound+1)
        let ts=candidates(vertical:false,low:ranges[2].lowerBound,high:ranges[2].upperBound+1)
        let bs=candidates(vertical:false,low:ranges[3].lowerBound,high:ranges[3].upperBound+1)
        var accepted=[(CGRect,Double)](),checked=0
        for l in ls { for r in rs { for t in ts { for b in bs {
            let rect=CGRect(x:l,y:t,width:r-l,height:b-t);checked+=1
            if let score=rectangleScore(rect) { accepted.append((rect,score)) }
        } } } }
        accepted.sort { $0.1==$1.1 ? $0.0.width*$0.0.height<$1.0.width*$1.0.height : $0.1>$1.1 }
        searchReport="Rectangle search: L \(ls), R \(rs), T \(ts), B \(bs); \(checked) checked, \(accepted.count) supported."
        guard let strongest=accepted.first else {
            return failure(searchReport+"\nNo rectangle has four supported borders and a consistent inner surround. Manual calibration is available.")
        }
        // Nested header rails may bound the same uniform surround. Prefer the innermost supported rectangle.
        let supported=accepted.filter { strongest.1-$0.1<0.08 }
        let outer=supported.max { $0.0.width*$0.0.height<$1.0.width*$1.0.height }!
        let surround=rgb(Int(outer.0.minX)+4,Int(outer.0.minY)+4)
        let best=supported.filter { distance(rgb(Int($0.0.minX)+4,Int($0.0.minY)+4),surround)<=8 }.min { $0.0.width*$0.0.height<$1.0.width*$1.0.height }!
        let distinct=accepted.first { candidate in
            let intersection=candidate.0.intersection(best.0)
            let overlap=intersection.isNull ? 0:intersection.width*intersection.height
            let smaller=min(candidate.0.width*candidate.0.height,best.0.width*best.0.height)
            return overlap/smaller<0.98
        }
        if let distinct,best.1-distinct.1<0.05 { return failure(searchReport+"\nCompeting UI rectangles are ambiguous. Manual calibration is available.") }
        func refine(_ side:Int)->Int {
            let base=Int(side==0 ? best.0.minX:side==1 ? best.0.maxX:side==2 ? best.0.minY:best.0.maxY)
            for delta in [0,1,-1,2,-2,3,-3] {
                let i=base+delta
                var inside=0,outside=0
                for j in 0..<32 {
                    let f=0.05+0.90*Double(j)/31
                    let x=Int(best.0.minX+best.0.width*f),y=Int(best.0.minY+best.0.height*f)
                    let a=side<2 ? rgb(side==0 ? i:i-1,y):rgb(x,side==2 ? i:i-1)
                    let b=side<2 ? rgb(side==0 ? i-1:i,y):rgb(x,side==2 ? i-1:i)
                    if distance(a,surround)<=8 { inside+=1 }
                    if distance(b,surround)<=8 { outside+=1 }
                }
                if inside>=29 && outside<16 { return i }
            }
            return base
        }
        left=refine(0);right=refine(1);top=refine(2);bottom=refine(3)
    }
    let rect=CGRect(x:left,y:top,width:right-left,height:bottom-top)
    do {
        let samples=[rgb(left+5,top+5),rgb(right-6,top+5),rgb(left+5,bottom-6),rgb(right-6,bottom-6)]
        return ViewportDetection(bounds:rect,verticalDivider:nil,horizontalDivider:nil,background:representative(samples).0.map{$0/255},summary:searchReport+"\nSingle-photo mode: UI bounds \(rect). Internal divider search disabled.")
    }
}

// Preserve an explicit old choice; only genuinely new settings default to AX.
enum AutomaticPlacementMode:String,CaseIterable {
    case accessibility, assisted, screenshot
    var title:String { switch self {
    case .accessibility:return "AX only"
    case .assisted:return "AX-assisted screenshot"
    case .screenshot:return "Pure screenshot"
    } }
    static func resolve(saved:String?,legacy:Bool?)->Self {
        if let saved,let mode=Self(rawValue:saved) { return mode }
        if let legacy { return legacy ? .accessibility:.screenshot }
        return .accessibility
    }
}
