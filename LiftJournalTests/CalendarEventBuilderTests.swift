import XCTest
@testable import LiftJournal

final class CalendarEventBuilderTests: XCTestCase {
    func testPayloadUsesPlannedDurationAndIncludesDeepLink() throws {
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = TemplateSnapshot(
            sourceTemplateID: "template-1",
            name: "Upper Body",
            notes: "Move with control.",
            durationMinutes: 45,
            exercises: [
                ExerciseSnapshot(
                    id: UUID(),
                    orderIndex: 0,
                    name: "Bench Press",
                    category: "Push",
                    defaultSets: 3,
                    defaultReps: 8,
                    defaultWeight: 135,
                    defaultDurationSeconds: nil,
                    defaultRestSeconds: 90,
                    notes: ""
                )
            ]
        )

        let plannedWorkout = PlannedWorkout(
            sourceTemplateID: snapshot.sourceTemplateID,
            templateName: snapshot.name,
            notes: snapshot.notes,
            scheduledFor: startDate,
            durationMinutes: 30,
            templateSnapshotData: try JSONEncoder().encode(snapshot)
        )

        let settings = AppSettings(defaultCalendarDurationMinutes: 60)
        let payload = CalendarEventBuilder().payload(for: plannedWorkout, settings: settings)

        XCTAssertEqual(payload.title, "Upper Body")
        XCTAssertEqual(payload.endDate.timeIntervalSince(payload.startDate), 30 * 60)
        XCTAssertTrue(payload.notes.contains("Bench Press"))
        XCTAssertTrue(payload.notes.contains("liftjournal://planned-workout/"))
    }
}
