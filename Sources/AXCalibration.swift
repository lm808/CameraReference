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
        "Library • Compare Left/Right • all four panels shown • toolbar shown"]
    static let keys=["axShownLeftOffsetPoints","axShownRightOffsetPoints","axShownTopOffsetPoints","axHiddenLeftOffsetPoints","axHiddenRightOffsetPoints","axHiddenTopOffsetPoints","axFilmstripShownOffsetPoints","axFilmstripHiddenOffsetPoints","axToolbarHeightPoints","axLibraryBottomOffsetPoints"]
    static func replacements(_ samples:[AXCalibrationSample],tolerance:CGFloat=2)throws->[String:CGFloat] {
        guard samples.count==5 else { throw failure("Complete all five measurements first.") }
        for sample in samples {
            guard !sample.raw.isNull,!sample.selected.isNull,sample.selected.width>100,sample.selected.height>100,sample.shifts.allSatisfy({$0.isFinite}) else { throw failure("A measurement is invalid.") }
        }
        let s=samples.map(\.shifts)
        // Repeated edges are checks, not additional degrees of freedom.
        for edge in 0..<3 {
            guard abs(s[1][edge]-s[2][edge])<=tolerance,abs(s[0][edge]-s[3][edge])<=tolerance,abs(s[0][edge]-s[4][edge])<=tolerance else {
                throw failure("Repeated left/right/top measurements differ by more than \(tolerance) pt. Check the selected borders and panel widths; restart rather than absorbing this difference into offsets.")
            }
        }
        guard abs(s[0][3]-s[3][3])<=tolerance else { throw failure("Develop Loupe and split bottom measurements disagree. Restart and check the combined working-area boundary.") }
        let toolbar=s[1][3]-s[2][3]
        let values=[s[0][0],s[0][1],s[0][2],s[1][0],s[1][1],s[1][2],s[0][3]-toolbar,s[2][3],toolbar,s[4][3]-s[0][3]]
        guard values.allSatisfy({(-200...200).contains($0)}),toolbar>=0,toolbar<=200 else { throw failure("Proposed values exceed config limits. Check the measured regions.") }
        return Dictionary(uniqueKeysWithValues:zip(keys,values))
    }
    static func failure(_ text:String)->NSError { NSError(domain:"AXCalibration",code:1,userInfo:[NSLocalizedDescriptionKey:text]) }
}
