import Foundation
import ImageIO
import CoreImage
import Darwin

enum ImageOrigin: String { case standalone = "Standalone JPEG", embedded = "Embedded JPEG" }
struct LoadedReference {
    let image: CGImage
    let origin: ImageOrigin
    let elapsed: TimeInterval
    let extraction: TimeInterval?
    let usedFallback: Bool
    var embeddedBytes: Data? = nil
    var cameraOrientation: UInt32? = nil
    var sourceFilename: String = ""
    var stages: String = ""
}

// A cancellation flag is shared with the worker. No photo bytes or paths are retained here.
final class Cancellation {
    private let lock = NSLock()
    private var value = false
    private var terminate: (() -> Void)?
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return value }
    func cancel() {
        lock.lock(); value = true; let action = terminate; lock.unlock(); action?()
    }
    func setTermination(_ action: (() -> Void)?) {
        lock.lock(); terminate = action; let cancelled = value; lock.unlock()
        if cancelled { action?() }
    }
    func check() throws { if isCancelled { throw ReferenceError.message("Cancelled.") } }
}

func findExifTool(custom: String? = nil) -> URL? {
    let paths = [custom, "/opt/homebrew/bin/exiftool", "/usr/local/bin/exiftool", "/usr/bin/exiftool"].compactMap { $0 }
    return paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map(URL.init(fileURLWithPath:))
}

// Both pipes are drained concurrently. This prevents a full stderr pipe blocking stdout.
// Only stdout is retained; stderr can contain private file paths, so it is discarded.
private final class BinaryBuffer {
    private let lock = NSLock()
    private var bytes = Data()
    private var tooLarge = false
    func append(_ chunk: Data, limit: Int) {
        lock.lock(); defer { lock.unlock() }
        if bytes.count + chunk.count <= limit && !tooLarge { bytes.append(chunk) }
        else { tooLarge = true; bytes.removeAll(keepingCapacity: false) }
    }
    var exceeded: Bool { lock.lock(); defer { lock.unlock() }; return tooLarge }
    func take() -> Data { lock.lock(); defer { lock.unlock() }; let result = bytes; bytes = Data(); return result }
}

func runExifTool(raw: URL, executable: URL, cancellation: Cancellation, arguments: [String],
                 timeout: TimeInterval = 12, byteLimit: Int = 128 * 1024 * 1024) throws -> Data {
    try cancellation.check()
    let process = Process()
    process.executableURL = executable
    // Disable user ExifTool configuration; pass arguments directly, with no shell or output file.
    process.arguments = ["-config", ""] + arguments + ["--", raw.path]
    process.standardInput = FileHandle.nullDevice
    let output = Pipe(), errors = Pipe()
    process.standardOutput = output; process.standardError = errors
    let exited = DispatchSemaphore(value: 0)
    process.terminationHandler = { _ in exited.signal() }
    do { try process.run() } catch { throw ReferenceError.message("ExifTool could not start.") }
    cancellation.setTermination { [weak process] in
        if let process, process.isRunning { process.terminate() }
    }
    defer { cancellation.setTermination(nil) }
    // Parent must not hold the writing ends open, otherwise reading EOF could stall.
    try? output.fileHandleForWriting.close(); try? errors.fileHandleForWriting.close()
    let buffer = BinaryBuffer(), readers = DispatchGroup()
    let stopReaders = Cancellation()
    for (handle, keep) in [(output.fileHandleForReading, true), (errors.fileHandleForReading, false)] {
        readers.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            defer { try? handle.close(); readers.leave() }
            while !stopReaders.isCancelled {
                var descriptor = pollfd(fd: handle.fileDescriptor, events: Int16(POLLIN | POLLHUP), revents: 0)
                let ready = poll(&descriptor, 1, 100)
                if ready < 0 { break }
                if ready == 0 { continue }
                guard let data = try? handle.read(upToCount: 64 * 1024), !data.isEmpty else { break }
                if keep { buffer.append(data, limit: byteLimit) }
            }
        }
    }
    let deadline = ProcessInfo.processInfo.systemUptime + timeout
    var aborted = false
    while exited.wait(timeout: .now() + 0.025) == .timedOut {
        if cancellation.isCancelled || buffer.exceeded || ProcessInfo.processInfo.systemUptime >= deadline {
            aborted = true
            if process.isRunning { process.terminate() }
            if exited.wait(timeout: .now() + 0.4) == .timedOut {
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                _ = exited.wait(timeout: .now() + 1)
            }
            break
        }
    }
    if readers.wait(timeout: .now() + 1) == .timedOut {
        stopReaders.cancel(); readers.wait()
        aborted = true
    }
    process.terminationHandler = nil
    try cancellation.check()
    guard !buffer.exceeded else { throw ReferenceError.message("Embedded JPEG exceeds the memory limit.") }
    guard !aborted else { throw ReferenceError.message("Embedded JPEG extraction timed out.") }
    guard process.terminationStatus == 0 else { throw ReferenceError.message("ExifTool could not read the requested embedded data.") }
    let bytes = buffer.take()
    guard !bytes.isEmpty else { throw ReferenceError.message("No requested embedded data is available.") }
    return bytes
}

