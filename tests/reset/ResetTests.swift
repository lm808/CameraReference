import Foundation
@main struct ResetTests {
 static func main() async {
    let actor=ScreenGeometryCache()
    let old=await actor.ticket()
    await actor.reset()
    let raster=EdgeRaster(width:900,height:650,rgba:[UInt8](repeating:0,count:900*650*4))
    let stale=await actor.inspect(raster,key:"stale",ticket:old)
    precondition(stale==nil,"A capture started before clearing repopulated the cache")
    let current=await actor.ticket()
    precondition(old != current)
    let fresh=await actor.inspect(raster,key:"fresh",ticket:current)
    precondition(fresh != nil && fresh!.1==false)
    print("PASS: cache reset rejects stale captures and allows fresh requests")
 }
}
