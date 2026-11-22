import Foundation

enum TitlebarVisibility { case unknown, hidden, visible(CGRect) }

// A decision is scoped to its operation: geometry adjust preserves zoom/image;
// photo adjust requests a fresh selection at Fit. Neither can open an off overlay.

enum AXOverlayChangeAction { case retain, adjust, dismiss }
enum OverlayHostAction:Equatable { case retain,suspend,translate(CGPoint) }

/// Pure behaviour decisions. No preferences, AX reads, capture, timers or windows.
/// Callers keep their existing evidence freshness, request identity and visibility
/// guards, and execute actions in the original order. Do not fold suspension into
/// dismissal, or screenshot cache invalidation into AX live placement.
enum OverlayBehaviourPolicy {
    // Confirmed native full-screen avoids floating-level priority over system UI.
    // Unknown evidence retains the windowed policy; no geometry inference.
    static func useFloatingOverlayLevel(lightroomActive:Bool,overview:Bool,dialog:Bool,fullScreen:Bool?)->Bool {
        lightroomActive && !overview && !dialog && fullScreen != true
    }

    // Presentation only: shave the top through the occluder's lower edge.
    // Both rectangles are AppKit coordinates. Never change the photo viewport.
    static func titlebarClipHeight(overlay:CGRect,titlebar:CGRect?)->CGFloat {
        guard let titlebar,overlay.intersects(titlebar) else { return 0 }
        return min(overlay.height,max(0,overlay.maxY-titlebar.minY))
    }

    static func geometryChange(accessibility:Bool,automatic:Bool,displayed:OverlayLayout?,selected:OverlayLayout,panelsChanged:Bool,live:Bool,screenshotAXDetection:Bool=false)->AXOverlayChangeAction {
        guard (accessibility || screenshotAXDetection),automatic,let displayed,displayed != selected || panelsChanged else { return .retain }
        return accessibility && live ? .adjust:.dismiss
    }

    static func photoSelectionChange(accessibility:Bool,automatic:Bool,overlayOpen:Bool,previous:String?,current:String?,live:Bool,screenshot:Bool=false)->AXOverlayChangeAction {
        guard (accessibility || screenshot),automatic,overlayOpen,let previous,let current,previous != current else { return .retain }
        return accessibility && live ? .adjust:.dismiss
    }

    static func hostChange(saved:CGRect,current:CGRect?,onScreen:Bool,overview:Bool)->OverlayHostAction {
        if overview { return .suspend }
        guard let current else { return .retain }
        if !onScreen { return .suspend }
        return .translate(CGPoint(x:current.minX-saved.minX,y:current.minY-saved.minY))
    }

    static func moduleChanged(previous:String?,current:String?)->Bool {
        guard let previous,let current else { return false }
        return previous != current
    }
    // Existing explicit menu selection dismisses screenshot overlays. AX follows
    // its separate geometry-change decision after selection/menu/cache updates.
    static func dismissForExplicitSelection(screenshot:Bool)->Bool { screenshot }
    // Evidence has already been restricted to direct View > Grid by the reader.
    // Nil is uncertainty, not a selected Grid. Preserve caller read/epoch guards.
    static func isGridSelected(_ selected:Bool?)->Bool { selected == true }
}
