import Foundation
let token = "11111111-1111-1111-1111-111111111111"
let path = "/Photos/假期 trip/IMG_1234.CR3"
let hex = path.utf8.map { String(format: "%02x", $0) }.joined()
let valid = "\(token)\nOK\n\(hex)\nEND\n"
assert(BridgeResponse(valid, expected: token)?.value == path)
assert(BridgeResponse(valid, expected: "different") == nil)
assert(BridgeResponse(String(valid.dropLast(2)), expected: token) == nil)
assert(BridgeResponse("\(token)\nOK\nzz\nEND\n", expected: token) == nil)
assert(BridgeResponse("\(token)\nERR\n\(hex)\nEND\n", expected: token)?.success == false)
let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: folder) }
let raw = folder.appendingPathComponent("IMG_1234.CR3")
try Data().write(to: raw)
func expectFailure(_ work: () throws -> Void) { do { try work(); fatalError("Expected failure") } catch {} }
expectFailure { _ = try matchingJPEG(for: raw) }
let jpeg = folder.appendingPathComponent("IMG_1234.jPg")
try Data().write(to: jpeg)
let matched = try matchingJPEG(for: raw)
assert(matched.standardizedFileURL == jpeg.standardizedFileURL)
try Data().write(to: folder.appendingPathComponent("IMG_1234.JPEG"))
expectFailure { _ = try matchingJPEG(for: raw) }
try FileManager.default.removeItem(at: raw)
expectFailure { _ = try matchingJPEG(for: raw) }
print("PASS: Unicode protocol, stale/partial/invalid replies, error reply, missing/ambiguous JPEG, mixed-case extension, offline RAW")

for ext in ["CR2", "NEF", "ARW", "RAF", "ORF", "RW2", "DNG"] {
    let other = folder.appendingPathComponent("other.\(ext)")
    let jpg = folder.appendingPathComponent("other.JPG")
    try Data().write(to: other); try Data().write(to: jpg)
    let match = try matchingJPEG(for: other)
    assert(match.standardizedFileURL == jpg.standardizedFileURL)
    try FileManager.default.removeItem(at: other)
    try FileManager.default.removeItem(at: jpg)
}
print("PASS: non-Canon RAW extensions and DNG pairing")

// Synthetic JPEG fixture, created in memory. No real photo or extracted JPEG is written by tests.
import AppKit
import ImageIO
import CryptoKit
let bitmap = CGContext(data: nil, width: 64, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
bitmap.setFillColor(CGColor(red: 0.4, green: 0.6, blue: 0.8, alpha: 1)); bitmap.fill(CGRect(x: 0, y: 0, width: 64, height: 32))
bitmap.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1)); bitmap.fill(CGRect(x: 0, y: 0, width: 32, height: 16))
bitmap.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 1)); bitmap.fill(CGRect(x: 32, y: 0, width: 32, height: 16))
bitmap.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1)); bitmap.fill(CGRect(x: 0, y: 16, width: 32, height: 16))
let fixtureImage = bitmap.makeImage()!
let jpegBytes = NSMutableData()
let encoder = CGImageDestinationCreateWithData(jpegBytes, "public.jpeg" as CFString, 1, nil)!
CGImageDestinationAddImage(encoder, fixtureImage, [kCGImageDestinationLossyCompressionQuality: 0.8, kCGImagePropertyOrientation: 6] as CFDictionary)
assert(CGImageDestinationFinalize(encoder))
let plainFixture = jpegBytes as Data
// Insert a minimal EXIF Orientation=6 APP1 segment; the test encoder omits that property.
let exif: [UInt8] = [0xff,0xe1,0x00,0x22, 0x45,0x78,0x69,0x66,0,0,
  0x49,0x49,0x2a,0,8,0,0,0, 1,0, 0x12,0x01,3,0,1,0,0,0,6,0,0,0,0,0,0,0]
var fixture = Data(plainFixture.prefix(2)); fixture.append(contentsOf: exif); fixture.append(plainFixture.dropFirst(2))
let portrait = try decodeJPEG(CGImageSourceCreateWithData(fixture as CFData, nil))
assert(portrait.width == 32 && portrait.height == 64)
let secondRaw = folder.appendingPathComponent("test.CR3")
try Data("synthetic raw; not a real photo".utf8).write(to: secondRaw)
let standalone = folder.appendingPathComponent("test.JPG")
try fixture.write(to: standalone)
let baselineHash = SHA256.hash(data: try Data(contentsOf: secondRaw))
let baselineDate = try FileManager.default.attributesOfItem(atPath: secondRaw.path)[.modificationDate] as! Date
func script(_ name: String, _ body: String) throws -> URL {
    let url = folder.appendingPathComponent(name)
    try ("#!/usr/bin/python3\nimport sys,base64,time\n" + body).write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    return url
}
let successTool = try script("fake-exiftool", "assert sys.argv[1:5] == ['-config','','-b','-JpgFromRaw']\nassert sys.argv[5] == '--'\nsys.stderr.write('x'*200000)\nsys.stderr.flush()\nsys.stdout.buffer.write(base64.b64decode('\(fixture.base64EncodedString())'))\n")
let badTool = try script("bad-exiftool", "sys.stdout.buffer.write(b'not a JPEG')\n")
let failingTool = try script("failed-exiftool", "sys.exit(1)\n")
let hangingTool = try script("slow-exiftool", "time.sleep(30)\n")
let hugeTool = try script("huge-exiftool", "sys.stdout.buffer.write(b'x'*2000000)\n")
// Standalone-first does not invoke the supplied failing tool; embedded-first chooses the pipe image.
let first = try loadReference(raw: secondRaw, preferEmbedded: false, executable: failingTool, cancellation: Cancellation())
assert(first.origin == .standalone && !first.usedFallback)
assert(first.sourceFilename==standalone.lastPathComponent)
let embedded = try loadReference(raw: secondRaw, preferEmbedded: true, executable: successTool, cancellation: Cancellation())
assert(embedded.origin == .embedded && !embedded.usedFallback)
assert(embedded.image.width == 32 && embedded.image.height == 64)
let fallback = try loadReference(raw: secondRaw, preferEmbedded: true, executable: badTool, cancellation: Cancellation())
assert(fallback.origin == .standalone && fallback.usedFallback)
let missingToolFallback = try loadReference(raw: secondRaw, preferEmbedded: true, executable: nil, cancellation: Cancellation())
assert(missingToolFallback.origin == .standalone)
try FileManager.default.removeItem(at: standalone)
let rawOnly = try loadReference(raw: secondRaw, preferEmbedded: false, executable: successTool, cancellation: Cancellation())
assert(rawOnly.origin == .embedded && rawOnly.usedFallback)
expectFailure { _ = try loadReference(raw: secondRaw, preferEmbedded: false, executable: badTool, cancellation: Cancellation()) }
expectFailure { _ = try extractJPEG(raw: secondRaw, executable: failingTool, cancellation: Cancellation()) }
expectFailure { _ = try extractJPEG(raw: secondRaw, executable: hugeTool, cancellation: Cancellation(), byteLimit: 1024) }
let cancelled = Cancellation()
DispatchQueue.global().asyncAfter(deadline: .now()+0.15) { cancelled.cancel() }
let start = ProcessInfo.processInfo.systemUptime
expectFailure { _ = try extractJPEG(raw: secondRaw, executable: hangingTool, cancellation: cancelled) }
assert(ProcessInfo.processInfo.systemUptime-start < 3)
expectFailure { _ = try extractJPEG(raw: secondRaw, executable: hangingTool, cancellation: Cancellation(), timeout: 0.2) }
let beforeFiles = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
for _ in 0..<3 { _ = try loadReference(raw: secondRaw, preferEmbedded: true, executable: successTool, cancellation: Cancellation()) }
let afterFiles = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
assert(afterFiles == beforeFiles)
let afterHash = SHA256.hash(data: try Data(contentsOf: secondRaw))
let afterDate = try FileManager.default.attributesOfItem(atPath: secondRaw.path)[.modificationDate] as! Date
assert(baselineHash == afterHash && baselineDate == afterDate)
// Real ExifTool is used only against the synthetic invalid CR3: validate safe failure and unchanged input.
if let actual = findExifTool() {
    expectFailure { _ = try extractJPEG(raw: secondRaw, executable: actual, cancellation: Cancellation()) }
    let hash = SHA256.hash(data: try Data(contentsOf: secondRaw)); assert(hash == baselineHash)
}
assert(fittedSize(image: CGSize(width: 8000, height: 4000), inside: CGSize(width: 500, height: 400)) == CGSize(width: 500, height: 250))
print("PASS: source priority, both fallback directions, invalid JPEG, missing/failing tool, binary pipes with large stderr, orientation, cancellation, timeout, byte limit, repeat extraction without image files, synthetic RAW hash/mtime, fit geometry")

