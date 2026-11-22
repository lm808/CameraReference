// Preserve an explicit old choice; only genuinely new settings default to AX.
enum AutomaticPlacementMode:String,CaseIterable {
    case accessibility, screenshot
    var title:String { switch self {
    case .accessibility:return "AX only"
    case .screenshot:return "Pure screenshot"
    } }
    func usesAXViewDetection(screenshotOption:Bool)->Bool { self == .accessibility || screenshotOption }
    static func resolve(saved:String?,legacy:Bool?)->Self {
        if saved == "assisted" { return .screenshot } // Retired placement backend.
        if let saved,let mode=Self(rawValue:saved) { return mode }
        if let legacy { return legacy ? .accessibility:.screenshot }
        return .accessibility
    }
}
