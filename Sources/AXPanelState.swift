import Foundation
import CoreGraphics

// Structural signature for existing AX view/panel change monitoring only.
// Never supplies screenshot placement geometry.
struct AXPanelState {
    let host:CGRect
    let signature:String
    init?(host:CGRect,visibleFrames:[CGRect],toolbar:String) {
        guard host.width>200,host.height>200 else { return nil }
        let visible=visibleFrames.filter { host.contains($0) && $0 != host }
        let sides=visible.filter {
            $0.height>host.height*0.5 && $0.width>0 &&
            ((abs($0.minX-host.minX)<4) != (abs($0.maxX-host.maxX)<4))
        }
        let strips=visible.filter { $0.width>host.width*0.9 && $0.height<host.height*0.25 }
        let edges=[sides.filter { abs($0.minX-host.minX)<4 }.map(\.maxX).max() ?? host.minX,
               sides.filter { abs($0.maxX-host.maxX)<4 }.map(\.minX).min() ?? host.maxX,
               strips.filter { $0.midY<host.minY+host.height*0.25 }.map(\.maxY).max() ?? host.minY,
               strips.filter { $0.midY>host.minY+host.height*0.75 }.map(\.minY).min() ?? host.maxY]
        guard edges[1]>edges[0],edges[3]>edges[2] else { return nil }
        self.host=host
        // Host position deliberately excluded: translation does not change layout.
        let panels=(sides+strips).map { NSStringFromRect($0.offsetBy(dx:-host.minX,dy:-host.minY)) }.sorted()
        signature="\(host.size):\(panels):toolbar=\(toolbar)"
    }
}
