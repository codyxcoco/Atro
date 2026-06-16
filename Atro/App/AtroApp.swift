import SwiftData
import SwiftUI

@main
struct AtroApp: App {
    private static let storeConfigurationName = "Atro"
    private static let legacyStoreFilenames = [
        "default.store",
        "LiftJournal.store"
    ]

    private let container: ModelContainer
    @State private var appModel: AppModel

    @MainActor
    init() {
        LiftTypography.configureAppearance()

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
            self.container = try Self.makeContainer(schema: schema)
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

    private static func makeContainer(schema: Schema) throws -> ModelContainer {
        let preferredConfiguration = ModelConfiguration(storeConfigurationName, schema: schema, isStoredInMemoryOnly: false)
        let storeURL = resolvedPersistentStoreURL(for: preferredConfiguration.url)
        let configuration = ModelConfiguration(storeConfigurationName, schema: schema, url: storeURL)
        try ensurePersistentStoreDirectory(for: storeURL)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    static func ensurePersistentStoreDirectory(for storeURL: URL) throws {
        let directoryURL = storeURL.deletingLastPathComponent()
        var isDirectory = ObjCBool(false)

        if FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                return
            }

            throw CocoaError(.fileWriteFileExists, userInfo: [
                NSFilePathErrorKey: directoryURL.path
            ])
        }

        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    static func resolvedPersistentStoreURL(for preferredURL: URL, fileManager: FileManager = .default) -> URL {
        if persistentStoreArtifactsExist(at: preferredURL, fileManager: fileManager) {
            return preferredURL
        }

        let directoryURL = preferredURL.deletingLastPathComponent()

        for filename in legacyStoreFilenames {
            let candidateURL = directoryURL.appendingPathComponent(filename)

            if persistentStoreArtifactsExist(at: candidateURL, fileManager: fileManager) {
                return candidateURL
            }
        }

        return preferredURL
    }

    private static func persistentStoreArtifactsExist(at storeURL: URL, fileManager: FileManager) -> Bool {
        let relatedPaths = [
            storeURL.path,
            storeURL.path + "-shm",
            storeURL.path + "-wal"
        ]

        return relatedPaths.contains { fileManager.fileExists(atPath: $0) }
    }
}
