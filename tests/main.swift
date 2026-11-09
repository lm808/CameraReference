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
