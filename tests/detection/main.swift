import Foundation
import CoreGraphics

func fixture(photo:CGRect?,background:UInt8=0,flat:Bool=false,missingBottom:Bool=false,ui:Bool=true) -> EdgeRaster {
    let w=900,h=650
    var rgba=[UInt8](repeating:255,count:w*h*4)
    for y in 0..<h { for x in 0..<w {
        let i=(y*w+x)*4
        var r=background,g=background,b=background
        if ui && (x<120 || x>780 || y<35 || y>590) {
            r=45;g=45;b=45
            // Deterministic panel text/controls and filmstrip-like clutter.
            if (y%19<3 && x%80<55) { r=170;g=170;b=170 }
        }
        if let photo,photo.contains(CGPoint(x:x,y:y)) {
            if !missingBottom || Double(y)<photo.maxY-10 {
                if flat { r=120;g=120;b=120 }
                else {
                    r=UInt8(35+(x*7+y*3)%170);g=UInt8(25+(x*3+y*11)%190);b=UInt8(40+(x*13+y*2)%160)
                }
            }
        }
        rgba[i]=r;rgba[i+1]=g;rgba[i+2]=b
    } }
    return EdgeRaster(width:w,height:h,rgba:rgba)
}
func check(_ name:String,_ rect:CGRect,background:UInt8=0,missingBottom:Bool=false,ui:Bool=true) {
    let started=Date()
    let result=detectPhoto(in:fixture(photo:rect,background:background,missingBottom:missingBottom,ui:ui),imageSize:rect.size)
    guard let n=result.bounds else { fatalError("\(name): \(result.summary)") }
    let found=CGRect(x:n.minX*900,y:n.minY*650,width:n.width*900,height:n.height*650)
    assert(abs(found.minX-rect.minX)<=4 && abs(found.minY-rect.minY)<=4 && abs(found.maxX-rect.maxX)<=4 && abs(found.maxY-rect.maxY)<=4,"\(name): \(found) expected \(rect)")
    print("PASS: \(name), within 4 raster pixels, \(Int(Date().timeIntervalSince(started)*1000)) ms")
}
check("landscape, black surround",CGRect(x:180,y:100,width:540,height:360))
check("portrait, grey surround",CGRect(x:300,y:55,width:330,height:495),background:70)
check("landscape, white surround",CGRect(x:165,y:100,width:570,height:380),background:255)
check("hidden panels",CGRect(x:120,y:90,width:660,height:440),ui:false)
check("one edge blends into black",CGRect(x:180,y:100,width:540,height:360),missingBottom:true)
assert(detectPhoto(in:fixture(photo:nil),imageSize:CGSize(width:3,height:2)).bounds==nil)
assert(detectPhoto(in:fixture(photo:CGRect(x:180,y:100,width:540,height:360),flat:true),imageSize:CGSize(width:3,height:2)).bounds==nil)
assert(detectPhoto(in:fixture(photo:CGRect(x:180,y:100,width:540,height:360)),imageSize:CGSize(width:2,height:3)).bounds==nil)
print("PASS: UI-only, uniform rectangle and mismatched aspect ratio rejected")

// Two equally plausible photos must not be silently chosen.
let leftRect=CGRect(x:140,y:160,width:300,height:300)
let rightRect=CGRect(x:460,y:160,width:300,height:300)
let left=fixture(photo:leftRect,ui:false),right=fixture(photo:rightRect,ui:false)
var two=left.rgba
for y in 160..<460 { for x in 460..<760 {
    let i=(y*900+x)*4
    two.replaceSubrange(i..<i+4,with:right.rgba[i..<i+4])
} }
let ambiguous=detectPhoto(in:EdgeRaster(width:900,height:650,rgba:two),imageSize:CGSize(width:1,height:1))
assert(ambiguous.bounds==nil,ambiguous.summary)
print("PASS: two comparable photo rectangles rejected")

// Test CGImage -> CPU raster conversion, not only preconstructed byte arrays.
let original=fixture(photo:CGRect(x:180,y:100,width:540,height:360))
let provider=CGDataProvider(data:Data(original.rgba) as CFData)!
let cg=CGImage(width:900,height:650,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:3600,
              space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),
              provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
let roundTrip=detectPhoto(in:EdgeRaster(image:cg)!,imageSize:CGSize(width:3,height:2))
assert(roundTrip.bounds != nil)
assert(abs(roundTrip.bounds!.minY-100.0/650)<0.01)
print("PASS: CGImage raster conversion preserves top-left coordinate mapping")
