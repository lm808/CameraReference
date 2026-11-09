import Foundation
import CoreGraphics

// Geometry is top-left pixel based here; conversion to macOS coordinates happens once in ScreenProbe.
struct ViewportDetection {
    let bounds: CGRect?
    let verticalDivider: CGFloat?
    let horizontalDivider: CGFloat?
    let background: [Double]
    let summary: String
    var workingAreaTooNarrow=false
}
func detectViewport(in raster: EdgeRaster, knownBounds:CGRect? = nil,singlePhoto:Bool=false,sideSearchPercent:Double=45) -> ViewportDetection {
    let w=raster.width, h=raster.height
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
    // Both sides must be nearly uniform along the line. A textured photograph's edge is not a UI separator.
    func lines(vertical:Bool,from:Int,to:Int,alongFrom:Int,alongTo:Int,separator:Bool=false)->[Int] {
        guard to>from,alongTo>alongFrom else { return [] }
        var found=[Int]()
        for i in from..<to {
            var a=[[Double]](),b=[[Double]]()
            for j in 0..<64 {
                let p=alongFrom+(alongTo-alongFrom-1)*j/63
                a.append(vertical ? rgb(i-1,p) : rgb(p,i-1))
                b.append(vertical ? rgb(i,p) : rgb(p,i))
            }
            let (ca,ua)=representative(a), (cb,ub)=representative(b)
            let changed=Double(zip(a,b).filter { distance($0,$1)>=4 }.count)/64
            if separator ? (max(ua,ub)>=0.95 && changed>=0.90) : (ua>=0.90 && ub>=0.90 && distance(ca,cb)>=(vertical ? 12:4)) { found.append(i) }
        }
        return found
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
        let ls=candidates(vertical:true,low:2,high:Int(Double(w)*sideSearchPercent/100))
        let rs=candidates(vertical:true,low:Int(Double(w)*(100-sideSearchPercent)/100),high:w-2)
        let ts=candidates(vertical:false,low:2,high:h*30/100)
        let bs=candidates(vertical:false,low:h*65/100,high:h-2)
        var accepted=[(CGRect,Double)](),checked=0
        for l in ls { for r in rs { for t in ts { for b in bs {
            let rect=CGRect(x:l,y:t,width:r-l,height:b-t);checked+=1
            if let score=rectangleScore(rect) { accepted.append((rect,score)) }
        } } } }
        accepted.sort { $0.1==$1.1 ? $0.0.width*$0.0.height<$1.0.width*$1.0.height : $0.1>$1.1 }
        searchReport="Rectangle search: L \(ls), R \(rs), T \(ts), B \(bs); \(checked) checked, \(accepted.count) supported."
        guard let strongest=accepted.first else {
            // Diagnose an interval-limited viewport with the same full validation.
            // The wider result is evidence for the message, never a placement fallback.
            if sideSearchPercent < 50,
               let wider=detectViewport(in:raster,singlePhoto:singlePhoto,sideSearchPercent:50).bounds,
               wider.minX >= CGFloat(Int(Double(w)*sideSearchPercent/100)) || wider.maxX < CGFloat(Int(Double(w)*(100-sideSearchPercent)/100)) {
                var result=failure(searchReport+"\nWorking area too narrow for automatic placement—enlarge it or calibrate manually.")
                result.workingAreaTooNarrow=true
                return result
            }
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
    if singlePhoto {
        let samples=[rgb(left+5,top+5),rgb(right-6,top+5),rgb(left+5,bottom-6),rgb(right-6,bottom-6)]
        return ViewportDetection(bounds:rect,verticalDivider:nil,horizontalDivider:nil,background:representative(samples).0.map{$0/255},summary:searchReport+"\nSingle-photo mode: UI bounds \(rect). Internal divider search disabled.")
    }
    let vx=lines(vertical:true,from:left+(right-left)*30/100,to:left+(right-left)*70/100,alongFrom:top+6,alongTo:bottom-6,separator:true)
    let hy=lines(vertical:false,from:top+(bottom-top)*30/100,to:top+(bottom-top)*70/100,alongFrom:left+6,alongTo:right-6,separator:true)
    func divider(_ values:[Int])->CGFloat? {
        guard let first=values.first,let last=values.last,last-first<=12 else { return nil }
        return CGFloat(first+last)/2
    }
    // Sample corner margins; use the median to resist a tiny control or cursor remnant.
    let samples=[rgb(left+5,top+5),rgb(right-6,top+5),rgb(left+5,bottom-6),rgb(right-6,bottom-6)]
    let colour=representative(samples).0.map { $0/255 }
    let v=divider(vx),u=divider(hy)
    if !vx.isEmpty && v==nil || !hy.isEmpty && u==nil || v != nil && u != nil {
        return failure("Multiple internal UI dividers are ambiguous. Select the intended pane manually.")
    }
    return ViewportDetection(bounds:rect,verticalDivider:v,horizontalDivider:u,background:colour,
        summary:searchReport+"\nUI borders found at x=\(left)…\(right), y=\(top)…\(bottom) capture pixels. " + (v != nil ? "Side-by-side panes." : u != nil ? "Stacked panes." : "Single viewing area."))
}

func referencePane(_ viewport:CGRect,vertical:CGFloat?,horizontal:CGFloat?) -> CGRect {
    if let vertical { return CGRect(x:viewport.minX,y:viewport.minY,width:vertical-viewport.minX,height:viewport.height) }
    if let horizontal { return CGRect(x:viewport.minX,y:viewport.minY,width:viewport.width,height:horizontal-viewport.minY) }
    return viewport
}

func imageZoomPercent(image:CGSize,viewport:CGSize,zoom:CGFloat,scale:CGFloat)->Double {
    guard image.width>0,image.height>0 else { return 0 }
    return Double(min(viewport.width/image.width,viewport.height/image.height)*zoom*scale*100)
}

// In-memory UI samples only: never retain a screenshot or photo between invocations.
struct ViewportCache {
    var bounds:CGRect?
    var width=0,height=0
    var windowKey=""
    var samples=[UInt8]()
    private func signature(_ raster:EdgeRaster,_ r:CGRect)->[UInt8] {
        var result=[UInt8]()
        func add(_ x:Int,_ y:Int) {
            let i=(max(0,min(raster.height-1,y))*raster.width+max(0,min(raster.width-1,x)))*4
            result.append(contentsOf:raster.rgba[i..<i+3])
        }
        for j in 0..<48 {
            let x=Int(r.minX+CGFloat(j)*(r.width-1)/47),y=Int(r.minY+CGFloat(j)*(r.height-1)/47)
            for d in [-3,3] {
                add(x,Int(r.minY)+d);add(x,Int(r.maxY)+d)
                add(Int(r.minX)+d,y);add(Int(r.maxX)+d,y)
            }
        }
        return result
    }
    mutating func inspect(_ raster:EdgeRaster,key:String,singlePhoto:Bool=false,sideSearchPercent:Double=45)->(ViewportDetection,Bool) {
        let cacheKey="\(key):sideSearchPercent=\(sideSearchPercent)"
        var reuse=false
        if cacheKey==windowKey,width==raster.width,height==raster.height,let bounds {
            let now=signature(raster,bounds)
            reuse=now.count==samples.count && zip(now,samples).allSatisfy { abs(Int($0)-Int($1))<=3 }
        }
        let result=detectViewport(in:raster,knownBounds:reuse ? bounds:nil,singlePhoto:singlePhoto,sideSearchPercent:sideSearchPercent)
        bounds=result.bounds;width=raster.width;height=raster.height;windowKey=cacheKey
        samples=result.bounds.map { signature(raster,$0) } ?? []
        return (result,reuse)
    }
}
actor ScreenGeometryCache {
    static let shared=ScreenGeometryCache()
    var cache=ViewportCache()
    var generation=UUID()
    func reset() { generation=UUID();cache=ViewportCache() }
    func ticket()->UUID { generation }
    func inspect(_ raster:EdgeRaster,key:String,ticket:UUID,singlePhoto:Bool=false,sideSearchPercent:Double=45)->(ViewportDetection,Bool)? {
        guard ticket==generation else { return nil };return cache.inspect(raster,key:key,singlePhoto:singlePhoto,sideSearchPercent:sideSearchPercent)
    }
    func inspect(_ raster:EdgeRaster,key:String,singlePhoto:Bool=false,sideSearchPercent:Double=45)->(ViewportDetection,Bool) { cache.inspect(raster,key:key,singlePhoto:singlePhoto,sideSearchPercent:sideSearchPercent) }
}
