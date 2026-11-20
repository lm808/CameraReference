import AppKit

/// Owns the displayed overlay and its host/lifecycle state.
/// Main-thread access only. Placement, request policy and monitoring stay at their
/// coordinator boundaries; this owner introduces no timers or alternate state.
final class OverlayController {
    var panel: OverlayPanel?
    var overlayHost:HostWindowSnapshot?
    var displayedOverlayLayout:OverlayLayout?
    var displayedOverlayModule:String?
    var overlayGeometrySettler=OverlayGeometrySettler()
    var overlayGeometrySource="not sampled"
    var overlayAccessibility:LightroomHostAccessibility?
    var nextAccessibilityBind:TimeInterval=0
    var accessibilityBindingStatus="Host binding not attempted; show an overlay first."
    var lifecycleTrace:[String]=[]
    var lastLifecycleEvent=""
    var overlayBaselineWindows=Set<CGWindowID>()
    var overlayDialogVisible=false
    var overlayLifecycleStatus="Window lifecycle not sampled."
    var attemptedSelectionRefresh:String?
    var overlayEpoch:String?
    var overlaySuspended=false
    var overlayResumeAfter:TimeInterval=0
    var overlayVisibilityStatus="Overlay not shown."
    var overlayMoveCount=0
    var overlayOrderCount=0
    var overlayLevelChangeCount=0
    var livePanelSignature:String?

    func recordLifecycle(_ event:String) {
        guard event != lastLifecycleEvent else { return }
        lastLifecycleEvent=event
        lifecycleTrace.append(String(format:"%.3f ",ProcessInfo.processInfo.systemUptime)+event)
        lifecycleTrace=Array(lifecycleTrace.suffix(12))
    }
}
