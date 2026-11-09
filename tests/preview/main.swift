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
