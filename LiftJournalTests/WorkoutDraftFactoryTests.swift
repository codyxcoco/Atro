import XCTest
@testable import LiftJournal

final class WorkoutDraftFactoryTests: XCTestCase {
    func testSessionFromSnapshotCreatesExerciseRowsAndSetCounts() {
        let snapshot = TemplateSnapshot(
            sourceTemplateID: "template-1",
            name: "Upper Body",
            notes: "Keep it steady.",
            durationMinutes: 50,
            exercises: [
                ExerciseSnapshot(
                    id: UUID(),
                    orderIndex: 0,
                    name: "Bench Press",
                    category: "Push",
                    defaultSets: 4,
                    defaultReps: 6,
                    defaultWeight: 135,
                    defaultDurationSeconds: nil,
                    defaultRestSeconds: 120,
                    notes: ""
                )
            ]
        )

        let draft = WorkoutDraftFactory.session(from: snapshot)

        XCTAssertEqual(draft.workoutName, "Upper Body")
        XCTAssertEqual(draft.exercises.count, 1)
        XCTAssertEqual(draft.exercises[0].sets.count, 4)
        XCTAssertTrue(draft.exercises[0].sets[0].tracksWeight)
        XCTAssertEqual(draft.exercises[0].sets[0].actualWeight, 135)
    }

    func testMakeLoggedWorkoutCarriesNotesTagsAndMoodCheckIns() {
        let snapshot = TemplateSnapshot(
            sourceTemplateID: "template-2",
            name: "Leg Day",
            notes: "",
            durationMinutes: 60,
            exercises: [
                ExerciseSnapshot(
                    id: UUID(),
                    orderIndex: 0,
                    name: "Back Squat",
                    category: "Legs",
                    defaultSets: 3,
                    defaultReps: 5,
                    defaultWeight: 185,
                    defaultDurationSeconds: nil,
                    defaultRestSeconds: 150,
                    notes: ""
                )
            ]
        )

        var draft = WorkoutDraftFactory.session(from: snapshot)
        draft.notes = "Felt strong."
        draft.tagText = "legs, morning"
        draft.includePreCheckIn = true
        draft.preCheckIn.energyLevel = 2
        draft.postCheckIn.moodLevel = 4
        draft.exercises[0].sets[0].isCompleted = true

        let finishedAt = Date(timeIntervalSince1970: 1_000)
        let loggedWorkout = WorkoutDraftFactory.makeLoggedWorkout(from: draft, finishedAt: finishedAt)

        XCTAssertEqual(loggedWorkout.sourceTemplateID, "template-2")
        XCTAssertEqual(loggedWorkout.notes, "Felt strong.")
        XCTAssertEqual(loggedWorkout.tags, ["legs", "morning"])
        XCTAssertEqual(loggedWorkout.completedSetCount, 1)
        XCTAssertEqual(loggedWorkout.moodCheckIns.count, 2)
        XCTAssertEqual(loggedWorkout.mood(for: .pre)?.energyLevel, 2)
        XCTAssertEqual(loggedWorkout.mood(for: .post)?.moodLevel, 4)
    }
}
