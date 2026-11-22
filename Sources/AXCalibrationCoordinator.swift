import AppKit

// Dedicated workflow: selection UI returns coordinates; only this coordinator
// interprets them as calibration observations. Production placement is untouched.
final class AXCalibrationCoordinator:NSWindowController,NSWindowDelegate {
    private unowned let appCoordinator:AppDelegate
    private var samples=[AXCalibrationSample]()
    private var original=""
    private var generation=UUID()
    private var busy=false
    private var selector:CalibrationController?
    private let instructions=NSTextField(wrappingLabelWithString:"")
    private let detail=NSTextField(wrappingLabelWithString:"")
    private let select=NSButton(title:"Select region (3-second delay)",target:nil,action:nil)
    private let restart=NSButton(title:"Restart",target:nil,action:nil)
    private var proposed:[String:CGFloat]?
    private struct Evidence {
        let proposal:AXTrialProposal
        let signature:String
        let module:String
        let toolbarShown:Bool
        let fullScreen:Bool
    }
    init(appCoordinator:AppDelegate) {
        self.appCoordinator=appCoordinator
        let window=NSWindow(contentRect:CGRect(x:0,y:0,width:650,height:530),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        super.init(window:window);window.title="Guided AX calibration";window.isReleasedWhenClosed=false;window.delegate=self
        let warning=NSTextField(wrappingLabelWithString:"Developer tool — measures AX offsets using your selections. Use windowed Lightroom on one display. Select the whole working area between panels, excluding toolbars and including photo margins; for split views include BOTH panes. No manual region or detection preference is changed.")
        instructions.font = .boldSystemFont(ofSize:15)
        select.target=self;select.action=#selector(selectRegion)
        restart.target=self;restart.action=#selector(startOver)
        let close=NSButton(title:"Close",target:self,action:#selector(closeGuide))
        let buttons=NSStackView(views:[select,restart,close]);buttons.spacing=12
        let stack=NSStackView(views:[warning,instructions,detail,buttons]);stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=18
        stack.translatesAutoresizingMaskIntoConstraints=false;window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:22),stack.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-22),stack.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:22)])
        [warning,instructions,detail].forEach{$0.widthAnchor.constraint(equalToConstant:606).isActive=true}
        startOver()
    }
    required init?(coder:NSCoder) { fatalError() }
    @objc private func closeGuide() { close() }
    func windowWillClose(_ notification:Notification) {
        generation=UUID();busy=false
        if let selector,appCoordinator.calibration === selector { appCoordinator.calibration=nil;selector.finish(nil) }
        selector=nil
    }
    @objc private func startOver() {
        generation=UUID();busy=false;samples=[];proposed=nil
        do { _ = try appCoordinator.detectionSettings.reload();original=try String(contentsOf:appCoordinator.detectionSettings.url,encoding:.utf8);updateStep() }
        catch { detail.stringValue=error.localizedDescription;select.isEnabled=false }
    }
    private func updateStep() {
        instructions.stringValue="Step \(samples.count+1) of 5: "+AXCalibrationPlan.instructions[samples.count]
        detail.stringValue="Arrange Lightroom as described, keeping panel widths unchanged throughout. Then click Select region and return focus to Lightroom within 3 seconds. Drag around the combined working area. Escape cancels this measurement; earlier steps remain. Toolbar status must be confirmed by AX."
        select.title="Select region (3-second delay)";select.isEnabled=true;restart.isEnabled=true
    }
    @objc private func selectRegion() {
        guard !busy else { return }
        if proposed != nil { apply();return }
        guard appCoordinator.calibration==nil,appCoordinator.pending==nil,appCoordinator.screenInspectionID==nil else { detail.stringValue="Finish the current operation first.";return }
        busy=true;select.isEnabled=false;restart.isEnabled=false
        appCoordinator.hide();appCoordinator.cancelPanelCheck();appCoordinator.cancelScreenInspection();appCoordinator.cancelRequest()
        window?.orderOut(nil)
        let token=generation
        DispatchQueue.main.asyncAfter(deadline:.now()+3) { [weak self] in
            guard let self,self.generation==token else { return }
            guard self.appCoordinator.isLightroom() else { self.failed("Lightroom was not active. Retry and focus Lightroom during the delay.");return }
            self.readEvidence { [weak self] evidence in
                guard let self,self.generation==token else { return }
                guard self.appCoordinator.calibration==nil,self.appCoordinator.pending==nil,self.appCoordinator.screenInspectionID==nil,let evidence,self.appCoordinator.currentModule()==evidence.module,self.matchesStep(evidence) else { self.failed("AX could not confirm the required windowed module/view/panels/toolbar. Check this step and retry; no fallback toolbar state is used.");return }
                let controller=CalibrationController();self.selector=controller;self.appCoordinator.calibration=controller
                controller.completed = { [weak self] rect in
                    guard let self,self.generation==token else { return }
                    self.appCoordinator.calibration=nil;self.selector=nil
                    guard let rect else { self.failed("Measurement cancelled. Retry this step.");return }
                    self.readEvidence { [weak self] after in
                        guard let self,self.generation==token else { return }
                        guard let after,after.signature==evidence.signature,after.module==evidence.module,after.proposal.host==evidence.proposal.host,after.proposal.layout==evidence.proposal.layout,
                              after.fullScreen==evidence.fullScreen,after.toolbarShown==evidence.toolbarShown,
                              let raw=evidence.proposal.rawArea else { self.failed("Window, panels, toolbar or view changed during selection, or AX became unavailable. Retry this measurement.");return }
                        let selected=appKitRect(rect,primaryHeight:CGDisplayBounds(CGMainDisplayID()).height)
                        guard evidence.proposal.host.contains(selected) else { self.failed("Select a region entirely inside Lightroom.");return }
                        self.samples.append(AXCalibrationSample(raw:raw,selected:selected));self.busy=false
                        if self.samples.count==5 { self.review() } else { self.updateStep() }
                        self.showWindow(nil);NSApp.activate(ignoringOtherApps:true)
                    }
                }
                controller.start(snapAvailable:false,instruction:"Select the entire combined working area, including both panes in split view. Exclude toolbars; include photo margins. Esc cancels this measurement.")
            }
        }
    }
    private func readEvidence(_ done:@escaping(Evidence?)->Void) {
        let module=appCoordinator.currentModule(),settings=appCoordinator.reloadDetectionConfig()
        DispatchQueue.global(qos:.userInitiated).async {
            let toolbar=accessibilityToolbarReading(module:module)
            var result:Evidence?
            _=accessibilityMappingReport { host,windows,fullScreen in
                if let module,let fullScreen,let shown=toolbar.shown {
                    var effective=settings;effective.axToolbarState=shown ? "shown":"hidden"
                    if let proposal=axTrialProposal(host:host,windows:windows,settings:effective,module:module,fullScreen:fullScreen),
                       let state=AXPanelState(host:host,visibleFrames:windows.filter(\.visible).map(\.frame),toolbar:effective.axToolbarState) {
                        result=Evidence(proposal:proposal,signature:state.signature,module:module,toolbarShown:shown,fullScreen:fullScreen)
                    }
                }
            }
            let captured=result
            DispatchQueue.main.async { done(captured) }
        }
    }
    private func matchesStep(_ e:Evidence)->Bool {
        let index=samples.count,shown=index==0 || index>=3
        return !e.fullScreen && e.module==(index==4 ? "library":"develop") &&
            e.proposal.layout==(index>=3 ? "Side-by-side":"Single view") &&
            e.proposal.panelVisibility==AXPanelVisibility(left:shown,right:shown,top:shown,bottom:shown) && e.toolbarShown==(index != 2)
    }
    private func failed(_ message:String) {
        busy=false;detail.stringValue=message;select.isEnabled=true;restart.isEnabled=true
        showWindow(nil);NSApp.activate(ignoringOtherApps:true)
    }
    private func review() {
        do {
            let values=try AXCalibrationPlan.replacements(samples)
            let document=ConfigEditorDocument(original)
            proposed=values;instructions.stringValue="Review proposed replacements — points; right/up positive"
            detail.stringValue=AXCalibrationPlan.keys.map { key in
                let old=document.rows.last{$0.name==key}?.value ?? "missing"
                return "\(key): \(old) → \(String(format:"%.2f",Double(values[key]!)))"
            }.joined(separator:"\n")+"\n\nOnly these ten offsets change. Hidden base insets, full-screen allowance and all other settings remain. Apply creates a config backup."
            select.title="Apply offsets and back up config";select.isEnabled=true;restart.isEnabled=true
        } catch { proposed=nil;instructions.stringValue="Measurements need checking";detail.stringValue=error.localizedDescription;select.isEnabled=false;restart.isEnabled=true }
    }
    private func apply() {
        guard let proposed else { return }
        do {
            let url=appCoordinator.detectionSettings.url
            guard try String(contentsOf:url,encoding:.utf8)==original else { throw AXCalibrationPlan.failure("Config changed during calibration. Restart to load the current settings.") }
            var document=ConfigEditorDocument(original)
            for key in AXCalibrationPlan.keys {
                let matches=document.rows.indices.filter{document.rows[$0].name==key}
                guard matches.count==1 else { throw AXCalibrationPlan.failure("Config must contain exactly one \(key) entry. Check Advanced settings first.") }
                document.rows[matches[0]].value=String(format:"%.3f",locale:Locale(identifier:"en_US_POSIX"),Double(proposed[key]!))
            }
            _ = try DetectionConfig.parse(document.rendered())
            let backup=url.deletingLastPathComponent().appendingPathComponent("config.before-ax-calibration-\(UUID().uuidString).conf")
            try Data(original.utf8).write(to:backup,options:.withoutOverwriting)
            try document.save(to:url)
            _ = appCoordinator.reloadDetectionConfig();appCoordinator.invalidateAutomaticGeometry()
            self.proposed=nil;select.isEnabled=false
            instructions.stringValue="Offsets saved"
            detail.stringValue="Backup: \(backup.path)\n\nInvoke the overlay to test the new offsets. Also verify a resized window and Top/Bottom split. Full-screen title-bar allowance is not calibrated by this guide. No manual region or placement preference was changed."
        } catch { detail.stringValue=error.localizedDescription }
    }
}
extension AppDelegate {
    @objc func guidedAXCalibration() {
        guard FeaturePermission.accessibility.ensure() else { return }
        if guidedCalibration==nil { guidedCalibration=AXCalibrationCoordinator(appCoordinator:self) }
        guidedCalibration?.showWindow(nil);NSApp.activate(ignoringOtherApps:true)
    }
}
