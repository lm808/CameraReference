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
    var label:String { switch self { case .full:return "Loupe View";case .left:return "Left";case .right:return "Right";case .upper:return "Top";case .lower:return "Bottom" } }
    var viewName:String { group==0 ? "Loupe View":group==1 ? "Reference View (Left/Right)":"Reference View (Top/Bottom)" }
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
struct PlacementMemory:Equatable {
    let ui:CGRect,window:CGRect,windowID:UInt32,epoch:String,settingsKey:String,layout:OverlayLayout
    var background:[Double]=[0,0,0]
    // Equal panes encode the complete working area without a second cache owner.
    // Coordinates are AppKit: the upper pane occupies the higher y half.
    var workingArea:CGRect {
        switch layout {
        case .full:return ui
        case .left:return CGRect(x:ui.minX,y:ui.minY,width:ui.width*2,height:ui.height)
        case .right:return CGRect(x:ui.minX-ui.width,y:ui.minY,width:ui.width*2,height:ui.height)
        case .upper:return CGRect(x:ui.minX,y:ui.minY-ui.height,width:ui.width,height:ui.height*2)
        case .lower:return CGRect(x:ui.minX,y:ui.minY,width:ui.width,height:ui.height*2)
        }
    }
    func supportsLayout(_ mode:OverlayLayout,module:String?,expandedReuse:Bool)->Bool {
        if !expandedReuse { return mode==layout }
        // Library Compare adds lower controls; Develop uses the same outer area.
        return module != "library" || (mode == .full)==(layout == .full)
    }
    func translated(window current:CGRect,windowID id:UInt32,epoch next:String?,settingsKey key:String,layout mode:OverlayLayout,expandedReuse:Bool=false,module:String?=nil)->CGRect? {
        guard id==windowID,next != nil,(expandedReuse || next==epoch),key==settingsKey,
              supportsLayout(mode,module:module,expandedReuse:expandedReuse),
              abs(current.width-window.width)<0.5,abs(current.height-window.height)<0.5 else { return nil }
        var area=ui
        if expandedReuse {
            let whole=workingArea
            switch mode {
            case .full:area=whole
            case .left:area=CGRect(x:whole.minX,y:whole.minY,width:whole.width/2,height:whole.height)
            case .right:area=CGRect(x:whole.midX,y:whole.minY,width:whole.width/2,height:whole.height)
            case .upper:area=CGRect(x:whole.minX,y:whole.midY,width:whole.width,height:whole.height/2)
            case .lower:area=CGRect(x:whole.minX,y:whole.minY,width:whole.width,height:whole.height/2)
            }
        }
        guard mode == .full || (area.width>100 && area.height>100) else { return nil }
        return area.offsetBy(dx:current.minX-window.minX,dy:current.minY-window.minY)
    }
}

func regionPreferenceKey(_ key:String,layout:OverlayLayout)->String {
    layout == .full ? key:"split.\(layout.rawValue).\(key)"
}

func panelBoundsChanged(previous:CGRect?,current:CGRect?,tolerance:CGFloat=1)->Bool {
    guard let previous,let current else { return true }
    return abs(previous.minX-current.minX)>tolerance || abs(previous.minY-current.minY)>tolerance || abs(previous.width-current.width)>tolerance || abs(previous.height-current.height)>tolerance
}
// The overlay need only stay above its host, not immediately adjacent to it.
// Lightroom owns transient child windows during interaction. Reordering around
// those every poll causes needless WindowServer changes. Other applications
// between the overlay and host still take precedence and must cover the overlay.
func overlayNeedsOrdering(order:[Int],overlay:Int,lightroom:Int,lightroomWindows:Set<Int> = [])->Bool {
    guard let lr=order.firstIndex(of:lightroom) else { return false }
    guard let own=order.firstIndex(of:overlay) else { return true }
    if own>lr { return true }
    return order[(own+1)..<lr].contains { !lightroomWindows.contains($0) }
}

func calibrationInstructions(layout:OverlayLayout,automatic:Bool)->String {
    let mode=automatic ? "auto-detection":"manual mode"
    return "Select the region where you want the overlay to appear.\n\n• Selecting a region switches to manual mode.\n• Cancelling keeps \(mode) and the saved region."
}

// Keep the historical Develop key; Library starts at Full without overwriting it.
func overlayLayoutPreferenceKey(module:String?)->String {
    module == "library" ? "library.overlayLayout":"overlayLayout"
}
func savedOverlayLayout(_ defaults:UserDefaults,module:String?)->OverlayLayout {
    OverlayLayout(rawValue:defaults.string(forKey:overlayLayoutPreferenceKey(module:module)) ?? "full") ?? .full
}

// Compatibility entry points retained for existing geometry/helper callers.
func axOverlayChangeAction(accessibility:Bool,automatic:Bool,displayed:OverlayLayout?,selected:OverlayLayout,panelsChanged:Bool,live:Bool)->AXOverlayChangeAction {
    OverlayBehaviourPolicy.geometryChange(accessibility:accessibility,automatic:automatic,displayed:displayed,selected:selected,panelsChanged:panelsChanged,live:live)
}
func axSelectionChangeAction(accessibility:Bool,automatic:Bool,overlayOpen:Bool,previous:String?,current:String?,live:Bool)->AXOverlayChangeAction {
    OverlayBehaviourPolicy.photoSelectionChange(accessibility:accessibility,automatic:automatic,overlayOpen:overlayOpen,previous:previous,current:current,live:live)
}

// An inconclusive pixel check is not evidence of changed geometry when expanded
// reuse is enabled. Host/config/layout invalidation remains with its observers.
func invalidateScreenshotArea(previous:CGRect?,current:CGRect?,expandedReuse:Bool,tolerance:CGFloat=4)->Bool {
    if expandedReuse && previous != nil && current == nil { return false }
    return panelBoundsChanged(previous:previous,current:current,tolerance:tolerance)
}
