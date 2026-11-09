import Foundation
import ImageIO
import CoreGraphics

func expect(_ condition:Bool,_ message:String) { if !condition { fatalError(message) } }
if CommandLine.arguments.count>1 {
    let source=CGImageSourceCreateWithURL(URL(fileURLWithPath:CommandLine.arguments[1]) as CFURL,nil)!
    let image=CGImageSourceCreateImageAtIndex(source,0,nil)!
    // Reproduce window-only capture at the user's logical 2560 x 1349 resolution.
    for cropTop in [0,23,24,30] {
        let crop=image.cropping(to:CGRect(x:0,y:cropTop,width:image.width,height:image.height-cropTop))!
        let c=CGContext(data:nil,width:2560,height:1349,bitsPerComponent:8,bytesPerRow:2560*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.interpolationQuality = .high
        c.draw(crop,in:CGRect(x:0,y:0,width:2560,height:1349))
        let scaled=detectViewport(in:EdgeRaster(image:c.makeImage()!)!)
        expect(scaled.bounds != nil,"Scaled capture missing: \(scaled.summary)")
        expect(abs(scaled.bounds!.minX-305)<=2 && abs(scaled.bounds!.maxX-2242.5)<=2,"Scaled capture chose photo edge: \(scaled.summary)")
    }
    print("PASS: 2560 × 1349 window-crop/resampling cases reject faint photo-edge fringes")
    let raster=EdgeRaster(image:image)!
    let result=detectViewport(in:raster,singlePhoto:true)
    print("Screenshot \(raster.width)x\(raster.height): \(result.summary); bg=\(result.background)")
    expect(result.bounds != nil,"Screenshot viewport missing")
    if let r=result.bounds {
        expect(abs(r.minX/CGFloat(raster.width)-0.119)<0.006 && abs(r.maxX/CGFloat(raster.width)-0.875)<0.006,"Screenshot horizontal bounds wrong: \(r)")
        expect(abs(r.minY/CGFloat(raster.height)-0.086)<0.006 && abs(r.maxY/CGFloat(raster.height)-0.868)<0.006,"Screenshot vertical bounds wrong: \(r)")
    }
}
func fixture(bg:[UInt8],hidden:Bool=false,split:Int=0,narrow:Bool=false)->EdgeRaster {
    let w=900,h=650,l=hidden ? 8:(narrow ? 320:120),r=hidden ? 892:(narrow ? 580:780),t=60,b=580
    var rgba=[UInt8](repeating:255,count:w*h*4)
    for y in 0..<h { for x in 0..<w {
        var c:[UInt8]=[45,45,45]
        if x>=l && x<r && y>=t && y<b { c=bg }
        if x==l-1 || x==r || y==t-1 || y==b { c=[90,90,90] }
        // Near-black photograph, indistinguishable from the surround along some edges.
        if x>l+100 && x<r-100 && y>t+60 && y<b-60 { c=[UInt8((x+y)%4),UInt8((x+y)%4),UInt8((x+y)%4)] }
        if split==1 && abs(x-450)<2 && y>=t && y<b { c=[90,90,90] }
        if split==2 && abs(y-320)<2 && x>=l && x<r { c=[90,90,90] }
        for k in 0..<3 { rgba[(y*w+x)*4+k]=c[k] }
    } }
    return EdgeRaster(width:w,height:h,rgba:rgba)
}
for bg:[UInt8] in [[0,0,0],[70,70,70],[255,255,255],[40,80,110]] {
    for hidden in [false,true] {
        let result=detectViewport(in:fixture(bg:bg,hidden:hidden))
        expect(result.bounds != nil,"Dark/coloured background failed: \(result.summary)")
        expect(result.bounds!.minX == CGFloat(hidden ? 8:120),"Left edge offset: \(result.summary)")
        expect(result.bounds!.minY == 60,"Top edge offset: \(result.summary)")
    }
}
for split in [1,2] {
    let result=detectViewport(in:fixture(bg:[0,0,0],split:split))
    expect(result.bounds != nil,"Split bounds failed")
    expect(split==1 ? result.verticalDivider != nil : result.horizontalDivider != nil,"Divider missing: \(result.summary)")
}
expect(abs(imageZoomPercent(image:CGSize(width:6000,height:4000),viewport:CGSize(width:1500,height:1000),zoom:2,scale:2)-100)<0.001,"Zoom percent incorrect")
print("PASS: UI borders, dark photos, arbitrary surround colours, hidden panels, both split orientations and physical-pixel zoom")
var cache=ViewportCache()
let first=cache.inspect(fixture(bg:[0,0,0]),key:"one")
let second=cache.inspect(fixture(bg:[0,0,0]),key:"one")
expect(!first.1 && second.1,"Unchanged geometry not reused")
expect(!cache.inspect(fixture(bg:[70,70,70]),key:"one").1,"Background change not noticed")
expect(!cache.inspect(fixture(bg:[70,70,70],hidden:true),key:"one").1,"Panel change not noticed")
expect(!cache.inspect(fixture(bg:[70,70,70],hidden:true),key:"resized").1,"Window change not noticed")
let splitCached=cache.inspect(fixture(bg:[70,70,70],hidden:true,split:1),key:"resized")
expect(splitCached.0.verticalDivider != nil,"Split change not noticed with cached outer bounds")
let blank=EdgeRaster(width:900,height:650,rgba:[UInt8](repeating:0,count:900*650*4))
expect(detectViewport(in:blank).bounds==nil,"Uniform screenshot must not detect a viewport")
print("PASS: viewport reuse, background/panel/window/divider changes, and missing-boundary rejection")
let guides=[SnapEdge(vertical:true,coordinate:100,start:20,end:300),SnapEdge(vertical:false,coordinate:200,start:20,end:300)]
let free=CGPoint(x:105,y:197)
expect(snappedPosition(free,edges:guides,enabled:false).point==free,"Free movement altered")
expect(snappedPosition(free,edges:guides,enabled:true).point==CGPoint(x:100,y:200),"Independent axis snapping failed")
expect(snappedPosition(CGPoint(x:110,y:210),edges:guides,enabled:true).edges.isEmpty,"Snapped outside radius")
expect(snappedPosition(CGPoint(x:102,y:400),edges:guides,enabled:true).point==CGPoint(x:100,y:400),"Full vertical guide failed beyond segment")
let snapRaster=fixture(bg:[0,0,0])
let snapLines=calibrationEdges(in:snapRaster,window:CGRect(x:100,y:50,width:900,height:650),primaryHeight:1000)
expect(snapLines.contains { $0.vertical && abs($0.coordinate-220)<2 },"Vertical capture-to-screen edge conversion")
expect(snapLines.contains { !$0.vertical && abs($0.coordinate-890)<2 },"Horizontal capture-to-screen edge conversion")
print("PASS: Option-only snapping, independent axes, radius/full-guide projection and screen-coordinate conversion")

if CommandLine.arguments.count>2 {
    let source=CGImageSourceCreateWithURL(URL(fileURLWithPath:CommandLine.arguments[2]) as CFURL,nil)!
    let image=CGImageSourceCreateImageAtIndex(source,0,nil)!
    let raster=EdgeRaster(image:image)!,start=Date()
    let found=detectViewport(in:raster,singlePhoto:true)
    print("Latest screenshot: \(Int(Date().timeIntervalSince(start)*1000)) ms; \(found.summary)")
    expect(found.bounds != nil,"Latest screenshot missing viewport")
    let r=found.bounds!
    expect(abs(r.minX-242)<=3 && abs(r.maxX-1802)<=3 && abs(r.minY-44)<=3 && abs(r.maxY-912)<=3,"Latest screenshot chose outer rails or overlay: \(r)")
}
// A short, low-contrast panel edge must be usable by manual snapping.
var paneBytes=[UInt8](repeating:255,count:400*300*4)
for y in 0..<300 { for x in 0..<400 { for c in 0..<3 { paneBytes[(y*400+x)*4+c]=UInt8(x>=100 && y>=90 && y<126 ? 48:40) } } }
let paneEdges=calibrationEdges(in:EdgeRaster(width:400,height:300,rgba:paneBytes),window:CGRect(x:0,y:0,width:400,height:300),primaryHeight:300)
expect(!paneEdges.contains { $0.vertical && $0.coordinate==100 },"Short UI detail must be rejected")
print("PASS: short UI details are rejected by proportional snapping")
var weak=fixture(bg:[0,0,0]).rgba
for y in 0..<650 { for x in 0..<900 {
    let i=(y*900+x)*4
    if weak[i]==45 || weak[i]==90 { for k in 0..<3 { weak[i+k]=6 } }
    if x==8 || x==891 { for k in 0..<3 { weak[i+k]=90 } }
} }
let weakUI=detectViewport(in:EdgeRaster(width:900,height:650,rgba:weak))
expect(weakUI.bounds != nil,"Weak UI rectangle missing: \(weakUI.summary)")
expect(abs(weakUI.bounds!.minX-120)<=2 && abs(weakUI.bounds!.maxX-780)<=2,"Strong outer rails displaced weak inner borders: \(weakUI.summary)")
print("PASS: complete rectangles select weak inner UI borders instead of strong outer rails")

let separate=[SnapEdge(vertical:true,coordinate:100,start:400,end:500),SnapEdge(vertical:false,coordinate:200,start:600,end:700)]
expect(snappedPosition(CGPoint(x:103,y:204),edges:separate,enabled:true).point==CGPoint(x:100,y:200),"Disconnected edges must align independently")
if CommandLine.arguments.count>3 {
    let source=CGImageSourceCreateWithURL(URL(fileURLWithPath:CommandLine.arguments[3]) as CFURL,nil)!
    let image=CGImageSourceCreateImageAtIndex(source,0,nil)!,r=EdgeRaster(image:CGImageSourceCreateImageAtIndex(source,0,nil)!)!
    let edges=calibrationEdges(in:r,window:CGRect(x:0,y:0,width:r.width,height:r.height),primaryHeight:CGFloat(r.height))
    expect(edges.contains { $0.vertical && abs($0.coordinate-31)<=1 && $0.end-$0.start>800 },"Supplied screenshot left pane edge missing")
    expect(edges.contains { !$0.vertical && abs(CGFloat(r.height)-$0.coordinate-20)<=1 && $0.end-$0.start>700 },"Supplied screenshot thin upper line missing")
    let point=snappedPosition(CGPoint(x:32,y:CGFloat(image.height)-20),edges:edges,enabled:true)
    expect(point.edges.count==2,"Disconnected pane/upper line projection failed")
    print("PASS: supplied pane screenshot detects left border and thin upper line; full guides combine them")
}

// Single-photo mode must not be rejected by competing interior lines.
var clutter=fixture(bg:[0,0,0]).rgba
for y in 60..<580 { for x in [400,401,500,501] { for k in 0..<3 { clutter[(y*900+x)*4+k]=90 } } }
let clutterRaster=EdgeRaster(width:900,height:650,rgba:clutter)
let single=detectViewport(in:clutterRaster,singlePhoto:true)
expect(single.bounds != nil && single.verticalDivider==nil && single.horizontalDivider==nil,"Interior lines blocked single-photo viewport")
let defaults=try! DetectionConfig.parse(DetectionConfig.template)
expect(defaults==DetectionConfig(),"Template/default mismatch")
for invalid in ["left = phoot", "snapDistancePoints = 0", "fitInsetPoints = nan", "snapContrast = 1.5", "typo = 4", "top=ui\ntop=photo"] {
    do { _=try DetectionConfig.parse(invalid);fatalError("Invalid config accepted") } catch {}
}
let ui=CGRect(x:100,y:200,width:1200,height:900)
for size in [CGSize(width:6000,height:4000),CGSize(width:4000,height:6000)] {
    let base=defaults.placement(ui:ui,image:size)!.photo
    for mask in 0..<16 {
        var c=defaults
        c.left=mask&1==0 ? .ui:.photo;c.right=mask&2==0 ? .ui:.photo
        c.top=mask&4==0 ? .ui:.photo;c.bottom=mask&8==0 ? .ui:.photo
        let p=c.placement(ui:ui,image:size)!
        expect(p.photo==base && p.region.contains(base),"Side options shifted/clipped calculated photograph")
        expect(p.region.minX==(c.left == .ui ? ui.minX:base.minX),"Left side incorrect")
        expect(p.region.maxY==(c.bottom == .ui ? ui.maxY:base.maxY),"Bottom side incorrect")
    }
}
let temporary=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("detection.conf")
let store=DetectionConfigStore(url:temporary)
_ = try! store.reload()
try! "fitInsetPoints=22\nleft=photo".write(to:temporary,atomically:true,encoding:.utf8)
expect(try! store.reload().fitInsetPoints==22,"Live config reload failed")
try! "fitInsetPoints=-1".write(to:temporary,atomically:true,encoding:.utf8)
do { _=try store.reload();fatalError("Bad reload accepted") } catch {}
expect(store.current.fitInsetPoints==22,"Invalid edit erased last valid config")
try! FileManager.default.removeItem(at:temporary.deletingLastPathComponent())
var permissive=defaults;permissive.verticalSnapFraction=0.05
let restored=calibrationEdges(in:EdgeRaster(width:400,height:300,rgba:paneBytes),window:CGRect(x:0,y:0,width:400,height:300),primaryHeight:300,config:permissive)
expect(restored.contains{$0.vertical && $0.coordinate==100},"Config did not change minimum snapping length")
print("PASS: single-photo ambiguity bypass, all 16 side combinations in both orientations, config validation/reload/retention and snapping tuning")

// User's full-screen report: convert top-left coordinates exactly once.
let fullPhoto=CGRect(x:394.6661786237189,y:107,width:1704.6676427525622,height:1137)
let fullScreenPhoto=appKitRect(fullPhoto,primaryHeight:1440)
expect(abs(fullScreenPhoto.minY-196)<0.001 && fullScreenPhoto.minX==fullPhoto.minX,"Full-screen coordinate conversion shifted image")
expect(appKitRect(fullScreenPhoto,primaryHeight:1440)==fullPhoto,"Coordinate conversion not reversible")
let moved=fullPhoto.offsetBy(dx:-2560,dy:100)
expect(appKitRect(moved,primaryHeight:1440).minX==moved.minX,"Negative-origin monitor shifted")
let oldFrame=CGRect(x:100,y:40,width:1600,height:1000)
expect(!sameWindowGeometry(oldFrame,oldFrame.offsetBy(dx:20,dy:0)),"Window move ignored")
expect(!sameWindowGeometry(oldFrame,CGRect(x:100,y:40,width:1590,height:1000)),"Resize ignored")
expect(!sameWindowGeometry(nil,oldFrame),"Unavailable geometry treated as stable")
expect(sameWindowGeometry(oldFrame,oldFrame),"Stable geometry rejected")
var transitionCache=ViewportCache()
_ = transitionCache.inspect(fixture(bg:[0,0,0]),key:"window",singlePhoto:true)
expect(transitionCache.inspect(fixture(bg:[0,0,0]),key:"window",singlePhoto:true).1,"Stable viewport not reused")
expect(!transitionCache.inspect(fixture(bg:[0,0,0]),key:"fullscreen",singlePhoto:true).1,"Full-screen transition reused prior bounds")
expect(!transitionCache.inspect(fixture(bg:[0,0,0]),key:"window",singlePhoto:true).1,"Restored window reused full-screen bounds")
print("PASS: reported full-screen coordinates, moved/negative-origin geometry and window/full-screen/restore cache transitions")

for bg:[UInt8] in [[0,0,0],[70,70,70],[255,255,255],[40,80,110]] {
    let narrow=detectViewport(in:fixture(bg:bg,narrow:true),singlePhoto:true)
    expect(narrow.bounds == CGRect(x:320,y:60,width:260,height:520),"Narrow centre viewport lost: \(narrow.summary)")
}
print("PASS: narrow centre viewport with wide side panels across black, grey, white and coloured surrounds")

let limited=detectViewport(in:fixture(bg:[0,0,0],narrow:true),singlePhoto:true,sideSearchPercent:30)
expect(limited.bounds == nil && limited.workingAreaTooNarrow,"Interval-limited viewport must fail gracefully, not use wider bounds")
expect(limited.summary.contains("Working area too narrow for automatic placement—enlarge it or calibrate manually."),"Narrow message changed")
expect(!detectViewport(in:blank,singlePhoto:true,sideSearchPercent:30).workingAreaTooNarrow,"Missing borders incorrectly labelled narrow")
var intervalCache=ViewportCache()
expect(intervalCache.inspect(fixture(bg:[0,0,0],narrow:true),key:"same",singlePhoto:true,sideSearchPercent:45).0.bounds != nil,"Wide interval failed")
let changedInterval=intervalCache.inspect(fixture(bg:[0,0,0],narrow:true),key:"same",singlePhoto:true,sideSearchPercent:30)
expect(!changedInterval.1 && changedInterval.0.bounds == nil && changedInterval.0.workingAreaTooNarrow,"Interval edit reused cached placement")
expect(try! DetectionConfig.parse("sideSearchPercent = 30").sideSearchPercent == 30,"Interval config not parsed")
for invalid in ["sideSearchPercent = 4", "sideSearchPercent = 51", "sideSearchPercent = nan", "sideSearchPercent = 30\nsideSearchPercent = 45"] {
    do { _=try DetectionConfig.parse(invalid);fatalError("Invalid interval accepted") } catch {}
}
let oldConfigURL=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
defer { try? FileManager.default.removeItem(at:oldConfigURL) }
try! "# User comment\nfitInsetPoints = 22\n".write(to:oldConfigURL,atomically:true,encoding:.utf8)
let oldStore=DetectionConfigStore(url:oldConfigURL)
let migrated=try! oldStore.reload()
expect(migrated.fitInsetPoints == 22 && migrated.sideSearchPercent == 45,"Existing settings not preserved")
let once=try! String(contentsOf:oldConfigURL,encoding:.utf8)
try! oldStore.ensureFile()
expect(try! String(contentsOf:oldConfigURL,encoding:.utf8) == once,"Interval appended twice")
try! "sideSearchPercent = 30\nfitInsetPoints = 22\n".write(to:oldConfigURL,atomically:true,encoding:.utf8)
expect(try! oldStore.reload().sideSearchPercent == 30,"Edited interval not reloaded")
expect(DetectionConfig().key != (try! DetectionConfig.parse("sideSearchPercent = 30")).key,"Manual layout key ignores interval")
print("PASS: configurable side search, narrow-only failure message, cache invalidation, config migration and reload")
