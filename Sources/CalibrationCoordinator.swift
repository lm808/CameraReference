import AppKit
import ApplicationServices

// App-facing actions grouped by responsibility. Existing guard, callback and
// effect order is preserved; shared operation identities belong to composition.
extension AppDelegate {
    @objc func calibrate() { beginCalibration() }
    func beginCalibration(proposal requestedProposal:CGRect? = nil, useManualOnAccept:Bool = false) {
        guard requireSupportedModule() else { return }
        guard !regionResetting else { return }
        cancelPanelCheck()
        cancelScreenInspection(); hide(); cancelRequest(); calibration?.finish(nil)
        let settings=reloadDetectionConfig()
        let proposal=requestedProposal == nil ? nil:lastProbe?.uiFrame
        let selectionKind="ui"
        let calibrationModule=currentModule()
        let controller=CalibrationController();controller.snapRadius=settings.snapDistancePoints; calibration=controller
        controller.completed = { [weak self] result in
            guard let self else { return }
            self.calibrationTask?.cancel(); self.calibrationTask=nil
            self.calibrationTimer?.invalidate();self.calibrationTimer=nil
            self.calibration=nil
            if let result {
                guard self.currentModule()==calibrationModule else { self.report("Module changed; calibration was not saved.");return }
                guard let window=lightroomWindowFrame(),window.contains(result) else {
                    self.report("Select the UI backdrop inside the Lightroom window. Previous calibration retained.");return
                }
                // Accepting calibration makes this selected pane the manual region too.
                if self.automaticViewEnabled { let selected=self.overlayLayout;self.overlayLayout=selected }
                self.region=result; self.manualLayoutKey=self.lastProbe?.layoutKey
                CameraPreferences.shared.set(selectionKind,forKey:self.regionKey("regionKind"))
                CameraPreferences.shared.set(false,forKey:self.regionKey("automaticBounds")); self.autoItem.state = .off
                self.invalidateAutomaticGeometry()
                self.report("Image region saved. Shortcut toggles the reference.")
            }
            else { self.report("Calibration cancelled. Previous region retained.") }
        }
        prepareCalibrationSelection(controller,proposal:proposal,settings:settings)
    }
    // Shared selection preparation only. Each workflow owns its completion,
    // interpretation and persistence; no placement preference is changed here.
    func prepareCalibrationSelection(_ controller:CalibrationController,proposal:CGRect?=nil,settings:DetectionConfig,instruction:String?=nil) {
        guard calibration === controller else { return }
        controller.snapRadius=settings.snapDistancePoints
        guard #available(macOS 14.0,*),FeaturePermission.screenCapture.granted else {
            if calibration === controller { controller.start(proposal:proposal,snapAvailable:false,permissionUnavailable:!FeaturePermission.screenCapture.granted,instruction:instruction) }; return
        }
        guard calibration === controller else { return }
        report("Preparing calibration edges…")
        // Timeout enters free calibration; a late capture cannot replace it.
        calibrationTimer=Timer(timeInterval:3,repeats:false) { [weak self,weak controller] _ in
            guard let self,let controller,self.calibration === controller else { return }
            self.calibrationTask?.cancel();self.calibrationTask=nil;self.calibrationTimer=nil
            controller.start(proposal:proposal,snapAvailable:false,instruction:instruction)
        }
        RunLoop.main.add(calibrationTimer!,forMode:.common)
        calibrationTask=Task.detached(priority:.userInitiated) { [weak self,weak controller] in
            let result=await inspectScreenLayout(imageSize:.zero,forCalibration:true,settings:settings)
            guard !Task.isCancelled,let controller else { return }
            await self?.finishCalibrationPreparation(result,controller:controller,proposal:proposal,instruction:instruction)
        }
    }
    @MainActor func finishCalibrationPreparation(_ result:ScreenProbeResult,controller:CalibrationController,proposal:CGRect?,instruction:String?=nil) {
        guard calibration === controller,calibrationTimer != nil else { return }
        calibrationTimer?.invalidate();calibrationTimer=nil;calibrationTask=nil
        lastLayout=result.summary
        controller.start(proposal:proposal,edges:result.snapEdges,snapAvailable:!result.snapEdges.isEmpty,permissionUnavailable:result.failureReason == .permissionUnavailable,instruction:instruction)
    }
    @objc func clearAllRegionData() {
        guard !regionResetting else { return };regionResetting=true
        calibration?.finish(nil);calibrationTask?.cancel();calibrationTask=nil
        calibrationTimer?.invalidate();calibrationTimer=nil
        cancelPanelCheck()
        cancelScreenInspection();cancelRequest();hide();saveToast.close();capturePreview?.close();capturePreview=nil
        clearRegionPreferences(CameraPreferences.shared,layout:overlayLayout,modulePrefix:currentModule() == "library" ? "library.":"")
        placementMemory=nil
        acceptedSplitKey=nil;lastProbe=nil;lastImageSize=nil
        lastLayout="No region data. Detection/calibration starts fresh."
        report("Clearing region data…")
        Task { @MainActor [weak self] in
            await ScreenGeometryCache.shared.reset()
            guard let self else { return };self.regionResetting=false
            self.report("Region cleared for this layout/pane. Automatic detection preference unchanged.")
        }
    }
    func askForCalibration(workingAreaTooNarrow:Bool = false,reason:String? = nil) {
        let alert=NSAlert();alert.icon=NSApp.applicationIconImage
        alert.messageText="Cannot reliably identify viewing area."
        let automatic=CameraPreferences.shared.bool(forKey:regionKey("automaticBounds"))
        alert.informativeText=(reason.map { $0 + "\n\n" } ?? "") + (workingAreaTooNarrow ? "Working area too narrow—enlarge it or calibrate manually.\n\n":"") + calibrationInstructions(layout:overlayLayout,automatic:automatic)
        if automatic { alert.informativeText += "\n\nIf detection keeps failing with Lightroom partly off-screen, try restarting Lightroom Classic." }
        lastPlacementFailure="Recorded: \(Date()). Module: \(currentModule() ?? "unknown"); view: \(overlayLayout.viewName); pane: \(overlayLayout.label); method: \(automaticPlacementMode.title); automatic: \(automatic).\n" + alert.informativeText + "\n\nCalculation at failure:\n" + (automatic ? lastLayout:"Manual region missing or no longer valid; automatic detection was not attempted.") + "\n\nTiming at failure: " + lastTiming
        lastResult="Placement unavailable; manual calibration offered."
        // Save synchronously before entering the modal loop. Keep this failure
        // snapshot separate from subsequent successful placements and AX refreshes.
        saveInvocationDiagnostics()
        alert.addButton(withTitle:"Calibrate manually…"); alert.addButton(withTitle:"Cancel")
        NSApp.activate(ignoringOtherApps:true)
        if alert.runModal() == .alertFirstButtonReturn {
            beginCalibration(useManualOnAccept:true)
        } else { report("Overlay cancelled; calibration was not changed.") }
    }
}
