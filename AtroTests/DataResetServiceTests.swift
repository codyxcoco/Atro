import SwiftData
import XCTest
@testable import Atro

final class DataResetServiceTests: XCTestCase {
    @MainActor
    func testResetAllDataClearsRecordsAndRestoresDefaultSettings() throws {
        let schema = Schema([
            WorkoutTemplate.self,
            ExerciseTemplate.self,
            PlannedWorkout.self,
            LoggedWorkout.self,
            LoggedExercise.self,
            LoggedSet.self,
            MoodCheckIn.self,
            MealEntry.self,
            AppSettings.self,
            CalendarSyncRecord.self,
            WorkoutBuddyInsightSnapshot.self,
            StreakCounter.self,
            StreakIncident.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        SeedDataService.ensureSeedData(in: context)

        let settings = try XCTUnwrap(try context.fetch(FetchDescriptor<AppSettings>()).first)
        settings.hasCompletedOnboarding = true
        settings.calendarSyncEnabled = true
        settings.healthIntegrationEnabled = true
        settings.healthWorkoutWriteEnabled = true
        settings.healthMoodWriteEnabled = true
        settings.mealsEnabled = true
        settings.defaultCalendarDurationMinutes = 90
        settings.preferredCalendarIdentifier = "primary"

        context.insert(MoodCheckIn(phase: .checkIn, moodLevel: 5))
        context.insert(
            CalendarSyncRecord(
                plannedWorkoutID: UUID().uuidString,
                eventIdentifier: "event-1",
                calendarIdentifier: "calendar-1",
                titleSnapshot: "Upper Body",
                notesSnapshot: "Synced"
            )
        )
        let streakCounter = StreakCounter(
            title: "Days Without Injury",
            subtitle: "Reset coverage",
            phrase: "days without injury",
            symbolName: "figure.strengthtraining.traditional",
            theme: .strength,
            lastIncidentDate: .now,
            goalDays: 30
        )
        streakCounter.incidents = [
            StreakIncident(date: .now, note: "Test incident", previousStreakLength: 12)
        ]
        context.insert(streakCounter)
        try context.save()

        try DataResetService.resetAllData(in: context, settings: settings)

        XCTAssertTrue(try context.fetch(FetchDescriptor<WorkoutTemplate>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseTemplate>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PlannedWorkout>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<LoggedWorkout>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<LoggedExercise>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<LoggedSet>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<MoodCheckIn>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<MealEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<CalendarSyncRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<StreakCounter>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<StreakIncident>()).isEmpty)

        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertFalse(settings.calendarSyncEnabled)
        XCTAssertFalse(settings.healthIntegrationEnabled)
        XCTAssertFalse(settings.healthWorkoutWriteEnabled)
        XCTAssertFalse(settings.healthMoodWriteEnabled)
        XCTAssertTrue(settings.feelingCheckInsEnabled)
        XCTAssertFalse(settings.mealsEnabled)
        XCTAssertEqual(settings.defaultCalendarDurationMinutes, 60)
        XCTAssertEqual(settings.preferredCalendarIdentifier, "")
    }
}