let orientationTool = try script("orientation-exiftool", "if '-Orientation' in sys.argv:\n sys.stdout.write('6\\n')\nelse:\n sys.stdout.buffer.write(base64.b64decode('\(plainFixture.base64EncodedString())'))\n")
let oriented = try loadReference(raw: secondRaw, preferEmbedded: true, executable: orientationTool, cancellation: Cancellation())
assert(oriented.image.width == 32 && oriented.image.height == 64)
print("PASS: embedded JPEG without EXIF uses read-only RAW orientation query")

func samples(_ image: CGImage) -> [UInt8] {
    let c = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 16,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.interpolationQuality = .none; c.draw(image, in: CGRect(x: 0, y: 0, width: 4, height: 4))
    return Array(UnsafeBufferPointer(start: c.data!.assumingMemoryBound(to: UInt8.self), count: 64))
}
for orientation in 1...8 {
    var segment = exif; segment[28] = UInt8(orientation)
    var tagged = Data(plainFixture.prefix(2)); tagged.append(contentsOf: segment); tagged.append(plainFixture.dropFirst(2))
    let expected = try decodeJPEG(CGImageSourceCreateWithData(tagged as CFData, nil))
    let tool = try script("orient-\(orientation)", "if '-Orientation' in sys.argv:\n sys.stdout.write('\(orientation)\\n')\nelse:\n sys.stdout.buffer.write(base64.b64decode('\(plainFixture.base64EncodedString())'))\n")
    let actual = try embeddedImage(raw: secondRaw, executable: tool, cancellation: Cancellation()).image
    assert(actual.width == expected.width && actual.height == expected.height)
    assert(zip(samples(actual), samples(expected)).allSatisfy { abs(Int($0)-Int($1)) <= 3 })
}
print("PASS: all eight RAW orientation transforms agree with ImageIO JPEG orientation")

// Remove only EXIF segments for byte comparison; preserve all other JPEG bytes.
func withoutEXIF(_ data: Data) -> Data {
    let b = [UInt8](data); var out = Data(b.prefix(2)); var i = 2
    while i+4 <= b.count, b[i] == 255, b[i+1] != 0xda, b[i+1] != 0xd9 {
        let length = Int(b[i+2])*256+Int(b[i+3]); let end = i+2+length
        guard length >= 2, end <= b.count else { break }
        if !(b[i+1] == 225 && length >= 8 && Array(b[(i+4)..<(i+10)]) == [69,120,105,102,0,0]) { out.append(contentsOf: b[i..<end]) }
        i = end
    }
    out.append(contentsOf: b[i...]); return out
}
for n in 1...8 {
    let data = try exportJPEG(plainFixture, orientation: UInt32(n))
    assert(withoutEXIF(data) == withoutEXIF(plainFixture))
    let decoded = try decodeJPEG(CGImageSourceCreateWithData(data as CFData,nil))
    assert(decoded.width == (n >= 5 ? 32 : 64))
    let updated = try exportJPEG(fixture, orientation: UInt32(n))
    let image = try decodeJPEG(CGImageSourceCreateWithData(updated as CFData,nil))
    assert(image.width == decoded.width && image.height == decoded.height)
    assert(samples(image) == samples(decoded))
    assert(withoutEXIF(updated) == withoutEXIF(plainFixture))
}
let unchanged = try exportJPEG(fixture, orientation: nil)
assert(unchanged == fixture)
let saved = folder.appendingPathComponent("test_JpgFromRaw.jpg")
try writeExport(fixture, to: saved, replacing: nil)
let savedBytes = try Data(contentsOf: saved)
assert(savedBytes == fixture)
expectFailure { try writeExport(plainFixture, to: saved, replacing: nil) }
let confirmed = try exportIdentity(saved)
try writeExport(plainFixture, to: saved, replacing: confirmed)
expectFailure { try writeExport(fixture, to: saved, replacing: confirmed) }
let link = folder.appendingPathComponent("linked.jpg")
try FileManager.default.createSymbolicLink(at: link, withDestinationURL: secondRaw)
expectFailure { _ = try exportIdentity(link) }
expectFailure { try writeExport(fixture, to: link, replacing: nil) }
let finalRaw = try Data(contentsOf: secondRaw)
assert(SHA256.hash(data: finalRaw) == baselineHash)
print("PASS: lossless export orientation 1–8, unchanged compressed JPEG bytes, exclusive create, confirmed replacement, stale destination and symlink rejection, RAW unchanged")

