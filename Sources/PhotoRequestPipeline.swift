import AppKit

enum Destination:String { case overlay, window, check, detect }
typealias PhotoLoadResult = Result<(LoadedReference, LayoutProbe?), Error>

/// Immutable identities captured for a load, not a replacement generation scheme.
struct PhotoLoadContext {
    let token:String
    let target:Destination
    let cancellation:Cancellation
    let invoked:TimeInterval
    let module:String?
    let refreshingPanel:OverlayPanel?
    let refreshGeneration:Int
    let epoch:String?
}

/// Bridge transport, cancellation state and one-selection image cache. No
/// AppDelegate reference, placement decisions, permission prompts or windows
/// manipulated here. Request fields stay on the existing main-thread callers;
/// imageCache and Cancellation retain their existing thread-safe implementations.
final class PhotoRequestPipeline {
    let folder:URL
    let imageCache=SelectionImageCache()
    var cancellation:Cancellation?
    var destination:Destination?
    var pendingModule:String?
    var selectionRefreshPanel:OverlayPanel?
    var pending:String?
    var timer:Timer?
    var invocationStart:TimeInterval?
    init(folder:URL) { self.folder=folder }
    func writeRequest(token:String,target:Destination) throws {
        try (token + "\n" + (target == .detect ? "check" : target.rawValue)).write(to:folder.appendingPathComponent("request.txt"),atomically:true,encoding:.utf8)
    }
    func cancel() {
        cancellation?.cancel(); cancellation = nil; pending = nil; destination = nil;selectionRefreshPanel=nil
        timer?.invalidate(); timer = nil
        try? FileManager.default.removeItem(at: folder.appendingPathComponent("request.txt"))
        try? FileManager.default.removeItem(at: folder.appendingPathComponent("response.txt"))
    }
    func poll(token:String,deadline:Date,onResponse:@escaping(BridgeResponse)->Void,onTimeout:@escaping()->Void) {
        timer = Timer.scheduledTimer(withTimeInterval:0.05,repeats:true) { [weak self] timer in
            guard let self,self.pending == token else { timer.invalidate();return }
            if let text=try? String(contentsOf:self.folder.appendingPathComponent("response.txt"),encoding:.utf8),
               let response=BridgeResponse(text,expected:token) {
                timer.invalidate();self.timer=nil
                try? FileManager.default.removeItem(at:self.folder.appendingPathComponent("response.txt"))
                try? FileManager.default.removeItem(at:self.folder.appendingPathComponent("request.txt"))
                onResponse(response)
            } else if Date() >= deadline { onTimeout() }
        }
    }
    func selectionEpoch()->String? {
        let url=folder.appendingPathComponent("selection.txt")
        guard let attrs=try? FileManager.default.attributesOfItem(atPath:url.path),let date=attrs[.modificationDate] as? Date,
              Date().timeIntervalSince(date)<3,let text=try? String(contentsOf:url,encoding:.utf8) else { return nil }
        let lines=text.components(separatedBy:"\n")
        return lines.count==3 && lines[1]=="END" && !lines[0].isEmpty ? lines[0]:nil
    }
    func responseEpoch(_ token:String)->String? {
        guard let text=try? String(contentsOf:folder.appendingPathComponent("response-selection.txt"),encoding:.utf8) else { return nil }
        let lines=text.components(separatedBy:"\n")
        return lines.count==4 && lines[0]==token && lines[2]=="END" ? lines[1]:nil
    }
    // Keep the original worker/main handoff and cache fingerprint/epoch checks.
    func load(_ path:String,context:PhotoLoadContext,prefer:Bool,executable:URL?,automatic:Bool,completion:@escaping(PhotoLoadResult)->Void) {
        let epoch=context.epoch,work=context.cancellation,target=context.target
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let result: PhotoLoadResult = Result {
                let raw=URL(fileURLWithPath:path)
                let started=ProcessInfo.processInfo.systemUptime
                let signature=epoch == nil ? nil:referenceFileSignature(raw:raw,preferEmbedded:prefer,executable:executable)
                var loaded:LoadedReference
                if let epoch,let signature,let cached=imageCache.value(key:signature,epoch:epoch),selectionEpoch()==epoch {
                    loaded=LoadedReference(image:cached.image,origin:cached.origin,elapsed:ProcessInfo.processInfo.systemUptime-started,extraction:nil,usedFallback:cached.usedFallback,embeddedBytes:cached.embeddedBytes,cameraOrientation:cached.cameraOrientation,sourceFilename:cached.sourceFilename,stages:"RAM cache hit; source files revalidated")
                } else {
                    loaded=try loadReference(raw:raw,preferEmbedded:prefer,executable:executable,cancellation:work)
                    loaded.stages += epoch == nil ? "; RAM cache unavailable: reload bridge 0.5.3 or check heartbeat":"; RAM cache miss"
                    if let epoch,let signature,selectionEpoch()==epoch,!work.isCancelled,
                       referenceFileSignature(raw:raw,preferEmbedded:prefer,executable:executable)==signature {
                        imageCache.insert(loaded,key:signature,epoch:epoch)
                    }
                }
                let layout = automatic && target != .check && target != .detect ? probeLightroom(imageSize: CGSize(width: loaded.image.width, height: loaded.image.height)) : nil
                try work.check()
                return (loaded, layout)
            }
            DispatchQueue.main.async { completion(result) }
        }
    }
}
