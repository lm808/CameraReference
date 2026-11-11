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

precondition(floatingDragMovesWindow(zoom:1,inTitleBar:false))
precondition(!floatingDragMovesWindow(zoom:2,inTitleBar:false))
precondition(floatingDragMovesWindow(zoom:2,inTitleBar:true))
var masks=Set<Data>()
for layout in OverlayLayout.allCases {
    let icon=layoutMenuIcon(layout)
    precondition(icon.isTemplate && icon.size==CGSize(width:22,height:16))
    let cg=icon.cgImage(forProposedRect:nil,context:nil,hints:nil)!
    let data=cg.dataProvider!.data! as Data
    precondition(data.contains(where:{$0 != 0}),"Empty menu diagram")
    masks.insert(data)
}
precondition(masks.count==5,"Pane diagrams must be distinct")
print("PASS: five nonempty distinct menu diagrams and title-bar drag at any zoom")

// Pixel-level regression: zoom must draw into margins outside the Fit rectangle.
let zoomView=ReferenceView(frame:CGRect(x:0,y:0,width:400,height:300))
zoomView.imageViewport=CGRect(x:100,y:100,width:200,height:100)
let redContext=CGContext(data:nil,width:200,height:100,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
redContext.setFillColor(CGColor(red:1,green:0,blue:0,alpha:1));redContext.fill(CGRect(x:0,y:0,width:200,height:100))
zoomView.image=NSImage(cgImage:redContext.makeImage()!,size:CGSize(width:200,height:100))
func renderZoom(_ zoom:CGFloat)->NSBitmapImageRep {
    let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:400,pixelsHigh:300,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    zoomView.navigation.zoom=zoom
    NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
    zoomView.draw(zoomView.bounds);NSGraphicsContext.restoreGraphicsState()
    return bitmap
}
let fitRender=renderZoom(1),zoomRender=renderZoom(2)
precondition(fitRender.colorAt(x:20,y:150)!.redComponent<0.1)
precondition(fitRender.colorAt(x:200,y:150)!.redComponent>0.9)
precondition(zoomRender.colorAt(x:20,y:150)!.redComponent>0.9)
print("PASS: zoom draws across the full region while Fit retains its original rectangle")
