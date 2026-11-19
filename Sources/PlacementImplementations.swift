import AppKit

/// Shared UI area in global AppKit points. Do not confuse with the photo Fit
/// rectangle or a capture-local pixel rectangle. Probe metadata remains intact.
struct UIPlacement {
    let areaAppKit:CGRect
    init(areaAppKit:CGRect) { self.areaAppKit=areaAppKit }
    init?(probe:ScreenProbeResult) {
        guard let area=probe.uiFrame else { return nil }
        self.areaAppKit=area
    }
}

enum ManualPlacement {
    static func translate(_ rect:CGRect,from saved:CGRect,to current:CGRect)->UIPlacement? {
        translatedCalibration(rect,from:saved,to:current).map { UIPlacement(areaAppKit:$0) }
    }
}

enum AXPlacement {
    static func selectedArea(_ proposal:AXTrialProposal,layout:OverlayLayout,primaryHeight:CGFloat)->(topLeft:CGRect,placement:UIPlacement)? {
        guard let area=axSelectedArea(proposal,layout:layout) else { return nil }
        return (area,UIPlacement(areaAppKit:appKitRect(area,primaryHeight:primaryHeight)))
    }
}

// Keep the nil-hint route explicit. Neither adapter modifies the original
// detector, capture normalization, split scanning or failure metadata.
enum ScreenshotPlacement {
    @available(macOS 14.0, *)
    static func inspect(imageSize:CGSize,previewCapture:Bool,settings:DetectionConfig,layout:OverlayLayout,seed:CGRect?) async -> ScreenProbeResult {
        await inspectScreenLayout(imageSize:imageSize,previewCapture:previewCapture,settings:settings,layout:layout,seed:seed,axHints:nil)
    }
}
enum AssistedScreenshotPlacement {
    @available(macOS 14.0, *)
    static func inspect(imageSize:CGSize,previewCapture:Bool,settings:DetectionConfig,layout:OverlayLayout,seed:CGRect?,hints:AXScreenHints?) async -> ScreenProbeResult {
        await inspectScreenLayout(imageSize:imageSize,previewCapture:previewCapture,settings:settings,layout:layout,seed:seed,axHints:hints)
    }
}
