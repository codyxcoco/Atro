import SwiftData
import SwiftUI

struct PreviewContainer<Content: View>: View {
    private let content: Content
    private let container: ModelContainer
    @State private var appModel = AppModel()

    init(@ViewBuilder content: () -> Content) {
        self.content = content()

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

        do {
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
            SeedDataService.ensureSeedData(in: container.mainContext)
            self.container = container
        } catch {
            fatalError("Unable to create preview container: \(error)")
        }
    }

    var body: some View {
        content
            .environment(appModel)
            .modelContainer(container)
    }
}
