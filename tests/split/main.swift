import Foundation
import CoreGraphics
let viewport=CGRect(x:300,y:100,width:1000,height:700)
for image in [CGSize(width:6000,height:4000),CGSize(width:4000,height:6000)] {
 let left=splitReferencePlacement(viewport:viewport,kind:.separateLeftRight,divider:800,dividerWidth:4,image:image,settings:DetectionConfig())!
 assert(left.region.minX==300 && left.region.maxX==798)
 assert(left.photo.minX>=318 && left.photo.maxX<=780 && left.photo.minY>=118 && left.photo.maxY<=782)
 let upper=splitReferencePlacement(viewport:viewport,kind:.separateUpperLower,divider:450,dividerWidth:4,image:image,settings:DetectionConfig())!
 assert(upper.photo.minY>=118 && upper.photo.maxY<=430)
 assert(abs(left.photo.width/left.photo.height-image.width/image.height)<0.0001)
}
for kind:SplitLayoutKind in [.wipe,.unknown] {
 assert(splitReferencePlacement(viewport:viewport,kind:kind,divider:800,image:CGSize(width:6000,height:4000),settings:DetectionConfig()) == nil)
}
assert(splitReferencePlacement(viewport:viewport,kind:.separateLeftRight,divider:nil,image:.zero,settings:DetectionConfig()) == nil)
assert(splitReferencePlacement(viewport:viewport,kind:.separateLeftRight,divider:350,image:CGSize(width:6000,height:4000),settings:DetectionConfig()) == nil)
print("PASS: split groundwork fits landscape/portrait in left/upper pane; rejects wipe, unknown, missing and undersized panes")

for mode in OverlayLayout.allCases {
 let pane=mode.pane(in:viewport,vertical:800,horizontal:450)!
 switch mode {
 case .full:assert(pane==viewport)
 case .left:assert(pane==CGRect(x:300,y:100,width:500,height:700))
 case .right:assert(pane==CGRect(x:800,y:100,width:500,height:700))
 case .upper:assert(pane==CGRect(x:300,y:100,width:1000,height:350))
 case .lower:assert(pane==CGRect(x:300,y:450,width:1000,height:350))
 }
 if mode != .full { assert(mode.pane(in:viewport,vertical:nil,horizontal:nil)==nil) }
}
let config=DetectionConfig()
let landscape=floatingPhotoSize(viewport:viewport.size,image:CGSize(width:6000,height:4000),settings:config)!
let portrait=floatingPhotoSize(viewport:viewport.size,image:CGSize(width:4000,height:6000),settings:config)!
assert(abs(landscape.width-464)<0.001 && abs(landscape.height-309.333333)<0.001)
assert(abs(portrait.height-664)<0.001 && abs(portrait.width-442.666667)<0.001)
let window=CGRect(x:120,y:40,width:1300,height:850)
let memory=PlacementMemory(ui:viewport,window:window,windowID:42,epoch:"A",settingsKey:config.key,layout:.full)
let moved=window.offsetBy(dx:200,dy:100)
assert(memory.translated(window:moved,windowID:42,epoch:"A",settingsKey:config.key,layout:.full)==viewport.offsetBy(dx:200,dy:100))
assert(memory.translated(window:window.insetBy(dx:1,dy:0),windowID:42,epoch:"A",settingsKey:config.key,layout:.full)==nil)
assert(memory.translated(window:window,windowID:43,epoch:"A",settingsKey:config.key,layout:.full)==nil)
assert(memory.translated(window:window,windowID:42,epoch:"B",settingsKey:config.key,layout:.full)==nil)
assert(memory.translated(window:window,windowID:42,epoch:"A",settingsKey:"changed",layout:.full)==nil)
assert(memory.translated(window:window,windowID:42,epoch:"A",settingsKey:config.key,layout:.left)==nil)
assert(memory.translated(window:window,windowID:42,epoch:nil,settingsKey:config.key,layout:.full)==nil)
let file=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("detection.conf")
let store=DetectionConfigStore(url:file)
_ = try store.reload();assert(!DetectionConfig.template.contains("overlayAnimation"))
let count=store.parseCount
_ = try store.reload();assert(store.parseCount==count)
try "overlayAnimation = true\nfitInsetPoints = 20\n".write(to:file,atomically:true,encoding:.utf8)
_ = try store.reload()
assert(store.current.fitInsetPoints==20 && store.parseCount==count+1)
try "overlayAnimation = typo".write(to:file,atomically:true,encoding:.utf8)
do { _ = try store.reload();fatalError("Invalid config accepted") } catch { assert(store.current.fitInsetPoints==20) }
try FileManager.default.removeItem(at:file.deletingLastPathComponent())
print("PASS: explicit four-pane selection, half-viewport floating fit for both orientations, placement reuse/invalidation, config caching and animation validation")

