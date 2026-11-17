import Foundation

enum HidingMethod: String, CaseIterable {
    case assessment
    case systemSettings
    case legacy

    var title: String {
        switch self {
        case .assessment: return "Compatibility"
        case .systemSettings: return "System Settings (Experimental)"
        case .legacy: return "Legacy Spacer (macOS 15–26)"
        }
    }

    /// Before macOS 27 the menu bar belongs to Control Center, so the two private
    /// allow-list methods have nothing to talk to. The spacer works there and on 27.
    static func supported(onMajorVersion majorVersion: Int) -> [HidingMethod] {
        majorVersion >= 27 ? [.assessment, .systemSettings] : [.legacy]
    }

    static var supportedOnThisMac: [HidingMethod] {
        supported(onMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
    }
}
