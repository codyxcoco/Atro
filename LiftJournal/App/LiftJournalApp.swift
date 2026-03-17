import SwiftData
import SwiftUI

@main
struct LiftJournalApp: App {
    private let container: ModelContainer
    @State private var appModel: AppModel

    init() {
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
            CalendarSyncRecord.self
        ])

        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: configuration)
            SeedDataService.ensureSeedData(in: container.mainContext)
            self.container = container
        } catch {
            fatalError("Unable to create ModelContainer: \(error)")
        }

        _appModel = State(initialValue: AppModel())
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(appModel)
        }
        .modelContainer(container)
    }
}
