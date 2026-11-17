import Foundation

/// Owned by StatusItemController: the left separator (`|`) doubles as the spacer.
protocol MenuBarSpacer: AnyObject {
    var isAvailable: Bool { get }
    /// True while the separator is widened so everything left of it is pushed off screen.
    var isExpanded: Bool { get set }
}

enum SpacerHidingFailure: LocalizedError {
    case unavailable
    case notExpanded
    case separatorOrder

    var errorDescription: String? {
        switch self {
        case .unavailable: return "The | separator is not available."
        case .notExpanded: return "The menu bar could not be collapsed."
        case .separatorOrder:
            return
                "On macOS 15–26, place | to the left of » and to the right of the icons you want to hide."
        }
    }
}

/// macOS 15–26 fallback. Widening the `|` status item pushes every icon to its left off
/// screen; restoring the standard length brings them back. No item is moved, so a crash or
/// a forced quit cannot strand icons off screen, and no event injection is involved.
final class SpacerHidingEngine: HidingEngine {
    private weak var spacer: MenuBarSpacer?
    private var lastRestriction: MenuBarRestriction?
    private(set) var lastOperationError: Error?

    var hidingMethod: HidingMethod { .legacy }
    /// The spacer covers the whole strip left of `»`, extras included.
    var unloadsMenuExtras: Bool { false }
    var requiresClockHover: Bool { false }
    var isAvailable: Bool { spacer?.isAvailable == true }

    var appliedAllowList: [String]? { requestedAllowList }
    var requestedAllowList: [String]? {
        guard spacer?.isExpanded == true else { return nil }
        return lastRestriction?.allowedBundleIDs
    }
    var requestedRestriction: MenuBarRestriction? {
        requestedAllowList == nil ? nil : lastRestriction
    }

    init(spacer: MenuBarSpacer) {
        self.spacer = spacer
    }

    func validate(_ restriction: MenuBarRestriction) throws {
        guard isAvailable else { throw SpacerHidingFailure.unavailable }
    }

    func restrict(_ restriction: MenuBarRestriction, completion: @escaping (Error?) -> Void) {
        guard let spacer, spacer.isAvailable else {
            lastOperationError = SpacerHidingFailure.unavailable
            completion(lastOperationError)
            return
        }
        lastRestriction = restriction
        spacer.isExpanded = true
        guard spacer.isExpanded else {
            lastRestriction = nil
            lastOperationError = SpacerHidingFailure.notExpanded
            completion(lastOperationError)
            return
        }
        lastOperationError = nil
        completion(nil)
    }

    func restrict(allowedBundleIDs: [String], completion: @escaping (Error?) -> Void) {
        restrict(MenuBarRestriction(allowedBundleIDs: allowedBundleIDs), completion: completion)
    }

    func release() {
        spacer?.isExpanded = false
        lastRestriction = nil
        lastOperationError = nil
    }
}
