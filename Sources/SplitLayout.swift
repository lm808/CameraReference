import Foundation
import CoreGraphics

// Groundwork only: not enabled by the live capture path until native layout
// identity and divider evidence are validated. Do not infer mode from an edge.
enum SplitLayoutKind {
    case separateLeftRight, separateUpperLower, wipe, unknown
}
func splitReferencePlacement(viewport:CGRect,kind:SplitLayoutKind,divider:CGFloat?,dividerWidth:CGFloat=0,image:CGSize,settings:DetectionConfig)->(region:CGRect,photo:CGRect)? {
    guard viewport.width>0,viewport.height>0,let divider,divider.isFinite,
          dividerWidth.isFinite,dividerWidth>=0 else { return nil }
    let pane:CGRect
    switch kind {
    case .separateLeftRight:
        guard divider>viewport.minX,divider<viewport.maxX else { return nil }
        pane=CGRect(x:viewport.minX,y:viewport.minY,width:divider-dividerWidth/2-viewport.minX,height:viewport.height)
    case .separateUpperLower:
        guard divider>viewport.minY,divider<viewport.maxY else { return nil }
        // Detector coordinates are top-left based: the upper pane starts at minY.
        pane=CGRect(x:viewport.minX,y:viewport.minY,width:viewport.width,height:divider-dividerWidth/2-viewport.minY)
    case .wipe,.unknown: return nil
    }
    guard pane.width>100,pane.height>100 else { return nil }
    return settings.placement(ui:pane,image:image)
}
