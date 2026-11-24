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

var full=Dictionary(uniqueKeysWithValues:samples.enumerated().map{($0.offset,$0.element)})
full[5]=sample(moved,[-1,1,33,17])
let area=samples[0].selected
let photo=CGRect(x:area.minX+18,y:area.midY-200,width:area.width-36,height:400)
let complete=try AXCalibrationPlan.complete(full,photo:photo,baseHiddenTop:50)
assert(complete.count==12 && complete["axFullScreenTitleBarAllowancePoints"]==32 && complete["fitInsetPoints"]==18)
var conflict=full;conflict[5]=sample(moved,[9,1,33,17])
do { _ = try AXCalibrationPlan.complete(conflict,photo:photo,baseHiddenTop:50);fatalError() } catch { assert(error.localizedDescription.contains("Setup 3 conflicts with setup 6")) }
do { _ = try AXCalibrationPlan.complete(full,photo:photo.offsetBy(dx:10,dy:0),baseHiddenTop:50);fatalError() } catch { assert(error.localizedDescription.contains("Setup 1 photo")) }
do { _ = try AXCalibrationPlan.complete(full,photo:photo,baseHiddenTop:10);fatalError() } catch {}
// Height-limited Fit and negative screen coordinates use the same margin formula.
let tallArea=CGRect(x:-900,y:-300,width:800,height:600)
let tallPhoto=CGRect(x:tallArea.midX-100,y:tallArea.minY+21,width:200,height:558)
assert(try! AXCalibrationPlan.fitInset(area:tallArea,photo:tallPhoto)==21)
print("PASS: six independent setups recover full-screen allowance and photo inset; conflicts identify retryable measurements")
