import XCTest
@testable import Atro

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

    func testStretchSnapshotCarriesKindIntoDraftAndLoggedWorkout() {
        let snapshot = TemplateSnapshot(
            sourceTemplateID: "template-stretch",
            name: "Cooldown Flow",
            notes: "Slow exhales.",
            kindRawValue: WorkoutTemplateKind.stretch.rawValue,
            durationMinutes: 6,
            exercises: [
                ExerciseSnapshot(
                    id: UUID(),
                    orderIndex: 0,
                    name: "Hamstring Fold",
                    category: "",
                    defaultSets: 1,
                    defaultReps: nil,
                    defaultWeight: nil,
                    defaultDurationSeconds: 180,
                    defaultRestSeconds: 0,
                    notes: "Switch sides halfway."
                )
            ]
        )

        let draft = WorkoutDraftFactory.session(from: snapshot)

        XCTAssertEqual(draft.templateKind, .stretch)
        XCTAssertEqual(draft.workoutName, "Cooldown Flow")
        XCTAssertEqual(draft.exercises.count, 1)
        XCTAssertEqual(draft.exercises[0].sets.count, 1)
        XCTAssertTrue(draft.exercises[0].sets[0].tracksDuration)
        XCTAssertEqual(draft.exercises[0].sets[0].actualDurationSeconds, 180)

        let loggedWorkout = WorkoutDraftFactory.makeLoggedWorkout(from: draft, finishedAt: Date(timeIntervalSince1970: 2_000))
        XCTAssertEqual(loggedWorkout.templateKind, .stretch)
        XCTAssertEqual(loggedWorkout.loggedExercises.count, 1)
        XCTAssertEqual(loggedWorkout.loggedExercises[0].loggedSets[0].plannedDurationSeconds, 180)
    }

    func testStretchTimerLogSummaryBuildsGenericIntervalsForStandaloneTimer() {
        let endedAt = Date(timeIntervalSince1970: 4_000)
        let summary = WorkoutDraftFactory.stretchTimerLogSummary(
            title: "Quick Stretch",
            intervalSeconds: 30,
            elapsedSeconds: 70,
            endedAt: endedAt
        )

        XCTAssertEqual(summary?.draft.templateKind, .stretch)
        XCTAssertEqual(summary?.draft.workoutName, "Quick Stretch")
        XCTAssertEqual(summary?.draft.startedAt, endedAt.addingTimeInterval(-70))
        XCTAssertEqual(summary?.stretchCount, 3)
        XCTAssertEqual(summary?.completedStretchCount, 2)
        XCTAssertEqual(summary?.draft.exercises.count, 3)
        XCTAssertEqual(summary?.draft.exercises[0].name, "Stretch 1")
        XCTAssertTrue(summary?.draft.exercises[0].sets[0].isCompleted == true)
        XCTAssertEqual(summary?.draft.exercises[2].sets[0].actualDurationSeconds, 10)
        XCTAssertTrue(summary?.summaryLine.contains("30") == true)
        XCTAssertTrue(summary?.summaryLine.contains("active time") == true)
    }

    func testStretchTimerLogSummaryUsesNamedExercisesAndPartialProgressFromSourceDraft() {
        let snapshot = TemplateSnapshot(
            sourceTemplateID: "template-stretch",
            name: "Mobility Flow",
            notes: "",
            kindRawValue: WorkoutTemplateKind.stretch.rawValue,
            durationMinutes: 3,
            exercises: [
                ExerciseSnapshot(
                    id: UUID(),
                    orderIndex: 0,
                    name: "Hamstring Fold",
                    category: "",
                    defaultSets: 1,
                    defaultReps: nil,
                    defaultWeight: nil,
                    defaultDurationSeconds: 45,
                    defaultRestSeconds: 0,
                    notes: "Long exhales."
                ),
                ExerciseSnapshot(
                    id: UUID(),
                    orderIndex: 1,
                    name: "Quad Stretch",
                    category: "",
                    defaultSets: 1,
                    defaultReps: nil,
                    defaultWeight: nil,
                    defaultDurationSeconds: 60,
                    defaultRestSeconds: 0,
                    notes: "Switch sides."
                )
            ]
        )

        let draft = WorkoutDraftFactory.session(from: snapshot)
        let summary = WorkoutDraftFactory.stretchTimerLogSummary(
            title: "Mobility Flow",
            intervalSeconds: 45,
            elapsedSeconds: 75,
            endedAt: Date(timeIntervalSince1970: 5_000),
            sourceDraft: draft
        )

        XCTAssertEqual(summary?.draft.sourceTemplateID, "template-stretch")
        XCTAssertEqual(summary?.stretchCount, 2)
        XCTAssertEqual(summary?.completedStretchCount, 1)
        XCTAssertEqual(summary?.draft.exercises.map(\.name), ["Hamstring Fold", "Quad Stretch"])
        XCTAssertEqual(summary?.draft.exercises[0].sets[0].actualDurationSeconds, 45)
        XCTAssertEqual(summary?.draft.exercises[1].sets[0].actualDurationSeconds, 30)
        XCTAssertFalse(summary?.draft.exercises[1].sets[0].isCompleted ?? true)
        XCTAssertTrue(summary?.summaryLine.contains("guided sequence") == true)
    }

    func testApplyWatchProgressMatchesSetsByExerciseAndOrder() {
        let plannedWorkoutID = UUID().uuidString
        let exerciseID = UUID()
        let startedAt = Date(timeIntervalSince1970: 10_000)
        let snapshot = TemplateSnapshot(
            sourceTemplateID: "template-watch",
            name: "Watch Synced Lift",
            notes: "",
            durationMinutes: 45,
            exercises: [
                ExerciseSnapshot(
                    id: exerciseID,
                    orderIndex: 0,
                    name: "Bench Press",
                    category: "Push",
                    defaultSets: 3,
                    defaultReps: 8,
                    defaultWeight: 135,
                    defaultDurationSeconds: nil,
                    defaultRestSeconds: 120,
                    notes: ""
                )
            ]
        )

        var draft = WorkoutDraftFactory.session(from: snapshot)
        draft.plannedWorkoutID = plannedWorkoutID
        draft.startedAt = startedAt.addingTimeInterval(300)

        let progress = WatchWorkoutProgressUpdate(
            id: UUID(),
            workoutID: UUID(),
            plannedWorkoutID: plannedWorkoutID,
            sourceTemplateID: "template-watch",
            workoutTitle: "Watch Synced Lift",
            startedAt: startedAt,
            finishedAt: nil,
            updatedAt: startedAt.addingTimeInterval(60),
            exercises: [
                WatchWorkoutProgressExercise(
                    id: exerciseID,
                    orderIndex: 0,
                    sets: [
                        WatchWorkoutProgressSet(id: UUID(), orderIndex: 0, isCompleted: true),
                        WatchWorkoutProgressSet(id: UUID(), orderIndex: 1, isCompleted: false),
                        WatchWorkoutProgressSet(id: UUID(), orderIndex: 2, isCompleted: true)
                    ]
                )
            ]
        )

        XCTAssertTrue(draft.applyWatchProgress(progress))
        XCTAssertEqual(draft.startedAt, startedAt)
        XCTAssertEqual(draft.exercises[0].sets.map(\.isCompleted), [true, false, true])
    }

    func testApplyWatchProgressIgnoresOtherPlannedWorkouts() {
        var draft = WorkoutDraftFactory.liveSession()
        draft.plannedWorkoutID = UUID().uuidString
        draft.exercises = [
            LoggedExerciseDraft(
                orderIndex: 0,
                name: "Squat",
                category: "Legs",
                notes: "",
                sets: [WorkoutDraftFactory.blankSet(orderIndex: 0)]
            )
        ]

        let progress = WatchWorkoutProgressUpdate(
            id: UUID(),
            workoutID: UUID(),
            plannedWorkoutID: UUID().uuidString,
            sourceTemplateID: "",
            workoutTitle: "Other Workout",
            startedAt: Date(timeIntervalSince1970: 12_000),
            finishedAt: nil,
            updatedAt: Date(timeIntervalSince1970: 12_010),
            exercises: [
                WatchWorkoutProgressExercise(
                    id: draft.exercises[0].id,
                    orderIndex: 0,
                    sets: [
                        WatchWorkoutProgressSet(id: UUID(), orderIndex: 0, isCompleted: true)
                    ]
                )
            ]
        )

        XCTAssertFalse(draft.applyWatchProgress(progress))
        XCTAssertFalse(draft.exercises[0].sets[0].isCompleted)
    }
}
