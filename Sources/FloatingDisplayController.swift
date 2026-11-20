import AppKit

/// Owns the independent floating display, title and zoom state.
/// Main-thread access only. Placement, request policy and monitoring stay at their
/// coordinator boundaries; this owner introduces no timers or alternate state.
final class FloatingDisplayController {
    var floatingTitle="Camera Reference"
    var floatingZoom:Double=0
    var floating: NSPanel?
    var floatingView: ReferenceView?

    func updateFloatingTitle() { floating?.title=floatingTitle + String(format:" — %.1f%%",floatingZoom) }
}
