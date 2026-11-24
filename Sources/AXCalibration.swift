import Foundation
import CoreGraphics

// Calibration mathematics consumes measurements only. No AX reads, UI or writes.
struct AXCalibrationSample {
    let raw:CGRect             // Global top-left points, before signed corrections.
    let selected:CGRect        // Same coordinate system; entire combined working area.
    var shifts:[CGFloat] { [selected.minX-raw.minX,selected.maxX-raw.maxX,raw.minY-selected.minY,raw.maxY-selected.maxY] }
}
struct AXCalibrationPlan {
    static let instructions=[
        "Develop • Loupe • all four panels shown • toolbar shown",
        "Develop • Loupe • all four panels hidden • toolbar shown",
        "Develop • Loupe • all four panels hidden • toolbar hidden",
        "Develop • Reference Left/Right • all four panels shown • toolbar shown",
        "Library • Compare Left/Right • all four panels shown • toolbar shown",
        "macOS full screen • Develop Loupe • all panels/toolbar hidden; native title/menu bars retracted"]
    static let boundaryKeys=["axShownLeftOffsetPoints","axShownRightOffsetPoints","axShownTopOffsetPoints","axHiddenLeftOffsetPoints","axHiddenRightOffsetPoints","axHiddenTopOffsetPoints","axFilmstripShownOffsetPoints","axFilmstripHiddenOffsetPoints","axToolbarHeightPoints","axLibraryBottomOffsetPoints"]
    static let keys=boundaryKeys+["axFullScreenTitleBarAllowancePoints","fitInsetPoints"]
    static func replacements(_ samples:[AXCalibrationSample],tolerance:CGFloat=2)throws->[String:CGFloat] {
        guard samples.count==5 else { throw failure("Complete all five measurements first.") }
        for sample in samples {
            guard !sample.raw.isNull,!sample.selected.isNull,sample.selected.width>100,sample.selected.height>100,sample.shifts.allSatisfy({$0.isFinite}) else { throw failure("A measurement is invalid.") }
        }
        let s=samples.map(\.shifts)
        // Repeated edges are checks, not additional degrees of freedom.
        for edge in 0..<3 {
            for (a,b) in [(1,2),(0,3),(0,4)] where abs(s[a][edge]-s[b][edge])>tolerance {
                throw failure("Setup \(a+1) conflicts with setup \(b+1): \(["left","right","top"][edge]) correction differs by more than \(tolerance) pt. Reselect either measurement.")
            }
        }
        guard abs(s[0][3]-s[3][3])<=tolerance else { throw failure("Setup 1 conflicts with setup 4: bottom corrections disagree. Reselect either combined working area.") }
        let toolbar=s[1][3]-s[2][3]
        let values=[s[0][0],s[0][1],s[0][2],s[1][0],s[1][1],s[1][2],s[0][3]-toolbar,s[2][3],toolbar,s[4][3]-s[0][3]]
        guard values.allSatisfy({(-200...200).contains($0)}),toolbar>=0,toolbar<=200 else { throw failure("Proposed values exceed config limits. Check the measured regions.") }
        return Dictionary(uniqueKeysWithValues:zip(boundaryKeys,values))
    }
    // Full-screen raw geometry is deliberately measured with allowance zero.
    // Thus its top shift includes both the hidden correction and the allowance.
    static func complete(_ samples:[Int:AXCalibrationSample],photo:CGRect?,baseHiddenTop:CGFloat,tolerance:CGFloat=2)throws->[String:CGFloat] {
        for (index,sample) in samples {
            guard !sample.raw.isNull,!sample.selected.isNull,sample.selected.width>100,sample.selected.height>100,sample.shifts.allSatisfy({$0.isFinite}) else { throw failure("Setup \(index+1) has an invalid working-area measurement. Reselect it.") }
        }
        for (a,b,edges) in [(0,3,[0,1,2,3]),(0,4,[0,1,2]),(1,2,[0,1,2]),(2,5,[0,1,3])] {
            if let x=samples[a],let y=samples[b] {
                for edge in edges where abs(x.shifts[edge]-y.shifts[edge])>tolerance {
                    throw failure("Setup \(a+1) conflicts with setup \(b+1): \(["left","right","top","bottom"][edge]) corrections disagree. Reselect either measurement.")
                }
            }
        }
        if let area=samples[0]?.selected,let photo { _ = try fitInset(area:area,photo:photo,tolerance:tolerance) }
        if let full=samples[5],let windowed=samples[2] {
            let allowance=full.shifts[2]-windowed.shifts[2]
            guard allowance>=0,allowance<=200,allowance<=baseHiddenTop else { throw failure("Setup 6 conflicts with setup 3: full-screen allowance is outside the usable hidden-top base. Reselect either measurement.") }
        }
        let missing=(0..<6).filter{samples[$0]==nil}
        guard missing.isEmpty else { throw failure("Still needed: setup \(missing.map{String($0+1)}.joined(separator:", ")) working area.") }
        var values=try replacements((0..<5).map{samples[$0]!},tolerance:tolerance)
        let allowance=samples[5]!.shifts[2]-samples[2]!.shifts[2]
        values["axFullScreenTitleBarAllowancePoints"]=allowance
        guard let photo else { throw failure("Still needed: setup 1 photo bounds, at Fit with a matching untransformed camera JPEG.") }
        values["fitInsetPoints"]=try fitInset(area:samples[0]!.selected,photo:photo,tolerance:tolerance)
        return values
    }
    static func fitInset(area:CGRect,photo:CGRect,tolerance:CGFloat=2)throws->CGFloat {
        guard photo.width>0,photo.height>0,area.contains(photo),
              abs(photo.midX-area.midX)<=tolerance,abs(photo.midY-area.midY)<=tolerance else {
            throw failure("Setup 1 photo conflicts with its working area: photo must be inside and centred at Fit. Reselect the photo or working area.")
        }
        let inset=min((area.width-photo.width)/2,(area.height-photo.height)/2)
        guard inset.isFinite,(0...100).contains(inset) else { throw failure("Setup 1 photo Fit inset is outside 0...100 pt. Check Fit and reselect either rectangle.") }
        return inset
    }
    static func failure(_ text:String)->NSError { NSError(domain:"AXCalibration",code:1,userInfo:[NSLocalizedDescriptionKey:text]) }
}
