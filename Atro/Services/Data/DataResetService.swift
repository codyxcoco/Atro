import SwiftData

enum DataResetService {
    @MainActor
    static func resetAllData(in context: ModelContext, settings: AppSettings) throws {
        try deleteAll(CalendarSyncRecord.self, in: context)
        try deleteAll(WorkoutBuddyInsightSnapshot.self, in: context)
        try deleteAll(StreakIncident.self, in: context)
        try deleteAll(StreakCounter.self, in: context)
        try deleteAll(MealEntry.self, in: context)
        try deleteAll(LoggedWorkout.self, in: context)
        try deleteAll(PlannedWorkout.self, in: context)
        try deleteAll(WorkoutTemplate.self, in: context)
        try context.save()

        try deleteAll(MoodCheckIn.self, in: context)
        try deleteAll(LoggedExercise.self, in: context)
        try deleteAll(LoggedSet.self, in: context)
        try deleteAll(ExerciseTemplate.self, in: context)

        settings.resetForFreshStart()
        try context.save()
    }

    private static func deleteAll<Model: PersistentModel>(_ model: Model.Type, in context: ModelContext) throws {
        let descriptor = FetchDescriptor<Model>()
        let models = try context.fetch(descriptor)

        for model in models {
            context.delete(model)
        }
    }
}
