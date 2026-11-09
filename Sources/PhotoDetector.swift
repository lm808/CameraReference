import Foundation
import CoreGraphics

struct PhotoDetection {
    let bounds: CGRect? // normalised, top-left origin
    let summary: String
}
private struct RGB {
    let r: Double, g: Double, b: Double
    func distance(_ other:RGB) -> Double { max(abs(r-other.r),abs(g-other.g),abs(b-other.b)) }
}
private struct PhotoCandidate {
    let rect: CGRect
    let score: Double
    let edges: Int
}

// CPU-only geometry: no Vision, OCR, machine-learning service or language dependency.
// Propose large central rectangles from sustained boundaries; validate the surround,
// interior variation and current reference aspect ratio. Never claim confidence when
// two substantially different rectangles fit the evidence equally well.
func detectPhoto(in raster:EdgeRaster, imageSize:CGSize) -> PhotoDetection {
    let w=raster.width,h=raster.height
    guard w>=320,h>=240,raster.rgba.count==w*h*4,imageSize.width>0,imageSize.height>0 else {
        return PhotoDetection(bounds:nil,summary:"Image or reference dimensions are unavailable.")
    }
    let aspect=imageSize.width/imageSize.height
    guard aspect>=0.2,aspect<=5 else { return PhotoDetection(bounds:nil,summary:"Reference aspect ratio is outside the initial detector's range.") }
    func pixel(_ x:Int,_ y:Int) -> RGB {
        let at=(min(h-1,max(0,y))*w+min(w-1,max(0,x)))*4
        return RGB(r:Double(raster.rgba[at]),g:Double(raster.rgba[at+1]),b:Double(raster.rgba[at+2]))
    }
    func mean(_ values:[RGB]) -> RGB {
        let n=Double(values.count)
        return RGB(r:values.reduce(0){$0+$1.r}/n,g:values.reduce(0){$0+$1.g}/n,b:values.reduce(0){$0+$1.b}/n)
    }
    func uniformity(_ values:[RGB]) -> Double {
        let centre=mean(values)
        return Double(values.filter{$0.distance(centre)<12}.count)/Double(values.count)
    }
    func peaks(vertical:Bool) -> [Int] {
        let extent=vertical ? w:h,along=vertical ? h:w
        var scores=[(Int,Double)]()
        for i in 4..<(extent-4) {
            var a=[RGB](),b=[RGB](),changed=0
            for j in 0..<32 {
                let p=Int(Double(along)*(0.22+0.52*Double(j)/31))
                let left=vertical ? pixel(i-2,p):pixel(p,i-2)
                let right=vertical ? pixel(i+2,p):pixel(p,i+2)
                a.append(left);b.append(right)
                if left.distance(right)>8 { changed += 1 }
            }
            let score=Double(changed)/32*(0.4+0.6*max(uniformity(a),uniformity(b)))
            if score>=0.16 { scores.append((i,score)) }
        }
        scores.sort { $0.1 == $1.1 ? $0.0<$1.0 : $0.1>$1.1 }
        var chosen=[Int]()
        for (i,_) in scores where !chosen.contains(where:{abs($0-i)<=5}) {
            chosen.append(i); if chosen.count==24 { break }
        }
        return chosen.sorted()
    }
    let xs=peaks(vertical:true),ys=peaks(vertical:false)
    var proposals=[CGRect]()
    var keys=Set<String>()
    func propose(_ rect:CGRect) {
        guard rect.minX>=4,rect.minY>=4,rect.maxX<Double(w-4),rect.maxY<Double(h-4),
              rect.width>=Double(w)*0.18,rect.height>=Double(h)*0.22,
              rect.width*rect.height>=Double(w*h)*0.12,
              rect.width*rect.height<=Double(w*h)*0.88,
              (0.28...0.72).contains(rect.midX/Double(w)),(0.22...0.76).contains(rect.midY/Double(h)),
              abs(log(rect.width/rect.height/aspect))<0.045 else { return }
        let key=[rect.minX,rect.minY,rect.maxX,rect.maxY].map{String(Int($0.rounded()))}.joined(separator:",")
        if keys.insert(key).inserted { proposals.append(rect) }
    }
    // Three observed edges can locate a fourth edge which blends into the background.
    for x0 in xs { for x1 in xs where x1>x0 {
        let height=Double(x1-x0)/aspect
        for y in ys {
            propose(CGRect(x:Double(x0),y:Double(y),width:Double(x1-x0),height:height))
            propose(CGRect(x:Double(x0),y:Double(y)-height,width:Double(x1-x0),height:height))
        }
    } }
    for y0 in ys { for y1 in ys where y1>y0 {
        let width=Double(y1-y0)*aspect
        for x in xs {
            propose(CGRect(x:Double(x),y:Double(y0),width:width,height:Double(y1-y0)))
            propose(CGRect(x:Double(x)-width,y:Double(y0),width:width,height:Double(y1-y0)))
        }
    } }
    var accepted=[PhotoCandidate]()
    for rect in proposals {
        var outside=[RGB](),fractions=[Double]()
        for side in 0..<4 {
            var changed=0
            for j in 0..<48 {
                let f=0.04+0.92*Double(j)/47
                let alongX=Int(rect.minX+rect.width*f),alongY=Int(rect.minY+rect.height*f)
                let inner:RGB,outer:RGB
                switch side {
                case 0: inner=pixel(Int(rect.minX)+3,alongY);outer=pixel(Int(rect.minX)-3,alongY)
                case 1: inner=pixel(Int(rect.maxX)-3,alongY);outer=pixel(Int(rect.maxX)+3,alongY)
                case 2: inner=pixel(alongX,Int(rect.minY)+3);outer=pixel(alongX,Int(rect.minY)-3)
                default: inner=pixel(alongX,Int(rect.maxY)-3);outer=pixel(alongX,Int(rect.maxY)+3)
                }
                outside.append(outer); if inner.distance(outer)>8 { changed += 1 }
            }
            fractions.append(Double(changed)/48)
        }
        let supported=fractions.filter{$0>=0.55}.count
        guard supported>=3 else { continue }
        let ring=uniformity(outside)
        guard ring>=0.80 else { continue }
        var inside=[RGB]()
        for y in 0..<12 { for x in 0..<16 {
            inside.append(pixel(Int(rect.minX+rect.width*(0.05+0.90*Double(x)/15)),Int(rect.minY+rect.height*(0.05+0.90*Double(y)/11))))
        } }
        let centre=mean(inside)
        let varied=Double(inside.filter{$0.distance(centre)>12}.count)/Double(inside.count)
        guard varied>=0.25 else { continue }
        let area=rect.width*rect.height/Double(w*h)
        let score=0.50*fractions.reduce(0,+)/4+0.30*ring+0.12*min(1,varied)+0.08*min(1,area/0.5)
        accepted.append(PhotoCandidate(rect:rect,score:score,edges:supported))
    }
    accepted.sort { $0.score>$1.score }
    let prefix="Image-first detector: \(xs.count) vertical / \(ys.count) horizontal boundary candidates; \(proposals.count) rectangles checked."
    guard let best=accepted.first,best.score>=0.77 else {
        return PhotoDetection(bounds:nil,summary:prefix+"\nNo sufficiently supported photo rectangle. Manual calibration retained.")
    }
    func overlap(_ a:CGRect,_ b:CGRect) -> Double {
        let intersect=a.intersection(b)
        let intersection=intersect.isNull ? 0:intersect.width*intersect.height
        return intersection/(a.width*a.height+b.width*b.height-intersection)
    }
    if let competitor=accepted.dropFirst().first(where:{overlap($0.rect,best.rect)<0.88}),best.score-competitor.score<0.045 {
        return PhotoDetection(bounds:nil,summary:prefix+"\nMore than one plausible rectangle; no region selected. Use one uncropped photo at Lightroom Fit.")
    }
    let r=best.rect
    let normalised=CGRect(x:r.minX/Double(w),y:r.minY/Double(h),width:r.width/Double(w),height:r.height/Double(h))
    return PhotoDetection(bounds:normalised,summary:prefix+String(format:"\nPhoto proposal: %d supported edges; evidence score %.2f (heuristic, not a probability).",best.edges,best.score))
}
