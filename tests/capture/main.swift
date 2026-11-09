import Foundation
import ImageIO
import CoreGraphics

let window = CGRect(x:120,y:33,width:1392,height:888)
let display = CGRect(x:0,y:0,width:1512,height:982)
assert(windowCaptureSourceRect(window:window,display:display) == window)
let otherDisplay = display.offsetBy(dx:-1512,dy:-300)
assert(windowCaptureSourceRect(window:window.offsetBy(dx:-1512,dy:-300),display:otherDisplay) == window)
assert(windowCaptureSourceRect(window:window.offsetBy(dx:10,dy:0),display:display) == nil)
assert(windowCaptureSourceRect(window:.zero,display:display) == nil)
assert(windowCaptureSourceRect(window:display,display:display) == CGRect(origin:.zero,size:display.size))
print("PASS: explicit window crop, negative display origins, full-screen bounds and cross-display rejection")

// Optional user-provided screen fixture, never bundled or captured by these tests.
if CommandLine.arguments.count > 1 {
    let source=CGImageSourceCreateWithURL(URL(fileURLWithPath:CommandLine.arguments[1]) as CFURL,nil)!
    let image=CGImageSourceCreateImageAtIndex(source,0,nil)!
    assert(image.width == 3024 && image.height == 1964)
    let crop=windowCaptureSourceRect(window:window,display:display)!
    let pixels=CGRect(x:crop.minX*2,y:crop.minY*2,width:crop.width*2,height:crop.height*2)
    let raster=EdgeRaster(image:image.cropping(to:pixels)!)!
    let found=detectViewport(in:raster,singlePhoto:true)
    guard let bounds=found.bounds else { fatalError(found.summary) }
    let ui=CGRect(x:window.minX+bounds.minX*window.width/CGFloat(raster.width),
                  y:window.minY+bounds.minY*window.height/CGFloat(raster.height),
                  width:bounds.width*window.width/CGFloat(raster.width),
                  height:bounds.height*window.height/CGFloat(raster.height))
    // Visible UI edges measured in the supplied screen image, in screen points.
    assert(abs(ui.minX-426)<2 && abs(ui.maxX-1195)<2)
    assert(abs(ui.minY-123)<2 && abs(ui.maxY-739)<2)
    let placed=DetectionConfig().placement(ui:ui,image:CGSize(width:6000,height:4000))!
    assert(abs(placed.photo.minX-446)<3 && abs(placed.photo.minY-188)<3)
    assert(abs(placed.photo.width-729)<4 && abs(placed.photo.height-486)<4)
    // The wrong full-width extent reproduces the user's displaced detection.
    let wide=image.cropping(to:CGRect(x:0,y:66,width:3024,height:1776))!
    let wrong=detectViewport(in:EdgeRaster(image:wide)!,singlePhoto:true).bounds!
    assert(abs(wrong.minX-722)<2 && abs(wrong.width-1301)<2)
    print("PASS: supplied small-window screenshot reproduces wrong full-width bounds; explicit crop aligns viewport and fitted photograph")
}

// Second optional fixture: the 900 × 702 pt window with wide side panels.
if CommandLine.arguments.count > 2 {
    let source=CGImageSourceCreateWithURL(URL(fileURLWithPath:CommandLine.arguments[2]) as CFURL,nil)!
    let image=CGImageSourceCreateImageAtIndex(source,0,nil)!
    let crop=image.cropping(to:CGRect(x:224,y:308,width:1800,height:1404))!
    let found=detectViewport(in:EdgeRaster(image:crop)!,singlePhoto:true)
    guard let bounds=found.bounds else { fatalError(found.summary) }
    assert(abs(bounds.minX-612)<2 && abs(bounds.maxX-1166)<2)
    assert(abs(bounds.minY-180)<2 && abs(bounds.maxY-1040)<2)
    let ui=CGRect(x:112+bounds.minX/2,y:154+bounds.minY/2,width:bounds.width/2,height:bounds.height/2)
    let photo=DetectionConfig().placement(ui:ui,image:CGSize(width:6000,height:4000))!.photo
    assert(abs(photo.minX-438)<3 && abs(photo.minY-380)<3)
    assert(abs(photo.width-237)<5 && abs(photo.height-158)<4)
    print("PASS: 900 × 702 screenshot detects narrow viewport and fits photograph within measured screen bounds")
}
