import AppKit

// Measurement workflow owns evidence and persistence. Shared selector/countdown
// only present UI; AXCalibrationPlan owns the independent calibration mathematics.
final class AXCalibrationCoordinator:NSWindowController,NSWindowDelegate {
    private unowned let appCoordinator:AppDelegate
    private var samples=[Int:AXCalibrationSample]()
    private var evidenceByStep=[Int:Evidence]()
    private var photo:CGRect?
    private var original=""
    private var generation=UUID()
    private var busy=false
    private var selector:CalibrationController?
    private var countdown:SelectionCountdown?
    private let status=NSTextField(wrappingLabelWithString:"")
    private let reviewText=NSTextField(wrappingLabelWithString:"")
    private var buttons=[NSButton](),marks=[NSTextField]()
    private let photoButton=NSButton(title:"Select photo bounds",target:nil,action:nil)
    private let photoMark=NSTextField(labelWithString:"Not measured")
    private let applyButton=NSButton(title:"Apply and back up config",target:nil,action:nil)
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
        let window=NSWindow(contentRect:CGRect(x:0,y:0,width:850,height:760),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        super.init(window:window);window.title="Guided AX calibration";window.isReleasedWhenClosed=false;window.delegate=self
        window.minSize=CGSize(width:760,height:600)
        let warning=NSTextField(wrappingLabelWithString:"Measure six setups on one display. Keep panel widths unchanged. Select the whole working area, including BOTH panes in split views and photo margins, excluding toolbars. Select hides this window for a three-second countdown; return to Lightroom. Hold Option to snap. Escape preserves the previous measurement. No manual region or detection preference is changed.")
        let fit=NSTextField(wrappingLabelWithString:"For setup 1 photo bounds: use Fit and an untransformed photo matching the camera JPEG (no crop or perspective edits). Select the actual photo edges. Keep this setup unchanged between its two measurements.")
        let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=10
        stack.addArrangedSubview(warning)
        for (index,text) in AXCalibrationPlan.instructions.enumerated() {
            let label=NSTextField(wrappingLabelWithString:"\(index+1). "+text);label.widthAnchor.constraint(equalToConstant:480).isActive=true
            let button=NSButton(title:"Select area",target:self,action:#selector(selectRegion(_:)));button.tag=index
            let mark=NSTextField(labelWithString:"Not measured");mark.widthAnchor.constraint(equalToConstant:100).isActive=true
            buttons.append(button);marks.append(mark)
            let row=NSStackView(views:[label,button,mark]);row.spacing=10;stack.addArrangedSubview(row)
            if index==0 {
                photoButton.target=self;photoButton.action=#selector(selectRegion(_:));photoButton.tag=6
                stack.addArrangedSubview(fit)
                stack.addArrangedSubview(NSStackView(views:[photoButton,photoMark]))
            }
        }
        status.textColor = .systemRed
        reviewText.font = .monospacedSystemFont(ofSize:12,weight:.regular)
        stack.addArrangedSubview(status);stack.addArrangedSubview(reviewText)
        let reset=NSButton(title:"Reset measurements",target:self,action:#selector(startOver))
        let close=NSButton(title:"Close",target:self,action:#selector(closeGuide))
        applyButton.target=self;applyButton.action=#selector(apply)
        stack.addArrangedSubview(NSStackView(views:[reset,applyButton,close]))
        let scroll=NSScrollView();scroll.hasVerticalScroller=true;scroll.documentView=stack
        scroll.translatesAutoresizingMaskIntoConstraints=false;stack.translatesAutoresizingMaskIntoConstraints=false
        window.contentView!.addSubview(scroll)
        NSLayoutConstraint.activate([scroll.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:18),scroll.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-18),scroll.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:18),scroll.bottomAnchor.constraint(equalTo:window.contentView!.bottomAnchor,constant:-18),stack.leadingAnchor.constraint(equalTo:scroll.contentView.leadingAnchor),stack.topAnchor.constraint(equalTo:scroll.contentView.topAnchor),stack.widthAnchor.constraint(equalTo:scroll.contentView.widthAnchor)])
        for text in [warning,fit,status,reviewText] { text.widthAnchor.constraint(equalTo:stack.widthAnchor).isActive=true }
        startOver();window.center()
    }
    required init?(coder:NSCoder) { fatalError() }
    @objc private func closeGuide() { close() }
    func windowWillClose(_ notification:Notification) { cancelOperation();refreshReview() }
    private func cancelOperation() {
        generation=UUID();busy=false;countdown?.cancel();countdown=nil
        if let selector,appCoordinator.calibration === selector {
            appCoordinator.calibrationTask?.cancel();appCoordinator.calibrationTask=nil
            appCoordinator.calibrationTimer?.invalidate();appCoordinator.calibrationTimer=nil
            appCoordinator.calibration=nil;selector.finish(nil)
        }
        selector=nil
    }
    @objc private func startOver() {
        cancelOperation();samples=[:];evidenceByStep=[:];photo=nil;proposed=nil
        do { _ = try appCoordinator.detectionSettings.reload();original=try String(contentsOf:appCoordinator.detectionSettings.url,encoding:.utf8);refreshReview() }
        catch { failed(error.localizedDescription) }
    }
    private func refreshReview() {
        for index in 0..<6 { buttons[index].title=samples[index]==nil ? "Select area":"Reselect area";buttons[index].isEnabled = !busy;marks[index].stringValue=samples[index]==nil ? "Not measured":"Measured" }
        photoButton.isEnabled = !busy && samples[0] != nil;photoButton.title=photo==nil ? "Select photo bounds":"Reselect photo bounds";photoMark.stringValue=photo==nil ? "Not measured":"Measured"
        proposed=nil;applyButton.isEnabled=false;reviewText.stringValue=""
        do {
            let settings=try DetectionConfig.parse(original)
            let values=try AXCalibrationPlan.complete(samples,photo:photo,baseHiddenTop:settings.axBaseHiddenTopInsetPoints)
            proposed=values
            let document=ConfigEditorDocument(original)
            reviewText.stringValue="Proposed values — points; offsets right/up positive\n"+AXCalibrationPlan.keys.map { key in
                let old=document.rows.last{$0.name==key}?.value ?? "missing"
                return "\(key): \(old) → \(String(format:"%.2f",Double(values[key]!)))"
            }.joined(separator:"\n")
            status.textColor = .labelColor;status.stringValue="All checks passed. Review the 12 values before Apply; a backup is created."
            applyButton.isEnabled = !busy
        } catch { status.textColor = .systemRed;status.stringValue=error.localizedDescription }
    }
    @objc private func selectRegion(_ sender:NSButton) {
        guard !busy,appCoordinator.calibration==nil,appCoordinator.pending==nil,appCoordinator.screenInspectionID==nil else { return }
        let index=sender.tag,step=index==6 ? 0:index
        busy=true;refreshReview()
        appCoordinator.hide();appCoordinator.cancelPanelCheck();appCoordinator.cancelScreenInspection();appCoordinator.cancelRequest()
        window?.orderOut(nil)
        let token=generation
        let countdown=SelectionCountdown();self.countdown=countdown
        countdown.start { [weak self] ready in
            guard let self,self.generation==token else { return };self.countdown=nil
            guard ready else { self.failed("Countdown cancelled; previous measurements retained.");return }
            // Let the countdown disappear before screen-edge capture starts.
            DispatchQueue.main.asyncAfter(deadline:.now()+0.15) { [weak self] in
                guard let self,self.generation==token else { return }
                guard self.appCoordinator.isLightroom() else { self.failed("Lightroom was not active. Retry and focus Lightroom during the countdown.");return }
                self.readEvidence { [weak self] evidence in
                    guard let self,self.generation==token else { return }
                    guard self.appCoordinator.calibration==nil,self.appCoordinator.pending==nil,self.appCoordinator.screenInspectionID==nil,let evidence,self.appCoordinator.currentModule()==evidence.module,self.matchesStep(evidence,index:step) else { self.failed("Setup \(step+1): AX could not confirm the required module/view/panels/toolbar/full-screen state. Previous measurement retained.");return }
                    if index==6,let previous=self.evidenceByStep[0],!self.sameEvidence(previous,evidence) {
                        self.failed("Setup 1 geometry changed. Reselect its working area before measuring photo bounds.");return
                    }
                    let controller=CalibrationController();self.selector=controller;self.appCoordinator.calibration=controller
                    controller.completed = { [weak self] rect in
                        guard let self,self.generation==token else { return }
                        self.appCoordinator.calibrationTask?.cancel();self.appCoordinator.calibrationTask=nil
                        self.appCoordinator.calibrationTimer?.invalidate();self.appCoordinator.calibrationTimer=nil
                        self.appCoordinator.calibration=nil;self.selector=nil
                        guard let rect else { self.failed("Selection cancelled; previous measurements retained.");return }
                        self.readEvidence { [weak self] after in
                            guard let self,self.generation==token else { return }
                            guard let after,self.sameEvidence(evidence,after),let raw=evidence.proposal.rawArea else { self.failed("Setup \(step+1) changed during selection. Previous measurement retained; retry.");return }
                            let selected=appKitRect(rect,primaryHeight:CGDisplayBounds(CGMainDisplayID()).height)
                            guard evidence.proposal.host.contains(selected) else { self.failed("Select entirely inside Lightroom. Previous measurement retained.");return }
                            if index==6 { self.photo=selected } else {
                                if index==0,let previous=self.evidenceByStep[0],!self.sameEvidence(previous,evidence) { self.photo=nil }
                                self.samples[index]=AXCalibrationSample(raw:raw,selected:selected);self.evidenceByStep[index]=evidence
                            }
                            self.busy=false;self.refreshReview();self.showWindow(nil);NSApp.activate(ignoringOtherApps:true)
                        }
                    }
                    let instruction=index==6 ? "Select the actual PHOTO edges at Fit, excluding margins. Use a photo matching its untransformed camera JPEG.":"Select the entire WORKING AREA, including both panes in split view. Exclude toolbars; include photo margins."
                    self.appCoordinator.prepareCalibrationSelection(controller,settings:self.appCoordinator.reloadDetectionConfig(),instruction:instruction)
                }
            }
        }
    }
    private func sameEvidence(_ a:Evidence,_ b:Evidence)->Bool {
        a.signature==b.signature && a.module==b.module && a.proposal.host==b.proposal.host && a.proposal.rawArea==b.proposal.rawArea && a.proposal.layout==b.proposal.layout && a.fullScreen==b.fullScreen && a.toolbarShown==b.toolbarShown
    }
    private func matchesStep(_ e:Evidence,index:Int)->Bool {
        let shown=index==0 || index==3 || index==4
        return e.fullScreen==(index==5) && e.module==(index==4 ? "library":"develop") &&
            e.proposal.layout==((index==3 || index==4) ? "Side-by-side":"Single view") &&
            e.proposal.panelVisibility==AXPanelVisibility(left:shown,right:shown,top:shown,bottom:shown) && e.toolbarShown==(index != 2 && index != 5)
    }
    private func failed(_ message:String) {
        busy=false;refreshReview();status.textColor = .systemRed;status.stringValue=message
        showWindow(nil);NSApp.activate(ignoringOtherApps:true)
    }
    private func readEvidence(_ done:@escaping(Evidence?)->Void) {
        let module=appCoordinator.currentModule(),settings=appCoordinator.reloadDetectionConfig()
        DispatchQueue.global(qos:.userInitiated).async {
            let toolbar=accessibilityToolbarReading(module:module)
            var result:Evidence?
            _=accessibilityMappingReport { host,windows,fullScreen in
                if let module,let fullScreen,let shown=toolbar.shown {
                    var effective=settings;effective.axFullScreenTitleBarAllowancePoints=0;effective.axToolbarState=shown ? "shown":"hidden"
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
    @objc private func apply() {
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
            self.proposed=nil;applyButton.isEnabled=false
            original=try String(contentsOf:url,encoding:.utf8)
            status.textColor = .labelColor;status.stringValue="Offsets saved. Backup: \(backup.path)\n\nInvoke the overlay to test the new offsets. Also verify a resized window and Top/Bottom split. No manual region or placement preference was changed."
        } catch { status.textColor = .systemRed;status.stringValue=error.localizedDescription }
    }
}
extension AppDelegate {
    @objc func guidedAXCalibration() {
        guard FeaturePermission.accessibility.ensure() else { return }
        if guidedCalibration==nil { guidedCalibration=AXCalibrationCoordinator(appCoordinator:self) }
        guidedCalibration?.showWindow(nil);NSApp.activate(ignoringOtherApps:true)
    }
}