// Pointer anchoring at 2× zoom should keep the same photo point under the pointer.
var nav=ImageNavigation()
let viewport=CGRect(x:0,y:0,width:800,height:600)
let photo=CGSize(width:1600,height:1200)
let pointer=CGPoint(x:500,y:350)
nav.magnify(factor:2,at:pointer,image:photo,viewport:viewport)
assert(nav.zoom==2 && nav.pan==CGPoint(x:-100,y:-50))
nav.move(dx:10000,dy:-10000,image:photo,viewport:viewport.size)
assert(nav.pan==CGPoint(x:400,y:-300))
nav.reset(); assert(nav.zoom==1 && nav.pan == .zero)
nav.move(dx:200,dy:100,image:photo,viewport:viewport.size); assert(nav.pan == .zero)
assert(scrollIntent(command:false,precise:true,momentum:false) == .pan)
assert(scrollIntent(command:false,precise:false,momentum:false) == .ignore)
assert(scrollIntent(command:true,precise:true,momentum:true) == .ignore)
assert(scrollIntent(command:true,precise:true,momentum:false) == .zoom)
assert(scrollIntent(command:true,precise:false,momentum:false) == .zoom)
let display=DisplayGeometry(id:1,frame:CGRect(x:0,y:0,width:2560,height:1440),scale:2)
let calibrated=CGRect(x:350,y:200,width:1800,height:1100)
assert(calibratedRegionIsUsable(calibrated,savedDisplay:display,current:[display]))
assert(!calibratedRegionIsUsable(calibrated,savedDisplay:display,current:[]))
// Returning after a transient empty screen list restores eligibility without changing saved data.
assert(calibratedRegionIsUsable(calibrated,savedDisplay:display,current:[display]))
let moved=DisplayGeometry(id:1,frame:CGRect(x:100,y:0,width:2560,height:1440),scale:2)
let scaled=DisplayGeometry(id:1,frame:display.frame,scale:1)
assert(!calibratedRegionIsUsable(calibrated,savedDisplay:display,current:[moved]))
assert(!calibratedRegionIsUsable(calibrated,savedDisplay:display,current:[scaled]))
assert(calibratedRegionIsUsable(calibrated,savedDisplay:display,current:[display,moved]))
let a=ExportSnapshot(raw:URL(fileURLWithPath:"/one/A.CR3"),bytes:fixture,orientation:nil)
let b=ExportSnapshot(raw:URL(fileURLWithPath:"/two/B.CR3"),bytes:plainFixture,orientation:6)
assert(a.destination.path=="/one/A_JpgFromRaw.jpg" && b.destination.path=="/two/B_JpgFromRaw.jpg")
print("PASS: pointer-anchored zoom, pan limits, Fit reset, scroll modifier/momentum policy, sleep/wake display eligibility, changed geometry rejection, independent export paths")

