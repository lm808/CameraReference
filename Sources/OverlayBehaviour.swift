import Foundation

// A decision is scoped to its operation: geometry adjust preserves zoom/image;
// photo adjust requests a fresh selection at Fit. Neither can open an off overlay.
enum AXOverlayChangeAction { case retain, adjust, dismiss }
enum OverlayHostAction:Equatable { case retain,suspend,translate(CGPoint) }

/// Pure behaviour decisions. No preferences, AX reads, capture, timers or windows.
/// Callers keep their existing evidence freshness, request identity and visibility
/// guards, and execute actions in the original order. Do not fold suspension into
/// dismissal, or screenshot cache invalidation into AX live placement.
enum OverlayBehaviourPolicy {
    static func geometryChange(accessibility:Bool,automatic:Bool,displayed:OverlayLayout?,selected:OverlayLayout,panelsChanged:Bool,live:Bool)->AXOverlayChangeAction {
        guard accessibility,automatic,let displayed,displayed != selected || panelsChanged else { return .retain }
        return live ? .adjust:.dismiss
    }

    static func photoSelectionChange(accessibility:Bool,automatic:Bool,overlayOpen:Bool,previous:String?,current:String?,live:Bool)->AXOverlayChangeAction {
        guard accessibility,automatic,overlayOpen,let previous,let current,previous != current else { return .retain }
        return live ? .adjust:.dismiss
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