func extractJPEG(raw: URL, executable: URL, cancellation: Cancellation,
                 timeout: TimeInterval = 12, byteLimit: Int = 128 * 1024 * 1024) throws -> Data {
    try extractEmbeddedJPEG(raw:raw,executable:executable,cancellation:cancellation,timeout:timeout,byteLimit:byteLimit).bytes
}

func extractEmbeddedJPEG(raw:URL,executable:URL,cancellation:Cancellation,
                         timeout:TimeInterval=12,byteLimit:Int=128*1024*1024) throws -> (bytes:Data,tag:String) {
    guard raw.pathExtension.lowercased()=="arw" else {
        // Keep the established CR3 request path unchanged.
        return (try runExifTool(raw:raw,executable:executable,cancellation:cancellation,
                               arguments:["-b","-JpgFromRaw"],timeout:timeout,byteLimit:byteLimit),"JpgFromRaw")
    }
    let deadline=ProcessInfo.processInfo.systemUptime+timeout
    var best:(bytes:Data,tag:String)?,bestPixels:Double=0
    for tag in ["JpgFromRaw","PreviewImage"] {
        try cancellation.check()
        let remaining=deadline-ProcessInfo.processInfo.systemUptime
        guard remaining>0 else { break }
        do {
            let data=try runExifTool(raw:raw,executable:executable,cancellation:cancellation,
                                    arguments:["-b","-"+tag],timeout:remaining,byteLimit:byteLimit)
            guard let source=CGImageSourceCreateWithData(data as CFData,nil),
                  CGImageSourceGetType(source) as String? == "public.jpeg",
                  let properties=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],
                  let width=properties[kCGImagePropertyPixelWidth] as? Double,
                  let height=properties[kCGImagePropertyPixelHeight] as? Double,
                  width>0,height>0,width*height>bestPixels else { continue }
            _ = try decodeJPEG(source) // Reject damaged/oversized candidates before choosing.
            best=(data,tag);bestPixels=width*height
        } catch { try cancellation.check() } // Missing/invalid tag may have a valid alternative.
    }
    try cancellation.check()
    guard let best else { throw ReferenceError.message("No valid embedded ARW JPEG found in JpgFromRaw or PreviewImage.") }
    return best
}

func embeddedImage(raw: URL, executable: URL, cancellation: Cancellation) throws -> (image: CGImage, extraction: TimeInterval, bytes: Data, orientation: UInt32?, tag:String) {
    let started = ProcessInfo.processInfo.systemUptime
    let selected = try extractEmbeddedJPEG(raw:raw,executable:executable,cancellation:cancellation)
    let data=selected.bytes
    var extraction = ProcessInfo.processInfo.systemUptime - started
    try cancellation.check()
    let source = CGImageSourceCreateWithData(data as CFData, nil)
    let image = try decodeJPEG(source)
    let properties = source.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any] }
    // Some extracted JPEGs have no EXIF orientation of their own. Read the camera orientation,
    // without applying Lightroom's edits. No second process is needed if the JPEG already has it.
    if properties?[kCGImagePropertyOrientation] != nil { return (image, extraction, data, nil,selected.tag) }
    let orientationStarted = ProcessInfo.processInfo.systemUptime
    let metadata = try runExifTool(raw: raw, executable: executable, cancellation: cancellation,
                                  arguments: ["-n", "-s3", "-Orientation"], byteLimit: 1024)
    extraction += ProcessInfo.processInfo.systemUptime - orientationStarted
    guard let number = UInt32(String(decoding: metadata, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)),
          let orientation = CGImagePropertyOrientation(rawValue: number) else {
        throw ReferenceError.message("Camera orientation is unavailable for this embedded JPEG.")
    }
    if orientation == .up { return (image, extraction, data, number,selected.tag) }
    let base = CIImage(cgImage: image)
    let transform = base.orientationTransform(forExifOrientation: Int32(number))
    let extent = base.extent.applying(transform).standardized
    let space = image.colorSpace?.model == .rgb ? image.colorSpace! : CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(data: nil, width: Int(extent.width), height: Int(extent.height),
                                  bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw ReferenceError.message("Cannot allocate the oriented JPEG.")
    }
    context.translateBy(x: -extent.minX, y: -extent.minY)
    context.concatenate(transform)
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    guard let result = context.makeImage() else { throw ReferenceError.message("Cannot orient the embedded JPEG.") }
    return (result, extraction, data, number,selected.tag)
}

func decodeJPEG(_ source: CGImageSource?) throws -> CGImage {
    guard let source, CGImageSourceGetType(source) as String? == "public.jpeg",
          CGImageSourceGetStatus(source) == .statusComplete,
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let w = properties[kCGImagePropertyPixelWidth] as? Double,
          let h = properties[kCGImagePropertyPixelHeight] as? Double,
          w > 0, h > 0, w * h <= 200_000_000,
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: 16384
          ] as CFDictionary) else { throw ReferenceError.message("No suitable, valid JPEG could be decoded.") }
    return image
}

