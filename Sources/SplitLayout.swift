import Foundation
import CoreGraphics

// Geometry helpers: live split detection requires an explicit user-selected mode.
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

// Explicit user selection, independent of Lightroom's undocumented view identity.
enum OverlayLayout:String,CaseIterable {
    case full,left,right,upper,lower
    var group:Int { self == .full ? 0 : ([.left,.right].contains(self) ? 1:2) }
    var label:String { switch self { case .full:return "Full";case .left:return "Left";case .right:return "Right";case .upper:return "Upper";case .lower:return "Lower" } }
    func pane(in ui:CGRect,vertical:CGFloat?,horizontal:CGFloat?)->CGRect? {
        switch self {
        case .full:return ui
        case .left,.right:
            guard let d=vertical,d>ui.minX+100,d<ui.maxX-100 else { return nil }
            return self == .left ? CGRect(x:ui.minX,y:ui.minY,width:d-ui.minX,height:ui.height):CGRect(x:d,y:ui.minY,width:ui.maxX-d,height:ui.height)
        case .upper,.lower:
            guard let d=horizontal,d>ui.minY+100,d<ui.maxY-100 else { return nil }
            return self == .upper ? CGRect(x:ui.minX,y:ui.minY,width:ui.width,height:d-ui.minY):CGRect(x:ui.minX,y:d,width:ui.width,height:ui.maxY-d)
        }
    }
}
func floatingPhotoSize(viewport:CGSize,image:CGSize,settings:DetectionConfig)->CGSize? {
    settings.placement(ui:CGRect(x:0,y:0,width:viewport.width/2,height:viewport.height),image:image)?.photo.size
}
// Window-local UI bounds can move with the window, but cannot survive a resize.
struct PlacementMemory {
    let ui:CGRect,window:CGRect,windowID:UInt32,epoch:String,settingsKey:String,layout:OverlayLayout
    var background:[Double]=[0,0,0]
    func translated(window current:CGRect,windowID id:UInt32,epoch next:String?,settingsKey key:String,layout mode:OverlayLayout)->CGRect? {
        guard id==windowID,next==epoch,key==settingsKey,mode==layout,
              abs(current.width-window.width)<0.5,abs(current.height-window.height)<0.5 else { return nil }
        return ui.offsetBy(dx:current.minX-window.minX,dy:current.minY-window.minY)
    }
}

func regionPreferenceKey(_ key:String,layout:OverlayLayout)->String {
    layout == .full ? key:"split.\(layout.rawValue).\(key)"
}
