import XCTest
@testable import LiftJournal

final class ICSExporterTests: XCTestCase {
    func testExporterEscapesSpecialCharactersAndNewLines() {
        let payload = CalendarEventPayload(
            title: "Upper, Body",
            notes: "Line 1\nLine 2; lift",
            startDate: Date(timeIntervalSince1970: 1_000),
            endDate: Date(timeIntervalSince1970: 1_600),
            deepLink: nil
        )

        let contents = ICSExporter().contents(for: payload)

        XCTAssertTrue(contents.contains("SUMMARY:Upper\\, Body"))
        XCTAssertTrue(contents.contains("DESCRIPTION:Line 1\\nLine 2\\; lift"))
        XCTAssertTrue(contents.contains("BEGIN:VEVENT"))
    }
}