// Exercise shared view state and context-menu eligibility without showing any window.
let overlayView=ReferenceView(frame:viewport)
let floatView=ReferenceView(frame:viewport)
overlayView.image=NSImage(cgImage:fixtureImage,size:photo); floatView.image=overlayView.image
overlayView.exportSnapshot=a; floatView.exportSnapshot=b
let saveItem=NSMenuItem(title:"Save",action:#selector(ReferenceView.saveImage),keyEquivalent:"")
assert(overlayView.validateMenuItem(saveItem) && floatView.validateMenuItem(saveItem))
var savedPath:String?
overlayView.save={ savedPath=$0.destination.path }
overlayView.saveImage(); assert(savedPath==a.destination.path)
floatView.save={ savedPath=$0.destination.path }
floatView.saveImage(); assert(savedPath==b.destination.path)
overlayView.canSave={false}; assert(!overlayView.validateMenuItem(saveItem))
floatView.exportSnapshot=nil; assert(!floatView.validateMenuItem(saveItem))
overlayView.releaseContent(); assert(overlayView.image==nil && overlayView.exportSnapshot==nil && overlayView.save==nil)
assert(floatView.image != nil)
print("PASS: shared context menu eligibility, export uses each view's snapshot, standalone disables Save, closing releases one view without clearing the other")


let nameResult=try loadReference(raw:secondRaw,preferEmbedded:true,executable:successTool,cancellation:Cancellation())
assert(nameResult.sourceFilename==secondRaw.lastPathComponent)
let titleView=ReferenceView(frame:viewport)
titleView.image=NSImage(cgImage:fixtureImage,size:photo)
titleView.showToast("Saved example_JpgFromRaw.jpg",duration:0.02)
assert(titleView.toast != nil)
RunLoop.current.run(until:Date().addingTimeInterval(0.08))
assert(titleView.toast == nil)
titleView.showToast("Saved example_JpgFromRaw.jpg")
titleView.image=nil; assert(titleView.toast==nil)
print("PASS: embedded source filename and transient save-message expiry/reset")

let savedWindow=CGRect(x:0,y:20,width:1200,height:800)
let movedWindow=CGRect(x:40,y:60,width:1200,height:800)
let calibrationRect=CGRect(x:200,y:100,width:700,height:600)
assert(translatedCalibration(calibrationRect,from:savedWindow,to:movedWindow)==calibrationRect.offsetBy(dx:40,dy:40))
assert(translatedCalibration(calibrationRect,from:savedWindow,to:CGRect(x:0,y:20,width:1100,height:800))==nil)
print("PASS: calibration translates with window movement and rejects resized windows")
let regionSuite="CameraReferenceRegionTest-"+UUID().uuidString
let regionPrefs=UserDefaults(suiteName:regionSuite)!
for key in regionPreferenceKeys { regionPrefs.set("fixture",forKey:key) }
regionPrefs.set(true,forKey:"automaticBounds");regionPrefs.set(true,forKey:"preferEmbedded");regionPrefs.set(38,forKey:"key")
clearRegionPreferences(regionPrefs)
assert(regionPreferenceKeys.allSatisfy { regionPrefs.object(forKey:$0)==nil })
assert(regionPrefs.bool(forKey:"automaticBounds") && regionPrefs.bool(forKey:"preferEmbedded") && regionPrefs.integer(forKey:"key")==38)
regionPrefs.removePersistentDomain(forName:regionSuite)
print("PASS: clear all region preferences preserves shortcut, source and automatic toggle")

let labelViewport=CGRect(x:0,y:0,width:1000,height:800),labelSize=CGSize(width:90,height:12)
let portraitFrame=CGRect(x:250,y:0,width:500,height:800)
let sideLabel=referenceLabelRect(viewport:labelViewport,imageFrame:portraitFrame,labelSize:labelSize)
assert(sideLabel != nil && !sideLabel!.intersects(portraitFrame))
let wideFrame=CGRect(x:0,y:100,width:1000,height:600)
let topLabel=referenceLabelRect(viewport:labelViewport,imageFrame:wideFrame,labelSize:labelSize)
assert(topLabel != nil && !topLabel!.intersects(wideFrame))
assert(referenceLabelRect(viewport:labelViewport,imageFrame:labelViewport,labelSize:labelSize)==nil)
print("PASS: reference label fits top or side margins without overlapping image")

// Reported 0.9.1 native rounding regression. Capture stability stays stricter.
let requestedOverlay = CGRect(x:304.94375,y:265.64814,width:890.890625,height:570.87138)
let roundedOverlay = CGRect(x:304,y:265,width:891,height:571)
assert(overlayPlacementIsAcceptable(requested:requestedOverlay,actual:roundedOverlay))
assert(!sameWindowGeometry(requestedOverlay,roundedOverlay))
assert(overlayPlacementIsAcceptable(requested:requestedOverlay,actual:requestedOverlay))
assert(!overlayPlacementIsAcceptable(requested:requestedOverlay,actual:requestedOverlay.offsetBy(dx:2,dy:0)))
assert(!overlayPlacementIsAcceptable(requested:requestedOverlay,actual:requestedOverlay.offsetBy(dx:0,dy:20)))
assert(!overlayPlacementIsAcceptable(requested:requestedOverlay,actual:requestedOverlay.insetBy(dx:2,dy:0)))
assert(!overlayPlacementIsAcceptable(requested:.zero,actual:.zero))
let negativeOverlay = requestedOverlay.offsetBy(dx:-2000,dy:-1000)
assert(overlayPlacementIsAcceptable(requested:negativeOverlay,actual:roundedOverlay.offsetBy(dx:-2000,dy:-1000)))
print("PASS: overlay rounding accepted independently of capture stability; displaced/resized panels rejected")

// Manual UI selection uses the same top-left Fit geometry, then returns to AppKit.
let manualUI=CGRect(x:100,y:200,width:900,height:600)
let manualSettings=try! DetectionConfig.parse("left=photo\nright=ui\ntop=ui\nbottom=photo\nfitInsetPoints=20")
let manualTop=appKitRect(manualUI,primaryHeight:1000)
let manualPlacement=manualSettings.placement(ui:manualTop,image:CGSize(width:6000,height:4000))!
let manualRegion=appKitRect(manualPlacement.region,primaryHeight:1000)
let manualPhoto=appKitRect(manualPlacement.photo,primaryHeight:1000)
assert(manualRegion.maxY == manualUI.maxY && manualRegion.maxX == manualUI.maxX)
assert(manualRegion.minX == manualPhoto.minX && manualRegion.minY == manualPhoto.minY)
assert(manualUI.contains(manualPhoto))
print("PASS: manual UI calibration preserves asymmetric side semantics through screen-coordinate conversion")

let ram=SelectionImageCache()
let ramImage=bitmap.makeImage()!
let ramLoaded=LoadedReference(image:ramImage,origin:.embedded,elapsed:1,extraction:0.5,usedFallback:false,embeddedBytes:Data([1,2,3]))
ram.observe("session:1")
ram.insert(ramLoaded,key:"raw-A-settings-1",epoch:"session:1")
assert(ram.value(key:"raw-A-settings-1",epoch:"session:1")?.embeddedBytes == Data([1,2,3]))
assert(ram.value(key:"raw-A-settings-2",epoch:"session:1") == nil)
ram.observe("session:2")
assert(ram.value(key:"raw-A-settings-1",epoch:"session:1") == nil)
ram.insert(ramLoaded,key:"raw-A-settings-1",epoch:"session:1")
assert(ram.value(key:"raw-A-settings-1",epoch:"session:2") == nil)
ram.observe("session:3") // A -> B -> A must not recover A's old cache.
assert(ram.value(key:"raw-A-settings-1",epoch:"session:3") == nil)
ram.insert(ramLoaded,key:"raw-A-settings-1",epoch:"session:3")
ram.observe(nil)
assert(ram.value(key:"raw-A-settings-1",epoch:"session:3") == nil)
ram.observe("restart:1")
ram.insert(ramLoaded,key:"raw-A-settings-1",epoch:"restart:1")
ram.clear()
assert(ram.value(key:"raw-A-settings-1",epoch:"restart:1") == nil)
let signatureRaw=folder.appendingPathComponent("signature.CR3")
try Data([1]).write(to:signatureRaw)
let signature1=referenceFileSignature(raw:signatureRaw,preferEmbedded:true,executable:nil)!
assert(referenceFileSignature(raw:signatureRaw,preferEmbedded:false,executable:nil) != signature1)
try Data([1,2]).write(to:signatureRaw)
assert(referenceFileSignature(raw:signatureRaw,preferEmbedded:true,executable:nil) != signature1)
let signature2=referenceFileSignature(raw:signatureRaw,preferEmbedded:true,executable:nil)!
try Data([3]).write(to:folder.appendingPathComponent("signature.jpg"))
assert(referenceFileSignature(raw:signatureRaw,preferEmbedded:true,executable:nil) != signature2)
try FileManager.default.removeItem(at:signatureRaw)
assert(referenceFileSignature(raw:signatureRaw,preferEmbedded:true,executable:nil) == nil)
print("PASS: one-photo RAM reuse, selection/return/restart/stale invalidation, late-load rejection and source/preference revalidation")

let layoutDefaultsName="CameraReference.LayoutTests."+UUID().uuidString
let layoutDefaults=UserDefaults(suiteName:layoutDefaultsName)!
for mode in OverlayLayout.allCases {
    layoutDefaults.set("saved-"+mode.rawValue,forKey:regionPreferenceKey("region",layout:mode))
    layoutDefaults.set(mode != .left,forKey:regionPreferenceKey("automaticBounds",layout:mode))
}
clearRegionPreferences(layoutDefaults,layout:.left)
assert(layoutDefaults.string(forKey:regionPreferenceKey("region",layout:.left))==nil)
assert(!layoutDefaults.bool(forKey:regionPreferenceKey("automaticBounds",layout:.left)))
clearRegionPreferences(layoutDefaults,layout:.right)
assert(layoutDefaults.bool(forKey:regionPreferenceKey("automaticBounds",layout:.right)))
for mode:OverlayLayout in [.full,.upper,.lower] {
    assert(layoutDefaults.string(forKey:regionPreferenceKey("region",layout:mode))=="saved-"+mode.rawValue)
}
assert(regionPreferenceKey("region",layout:.full)=="region")
layoutDefaults.removePersistentDomain(forName:layoutDefaultsName)
print("PASS: pane calibration isolation; clearing preserves each auto/manual preference and Full legacy keys")

let hostFrame=CGRect(x:100,y:100,width:1200,height:800)
let partialOffscreen=hostFrame.offsetBy(dx:-500,dy:0)
assert(overlayHostAction(saved:hostFrame,current:partialOffscreen,onScreen:true,overview:false) == .translate(CGPoint(x:-500,y:0)))
assert(overlayHostAction(saved:hostFrame,current:hostFrame,onScreen:true,overview:true) == .suspend)
assert(overlayHostAction(saved:hostFrame,current:hostFrame,onScreen:false,overview:false) == .suspend)
assert(overlayHostAction(saved:hostFrame,current:nil,onScreen:false,overview:false) == .retain)
assert(overlayHostAction(saved:hostFrame,current:nil,onScreen:false,overview:true) == .suspend)
assert(overlayHostAction(saved:hostFrame,current:hostFrame.insetBy(dx:5,dy:0),onScreen:true,overview:false) == .translate(CGPoint(x:5,y:0)))
assert(overlayHostAction(saved:hostFrame,current:hostFrame,onScreen:true,overview:false) == .translate(.zero))
print("PASS: overlay movement permits off-screen clipping; overview/off-Space suspends; resize retains; metadata uncertainty retains; host restores")

let support=folder.appendingPathComponent("support")
let legacy=support.appendingPathComponent("Camera Reference")
let canonical=support.appendingPathComponent("CameraReference")
try FileManager.default.createDirectory(at:legacy.appendingPathComponent("Bridge"),withIntermediateDirectories:true)
try "preserve me".write(to:legacy.appendingPathComponent("unknown.txt"),atomically:true,encoding:.utf8)
try "top=ui\nsideSearchPercent=30\n".write(to:legacy.appendingPathComponent("config.conf"),atomically:true,encoding:.utf8)
let legacyHeartbeat=legacy.appendingPathComponent("Bridge/heartbeat.txt")
try "old heartbeat".write(to:legacyHeartbeat,atomically:true,encoding:.utf8)
let deferredMigration=try consolidateSupportDirectory(applicationSupport:support)
assert(!deferredMigration && FileManager.default.fileExists(atPath:legacy.path))
let copiedSettings=try String(contentsOf:canonical.appendingPathComponent("config.conf"),encoding:.utf8)
assert(copiedSettings.contains("sideSearchPercent=30"))
try FileManager.default.setAttributes([.modificationDate:Date(timeIntervalSinceNow:-20)],ofItemAtPath:legacyHeartbeat.path)
try "canonical preference".write(to:canonical.appendingPathComponent("unknown.txt"),atomically:true,encoding:.utf8)
let completedMigration=try consolidateSupportDirectory(applicationSupport:support)
assert(completedMigration && !FileManager.default.fileExists(atPath:legacy.path))
let retainedFile=try String(contentsOf:canonical.appendingPathComponent("unknown.txt"),encoding:.utf8)
assert(retainedFile=="canonical preference")
let conflicts=try FileManager.default.contentsOfDirectory(at:canonical,includingPropertiesForKeys:nil).filter{$0.lastPathComponent.hasPrefix("unknown.txt.migrated-")}
assert(conflicts.count==1)
let preserved=try String(contentsOf:conflicts[0],encoding:.utf8);assert(preserved=="preserve me")
assert(!FileManager.default.fileExists(atPath:canonical.appendingPathComponent("Bridge/heartbeat.txt").path))
let repeatedMigration=try consolidateSupportDirectory(applicationSupport:support);assert(repeatedMigration)
// Original pre-alpha IPC lived directly under the unspaced folder.
try "stale".write(to:canonical.appendingPathComponent("response.txt"),atomically:true,encoding:.utf8)
let originalMigration=try consolidateSupportDirectory(applicationSupport:support);assert(originalMigration)
assert(!FileManager.default.fileExists(atPath:canonical.appendingPathComponent("response.txt").path))
print("PASS: unified support migration preserves settings/conflicts, waits for old bridge, removes empty old folder and never replays IPC")

assert(!dockOverviewEvidence(dockIsFrontmost:false,coverage:1)) // Permanent full-screen Dock surface.
assert(!dockOverviewEvidence(dockIsFrontmost:true,coverage:0.1))
assert(dockOverviewEvidence(dockIsFrontmost:true,coverage:1))
print("PASS: full-screen Dock window alone cannot suspend an ordinary overlay")

let hostMetadata=LightroomWindowMetadata(id:4,frame:hostFrame,layer:0,hasTitle:true)
let newDialog=LightroomWindowMetadata(id:7,frame:CGRect(x:200,y:200,width:400,height:250),layer:0,hasTitle:true)
let redraw=LightroomWindowMetadata(id:8,frame:hostFrame,layer:0,hasTitle:false)
assert(hasNewLightroomDialog(windows:[newDialog,hostMetadata],host:4,baseline:[4]))
assert(!hasNewLightroomDialog(windows:[newDialog,hostMetadata],host:4,baseline:[4,7]))
assert(!hasNewLightroomDialog(windows:[redraw,hostMetadata],host:4,baseline:[4]))
assert(!hasNewLightroomDialog(windows:[hostMetadata,newDialog],host:4,baseline:[4]))
assert(!hasNewLightroomDialog(windows:[newDialog],host:4,baseline:[4]))
assert(hostIsPresentationThumbnail(CGRect(x:0,y:0,width:160,height:90)))
assert(!hostIsPresentationThumbnail(hostFrame))
assert(!hostIsPresentationThumbnail(partialOffscreen))
print("PASS: new dialog fallback excludes existing panes/untitled redraws; thumbnail geometry is distinct from normal/off-screen host")

// Synthetic ARW candidates exercise selection independently of real camera data.
let arw=folder.appendingPathComponent("sony.ARW")
try Data("synthetic Sony RAW".utf8).write(to:arw)
let arwBefore=try Data(contentsOf:arw)
let arwDate=try FileManager.default.attributesOfItem(atPath:arw.path)[.modificationDate] as! Date
let largeBitmap=CGContext(data:nil,width:128,height:64,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
largeBitmap.draw(fixtureImage,in:CGRect(x:0,y:0,width:128,height:64))
let largeData=NSMutableData()
let largeEncoder=CGImageDestinationCreateWithData(largeData,"public.jpeg" as CFString,1,nil)!
CGImageDestinationAddImage(largeEncoder,largeBitmap.makeImage()!,nil)
assert(CGImageDestinationFinalize(largeEncoder))
let largeJPEG=largeData as Data
let arwTool=try script("arw-tool","if '-Orientation' in sys.argv:\n sys.stdout.write('6\\n')\nelif '-PreviewImage' in sys.argv:\n sys.stdout.buffer.write(base64.b64decode('\(largeJPEG.base64EncodedString())'))\nelse:\n sys.stdout.buffer.write(base64.b64decode('\(fixture.base64EncodedString())'))\n")
let arwLoaded=try loadReference(raw:arw,preferEmbedded:true,executable:arwTool,cancellation:Cancellation())
assert(arwLoaded.origin == .embedded && arwLoaded.image.width==64 && arwLoaded.image.height==128)
assert(arwLoaded.embeddedBytes==largeJPEG && arwLoaded.stages.contains("PreviewImage"))
let arwExport=try exportJPEG(arwLoaded.embeddedBytes!,orientation:arwLoaded.cameraOrientation)
let arwExportImage=try decodeJPEG(CGImageSourceCreateWithData(arwExport as CFData,nil))
assert(arwExportImage.width==64 && arwExportImage.height==128)
let arwCache=SelectionImageCache();arwCache.observe("sony-selection")
arwCache.insert(arwLoaded,key:"sony",epoch:"sony-selection")
assert(arwCache.value(key:"sony",epoch:"sony-selection")?.embeddedBytes==largeJPEG)
let arwJfrTool=try script("arw-jfr","if '-Orientation' in sys.argv:\n sys.stdout.write('1\\n')\nelif '-JpgFromRaw' in sys.argv:\n sys.stdout.buffer.write(base64.b64decode('\(largeJPEG.base64EncodedString())'))\nelse:\n sys.stdout.buffer.write(base64.b64decode('\(fixture.base64EncodedString())'))\n")
let arwLargest=try extractEmbeddedJPEG(raw:arw,executable:arwJfrTool,cancellation:Cancellation())
assert(arwLargest.tag=="JpgFromRaw" && arwLargest.bytes==largeJPEG)
let arwFallbackTool=try script("arw-fallback","if '-JpgFromRaw' in sys.argv:\n sys.stdout.buffer.write(b'invalid')\nelse:\n sys.stdout.buffer.write(base64.b64decode('\(fixture.base64EncodedString())'))\n")
let arwFallback=try extractEmbeddedJPEG(raw:arw,executable:arwFallbackTool,cancellation:Cancellation())
assert(arwFallback.tag=="PreviewImage" && arwFallback.bytes==fixture)
expectFailure { _ = try extractJPEG(raw:arw,executable:badTool,cancellation:Cancellation()) }
let arwCancel=Cancellation();arwCancel.cancel()
expectFailure { _ = try extractJPEG(raw:arw,executable:arwTool,cancellation:arwCancel) }
let arwAfter=try Data(contentsOf:arw)
let arwAfterDate=try FileManager.default.attributesOfItem(atPath:arw.path)[.modificationDate] as! Date
assert(arwAfter==arwBefore && arwAfterDate==arwDate)
print("PASS: ARW largest valid tag, invalid fallback, orientation/export, RAM reuse, cancellation and unchanged RAW")

// Separate Fit geometry from the zoom/pan boundary, including asymmetric margins.
let zoomRegion=CGRect(x:0,y:0,width:1000,height:700)
for size in [CGSize(width:6000,height:4000),CGSize(width:4000,height:6000)] {
    let fitBox=CGRect(x:150,y:80,width:700,height:500)
    let fitSize=fittedSize(image:size,inside:fitBox.size)
    var n=ImageNavigation()
    n.clamp(image:size,fitRect:fitBox,viewport:zoomRegion)
    assert(n.pan == .zero && n.zoom==1)
    n.zoom=5
    let point=CGPoint(x:fitBox.midX+10,y:fitBox.midY+10)
    let before=CGPoint(x:(point.x-fitBox.midX-n.pan.x)/n.zoom,y:(point.y-fitBox.midY-n.pan.y)/n.zoom)
    n.magnify(factor:1.2,at:point,image:size,viewport:zoomRegion,fitRect:fitBox)
    let after=CGPoint(x:(point.x-fitBox.midX-n.pan.x)/n.zoom,y:(point.y-fitBox.midY-n.pan.y)/n.zoom)
    assert(abs(before.x-after.x)<0.001 && abs(before.y-after.y)<0.001)
    n.move(dx:100000,dy:-100000,image:size,fitRect:fitBox,viewport:zoomRegion)
    let frame=CGRect(x:fitBox.midX-fitSize.width*n.zoom/2+n.pan.x,y:fitBox.midY-fitSize.height*n.zoom/2+n.pan.y,width:fitSize.width*n.zoom,height:fitSize.height*n.zoom)
    assert(abs(frame.minX-zoomRegion.minX)<0.001 && abs(frame.maxY-zoomRegion.maxY)<0.001)
    n.reset();assert(n.zoom==1 && n.pan == .zero)
}
print("PASS: larger-region panning, pointer-centred zoom and exact Fit reset for portrait/landscape")

assert(hostMinimizedState(polled:false,notified:true,notificationAge:0.1) == true)
assert(hostMinimizedState(polled:false,notified:true,notificationAge:1) == false)
assert(hostMinimizedState(polled:true,notified:false,notificationAge:1) == true)
assert(hostMinimizedState(polled:nil,notified:true,notificationAge:1) == true)
assert(hostMinimizedState(polled:nil,notified:nil,notificationAge:1) == nil)
print("PASS: minimise notification bridges attribute lag; polling recovers a missed restore without treating uncertainty as minimisation")

let hostMatch=CGRect(x:-122,y:30,width:2560,height:1349)
assert(uniqueHostFrameMatch([nil,hostMatch.offsetBy(dx:0.5,dy:-0.5)],target:hostMatch)==1)
assert(uniqueHostFrameMatch([hostMatch,hostMatch],target:hostMatch)==nil)
assert(uniqueHostFrameMatch([hostMatch.offsetBy(dx:10,dy:0)],target:hostMatch)==nil)
assert(accessibilityStatus(.notificationUnsupported).contains("notification unsupported"))
assert(accessibilityStatus(.cannotComplete).contains("timeout"))
print("PASS: AX binding rejects ambiguous/wrong windows, handles unreadable frames and reports notification/timeout causes")

var settling=OverlayGeometrySettler()
let stableHost=CGRect(x:100,y:100,width:1200,height:800)
let movedHost=stableHost.offsetBy(dx:30,dy:20)
assert(settling.accepts(movedHost,saved:stableHost,restoring:false,now:0))
let animationFrame=CGRect(x:130,y:60,width:1000,height:650)
assert(!settling.accepts(animationFrame,saved:stableHost,restoring:false,now:1))
assert(!settling.accepts(stableHost,saved:stableHost,restoring:true,now:1.1))
assert(!settling.accepts(stableHost,saved:stableHost,restoring:true,now:1.2))
assert(settling.accepts(stableHost,saved:stableHost,restoring:true,now:1.5))
settling.reset()
assert(!settling.accepts(animationFrame,saved:stableHost,restoring:false,now:2))
assert(settling.accepts(animationFrame,saved:stableHost,restoring:false,now:2.4))
print("PASS: ordinary moves follow immediately; resize/restore geometry waits for stable samples without accumulating animation deltas")
let diagnostic=diagnosticReport([DiagnosticSection(title:"Performance",body:"123 ms"),DiagnosticSection(title:"Placement",body:"Full")])
assert(diagnostic.components(separatedBy:"123 ms").count==2)
assert(diagnostic.contains("PERFORMANCE") && diagnostic.contains("PLACEMENT"))
print("PASS: sectioned diagnostic report retains headings and emits performance once")

assert(supportedLightroomModule("library") && supportedLightroomModule("develop"))
for module in ["map","book","print","slideshow","web",""] { assert(!supportedLightroomModule(module)) }
assert(!supportedLightroomModule(nil))
assert(confirmedModuleChange(previous:"library",current:"develop"))
assert(confirmedModuleChange(previous:"develop",current:"map"))
assert(!confirmedModuleChange(previous:"develop",current:nil))
assert(!confirmedModuleChange(previous:"library",current:"library"))
var manyFrames:[CGRect?]=(0..<24).map { CGRect(x:CGFloat($0)*10,y:0,width:50,height:20) }
manyFrames[23]=hostMatch
assert(uniqueHostFrameMatch(manyFrames,target:hostMatch)==23)
print("PASS: Library/Develop allowlist, confirmed transitions versus heartbeat uncertainty, host beyond first 16 frames")

let modulePrefs=UserDefaults(suiteName:"CameraReference.ModuleTests.\(UUID().uuidString)")!
modulePrefs.set("develop-region",forKey:"region")
modulePrefs.set("library-region",forKey:"library.region")
modulePrefs.set(false,forKey:"library.automaticBounds")
clearRegionPreferences(modulePrefs,modulePrefix:"library.")
assert(modulePrefs.string(forKey:"region")=="develop-region")
assert(modulePrefs.object(forKey:"library.region")==nil)
assert(modulePrefs.object(forKey:"library.automaticBounds") as? Bool == false)
modulePrefs.removeObject(forKey:"region");modulePrefs.removeObject(forKey:"library.automaticBounds")
print("PASS: Library region clearing preserves Develop region and automatic preference")

let moduleLayoutDefaults=UserDefaults(suiteName:"CameraReference-tests-layout-"+UUID().uuidString)!
// Use enum values to keep the test about module storage, not raw spelling.
let splitMode=OverlayLayout.allCases.first(where:{$0 != .full})!
moduleLayoutDefaults.set(splitMode.rawValue,forKey:overlayLayoutPreferenceKey(module:"develop"))
assert(savedOverlayLayout(moduleLayoutDefaults,module:"library") == .full)
assert(savedOverlayLayout(moduleLayoutDefaults,module:"develop") == splitMode)
moduleLayoutDefaults.set(OverlayLayout.allCases.last!.rawValue,forKey:overlayLayoutPreferenceKey(module:"library"))
assert(savedOverlayLayout(moduleLayoutDefaults,module:"develop") == splitMode)
assert(savedOverlayLayout(moduleLayoutDefaults,module:"library") == OverlayLayout.allCases.last!)
moduleLayoutDefaults.removeObject(forKey:"overlayLayout");moduleLayoutDefaults.removeObject(forKey:"library.overlayLayout")
let logicalHost=CGRect(x:-132,y:101,width:2560,height:1349)
assert(!hostPresentationIsShrinking(reported:logicalHost.offsetBy(dx:-400,dy:40),logical:logicalHost,saved:logicalHost))
let animatedHost=CGRect(x:100,y:300,width:2304,height:1214.1)
assert(hostPresentationIsShrinking(reported:animatedHost,logical:logicalHost,saved:logicalHost))
assert(!hostPresentationIsShrinking(reported:animatedHost,logical:animatedHost,saved:logicalHost))
assert(!hostPresentationIsShrinking(reported:CGRect(x:0,y:101,width:2428,height:1349),logical:logicalHost,saved:logicalHost))
assert(!hostPresentationIsShrinking(reported:.zero,logical:logicalHost,saved:logicalHost))
print("PASS: independent module layout preferences; animation evidence excludes movement, clipping and matching logical resize")

let mappingRows=(1...40).map { AXMappingRow(index:$0,frame:$0==40 ? nil:CGRect(x:-150.25,y:26.5,width:324,height:1116),details:$0==40 ? "not read: budget":"role=AXWindow; AXVisible=unavailable") }
let mappingText=formatAXMappingRows(mappingRows)
assert(mappingText.components(separatedBy:"\n").count==40)
assert(mappingText.contains("W40: rect=unavailable; not read: budget"))
assert(mappingText.contains("W2: rect=(-150.250, 26.500, 324.000, 1116.000)"))
assert(mappingText.contains("same rectangle as W1"))
assert(mappingRect(CGRect(x:2560,y:-300,width:1512,height:982))=="(2560.000, -300.000, 1512.000, 982.000)")
print("PASS: AX map retains all rows, duplicates, unknown state, subpoint and negative/multidisplay geometry")

// AX trial uses panel/label evidence only; no production detector dependency.
let trialHost=CGRect(x:0,y:30,width:2560,height:1349)
func tw(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ visible:Bool=true)->AXTrialWindow { AXTrialWindow(frame:CGRect(x:x,y:y,width:w,height:h),visible:visible) }
let trialPanels=[tw(0,62,2560,70),tw(0,1228,2560,151),tw(0,122,324,1116),tw(2225,122,335,1116)]
let trialSingle=axTrialProposal(host:trialHost,windows:trialPanels)!
assert(trialSingle.layout=="Single view" && trialSingle.panes==[CGRect(x:307,y:121,width:1935,height:1075)])
// Reported Library minimum-window cases: 324 pt panels exceed the old 30% cap.
for (x,width) in [(1513.0,1047.0),(1660.0,900.0)] {
    let host=CGRect(x:x,y:677,width:width,height:702)
    let strips=[tw(x,709,width,70),tw(x,1228,width,151)]
    let left=tw(x,769,324,469),right=tw(2236,769,324,469)
    // Full-width tall content and short edge controls must not become side panels.
    let distractions=[tw(x,779,width,400),tw(x,800,60,25),tw(2225,122,335,1116,false)]
    let both=axTrialProposal(host:host,windows:strips+[left,right]+distractions,module:"library")!
    assert(both.panes[0]==CGRect(x:x+307,y:768,width:2253-(x+307),height:428))
    assert(both.summary.contains("Panel evidence L/R/T/B: true/true/true/true"))
    let noLeft=axTrialProposal(host:host,windows:strips+[tw(x,769,324,469,false),right]+distractions)!
    assert(noLeft.panes[0].minX==x+17 && noLeft.panes[0].maxX==2253)
    let noRight=axTrialProposal(host:host,windows:strips+[left,tw(2236,769,324,469,false)]+distractions)!
    assert(noRight.panes[0].minX==x+307 && noRight.panes[0].maxX==host.maxX-17)
}
print("PASS: 1047/900 pt AX windows retain wide side panels; hidden sides and full-width/short distractors remain excluded")
let trialSide=axTrialProposal(host:trialHost,windows:trialPanels+[tw(1190,122,83,25),tw(1276,122,113,25)])!
assert(trialSide.layout=="Side-by-side" && trialSide.panes.count==2)
assert(trialSide.panes[0].maxX==1274.5 && trialSide.panes[1].minX==1274.5)
let trialStack=axTrialProposal(host:trialHost,windows:trialPanels+[tw(2128,632,113,25),tw(2128,660,113,25)])!
assert(trialStack.layout=="Above-and-below" && (657...660).contains(trialStack.panes[0].maxY))
assert(axTrialProposal(host:trialHost,windows:trialPanels+[tw(1190,122,83,25,false),tw(1276,122,113,25,false)])!.layout=="Single view")
let hiddenLeft=axTrialProposal(host:trialHost,windows:Array(trialPanels.prefix(2))+[tw(0,122,324,1116,false),trialPanels[3]])!
assert(hiddenLeft.panes[0].minX==17)
let trialMovedHost=CGRect(x:587,y:47,width:1950,height:1253)
let trialMoved=axTrialProposal(host:trialMovedHost,windows:[tw(587,79,1950,70),tw(587,1149,1950,151),tw(587,139,324,1020),tw(2202,139,335,1020),tw(1472,139,83,25),tw(1558,139,113,25)])!
assert(trialMoved.layout=="Side-by-side" && trialMoved.panes[0].maxX==1556.5)
print("PASS: diagnostic AX raw bounds, both splits, invisible labels/panels, resized translated host; no information windows")

assert(axTrialHostMatches(proposedTopLeft:CGRect(x:0,y:30,width:2560,height:1349),actualAppKit:CGRect(x:0,y:61,width:2560,height:1349),primaryHeight:1440))
assert(!axTrialHostMatches(proposedTopLeft:CGRect(x:0,y:30,width:2560,height:1349),actualAppKit:CGRect(x:0,y:30,width:2560,height:1349),primaryHeight:1440))
assert(axTrialHostMatches(proposedTopLeft:CGRect(x:-1080,y:-480,width:1000,height:1200),actualAppKit:CGRect(x:-1080,y:720,width:1000,height:1200),primaryHeight:1440))
print("PASS: AX trial host matching converts top-left to AppKit, including negative display origins")

// Accepted geometry defaults and append-only plain config generation.
let axDefaults=try DetectionConfig.parse(DetectionConfig.template)
assert(axDefaults.axShownLeftOffsetPoints == -17 && axDefaults.toolbarUnknownFallback == "shown")
let axFine=try DetectionConfig.parse("axShownLeftOffsetPoints=-17\naxShownRightOffsetPoints=17\naxShownTopOffsetPoints=11")
assert(axFine.key==DetectionConfig().key)
let fineProposal=axTrialProposal(host:trialHost,windows:trialPanels,settings:axFine)!
assert(fineProposal.panes[0].minX==307 && fineProposal.panes[0].minY==121)
assert(fineProposal.panes[0].maxY==1196 && fineProposal.panes[0].maxX==2242)
var axHidden=axFine;axHidden.axToolbarState="hidden"
assert(axTrialProposal(host:trialHost,windows:trialPanels,settings:axHidden)!.panes[0].maxY==1239)
assert((try? DetectionConfig.parse("axShownLeftOffsetPoints=nan")) == nil)
assert((try? DetectionConfig.parse("toolbarUnknownFallback=maybe")) == nil)
let history=AXToolbarHistory()
assert(history.resolve(shown:nil,fallback:"lastKnown",context:"1:library").shown)
assert(!history.resolve(shown:false,fallback:"shown",context:"1:library").shown)
assert(!history.resolve(shown:nil,fallback:"lastKnown",context:"1:library").shown)
assert(history.resolve(shown:nil,fallback:"lastKnown",context:"1:develop").shown)
assert(history.resolve(shown:nil,fallback:"lastKnown",context:"2:library").shown)
assert(history.resolve(shown:nil,fallback:"shown",context:"1:library").shown)
assert(!history.resolve(shown:nil,fallback:"hidden",context:"1:develop").shown)
assert(history.resolve(shown:true,fallback:"hidden",context:"1:develop").shown)
let axConfigDir=FileManager.default.temporaryDirectory.appendingPathComponent("ax-config-\(UUID().uuidString)")
try FileManager.default.createDirectory(at:axConfigDir,withIntermediateDirectories:true)
let axConfigURL=axConfigDir.appendingPathComponent("config.conf")
try "left=photo\nsideSearchPercent=30\naxShownLeftOffsetPoints=-9\n".write(to:axConfigURL,atomically:true,encoding:.utf8)
let axStore=DetectionConfigStore(url:axConfigURL)
try axStore.ensureFile()
let axMigrated=try String(contentsOf:axConfigURL,encoding:.utf8)
assert(axMigrated.contains("left=photo") && axMigrated.contains("sideSearchPercent=30"))
let loadedAX=try axStore.reload()
assert(loadedAX.axShownLeftOffsetPoints == -9)
try axStore.ensureFile()
let repeatedAX=try String(contentsOf:axConfigURL,encoding:.utf8)
assert(repeatedAX==axMigrated)
let oldReadable=axMigrated.components(separatedBy:.newlines).filter { !$0.trimmingCharacters(in:.whitespaces).hasPrefix("#") }.joined(separator:"\n")
let oldConfig=try DetectionConfig.parse(oldReadable)
assert(oldConfig.left == .photo)
try FileManager.default.removeItem(at:axConfigDir)
print("AX fine-adjustment and shared-config checks passed")

// Toolbar command titles are visibility evidence, never geometry or checkboxes.
assert(axToolbarTitleState("Hide Toolbar") == true)
assert(axToolbarTitleState("Show Toolbar") == false)
assert(axToolbarTitleState("Toolbar") == nil)
assert(AXToolbarReading(shown:nil,report:"failed").effectiveState == "shown")
assert(AXToolbarReading(shown:false,report:"fresh").effectiveState == "hidden")

// Calibrated state-dependent AX edges; signs right/up positive; all values in points.
let v2=try DetectionConfig.parse(DetectionConfig.template)
assert(v2.axShownLeftOffsetPoints == -17 && v2.axToolbarHeightPoints == 43)
let noSides=axTrialProposal(host:trialHost,windows:Array(trialPanels.prefix(2)),settings:v2)!
assert(noSides.panes[0]==CGRect(x:17,y:121,width:2526,height:1075))
let noTop=axTrialProposal(host:trialHost,windows:Array(trialPanels.dropFirst()),settings:v2)!
assert(noTop.panes[0].minY==79)
let noBottom=axTrialProposal(host:trialHost,windows:[trialPanels[0],trialPanels[2],trialPanels[3]],settings:v2)!
assert(noBottom.panes[0].maxY==1319)
var hiddenToolbar=v2;hiddenToolbar.axToolbarState="hidden"
let allHidden=axTrialProposal(host:trialHost,windows:[],settings:hiddenToolbar)!
assert(allHidden.panes[0]==CGRect(x:17,y:79,width:2526,height:1283))
assert(DetectionConfig().axLibraryBottomOffsetPoints == 25)
assert(v2.axLibraryBottomOffsetPoints == 25)
let lib=v2
assert(axTrialProposal(host:trialHost,windows:trialPanels,settings:lib,module:"library")!.panes[0].maxY==1196)
assert(axTrialProposal(host:trialHost,windows:trialPanels,settings:lib,module:"develop")!.panes[0].maxY==1196)
for labels in [[tw(1190,122,83,25),tw(1276,122,113,25)], [tw(2128,632,113,25),tw(2128,660,113,25)]] {
    let library=axTrialProposal(host:trialHost,windows:trialPanels+labels,settings:lib,module:"library")!
    let develop=axTrialProposal(host:trialHost,windows:trialPanels+labels,settings:lib,module:"develop")!
    assert(library.panes.count == 2 && develop.panes.count == 2)
    assert(library.panes.last!.maxY == develop.panes.last!.maxY-25)
}
let custom=try DetectionConfig.parse("axShownTopOffsetPoints=20\naxShownLeftOffsetPoints=-10")
assert(axTrialProposal(host:trialHost,windows:trialPanels,settings:custom)!.panes[0].minY==112)
assert(axTrialProposal(host:trialHost,windows:trialPanels,settings:custom)!.panes[0].minX==314)
assert(custom.key==v2.key) // Screenshot placement/cache settings unaffected.
assert(placementBackend(automatic:false,axOnly:true) == .manual)
assert(placementBackend(automatic:false,axOnly:false) == .manual)
assert(placementBackend(automatic:true,axOnly:false) == .screenshot)
assert(placementBackend(automatic:true,axOnly:true) == .accessibility)
assert(axSelectedArea(trialSide,layout:.left)==trialSide.panes[0])
assert(axSelectedArea(trialSide,layout:.right)==trialSide.panes[1])
assert(axSelectedArea(trialSide,layout:.full)==trialSingle.panes[0])
assert(axSelectedArea(trialSide,layout:.upper)==nil)
assert(axSelectedArea(trialStack,layout:.lower)==trialStack.panes[1])
assert(axSelectedArea(trialSingle,layout:.right)==nil)
print("PASS: AX signed shown/hidden offsets, cumulative bottom, Library allowance, backend precedence and pane selection")

assert(axGridMenuSelection([("Grid","✓")]) == true)
assert(axGridMenuSelection([("Grid","")]) == false)
assert(axGridMenuSelection([("Grid",nil)]) == nil)
assert(axGridMenuSelection([("Loupe","✓")]) == nil)
assert(axGridMenuSelection([("Grid","✓"),("Grid","")]) == nil)
assert(axGridMenuSelection([("Grid View","•")]) == true)
print("PASS: Grid requires unique explicit menu mark; missing, ambiguous and availability-only evidence remain unknown")
