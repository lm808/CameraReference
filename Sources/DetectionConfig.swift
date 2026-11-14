import Foundation
import CoreGraphics

struct DetectionConfig: Equatable {
    enum Bound:String { case ui,photo }
    // Legacy v1 fields: accepted for compatibility, ignored by v2 AX geometry.
    var axLeftOffsetPoints:CGFloat=0,axRightOffsetPoints:CGFloat=0,axTopOffsetPoints:CGFloat=0,axBottomOffsetPoints:CGFloat=0
    var axHiddenLeftInsetPoints:CGFloat=0,axHiddenRightInsetPoints:CGFloat=0,axHiddenTopInsetPoints:CGFloat=0,axHiddenBottomInsetPoints:CGFloat=0
    var axToolbarShownBottomOffsetPoints:CGFloat=0,axToolbarHiddenBottomOffsetPoints:CGFloat=0
    var axToolbarState="unknown"
    // Signed corrections: right/up positive. Legacy fields above remain parseable only.
    var axShownLeftOffsetPoints:CGFloat = -17
    var axHiddenLeftOffsetPoints:CGFloat = -1
    var axShownRightOffsetPoints:CGFloat=17
    var axHiddenRightOffsetPoints:CGFloat=1
    var axShownTopOffsetPoints:CGFloat=11
    var axHiddenTopOffsetPoints:CGFloat=1
    var axFilmstripShownOffsetPoints:CGFloat = -11
    var axFilmstripHiddenOffsetPoints:CGFloat=17
    var axToolbarHeightPoints:CGFloat=43
    var axLibraryBottomOffsetPoints:CGFloat=25
    var axBaseHiddenLeftInsetPoints:CGFloat=18
    var axBaseHiddenRightInsetPoints:CGFloat=18
    var axBaseHiddenTopInsetPoints:CGFloat=50
    var axBaseHiddenBottomInsetPoints:CGFloat=0
    static let axGeometryTemplate="""
    # AX geometry v2 — preview and experimental AX placement; points, not pixels.
    # Keep # AX: for compatibility with stable versions.
    # Signed OFFSETS: right/up positive; left/down negative.
    # Old axLeftOffsetPoints/axTopOffsetPoints etc. are retained but ignored.
    # Corrections start at raw panel edges, or the base hidden insets below.
    # AX: axShownLeftOffsetPoints = -17
    # AX: axHiddenLeftOffsetPoints = -1
    # AX: axShownRightOffsetPoints = 17
    # AX: axHiddenRightOffsetPoints = 1
    # AX: axShownTopOffsetPoints = 11
    # AX: axHiddenTopOffsetPoints = 1
    # AX: axFilmstripShownOffsetPoints = -11 # inferred for filmstrip shown / toolbar hidden
    # AX: axFilmstripHiddenOffsetPoints = 17
    # AX: axToolbarHeightPoints = 43
    # AX: axLibraryBottomOffsetPoints = 25 # extra upward allowance for Library
    # Base hidden insets measure inward from the window; offsets apply afterwards.
    # AX: axBaseHiddenLeftInsetPoints = 18
    # AX: axBaseHiddenRightInsetPoints = 18
    # AX: axBaseHiddenTopInsetPoints = 50
    # AX: axBaseHiddenBottomInsetPoints = 0
    """
    var left=Bound.ui,right=Bound.ui,top=Bound.ui,bottom=Bound.ui
    var panelCheckIntervalSeconds:Double=3
    var fitInsetPoints:CGFloat=18
    var sideSearchPercent:Double=40
    var verticalSnapFraction:CGFloat=0.25,horizontalSnapFraction:CGFloat=0.25
    var snapDistancePoints:CGFloat=8,snapGapPoints:CGFloat=4
    var snapContrast=4
    var key:String { "\(left.rawValue),\(right.rawValue),\(top.rawValue),\(bottom.rawValue),\(fitInsetPoints),\(sideSearchPercent)" }
    var needsPhoto:Bool { [left,right,top,bottom].contains(.photo) }
    static let template="""
    # Camera Reference advanced settings. Save as plain text.
    # Reloaded only when this file changes. No restart required.
    # Background UI checks in seconds; 0 disables checks. Range 0...3600.
    panelCheckIntervalSeconds = 3
    # Each side: ui or photo. Photo bounds are calculated, not edge-detected.
    left = ui
    right = ui
    top = ui
    bottom = ui
    # Minimum Fit margin, in macOS points (not Retina pixels). Range 0...100.
    fitInsetPoints = 18
    # Side-border search from each window edge, 5...50 percent.
    # 40 searches left 0...40% and right 60...100%; 50 reaches the centre.
    sideSearchPercent = 40
    # Minimum sustained edge length as fraction of Lightroom window, 0.05...1.
    verticalSnapFraction = 0.25
    horizontalSnapFraction = 0.25
    # Attraction radius 1...30 points; permitted small edge gaps 0...12 points.
    snapDistancePoints = 8
    snapGapPoints = 4
    # Minimum RGB contrast, 1...64. Raise to reject faint edges.
    snapContrast = 4
    """ + "\n\n" + axGeometryTemplate
    static func settingText(_ raw:String)->String {
        let trimmed=raw.trimmingCharacters(in:.whitespaces)
        return trimmed.hasPrefix("# AX: ") ? String(trimmed.dropFirst(6)):raw
    }
    static func parse(_ text:String) throws -> DetectionConfig {
        var c=DetectionConfig(),seen=Set<String>()
        func invalid(_ line:Int)->NSError { NSError(domain:"CameraReference",code:1,userInfo:[NSLocalizedDescriptionKey:"Invalid config.conf setting on line \(line). Check the name, value and allowed range."]) }
        for (index,raw) in text.components(separatedBy:.newlines).enumerated() {
            let line=settingText(raw).components(separatedBy:"#")[0].trimmingCharacters(in:.whitespaces)
            if line.isEmpty { continue }
            let parts=line.components(separatedBy:"=").map{$0.trimmingCharacters(in:.whitespaces)}
            guard parts.count==2,seen.insert(parts[0]).inserted else { throw invalid(index+1) }
            let k=parts[0],v=parts[1]
            if k == "overlayAnimation" {
                guard v == "true" || v == "false" else { throw invalid(index+1) }
                continue // Legacy 0.9.11 option: accepted but animation is always disabled.
            }
            if ["left","right","top","bottom"].contains(k) {
                guard let b=Bound(rawValue:v) else { throw invalid(index+1) }
                switch k { case "left":c.left=b;case "right":c.right=b;case "top":c.top=b;default:c.bottom=b };continue
            }
            if k == "axToolbarState" {
                guard ["unknown","shown","hidden"].contains(v) else { throw invalid(index+1) }
                c.axToolbarState=v;continue
            }
            guard let n=Double(v),n.isFinite else { throw invalid(index+1) }
            switch k {
            case "axShownLeftOffsetPoints" where (-200...200).contains(n):c.axShownLeftOffsetPoints=n
            case "axHiddenLeftOffsetPoints" where (-200...200).contains(n):c.axHiddenLeftOffsetPoints=n
            case "axShownRightOffsetPoints" where (-200...200).contains(n):c.axShownRightOffsetPoints=n
            case "axHiddenRightOffsetPoints" where (-200...200).contains(n):c.axHiddenRightOffsetPoints=n
            case "axShownTopOffsetPoints" where (-200...200).contains(n):c.axShownTopOffsetPoints=n
            case "axHiddenTopOffsetPoints" where (-200...200).contains(n):c.axHiddenTopOffsetPoints=n
            case "axFilmstripShownOffsetPoints" where (-200...200).contains(n):c.axFilmstripShownOffsetPoints=n
            case "axFilmstripHiddenOffsetPoints" where (-200...200).contains(n):c.axFilmstripHiddenOffsetPoints=n
            case "axToolbarHeightPoints" where (0...200).contains(n):c.axToolbarHeightPoints=n
            case "axLibraryBottomOffsetPoints" where (-200...200).contains(n):c.axLibraryBottomOffsetPoints=n
            case "axBaseHiddenLeftInsetPoints" where (0...200).contains(n):c.axBaseHiddenLeftInsetPoints=n
            case "axBaseHiddenRightInsetPoints" where (0...200).contains(n):c.axBaseHiddenRightInsetPoints=n
            case "axBaseHiddenTopInsetPoints" where (0...200).contains(n):c.axBaseHiddenTopInsetPoints=n
            case "axBaseHiddenBottomInsetPoints" where (0...200).contains(n):c.axBaseHiddenBottomInsetPoints=n
            case "axLeftOffsetPoints" where (-200...200).contains(n):c.axLeftOffsetPoints=n
            case "axRightOffsetPoints" where (-200...200).contains(n):c.axRightOffsetPoints=n
            case "axTopOffsetPoints" where (-200...200).contains(n):c.axTopOffsetPoints=n
            case "axBottomOffsetPoints" where (-200...200).contains(n):c.axBottomOffsetPoints=n
            case "axHiddenLeftInsetPoints" where (0...200).contains(n):c.axHiddenLeftInsetPoints=n
            case "axHiddenRightInsetPoints" where (0...200).contains(n):c.axHiddenRightInsetPoints=n
            case "axHiddenTopInsetPoints" where (0...200).contains(n):c.axHiddenTopInsetPoints=n
            case "axHiddenBottomInsetPoints" where (0...200).contains(n):c.axHiddenBottomInsetPoints=n
            case "axToolbarShownBottomOffsetPoints" where (-200...200).contains(n):c.axToolbarShownBottomOffsetPoints=n
            case "axToolbarHiddenBottomOffsetPoints" where (-200...200).contains(n):c.axToolbarHiddenBottomOffsetPoints=n
            case "panelCheckIntervalSeconds" where (0...3600).contains(n):c.panelCheckIntervalSeconds=n
            case "sideSearchPercent" where (5...50).contains(n):c.sideSearchPercent=n
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
    private var stamp:String?
    private(set) var parseCount=0
    private func fileStamp() throws -> String {
        let a=try FileManager.default.attributesOfItem(atPath:url.path)
        return "\((a[.modificationDate] as? Date)?.timeIntervalSinceReferenceDate ?? 0): \(a[.size] ?? ""): \(a[.systemFileNumber] ?? "")"
    }
    init(url:URL=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/CameraReference/config.conf")) { self.url=url }
    func ensureFile() throws {
        if !FileManager.default.fileExists(atPath:url.path) {
            try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
            let legacy=url.deletingLastPathComponent().appendingPathComponent("detection.conf")
            if url.lastPathComponent=="config.conf",FileManager.default.fileExists(atPath:legacy.path) {
                // Copy, do not delete: preserve the original as a migration backup.
                try FileManager.default.copyItem(at:legacy,to:url)
            } else { try DetectionConfig.template.write(to:url,atomically:true,encoding:.utf8) }
            try ensureFile()
        } else {
            var text=try String(contentsOf:url,encoding:.utf8)
            if !text.components(separatedBy:.newlines).contains(where:{ DetectionConfig.settingText($0).components(separatedBy:"#")[0].components(separatedBy:"=")[0].trimmingCharacters(in:.whitespaces)=="panelCheckIntervalSeconds" }) {
                text += "\n# Background panel checks in seconds; 0 disables (range 0...3600).\npanelCheckIntervalSeconds = 3\n"
                try text.write(to:url,atomically:true,encoding:.utf8)
            }
            let hasInterval=text.components(separatedBy:.newlines).contains {
                DetectionConfig.settingText($0).components(separatedBy:"#")[0].components(separatedBy:"=")[0].trimmingCharacters(in:.whitespaces) == "sideSearchPercent"
            }
            if !hasInterval {
                try (text + "\n# Side-border search from each window edge, 5...50 percent.\n# 40 searches left 0...40% and right 60...100%; 50 reaches the centre.\nsideSearchPercent = 40\n").write(to:url,atomically:true,encoding:.utf8)
            }
        }
        let existing=try String(contentsOf:url,encoding:.utf8)
        let keys=Set(existing.components(separatedBy:.newlines).map { DetectionConfig.settingText($0).components(separatedBy:"#")[0].components(separatedBy:"=")[0].trimmingCharacters(in:.whitespaces) })
        let missing=DetectionConfig.axGeometryTemplate.components(separatedBy:.newlines).filter { line in
            let key=DetectionConfig.settingText(line).components(separatedBy:"#")[0].components(separatedBy:"=")[0].trimmingCharacters(in:.whitespaces)
            return !key.isEmpty && !keys.contains(key)
        }
        if !missing.isEmpty {
            let addition=DetectionConfig.axGeometryTemplate.components(separatedBy:.newlines).filter { line in
                let key=DetectionConfig.settingText(line).components(separatedBy:"#")[0].components(separatedBy:"=")[0].trimmingCharacters(in:.whitespaces)
                return key.isEmpty || !keys.contains(key)
            }.joined(separator:"\n")
            try (existing+"\n\n# AX geometry (new keys only; existing values preserved).\n"+addition+"\n").write(to:url,atomically:true,encoding:.utf8)
        }
    }
    func reload() throws -> DetectionConfig {
        if let stamp,stamp == (try? fileStamp()) { return current }
        try ensureFile()
        let readStamp=try fileStamp()
        let next=try DetectionConfig.parse(String(contentsOf:url,encoding:.utf8))
        current=next;stamp=readStamp;parseCount += 1;return next
    }
}