assert(!panelBoundsChanged(previous:viewport,current:viewport))
assert(panelBoundsChanged(previous:viewport,current:viewport.insetBy(dx:40,dy:0)))
assert(panelBoundsChanged(previous:viewport,current:nil))
assert(!overlayNeedsOrdering(order:[9,5,4,3],overlay:5,lightroom:4))
assert(overlayNeedsOrdering(order:[5,9,4,3],overlay:5,lightroom:4))
assert(overlayNeedsOrdering(order:[9,4,5,3],overlay:5,lightroom:4))
assert(overlayNeedsOrdering(order:[9,4,3],overlay:5,lightroom:4))
assert(!overlayNeedsOrdering(order:[9,5,3],overlay:5,lightroom:4))
print("PASS: panel changes invalidate placement; overlay ordering preserves windows above Lightroom")

assert(try! DetectionConfig.parse("").panelCheckIntervalSeconds == 3)
assert(try! DetectionConfig.parse("panelCheckIntervalSeconds = 0").panelCheckIntervalSeconds == 0)
assert(try! DetectionConfig.parse("panelCheckIntervalSeconds = 12").panelCheckIntervalSeconds == 12)
do { _ = try DetectionConfig.parse("panelCheckIntervalSeconds = -1");fatalError("Negative interval accepted") } catch {}
assert(!panelBoundsChanged(previous:viewport,current:viewport.offsetBy(dx:2,dy:2),tolerance:4))
assert(panelBoundsChanged(previous:viewport,current:viewport.offsetBy(dx:10,dy:0),tolerance:4))
print("PASS: panel interval defaults/off/range and low-resolution quantisation tolerance")

let migrationDirectory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at:migrationDirectory,withIntermediateDirectories:true)
let legacyFile=migrationDirectory.appendingPathComponent("detection.conf")
let configFile=migrationDirectory.appendingPathComponent("config.conf")
try "# my settings\nleft = ui\nright = ui\ntop = ui\nbottom = ui\nsideSearchPercent = 30\npanelCheckIntervalSeconds = 0\n".write(to:legacyFile,atomically:true,encoding:.utf8)
let migrated=try DetectionConfigStore(url:configFile).reload()
assert(migrated.sideSearchPercent==30 && migrated.panelCheckIntervalSeconds==0)
assert([migrated.left,migrated.right,migrated.top,migrated.bottom].allSatisfy{$0 == .ui})
assert(FileManager.default.fileExists(atPath:legacyFile.path))
try "top = photo\nbottom = photo\nsideSearchPercent = 35\n".write(to:configFile,atomically:true,encoding:.utf8)
let retained=try DetectionConfigStore(url:configFile).reload()
assert(retained.sideSearchPercent==35 && retained.top == .photo && retained.bottom == .photo)
try FileManager.default.removeItem(at:migrationDirectory)
print("PASS: config.conf migration preserves existing values and legacy backup; existing config wins")

let defaults=try DetectionConfig.parse(DetectionConfig.template)
assert(defaults == DetectionConfig())
assert(defaults.sideSearchPercent == 40 && [defaults.left,defaults.right,defaults.top,defaults.bottom].allSatisfy{$0 == .ui})

// Front-to-back window list. Lightroom child windows need not be adjacent
// to their host; foreign windows must still cover the reference.
let lrWindows:Set<Int>=[4,6,7]
assert(!overlayNeedsOrdering(order:[9,5,6,7,4],overlay:5,lightroom:4,lightroomWindows:lrWindows))
assert(!overlayNeedsOrdering(order:[6,9,5,7,4],overlay:5,lightroom:4,lightroomWindows:lrWindows))
assert(overlayNeedsOrdering(order:[5,6,9,7,4],overlay:5,lightroom:4,lightroomWindows:lrWindows))
assert(overlayNeedsOrdering(order:[9,6,4,5],overlay:5,lightroom:4,lightroomWindows:lrWindows))
assert(!overlayNeedsOrdering(order:[9,6,5,4],overlay:5,lightroom:4,lightroomWindows:lrWindows))
let freshDirectory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
let freshFile=freshDirectory.appendingPathComponent("config.conf")
let fresh=try DetectionConfigStore(url:freshFile).reload()
assert(fresh.sideSearchPercent == 40)
try FileManager.default.removeItem(at:freshDirectory)
print("PASS: Lightroom child windows do not cause reordering; foreign windows retain precedence; new installs default to 40")

