import XCTest
@testable import LiftJournal

final class JournalFilterTests: XCTestCase {
    func testJournalFilterMatchesTemplateFavoriteTagAndDateRange() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 5_000_000)

        let matchingWorkout = LoggedWorkout(
            sourceTemplateID: "template-1",
            sourceTemplateName: "Upper",
            workoutName: "Upper",
            startedAt: now.addingTimeInterval(-3_600),
            endedAt: now,
            notes: "",
            tagText: "push, evening",
            isFavorite: true
        )

        let staleWorkout = LoggedWorkout(
            sourceTemplateID: "template-1",
            sourceTemplateName: "Upper",
            workoutName: "Upper",
            startedAt: now.addingTimeInterval(-60 * 60 * 24 * 45),
            endedAt: now.addingTimeInterval(-60 * 60 * 24 * 45),
            notes: "",
            tagText: "push",
            isFavorite: true
        )

        var filter = JournalFilter()
        filter.selectedTemplateID = "template-1"
        filter.favoritesOnly = true
        filter.dateRange = .last30Days
        filter.tagSearch = "even"

        XCTAssertTrue(filter.matches(matchingWorkout, now: now, calendar: calendar))
        XCTAssertFalse(filter.matches(staleWorkout, now: now, calendar: calendar))
    }

    func testJournalFilterRejectsTemplateMismatch() {
        let workout = LoggedWorkout(
            sourceTemplateID: "template-b",
            sourceTemplateName: "Legs",
            workoutName: "Legs",
            startedAt: .now,
            endedAt: .now
        )

        var filter = JournalFilter()
        filter.selectedTemplateID = "template-a"

        XCTAssertFalse(filter.matches(workout))
    }
}
