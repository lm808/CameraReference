import Foundation

// One settings file for stable and testing; separate bundle IDs isolate TCC
// entries, not the user's calibration/shortcuts. Stable keeps its original domain.
enum CameraPreferences {
    static let shared:UserDefaults = Bundle.main.bundleIdentifier == "org.local.CameraReference.testing"
        ? UserDefaults(suiteName:"org.local.CameraReference")! : .standard
}

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

// Consolidate support data without replaying old protocol files or overwriting
// explicit canonical settings. Wait until old writers have stopped.
func consolidateSupportDirectory(applicationSupport:URL, now:Date = Date()) throws -> Bool {
    let fm=FileManager.default
    let canonical=applicationSupport.appendingPathComponent("CameraReference")
    let spaced=applicationSupport.appendingPathComponent("Camera Reference")
    try fm.createDirectory(at:canonical,withIntermediateDirectories:true)
    // Seed settings before waiting for an old bridge to stop, so opening the
    // app cannot generate defaults in place of the existing user's config.
    for name in ["config.conf","detection.conf"] {
        let source=spaced.appendingPathComponent(name),destination=canonical.appendingPathComponent(name)
        if fm.fileExists(atPath:source.path),!fm.fileExists(atPath:destination.path) {
            try fm.copyItem(at:source,to:destination)
        }
    }
    for heartbeat in [spaced.appendingPathComponent("Bridge/heartbeat.txt"),canonical.appendingPathComponent("heartbeat.txt")] {
        if let a=try? fm.attributesOfItem(atPath:heartbeat.path),let date=a[.modificationDate] as? Date,now.timeIntervalSince(date)<10 { return false }
    }
    try fm.createDirectory(at:canonical,withIntermediateDirectories:true)
    let ipc:Set<String>=["request.txt","response.txt","response-selection.txt","selection.txt","heartbeat.txt","status.txt"]
    func merge(_ source:URL,_ destination:URL) throws {
        let sourceValues=try source.resourceValues(forKeys:[.isDirectoryKey,.isSymbolicLinkKey])
        guard fm.fileExists(atPath:destination.path) else { try fm.moveItem(at:source,to:destination);return }
        let destinationValues=try destination.resourceValues(forKeys:[.isDirectoryKey,.isSymbolicLinkKey])
        if sourceValues.isDirectory==true,sourceValues.isSymbolicLink != true,
           destinationValues.isDirectory==true,destinationValues.isSymbolicLink != true {
            for child in try fm.contentsOfDirectory(at:source,includingPropertiesForKeys:nil) {
                try merge(child,destination.appendingPathComponent(child.lastPathComponent))
            }
            try fm.removeItem(at:source) // Empty after successful merge only.
        } else if fm.contentsEqual(atPath:source.path,andPath:destination.path) {
            try fm.removeItem(at:source)
        } else {
            // Conflicts remain beside the canonical file for user review, not
            // in another legacy folder. Never silently replace a preference.
            try fm.moveItem(at:source,to:destination.deletingLastPathComponent().appendingPathComponent(destination.lastPathComponent+".migrated-"+UUID().uuidString))
        }
    }
    if fm.fileExists(atPath:spaced.path) {
        // These files are disposable IPC, not settings. Do not merge stale
        // requests/epochs into a bridge that may already be running here.
        let oldBridge=spaced.appendingPathComponent("Bridge")
        for name in ipc {
            let file=oldBridge.appendingPathComponent(name)
            if fm.fileExists(atPath:file.path) { try fm.removeItem(at:file) }
        }
        try merge(spaced,canonical)
    }
    for name in ipc {
        let old=canonical.appendingPathComponent(name)
        if fm.fileExists(atPath:old.path) { try fm.removeItem(at:old) }
    }
    return true
}

func supportedLightroomModule(_ module:String?)->Bool {
    module == "library" || module == "develop"
}
func confirmedModuleChange(previous:String?,current:String?)->Bool {
    guard let previous,let current else { return false }
    return previous != current
}