for (layout,expected) in [(OverlayLayout.full,"Loupe View ▣"),(.left,"left ◧"),(.right,"right ◨"),(.upper,"top pane ⬒"),(.lower,"bottom pane ⬓")] {
    let text=calibrationInstructions(layout:layout,automatic:true)
    assert(text.contains(expected) && text.contains("Cancelling keeps auto-detection and the saved region."))
}
let manualInstructions=calibrationInstructions(layout:.left,automatic:false)
assert(!manualInstructions.contains("Auto-detection expects") && manualInstructions.contains("Cancelling keeps manual mode and the saved region."))
print("PASS: calibration guidance reflects selected layout/pane and preserves mode wording")

for ax in [false,true] { for auto in [false,true] { for live in [false,true] {
    for panels in [false,true] { for from in OverlayLayout.allCases { for to in OverlayLayout.allCases {
        let result=axOverlayChangeAction(accessibility:ax,automatic:auto,displayed:from,selected:to,panelsChanged:panels,live:live)
        let changed=ax && auto && (from != to || panels)
        assert(result == (changed ? (live ? .adjust:.dismiss):.retain))
    } } }
    assert(axOverlayChangeAction(accessibility:ax,automatic:auto,displayed:nil,selected:.left,panelsChanged:true,live:live) == .retain)
} } }
print("PASS: AX-only live policy covers view, pane and panels; screenshot/manual/off overlays remain untouched")

for ax in [false,true] { for auto in [false,true] { for open in [false,true] { for live in [false,true] {
    for previous in [nil,"A"] as [String?] { for current in [nil,"A","B"] as [String?] {
        let changed=ax && auto && open && previous != nil && current != nil && previous != current
        assert(axSelectionChangeAction(accessibility:ax,automatic:auto,overlayOpen:open,previous:previous,current:current,live:live) == (changed ? (live ? .adjust:.dismiss):.retain))
    } }
} } } }
print("PASS: photo-selection policy ignores uncertainty, unchanged selection, off/manual/screenshot overlays")


// Qualifying observations remains with callers; pure policy must preserve unknowns.
for previous in [nil,"library","develop","map"] as [String?] {
    for current in [nil,"library","develop","map"] as [String?] {
        let expected=previous != nil && current != nil && previous != current
        assert(OverlayBehaviourPolicy.moduleChanged(previous:previous,current:current)==expected)
    }
}
for evidence in [nil,false,true] as [Bool?] {
    assert(OverlayBehaviourPolicy.isGridSelected(evidence)==(evidence == true))
}
for screenshot in [false,true] {
    assert(OverlayBehaviourPolicy.dismissForExplicitSelection(screenshot:screenshot)==screenshot)
}
// Same observations have deliberately different consequences by event/mode.
assert(OverlayBehaviourPolicy.geometryChange(accessibility:true,automatic:true,displayed:.full,selected:.left,panelsChanged:false,live:true) == .adjust)
assert(OverlayBehaviourPolicy.geometryChange(accessibility:false,automatic:true,displayed:.full,selected:.left,panelsChanged:true,live:true) == .retain)
assert(OverlayBehaviourPolicy.photoSelectionChange(accessibility:true,automatic:true,overlayOpen:false,previous:"A",current:"B",live:false) == .retain)
let policyHost=CGRect(x:100,y:100,width:1000,height:700)
assert(OverlayBehaviourPolicy.hostChange(saved:policyHost,current:nil,onScreen:false,overview:false) == .retain)
assert(OverlayBehaviourPolicy.hostChange(saved:policyHost,current:nil,onScreen:false,overview:true) == .suspend)
assert(OverlayBehaviourPolicy.hostChange(saved:policyHost,current:policyHost.offsetBy(dx:-500,dy:0),onScreen:true,overview:false) == .translate(CGPoint(x:-500,y:0)))
print("PASS: pure policy module/Grid unknowns, explicit selection, absent overlay and off-screen translation")
