import AppKit
let root=CommandLine.arguments[1]
let dir=root+"/build/AppIcon.iconset"
try FileManager.default.createDirectory(atPath:dir,withIntermediateDirectories:true)
for size in [16,32,128,256,512] {
 for scale in [1,2] {
  let pixels=size*scale
  let image=NSImage(size:NSSize(width:1024,height:1024))
  image.lockFocus()
  NSColor(calibratedRed:0.10,green:0.15,blue:0.21,alpha:1).setFill()
  NSBezierPath(roundedRect:NSRect(x:32,y:32,width:960,height:960),xRadius:210,yRadius:210).fill()
  NSColor(calibratedRed:0.35,green:0.79,blue:0.77,alpha:1).setFill()
  NSBezierPath(roundedRect:NSRect(x:164,y:278,width:696,height:454),xRadius:70,yRadius:70).fill()
  NSBezierPath(roundedRect:NSRect(x:310,y:680,width:260,height:100),xRadius:28,yRadius:28).fill()
  NSColor(calibratedRed:0.10,green:0.15,blue:0.21,alpha:1).setFill()
  NSBezierPath(ovalIn:NSRect(x:344,y:337,width:336,height:336)).fill()
  NSColor.white.withAlphaComponent(0.9).setStroke()
  let ring=NSBezierPath(ovalIn:NSRect(x:391,y:384,width:242,height:242));ring.lineWidth=18;ring.stroke()
  NSColor.white.setFill();NSBezierPath(roundedRect:NSRect(x:727,y:644,width:62,height:24),xRadius:8,yRadius:8).fill()
  image.unlockFocus()
  let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:pixels,pixelsHigh:pixels,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
  NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
  image.draw(in:NSRect(x:0,y:0,width:pixels,height:pixels));NSGraphicsContext.restoreGraphicsState()
  let suffix=scale == 2 ? "@2x" : ""
  try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:dir+"/icon_\(size)x\(size)\(suffix).png"))
 }
}
