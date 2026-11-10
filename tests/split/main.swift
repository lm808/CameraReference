import Foundation
import CoreGraphics
let viewport=CGRect(x:300,y:100,width:1000,height:700)
for image in [CGSize(width:6000,height:4000),CGSize(width:4000,height:6000)] {
 let left=splitReferencePlacement(viewport:viewport,kind:.separateLeftRight,divider:800,dividerWidth:4,image:image,settings:DetectionConfig())!
 assert(left.region.minX==300 && left.region.maxX==798)
 assert(left.photo.minX>=318 && left.photo.maxX<=780 && left.photo.minY>=118 && left.photo.maxY<=782)
 let upper=splitReferencePlacement(viewport:viewport,kind:.separateUpperLower,divider:450,dividerWidth:4,image:image,settings:DetectionConfig())!
 assert(upper.photo.minY>=118 && upper.photo.maxY<=430)
 assert(abs(left.photo.width/left.photo.height-image.width/image.height)<0.0001)
}
for kind:SplitLayoutKind in [.wipe,.unknown] {
 assert(splitReferencePlacement(viewport:viewport,kind:kind,divider:800,image:CGSize(width:6000,height:4000),settings:DetectionConfig()) == nil)
}
assert(splitReferencePlacement(viewport:viewport,kind:.separateLeftRight,divider:nil,image:.zero,settings:DetectionConfig()) == nil)
assert(splitReferencePlacement(viewport:viewport,kind:.separateLeftRight,divider:350,image:CGSize(width:6000,height:4000),settings:DetectionConfig()) == nil)
print("PASS: split groundwork fits landscape/portrait in left/upper pane; rejects wipe, unknown, missing and undersized panes")
