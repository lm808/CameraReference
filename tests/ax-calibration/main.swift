import Foundation
import CoreGraphics
func sample(_ raw:CGRect,_ shifts:[CGFloat])->AXCalibrationSample {
    let selected=CGRect(x:raw.minX+shifts[0],y:raw.minY-shifts[2],width:raw.width+shifts[1]-shifts[0],height:raw.height+shifts[2]-shifts[3])
    return AXCalibrationSample(raw:raw,selected:selected)
}
let raw=CGRect(x:300,y:132,width:1200,height:900)
let moved=CGRect(x:-1000,y:250,width:800,height:600)
let samples=[sample(raw,[-17,17,11,32]),sample(moved,[-1,1,1,60]),sample(moved,[-1,1,1,17]),sample(raw,[-17,17,11,32]),sample(raw,[-17,17,11,57])]
let values=try AXCalibrationPlan.replacements(samples)
assert(values["axShownLeftOffsetPoints"] == -17)
assert(values["axShownRightOffsetPoints"] == 17)
assert(values["axShownTopOffsetPoints"] == 11)
assert(values["axHiddenLeftOffsetPoints"] == -1)
assert(values["axHiddenRightOffsetPoints"] == 1)
assert(values["axHiddenTopOffsetPoints"] == 1)
assert(values["axFilmstripShownOffsetPoints"] == -11)
assert(values["axFilmstripHiddenOffsetPoints"] == 17)
assert(values["axToolbarHeightPoints"] == 43)
assert(values["axLibraryBottomOffsetPoints"] == 25)
func rejected(_ list:[AXCalibrationSample]) { do { _ = try AXCalibrationPlan.replacements(list);fatalError("Expected rejection") } catch {} }
rejected(Array(samples.prefix(4)))
var bad=samples;bad[3]=sample(raw,[-17,17,11,40]);rejected(bad)
bad=samples;bad[4]=sample(raw,[-12,17,11,57]);rejected(bad)
bad=samples;bad[1]=sample(moved,[-1,1,1,10]);rejected(bad)
// Consistent downwards/rightwards corrections remain signed, not absolute magnitudes.
let signed=[sample(raw,[5,-4,-3,12]),sample(raw,[2,-2,-2,20]),sample(raw,[2,-2,-2,10]),sample(raw,[5,-4,-3,12]),sample(raw,[5,-4,-3,7])]
let other=try AXCalibrationPlan.replacements(signed)
assert(other["axLibraryBottomOffsetPoints"] == -5 && other["axShownTopOffsetPoints"] == -3)
print("PASS: five-step offset recovery, cumulative bottom decomposition, signed coordinates, translated/resized raw areas and inconsistent-measurement rejection")
