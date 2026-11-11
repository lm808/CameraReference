import Foundation
import ImageIO
// Optional supplied crops: stacked left margin, then side-by-side bottom margin.
// Images remain outside the repository. Explicit crop coordinates test scanning, not Full detection.
precondition(CommandLine.arguments.count==3,"Supply the two original margin crops")
for (index,path) in CommandLine.arguments.dropFirst().enumerated() {
 guard let source=CGImageSourceCreateWithURL(URL(fileURLWithPath:path) as CFURL,nil),let image=CGImageSourceCreateImageAtIndex(source,0,nil) else { fatalError("Missing input crop") }
 for factor:CGFloat in [1,0.5,0.25] {
 let width=Int(CGFloat(image.width)*factor),height=Int(CGFloat(image.height)*factor)
 let c=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
 c.interpolationQuality = .medium;c.draw(image,in:CGRect(x:0,y:0,width:width,height:height))
 let raster=EdgeRaster(image:c.makeImage()!)!
 let scale=CGFloat(raster.width)/CGFloat(image.width)
 let area=index==0 ? CGRect(x:166,y:41,width:670,height:2155):CGRect(x:140,y:0,width:3874,height:124)
 let view=CGRect(x:area.minX*scale,y:area.minY*scale,width:area.width*scale,height:area.height*scale)
 let result=scanInsetDivider(in:raster,viewport:view,layout:index==0 ? .upper:.left,insetPixels:CGSize(width:36*scale,height:36*scale))
 print(index,result.summary,"divider original pixels",String(describing:result.position.map{$0/scale}))
 precondition(result.position != nil)
 let expected:CGFloat=index==0 ? 1119:2076
 precondition(abs(result.position!/scale-expected)<6)
 }
}
