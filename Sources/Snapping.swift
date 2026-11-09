import Foundation
import CoreGraphics

struct SnapEdge {
    let vertical:Bool
    let coordinate:CGFloat
    let start:CGFloat
    let end:CGFloat
}
struct SnapPosition {
    let point:CGPoint
    let edges:[SnapEdge]
}
func snappedPosition(_ point:CGPoint,edges:[SnapEdge],enabled:Bool,radius:CGFloat=8)->SnapPosition {
    guard enabled else { return SnapPosition(point:point,edges:[]) }
    var result=point,chosen=[SnapEdge]()
    for vertical in [true,false] {
        let cross=vertical ? point.x:point.y
        if let edge=edges.filter({ $0.vertical==vertical && abs($0.coordinate-cross)<=radius }).min(by:{ abs($0.coordinate-cross)<abs($1.coordinate-cross) }) {
            if vertical { result.x=edge.coordinate } else { result.y=edge.coordinate };chosen.append(edge)
        }
    }
    return SnapPosition(point:result,edges:chosen)
}
// Local sustained gradients, independent of complete viewport recognition.
func calibrationEdges(in raster:EdgeRaster,window:CGRect,primaryHeight:CGFloat,config:DetectionConfig=DetectionConfig())->[SnapEdge] {
    let w=raster.width,h=raster.height
    guard w>4,h>4,raster.rgba.count==w*h*4 else { return [] }
    let sx=window.width/CGFloat(w),sy=window.height/CGFloat(h)
    func difference(_ x1:Int,_ y1:Int,_ x2:Int,_ y2:Int)->Int {
        let a=(y1*w+x1)*4,b=(y2*w+x2)*4
        return (0..<3).map { abs(Int(raster.rgba[a+$0])-Int(raster.rgba[b+$0])) }.max()!
    }
    var edges=[SnapEdge]()
    for vertical in [true,false] {
        let extent=vertical ? w:h,along=vertical ? h:w
        let minRun=max(16,Int(CGFloat(along)*(vertical ? config.verticalSnapFraction:config.horizontalSnapFraction)))
        let maxGap=Int(config.snapGapPoints/(vertical ? sy:sx))
        for i in 1..<extent {
            var start:Int?,last=0
            func flush() {
                if let start,last-start>=minRun {
                    if vertical {
                        edges.append(SnapEdge(vertical:true,coordinate:window.minX+CGFloat(i)*sx,start:primaryHeight-window.minY-CGFloat(last)*sy,end:primaryHeight-window.minY-CGFloat(start)*sy))
                    } else {
                        edges.append(SnapEdge(vertical:false,coordinate:primaryHeight-window.minY-CGFloat(i)*sy,start:window.minX+CGFloat(start)*sx,end:window.minX+CGFloat(last)*sx))
                    }
                }
            }
            for j in stride(from:0,to:along,by:2) {
                let delta=vertical ? difference(i-1,j,i,j):difference(j,i-1,j,i)
                if delta>=config.snapContrast { if start==nil { start=j };last=j }
                else if start != nil && j-last>maxGap { flush();start=nil }
            }
            flush()
        }
    }
    return edges
}
let regionPreferenceKeys=["region","regionDisplay","regionWindow","manualLayoutKey"]
func clearRegionPreferences(_ defaults:UserDefaults) {
    for key in regionPreferenceKeys { defaults.removeObject(forKey:key) }
}
