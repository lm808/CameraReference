import AppKit
let view=ReferenceView(frame:CGRect(x:0,y:0,width:400,height:300))
view.allowsReferenceActions=false
view.image=NSImage(size:CGSize(width:400,height:300))
let event=NSEvent.mouseEvent(with:.rightMouseDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:0,context:nil,eventNumber:0,clickCount:1,pressure:1)!
let menu=view.menu(for:event)!
precondition(menu.items.count==2 && menu.items[0].title=="Fit" && menu.items[1].title.hasPrefix("100%"))
view.releaseContent()
precondition(view.image==nil && view.exportSnapshot==nil && view.menu(for:event)==nil)
print("PASS: capture preview has only Fit/100% actions and releases image content")

precondition(view.gestureRecognizers.isEmpty)
precondition(view.acceptsFirstResponder && view.needsPanelToBecomeKey)
print("PASS: shared image view has no gesture recognizers and accepts panel focus")

let app=NSApplication.shared
app.setActivationPolicy(.prohibited)
let floating=FloatingPanel(contentRect:CGRect(x:0,y:0,width:500,height:400),styleMask:[.titled,.closable,.resizable,.nonactivatingPanel,.fullSizeContentView],backing:.buffered,defer:false)
let photo=ReferenceView(frame:CGRect(x:0,y:0,width:500,height:400))
photo.autoresizingMask=[.width,.height];photo.movesWindowAtFit=true
floating.contentView=photo
floating.setFrame(CGRect(x:0,y:0,width:500,height:400),display:false)
floating.installChrome()
precondition(abs(photo.bounds.width-500)<1 && abs(photo.bounds.height-400)<1,"Full-size photo must fill requested dimensions")
let before=photo.bounds
floating.revealChrome(true);floating.revealChrome(false)
precondition(photo.bounds==before,"Chrome must not resize or shift the photo")
print("PASS: floating full-size photo geometry and stable hover chrome")