// The same resolver serves the overlay and the independent window. It holds no image cache.
func loadReference(raw: URL, preferEmbedded: Bool, executable: URL?, cancellation: Cancellation) throws -> LoadedReference {
    let start = ProcessInfo.processInfo.systemUptime
    let order: [ImageOrigin] = preferEmbedded ? [.embedded, .standalone] : [.standalone, .embedded]
    var reasons = [String]()
    var stages=[String]()
    for (index, origin) in order.enumerated() {
        try cancellation.check()
        let sourceStarted=ProcessInfo.processInfo.systemUptime
        do {
            let image: CGImage
            var extraction: TimeInterval?
            var bytes: Data?
            var orientation: UInt32?
            var sourceFilename=raw.lastPathComponent
            switch origin {
            case .standalone:
                let jpeg: URL
                do { jpeg = try matchingJPEG(for: raw) }
                catch let error as ReferenceError { throw error }
                catch { throw ReferenceError.message("Cannot read the standalone JPEG folder.") }
                stages.append(String(format:"JPEG lookup %.0f ms",(ProcessInfo.processInfo.systemUptime-sourceStarted)*1000))
                let decodeStarted=ProcessInfo.processInfo.systemUptime
                image = try decodeJPEG(CGImageSourceCreateWithURL(jpeg as CFURL, nil))
                stages.append(String(format:"Standalone decode %.0f ms",(ProcessInfo.processInfo.systemUptime-decodeStarted)*1000))
                sourceFilename=jpeg.lastPathComponent
            case .embedded:
                guard ["cr3","arw"].contains(raw.pathExtension.lowercased()) else {
                    throw ReferenceError.message("Embedded extraction currently supports CR3 and ARW.")
                }
                guard let executable else { throw ReferenceError.message("ExifTool not found. Use Choose ExifTool in the menu.") }
                let embedded = try embeddedImage(raw: raw, executable: executable, cancellation: cancellation)
                image = embedded.image; extraction = embedded.extraction
                bytes = embedded.bytes; orientation = embedded.orientation
                stages.append("Embedded preview: \(embedded.tag)")
                stages.append(String(format:"Embedded decode/orientation overhead %.0f ms",(ProcessInfo.processInfo.systemUptime-sourceStarted-embedded.extraction)*1000))
            }
            try cancellation.check()
            return LoadedReference(image: image, origin: origin, elapsed: ProcessInfo.processInfo.systemUptime - start,
                                   extraction: extraction, usedFallback: index > 0, embeddedBytes: bytes, cameraOrientation: orientation, sourceFilename: sourceFilename,stages:stages.joined(separator:"; "))
        } catch {
            try cancellation.check()
            stages.append(String(format:"%@ attempt failed after %.0f ms",origin.rawValue,(ProcessInfo.processInfo.systemUptime-sourceStarted)*1000))
            reasons.append(error.localizedDescription)
        }
    }
    throw ReferenceError.message("No camera JPEG reference is available.\n" + reasons.joined(separator: "\n"))
}

// One selection's image only; independent windows may still own their displayed image.
// No bytes or cache keys are written to disk.
final class SelectionImageCache {
    private let lock=NSLock()
    private var epoch:String?
    private var entry:(key:String,value:LoadedReference)?
    func observe(_ next:String?) {
        lock.lock();defer { lock.unlock() }
        if next == nil || next != epoch { entry=nil }
        epoch=next
    }
    func clear() { lock.lock();entry=nil;lock.unlock() }
    func value(key:String,epoch expected:String)->LoadedReference? {
        lock.lock();defer { lock.unlock() }
        guard epoch == expected,entry?.key == key else { return nil }
        return entry?.value
    }
    func insert(_ value:LoadedReference,key:String,epoch expected:String) {
        lock.lock();defer { lock.unlock() }
        guard epoch == expected else { return }
        entry=(key,value)
    }
}
func referenceFileSignature(raw:URL,preferEmbedded:Bool,executable:URL?)->String? {
    func stamp(_ url:URL)->String? {
        guard let a=try? FileManager.default.attributesOfItem(atPath:url.path),
              let date=a[.modificationDate] as? Date,let size=a[.size] as? NSNumber else { return nil }
        return "\(url.path):\(date.timeIntervalSince1970):\(size):\(a[.systemFileNumber] ?? "")"
    }
    guard let rawStamp=stamp(raw),let directoryStamp=stamp(raw.deletingLastPathComponent()) else { return nil }
    let jpeg=(try? matchingJPEG(for:raw)).flatMap(stamp) ?? "no-unambiguous-jpeg"
    let tool=executable.flatMap(stamp) ?? "no-tool"
    return "\(preferEmbedded):\(rawStamp):\(directoryStamp):\(jpeg):\(tool)"
}
