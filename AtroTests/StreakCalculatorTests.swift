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
        let counter = StreakCounter(title: "Training Streak", lastIncidentDate: start)

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

    func testCounterIconColorDefaultsAndUpdates() throws {
        let start = try date(year: 2026, month: 5, day: 1)
        let counter = StreakCounter(title: "Training Streak", lastIncidentDate: start)

        XCTAssertEqual(counter.iconColor, .accent)

        counter.iconColorRawValue = nil
        XCTAssertEqual(counter.iconColor, .accent)

        counter.iconColor = .health
        XCTAssertEqual(counter.iconColorRawValue, StreakIconColor.health.rawValue)
        XCTAssertEqual(counter.iconColor, .health)
    }

    func testCounterDisplayPhraseNormalizesOldDaysWithoutCopy() throws {
        let start = try date(year: 2026, month: 5, day: 1)
        let counter = StreakCounter(title: "Training Streak", phrase: "days without incident", lastIncidentDate: start)

        XCTAssertEqual(counter.displayPhrase, "current streak")

        counter.phrase = "Days Without Injury"
        XCTAssertEqual(counter.displayPhrase, "current streak")

        counter.phrase = "steady streak"
        XCTAssertEqual(counter.displayPhrase, "steady streak")
    }

    func testWidgetSnapshotDisplayPhraseNormalizesOldDaysWithoutCopy() throws {
        let start = try date(year: 2026, month: 5, day: 1)
        var snapshot = StreakWidgetSnapshot(
            counterId: UUID(),
            title: "Training Streak",
            subtitle: "",
            phrase: "days without incident",
            symbolName: "checkmark.seal",
            themeName: "recovery",
            colorHex: "#49C7C9",
            iconColorHex: "#49C7C9",
            lastIncidentDate: start,
            goalDays: nil,
            currentStreakDays: 0,
            totalIncidents: 0,
            isPinned: false,
            updatedAt: start
        )

        XCTAssertEqual(snapshot.displayPhrase, "current streak")

        snapshot.phrase = "steady streak"
        XCTAssertEqual(snapshot.displayPhrase, "steady streak")
    }

    func testElapsedFormatterBuildsLiveTimerText() throws {
        let start = try XCTUnwrap(calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 1,
            hour: 8,
            minute: 15,
            second: 30
        )))
        let end = try XCTUnwrap(calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 3,
            hour: 10,
            minute: 20,
            second: 35
        )))

        XCTAssertEqual(StreakElapsedFormatter.elapsedText(from: start, to: end), "2d 02h 05m 05s")
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
