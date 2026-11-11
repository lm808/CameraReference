import Foundation

struct BridgeResponse {
    let token: String
    let success: Bool
    let value: String
    init?(_ text: String, expected: String) {
        let lines = text.components(separatedBy: "\n")
        guard lines.count == 5, lines[0] == expected,
              ["OK", "ERR"].contains(lines[1]), lines[3] == "END", lines[4].isEmpty else { return nil }
        let hex = Array(lines[2].utf8)
        guard hex.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        for i in stride(from: 0, to: hex.count, by: 2) {
            guard let byte = UInt8(String(decoding: hex[i...i+1], as: UTF8.self), radix: 16) else { return nil }
            bytes.append(byte)
        }
        guard let value = String(bytes: bytes, encoding: .utf8) else { return nil }
        self.token = expected; self.success = lines[1] == "OK"; self.value = value
    }
}

enum ReferenceError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

func matchingJPEG(for raw: URL) throws -> URL {
    guard !["jpg", "jpeg"].contains(raw.pathExtension.lowercased()) else { throw ReferenceError.message("Select a RAW photograph, not its JPEG.") }
    guard FileManager.default.isReadableFile(atPath: raw.path) else {
        throw ReferenceError.message("Original photograph is offline or unreadable.")
    }
    let stem = raw.deletingPathExtension().lastPathComponent
    let files = try FileManager.default.contentsOfDirectory(at: raw.deletingLastPathComponent(), includingPropertiesForKeys: nil)
    let matches = files.filter {
        $0.deletingPathExtension().lastPathComponent == stem && ["jpg", "jpeg"].contains($0.pathExtension.lowercased())
    }.filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
    guard matches.count == 1 else {
        throw ReferenceError.message(matches.isEmpty ? "No matching standalone JPEG." : "Multiple matching JPEGs; keep one unambiguous pair.")
    }
    return matches[0]
}

// Old IPC is archived, never replayed into the new live bridge directory.
// A fresh legacy heartbeat means the old plugin must be stopped/reloaded first.
func consolidateLegacyBridge(applicationSupport:URL, now:Date = Date()) throws -> Bool {
    let fm=FileManager.default
    let legacy=applicationSupport.appendingPathComponent("CameraReference")
    guard fm.fileExists(atPath:legacy.path) else { return true }
    let heartbeat=legacy.appendingPathComponent("heartbeat.txt")
    if let attributes=try? fm.attributesOfItem(atPath:heartbeat.path),
       let modified=attributes[.modificationDate] as? Date,now.timeIntervalSince(modified)<10 { return false }
    let backups=applicationSupport.appendingPathComponent("Camera Reference/Backups")
    try fm.createDirectory(at:backups,withIntermediateDirectories:true)
    // Unique destination preserves unknown files and any earlier backup.
    try fm.moveItem(at:legacy,to:backups.appendingPathComponent("Legacy Bridge-"+UUID().uuidString))
    return true
}
