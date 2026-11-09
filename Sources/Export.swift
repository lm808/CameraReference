import Foundation
import Darwin

// Add orientation to EXIF without touching the compressed image stream or other metadata.
// Existing TIFF offsets remain valid: append a replacement IFD0 inside the existing APP1.
func exportJPEG(_ input: Data, orientation: UInt32?) throws -> Data {
    guard let orientation else { return input }
    guard (1...8).contains(orientation), input.starts(with: [0xff, 0xd8]) else {
        throw ReferenceError.message("Cannot prepare JPEG orientation.")
    }
    var bytes = [UInt8](input), offset = 2
    while offset + 4 <= bytes.count {
        guard bytes[offset] == 0xff else { break }
        let marker = bytes[offset+1]
        if marker == 0xda || marker == 0xd9 { break }
        let length = Int(bytes[offset+2]) * 256 + Int(bytes[offset+3])
        guard length >= 2, offset + 2 + length <= bytes.count else { break }
        if marker == 0xe1 && length >= 16 && Array(bytes[(offset+4)..<(offset+10)]) == [69,120,105,102,0,0] {
            var tiff = Array(bytes[(offset+10)..<(offset+2+length)])
            let little = tiff.starts(with: [73,73,42,0])
            guard little || tiff.starts(with: [77,77,0,42]) else { throw ReferenceError.message("Unsupported EXIF header.") }
            func read(_ at: Int, _ n: Int) throws -> Int {
                guard at >= 0, at+n <= tiff.count else { throw ReferenceError.message("Incomplete EXIF metadata.") }
                return (0..<n).reduce(0) { $0 | Int(tiff[at+$1]) << (8 * (little ? $1 : n-1-$1)) }
            }
            func encoded(_ value: Int, _ n: Int) -> [UInt8] {
                (0..<n).map { UInt8(truncatingIfNeeded: value >> (8 * (little ? $0 : n-1-$0))) }
            }
            let old = try read(4,4), count = try read(old,2)
            guard count < 5000, old+2+12*count+4 <= tiff.count else { throw ReferenceError.message("Unsupported EXIF directory.") }
            var entries = [[UInt8]]()
            for i in 0..<count {
                let at = old+2+i*12
                if try read(at,2) != 0x112 { entries.append(Array(tiff[at..<at+12])) }
            }
            entries.append(encoded(0x112,2)+encoded(3,2)+encoded(1,4)+encoded(Int(orientation),2)+[0,0])
            entries.sort { a,b in
                let tag: ([UInt8]) -> Int = { little ? Int($0[0])+Int($0[1])*256 : Int($0[0])*256+Int($0[1]) }
                return tag(a) < tag(b)
            }
            if tiff.count % 2 != 0 { tiff.append(0) }
            let replacement = tiff.count
            let next = Array(tiff[(old+2+count*12)..<(old+6+count*12)])
            tiff += encoded(entries.count,2) + entries.flatMap { $0 } + next
            tiff.replaceSubrange(4..<8, with: encoded(replacement,4))
            let newLength = 8+tiff.count
            guard newLength <= 65535 else { throw ReferenceError.message("EXIF metadata is too large to add orientation.") }
            let segment: [UInt8] = [0xff,0xe1,UInt8(newLength >> 8),UInt8(newLength & 255),69,120,105,102,0,0] + tiff
            bytes.replaceSubrange(offset..<(offset+2+length), with: segment)
            return Data(bytes)
        }
        offset += 2+length
    }
    let segment: [UInt8] = [0xff,0xe1,0,34,69,120,105,102,0,0,73,73,42,0,8,0,0,0,1,0,18,1,3,0,1,0,0,0,UInt8(orientation),0,0,0,0,0,0,0]
    bytes.insert(contentsOf: segment, at: 2)
    return Data(bytes)
}

struct ExportIdentity: Equatable {
    let device: dev_t
    let inode: ino_t
    let size: off_t
    let seconds: Int
    let nanoseconds: Int
    init(_ s: stat) { device=s.st_dev; inode=s.st_ino; size=s.st_size; seconds=s.st_mtimespec.tv_sec; nanoseconds=s.st_mtimespec.tv_nsec }
}
func exportIdentity(_ url: URL) throws -> ExportIdentity? {
    var s = stat()
    if lstat(url.path, &s) != 0 {
        if errno == ENOENT { return nil }
        throw ReferenceError.message("Cannot inspect the export destination.")
    }
    guard s.st_mode & S_IFMT == S_IFREG, s.st_nlink == 1 else {
        throw ReferenceError.message("Export destination must be a regular file, not a link.")
    }
    return ExportIdentity(s)
}
// No temporary image file. Exclusive create protects existing files; overwrite requires
// the same regular, singly-linked file that the user confirmed. RAW is never opened for writing.
func writeExport(_ data: Data, to url: URL, replacing expected: ExportIdentity?) throws {
    let fd = open(url.path, O_WRONLY | O_NOFOLLOW | (expected == nil ? O_CREAT | O_EXCL : 0), 0o600)
    guard fd >= 0 else { throw ReferenceError.message("Cannot save JPEG. Check folder access or an existing export.") }
    defer { close(fd) }
    var s = stat()
    guard fstat(fd,&s) == 0, s.st_mode & S_IFMT == S_IFREG, s.st_nlink == 1,
          expected == nil || ExportIdentity(s) == expected else { throw ReferenceError.message("Export destination changed. Try saving again.") }
    if expected != nil && ftruncate(fd,0) != 0 { throw ReferenceError.message("Cannot replace the existing export.") }
    try data.withUnsafeBytes { raw in
        var offset = 0
        while offset < raw.count {
            let count = Darwin.write(fd,raw.baseAddress!.advanced(by: offset),raw.count-offset)
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else { throw ReferenceError.message("JPEG write failed; the export may be incomplete.") }
            offset += count
        }
    }
    guard fsync(fd) == 0 else { throw ReferenceError.message("JPEG could not be flushed to disk.") }
}
