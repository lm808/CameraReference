import Foundation
import CoreGraphics

struct DetectionConfig: Equatable {
    enum Bound:String { case ui,photo }
    var left=Bound.ui,right=Bound.ui,top=Bound.photo,bottom=Bound.photo
    var fitInsetPoints:CGFloat=18
    var verticalSnapFraction:CGFloat=0.25,horizontalSnapFraction:CGFloat=0.25
    var snapDistancePoints:CGFloat=8,snapGapPoints:CGFloat=4
    var snapContrast=4
    var key:String { "\(left.rawValue),\(right.rawValue),\(top.rawValue),\(bottom.rawValue),\(fitInsetPoints)" }
    var needsPhoto:Bool { [left,right,top,bottom].contains(.photo) }
    static let template="""
    # Camera Reference detection settings. Save as plain text.
    # Reloaded on each detection/calibration. No restart required.
    # Single-photo Develop at Lightroom Fit only. Split views are deferred.
    # Each side: ui or photo. Photo bounds are calculated, not edge-detected.
    left = ui
    right = ui
    top = photo
    bottom = photo
    # Minimum Fit margin, in macOS points (not Retina pixels). Range 0...100.
    fitInsetPoints = 18
    # Minimum sustained edge length as fraction of Lightroom window, 0.05...1.
    verticalSnapFraction = 0.25
    horizontalSnapFraction = 0.25
    # Attraction radius 1...30 points; permitted small edge gaps 0...12 points.
    snapDistancePoints = 8
    snapGapPoints = 4
    # Minimum RGB contrast, 1...64. Raise to reject faint edges.
    snapContrast = 4
    """
    static func parse(_ text:String) throws -> DetectionConfig {
        var c=DetectionConfig(),seen=Set<String>()
        func invalid(_ line:Int)->NSError { NSError(domain:"CameraReference",code:1,userInfo:[NSLocalizedDescriptionKey:"Invalid detection.conf setting on line \(line). Check the name, value and allowed range."]) }
        for (index,raw) in text.components(separatedBy:.newlines).enumerated() {
            let line=raw.components(separatedBy:"#")[0].trimmingCharacters(in:.whitespaces)
            if line.isEmpty { continue }
            let parts=line.components(separatedBy:"=").map{$0.trimmingCharacters(in:.whitespaces)}
            guard parts.count==2,seen.insert(parts[0]).inserted else { throw invalid(index+1) }
            let k=parts[0],v=parts[1]
            if ["left","right","top","bottom"].contains(k) {
                guard let b=Bound(rawValue:v) else { throw invalid(index+1) }
                switch k { case "left":c.left=b;case "right":c.right=b;case "top":c.top=b;default:c.bottom=b };continue
            }
            guard let n=Double(v),n.isFinite else { throw invalid(index+1) }
            switch k {
            case "fitInsetPoints" where (0...100).contains(n):c.fitInsetPoints=n
            case "verticalSnapFraction" where (0.05...1).contains(n):c.verticalSnapFraction=n
            case "horizontalSnapFraction" where (0.05...1).contains(n):c.horizontalSnapFraction=n
            case "snapDistancePoints" where (1...30).contains(n):c.snapDistancePoints=n
            case "snapGapPoints" where (0...12).contains(n):c.snapGapPoints=n
            case "snapContrast" where (1...64).contains(n) && n.rounded()==n:c.snapContrast=Int(n)
            default:throw invalid(index+1)
            }
        }
        return c
    }
    // All rectangles here use top-left coordinates; ScreenProbe converts once.
    func placement(ui:CGRect,image:CGSize)->(region:CGRect,photo:CGRect)? {
        let inner=ui.insetBy(dx:fitInsetPoints,dy:fitInsetPoints)
        guard inner.width>0,inner.height>0,image.width>0,image.height>0 else { return nil }
        let scale=min(inner.width/image.width,inner.height/image.height)
        let photo=CGRect(x:inner.midX-image.width*scale/2,y:inner.midY-image.height*scale/2,width:image.width*scale,height:image.height*scale)
        let x=left == .ui ? ui.minX:photo.minX,y=top == .ui ? ui.minY:photo.minY
        let r=right == .ui ? ui.maxX:photo.maxX,b=bottom == .ui ? ui.maxY:photo.maxY
        return (CGRect(x:x,y:y,width:r-x,height:b-y),photo)
    }
}
final class DetectionConfigStore {
    let url:URL
    private(set) var current=DetectionConfig()
    init(url:URL=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Camera Reference/detection.conf")) { self.url=url }
    func ensureFile() throws {
        if !FileManager.default.fileExists(atPath:url.path) {
            try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
            try DetectionConfig.template.write(to:url,atomically:true,encoding:.utf8)
        }
    }
    func reload() throws -> DetectionConfig {
        try ensureFile()
        let next=try DetectionConfig.parse(String(contentsOf:url,encoding:.utf8))
        current=next;return next
    }
}
