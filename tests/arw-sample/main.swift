import AppKit
import ImageIO
import CryptoKit
let raw=URL(fileURLWithPath:CommandLine.arguments[1])
let before=try Data(contentsOf:raw)
let beforeDate=try FileManager.default.attributesOfItem(atPath:raw.path)[.modificationDate] as! Date
guard let tool=findExifTool() else { fatalError("ExifTool unavailable") }
let reference=try loadReference(raw:raw,preferEmbedded:true,executable:tool,cancellation:Cancellation())
assert(reference.origin == .embedded)
let exported=try exportJPEG(reference.embeddedBytes!,orientation:reference.cameraOrientation)
let decoded=try decodeJPEG(CGImageSourceCreateWithData(exported as CFData,nil))
assert(decoded.width==reference.image.width && decoded.height==reference.image.height)
let cache=SelectionImageCache();cache.observe("sample")
cache.insert(reference,key:"sample",epoch:"sample")
assert(cache.value(key:"sample",epoch:"sample")?.embeddedBytes==reference.embeddedBytes)
let after=try Data(contentsOf:raw)
let afterDate=try FileManager.default.attributesOfItem(atPath:raw.path)[.modificationDate] as! Date
assert(SHA256.hash(data:before)==SHA256.hash(data:after) && beforeDate==afterDate)
print("PASS: real ARW read-only extraction, orientation/export round-trip and RAM reuse")
print("Decoded \(decoded.width) × \(decoded.height); embedded bytes \(reference.embeddedBytes!.count); \(reference.stages)")
