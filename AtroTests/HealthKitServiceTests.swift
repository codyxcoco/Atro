import HealthKit
import SwiftData
import XCTest
@testable import Atro

final class HealthKitServiceTests: XCTestCase {
    @MainActor
    func testAttachmentCandidatesPreferClosestLoggedWorkout() {
        let service = HealthKitService()
        let importedWorkout = LoggedWorkout(
            healthKitWorkoutID: "apple-1",
            healthKitMetadataText: "Imported from Apple Health • 220 active kcal",
            workoutName: "Walk",
            startedAt: makeDate(2026, 3, 19, hour: 10),
            endedAt: makeDate(2026, 3, 19, hour: 11),
            notes: "",
            tagText: "Apple Health"
        )

        let closestLoggedWorkout = LoggedWorkout(
            workoutName: "Morning Walk",
            startedAt: makeDate(2026, 3, 19, hour: 10, minute: 5),
            endedAt: makeDate(2026, 3, 19, hour: 11, minute: 2),
            notes: "Tracked live in Atro.",
            loggedExercises: [
                LoggedExercise(name: "Walk", loggedSets: [LoggedSet(orderIndex: 0, actualReps: 1)])
            ]
        )
        let fartherLoggedWorkout = LoggedWorkout(
            workoutName: "Evening Lift",
            startedAt: makeDate(2026, 3, 19, hour: 18),
            endedAt: makeDate(2026, 3, 19, hour: 19),
            notes: "",
            loggedExercises: [
                LoggedExercise(name: "Bench Press", loggedSets: [LoggedSet(orderIndex: 0, actualReps: 8)])
            ]
        )

        let candidates = service.attachmentCandidates(
            for: importedWorkout,
            among: [importedWorkout, fartherLoggedWorkout, closestLoggedWorkout]
        )

        XCTAssertEqual(candidates.first?.id, closestLoggedWorkout.id)
    }

    @MainActor
    func testAttachImportedWorkoutPreservesNotesAndRemovesDuplicateEntry() throws {
        let schema = Schema([
            LoggedWorkout.self,
            LoggedExercise.self,
            LoggedSet.self,
            MoodCheckIn.self,
            PlannedWorkout.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let importedWorkout = LoggedWorkout(
            healthKitWorkoutID: "apple-2",
            healthKitMetadataText: "Imported from Apple Health • 299 active kcal • 2.1 mi",
            workoutName: "Walk",
            startedAt: makeDate(2026, 3, 19, hour: 8),
            endedAt: makeDate(2026, 3, 19, hour: 9),
            notes: "",
            tagText: "Apple Health"
        )
        let loggedWorkout = LoggedWorkout(
            workoutName: "Leg Day",
            startedAt: makeDate(2026, 3, 19, hour: 8, minute: 5),
            endedAt: makeDate(2026, 3, 19, hour: 9, minute: 2),
            notes: "Felt strong.",
            tagText: "legs, morning",
            loggedExercises: [
                LoggedExercise(
                    name: "Back Squat",
                    loggedSets: [
                        LoggedSet(orderIndex: 0, isCompleted: true, actualReps: 5, actualWeight: 225, restSeconds: 120)
                    ]
                )
            ]
        )

        context.insert(importedWorkout)
        context.insert(loggedWorkout)
        try context.save()

        let service = HealthKitService()
        try service.attachImportedWorkout(importedWorkout, to: loggedWorkout, in: context)

        let workouts = try context.fetch(FetchDescriptor<LoggedWorkout>())
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(loggedWorkout.healthKitWorkoutID, "apple-2")
        XCTAssertTrue(loggedWorkout.tags.contains("Apple Health"))
        XCTAssertTrue(loggedWorkout.displayNotes.contains("Felt strong."))
        XCTAssertTrue(loggedWorkout.displayNotes.contains("299 active kcal"))
        XCTAssertTrue(loggedWorkout.isHealthLinkedSession)
    }

    @MainActor
    func testStretchWorkoutMapsToCooldownActivityType() {
        let stretchWorkout = LoggedWorkout(
            templateKind: .stretch,
            workoutName: "Cooldown Flow",
            startedAt: makeDate(2026, 3, 19, hour: 8),
            endedAt: makeDate(2026, 3, 19, hour: 8, minute: 12)
        )
        let strengthWorkout = LoggedWorkout(
            workoutName: "Leg Day",
            startedAt: makeDate(2026, 3, 19, hour: 9),
            endedAt: makeDate(2026, 3, 19, hour: 10)
        )

        XCTAssertEqual(stretchWorkout.workoutActivityType, .cooldown)
        XCTAssertEqual(strengthWorkout.workoutActivityType, .traditionalStrengthTraining)
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int, minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0

        return calendar.date(from: components) ?? .distantPast
    }
}
