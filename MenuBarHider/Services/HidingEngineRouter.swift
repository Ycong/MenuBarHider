import Foundation

enum HidingMethodFailure: LocalizedError {
    case unavailable(HidingMethod)

    var errorDescription: String? {
        switch self {
        case .unavailable(let method):
            return "\(method.title) is unavailable on this macOS version."
        }
    }
}

final class HidingEngineRouter: HidingEngine {
    private let settings: Settings
    private let assessment: HidingEngine
    private let native: NativeHidingEngine
    private let spacer: HidingEngine
    private let availableMethods: [HidingMethod]
    private var recoveryError: Error?
    private var selectionError: Error?
    private(set) var method: HidingMethod

    init(
        settings: Settings, assessment: HidingEngine, native: NativeHidingEngine, spacer: HidingEngine,
        availableMethods: [HidingMethod] = HidingMethod.supportedOnThisMac
    ) {
        self.settings = settings
        self.assessment = assessment
        self.native = native
        self.spacer = spacer
        self.availableMethods = availableMethods
        let stored = settings.hidingMethod
        method = availableMethods.contains(stored) ? stored : (availableMethods.first ?? stored)
        do { try recoverNative() } catch { recoveryError = error }
    }

    private var current: HidingEngine {
        switch method {
        case .assessment: return assessment
        case .systemSettings: return native
        case .legacy: return spacer
        }
    }

    var isAvailable: Bool { recoveryError == nil && current.isAvailable }
    var appliedAllowList: [String]? { current.appliedAllowList }
    var requestedAllowList: [String]? { current.requestedAllowList }
    var requestedRestriction: MenuBarRestriction? { current.requestedRestriction }
    func validate(_ restriction: MenuBarRestriction) throws { try current.validate(restriction) }
    var requiresClockHover: Bool { current.requiresClockHover }
    var hidingMethod: HidingMethod { method }
    var unloadsMenuExtras: Bool { current.unloadsMenuExtras }
    var lastOperationError: Error? { recoveryError ?? selectionError ?? current.lastOperationError }

    func validateSystemSettingsAvailability() throws {
        guard availableMethods.contains(.systemSettings) else {
            throw HidingMethodFailure.unavailable(.systemSettings)
        }
        try native.validateAvailability()
    }

    func updateObservedBundleIDs(_ bundleIDs: Set<String>, failedBundleIDs: Set<String> = []) {
        native.updateObservedBundleIDs(bundleIDs, failedBundleIDs: failedBundleIDs)
    }

    func select(_ method: HidingMethod, restriction: MenuBarRestriction? = nil) throws {
        guard availableMethods.contains(method) else {
            let error = HidingMethodFailure.unavailable(method)
            selectionError = error
            throw error
        }
        do {
            current.release()
            if let error = current.lastOperationError {
                recoveryError = error
                throw error
            }
            try recoverNative()
            recoveryError = nil
            if method == .systemSettings { try native.validateAvailability() }
            if let restriction { try engine(for: method).validate(restriction) }
            self.method = method
            settings.hidingMethod = method
            selectionError = nil
        } catch {
            selectionError = error
            throw error
        }
    }

    func restrict(allowedBundleIDs: [String], completion: @escaping (Error?) -> Void) {
        restrict(MenuBarRestriction(allowedBundleIDs: allowedBundleIDs), completion: completion)
    }

    func restrict(_ restriction: MenuBarRestriction, completion: @escaping (Error?) -> Void) {
        guard isAvailable else {
            completion(lastOperationError ?? NativeHidingFailure.unavailable)
            return
        }
        selectionError = nil
        current.restrict(restriction, completion: completion)
    }

    func release() {
        current.release()
        if let error = current.lastOperationError {
            recoveryError = error
            return
        }
        do {
            try recoverNative()
            recoveryError = nil
            selectionError = nil
        } catch {
            recoveryError = error
        }
    }

    private func engine(for method: HidingMethod) -> HidingEngine {
        switch method {
        case .assessment: return assessment
        case .systemSettings: return native
        case .legacy: return spacer
        }
    }

    private func recoverNative() throws {
        guard availableMethods.contains(.systemSettings) else { return }
        try native.recover()
    }
}
