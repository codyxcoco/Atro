import Foundation

struct TemplateSnapshot: Codable, Hashable, Identifiable {
    var sourceTemplateID: String
    var name: String
    var notes: String
    var durationMinutes: Int
    var exercises: [ExerciseSnapshot]

    var id: String {
        "\(sourceTemplateID)-\(name)"
    }

    var exerciseCount: Int {
        exercises.count
    }

    var summaryLine: String {
        "\(exerciseCount) exercises • \(durationMinutes) min"
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
