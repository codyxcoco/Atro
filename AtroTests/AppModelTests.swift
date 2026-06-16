import XCTest
@testable import Atro

@MainActor
final class AppModelTests: XCTestCase {
    func testShowBannerAutoDismissesAfterRequestedDuration() async throws {
        let appModel = AppModel()

        appModel.showBanner("Synced 1 Health workout", duration: .milliseconds(50))

        XCTAssertEqual(appModel.pendingBanner?.title, "Synced 1 Health workout")

        try await Task.sleep(for: .milliseconds(150))

        XCTAssertNil(appModel.pendingBanner)
    }

    func testShowBannerCancelsPreviousDismissTaskForNewMessage() async throws {
        let appModel = AppModel()

        appModel.showBanner("First banner", duration: .milliseconds(50))
        try await Task.sleep(for: .milliseconds(20))

        appModel.showBanner("Newest banner", duration: .milliseconds(120))

        try await Task.sleep(for: .milliseconds(70))
        XCTAssertEqual(appModel.pendingBanner?.title, "Newest banner")

        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(appModel.pendingBanner)
    }
}
