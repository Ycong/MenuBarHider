import XCTest

@testable import MenuBarHider

final class SpacerHidingEngineTests: XCTestCase {
    private var spacer: FakeSpacer!
    private var engine: SpacerHidingEngine!

    override func setUp() {
        super.setUp()
        spacer = FakeSpacer()
        engine = SpacerHidingEngine(spacer: spacer)
    }

    func testRestrictExpandsSpacerAndReleaseRestoresIt() {
        let restriction = MenuBarRestriction(allowedBundleIDs: ["app.visible"], hiddenSystemItems: [6])

        engine.restrict(restriction) { XCTAssertNil($0) }

        XCTAssertTrue(spacer.isExpanded)
        XCTAssertEqual(engine.appliedAllowList, ["app.visible"])
        XCTAssertEqual(engine.requestedRestriction, restriction)
        XCTAssertFalse(engine.requiresClockHover)
        XCTAssertFalse(engine.unloadsMenuExtras)
        XCTAssertEqual(engine.hidingMethod, .legacy)

        engine.release()

        XCTAssertFalse(spacer.isExpanded)
        XCTAssertNil(engine.appliedAllowList)
        XCTAssertNil(engine.requestedRestriction)
    }

    func testRepeatedRestrictionUpdatesTheAllowList() {
        engine.restrict(allowedBundleIDs: ["app.a"]) { XCTAssertNil($0) }
        engine.restrict(allowedBundleIDs: ["app.a", "app.b"]) { XCTAssertNil($0) }

        XCTAssertTrue(spacer.isExpanded)
        XCTAssertEqual(engine.appliedAllowList, ["app.a", "app.b"])
    }

    func testUnavailableSpacerReportsAnError() {
        spacer.isAvailable = false

        var result: Error?
        engine.restrict(allowedBundleIDs: []) { result = $0 }

        XCTAssertNotNil(result)
        XCTAssertFalse(spacer.isExpanded)
        XCTAssertNotNil(engine.lastOperationError)

        engine.release()

        XCTAssertNil(engine.lastOperationError)
    }

    func testSystemItemsAreAccepted() {
        XCTAssertNoThrow(
            try engine.validate(MenuBarRestriction(allowedBundleIDs: [], hiddenSystemItems: [6])))
    }

    func testLegacyIsTheOnlyMethodBeforeMacOS27() {
        XCTAssertEqual(HidingMethod.supported(onMajorVersion: 15), [.legacy])
        XCTAssertEqual(HidingMethod.supported(onMajorVersion: 26), [.legacy])
        XCTAssertEqual(HidingMethod.supported(onMajorVersion: 27), [.assessment, .systemSettings])
    }
}
