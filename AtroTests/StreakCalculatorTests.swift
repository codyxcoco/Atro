import XCTest
@testable import Atro

final class StreakCalculatorTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testStreakStartedTodayReturnsZeroDays() throws {
        let start = try date(year: 2026, month: 6, day: 7)
        let end = try date(year: 2026, month: 6, day: 7)

        XCTAssertEqual(StreakCalculator.fullCalendarDays(from: start, to: end, calendar: calendar), 0)
    }

    func testStreakStartedYesterdayReturnsOneDay() throws {
        let start = try date(year: 2026, month: 6, day: 6)
        let end = try date(year: 2026, month: 6, day: 7)

        XCTAssertEqual(StreakCalculator.fullCalendarDays(from: start, to: end, calendar: calendar), 1)
    }

    func testStreakAcrossMonthBoundaryCountsCalendarDays() throws {
        let start = try date(year: 2026, month: 1, day: 31)
        let end = try date(year: 2026, month: 2, day: 2)

        XCTAssertEqual(StreakCalculator.fullCalendarDays(from: start, to: end, calendar: calendar), 2)
    }

    func testStreakAcrossYearBoundaryCountsCalendarDays() throws {
        let start = try date(year: 2025, month: 12, day: 31)
        let end = try date(year: 2026, month: 1, day: 2)

        XCTAssertEqual(StreakCalculator.fullCalendarDays(from: start, to: end, calendar: calendar), 2)
    }

    func testLeapYearDateCountsCalendarDays() throws {
        let start = try date(year: 2024, month: 2, day: 28)
        let end = try date(year: 2024, month: 3, day: 1)

        XCTAssertEqual(StreakCalculator.fullCalendarDays(from: start, to: end, calendar: calendar), 2)
    }

    func testIncidentLoggingResetsCurrentStreakDate() throws {
        let start = try date(year: 2026, month: 5, day: 1)
        let incidentDate = try date(year: 2026, month: 5, day: 10)
        let today = try date(year: 2026, month: 5, day: 12)
        let counter = StreakCounter(title: "Days Without Injury", lastIncidentDate: start)

        let previousStreak = StreakCalculator.fullCalendarDays(from: counter.lastIncidentDate, to: incidentDate, calendar: calendar)
        counter.incidents = [
            StreakIncident(date: incidentDate, previousStreakLength: previousStreak)
        ]
        counter.lastIncidentDate = incidentDate

        XCTAssertEqual(previousStreak, 9)
        XCTAssertEqual(StreakCalculator.fullCalendarDays(from: counter.lastIncidentDate, to: today, calendar: calendar), 2)
    }

    func testLongestStreakCalculationIncludesCurrentStreak() {
        XCTAssertEqual(StreakCalculator.longestStreak(currentStreak: 18, previousStreaks: [3, 42, 7]), 42)
        XCTAssertEqual(StreakCalculator.longestStreak(currentStreak: 50, previousStreaks: [3, 42, 7]), 50)
    }

    func testAverageStreakCalculationUsesIncidentHistory() {
        XCTAssertEqual(StreakCalculator.averageStreak(previousStreaks: [7, 14, 21]), 14)
        XCTAssertNil(StreakCalculator.averageStreak(previousStreaks: []))
    }

    private func date(year: Int, month: Int, day: Int) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day
        )))
    }
}
