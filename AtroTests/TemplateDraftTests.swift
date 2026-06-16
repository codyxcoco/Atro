import XCTest
@testable import Atro

final class TemplateDraftTests: XCTestCase {
    func testApplyFiltersBlankExercisesAndTrimsFields() {
        var draft = TemplateDraft()
        draft.name = "  Push Day  "
        draft.notes = "  Focus on form.  "
        draft.exercises = [
            ExerciseDraft(),
            {
                var exercise = ExerciseDraft()
                exercise.name = "  Bench Press  "
                exercise.category = "  Chest  "
                exercise.notes = "  Pause on chest  "
                return exercise
            }(),
            {
                var exercise = ExerciseDraft()
                exercise.name = "   "
                exercise.category = "Shoulders"
                return exercise
            }()
        ]

        let template = WorkoutTemplate(name: "Placeholder")
        draft.apply(to: template)

        XCTAssertEqual(template.name, "Push Day")
        XCTAssertEqual(template.notes, "Focus on form.")
        XCTAssertEqual(template.exercises.count, 1)
        XCTAssertEqual(template.exercises.first?.name, "Bench Press")
        XCTAssertEqual(template.exercises.first?.category, "Chest")
        XCTAssertEqual(template.exercises.first?.notes, "Pause on chest")
    }

    func testApplyPersistsStretchKindAndNormalizesStretchSteps() throws {
        var draft = TemplateDraft()
        draft.kind = .stretch
        draft.name = "  Desk Reset  "
        draft.notes = "  Breathe slowly.  "
        draft.exercises = [
            {
                var exercise = ExerciseDraft(template: nil, kind: .stretch)
                exercise.name = "  Neck Roll  "
                exercise.category = "Mobility"
                exercise.defaultSets = 4
                exercise.defaultReps = 12
                exercise.tracksWeight = true
                exercise.defaultWeight = 15
                exercise.defaultDurationMinutes = 2
                exercise.defaultRestSeconds = 30
                exercise.notes = "  Move gently.  "
                return exercise
            }()
        ]

        let template = WorkoutTemplate(name: "Placeholder")
        draft.apply(to: template)

        XCTAssertEqual(template.kind, .stretch)
        XCTAssertEqual(template.name, "Desk Reset")
        XCTAssertEqual(template.notes, "Breathe slowly.")
        XCTAssertEqual(template.defaultDurationMinutes, 2)

        let step = try XCTUnwrap(template.exercises.first)
        XCTAssertEqual(step.name, "Neck Roll")
        XCTAssertEqual(step.category, "")
        XCTAssertEqual(step.defaultSets, 1)
        XCTAssertNil(step.defaultReps)
        XCTAssertNil(step.defaultWeight)
        XCTAssertEqual(step.defaultDurationSeconds, 120)
        XCTAssertEqual(step.defaultRestSeconds, 0)
        XCTAssertEqual(step.notes, "Move gently.")
    }
}
