import Foundation

struct TemplateSnapshot: Codable, Hashable, Identifiable {
    var sourceTemplateID: String
    var name: String
    var notes: String
    var kindRawValue: String? = nil
    var durationMinutes: Int
    var exercises: [ExerciseSnapshot]

    var id: String {
        "\(sourceTemplateID)-\(name)"
    }

    var kind: WorkoutTemplateKind {
        WorkoutTemplateKind(rawValue: kindRawValue ?? "") ?? .workout
    }

    var exerciseCount: Int {
        exercises.count
    }

    var summaryLine: String {
        let noun = exerciseCount == 1 ? kind.summaryItemName : "\(kind.summaryItemName)s"
        return "\(exerciseCount) \(noun) • \(durationMinutes) min"
    }
}

struct ExerciseSnapshot: Codable, Hashable, Identifiable {
    var id: UUID
    var orderIndex: Int
    var name: String
    var category: String
    var defaultSets: Int
    var defaultReps: Int?
    var defaultWeight: Double?
    var defaultDurationSeconds: Int?
    var defaultRestSeconds: Int?
    var notes: String
}
