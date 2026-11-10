import Foundation
import ImageIO
import CoreGraphics
let source=CGImageSourceCreateWithURL(URL(fileURLWithPath:CommandLine.arguments[1]) as CFURL,nil)!
let image=CGImageSourceCreateImageAtIndex(source,0,nil)!
let small=CommandLine.arguments.contains("small")
let crop=image.cropping(to:small ? CGRect(x:224,y:308,width:1800,height:1404):CGRect(x:240,y:66,width:2784,height:1776))!
func measure(_ name:String,_ block:()->Void) {
 var times=[Double]()
 for _ in 0..<10 { let t=ProcessInfo.processInfo.systemUptime;block();times.append((ProcessInfo.processInfo.systemUptime-t)*1000) }
 let sorted=times.sorted()
 print(String(format:"%@ first %.1f ms; median %.1f ms; max %.1f ms",name,times[0],sorted[5],sorted.last!))
}
measure("Raster") { _=EdgeRaster(image:crop) }
let raster=EdgeRaster(image:crop)!
measure("Detection") { precondition(detectViewport(in:raster,singlePhoto:true).bounds != nil) }
var cache=ViewportCache();_ = cache.inspect(raster,key:"fixed",singlePhoto:true)
measure("Cached validation") { precondition(cache.inspect(raster,key:"fixed",singlePhoto:true).0.bounds != nil) }
