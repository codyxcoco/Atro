import Foundation
import SwiftData

@Model
final class WorkoutTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var defaultDurationMinutes: Int
    var tintName: String

    @Relationship(deleteRule: .cascade, inverse: \ExerciseTemplate.template)
    var exercises: [ExerciseTemplate]

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isArchived: Bool = false,
        defaultDurationMinutes: Int = 60,
        tintName: String = "AccentColor",
        exercises: [ExerciseTemplate] = []
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.defaultDurationMinutes = defaultDurationMinutes
        self.tintName = tintName
        self.exercises = exercises.sorted(using: SortDescriptor(\.orderIndex))
    }

    var activeExercises: [ExerciseTemplate] {
        exercises.sorted(using: SortDescriptor(\.orderIndex))
    }

    var summaryLine: String {
        let exerciseCount = activeExercises.count
        let noun = exerciseCount == 1 ? "exercise" : "exercises"
        return "\(exerciseCount) \(noun) • \(defaultDurationMinutes) min"
    }

    func touch() {
        updatedAt = .now
    }

    func makeSnapshot() -> TemplateSnapshot {
        TemplateSnapshot(
            sourceTemplateID: id.uuidString,
            name: name,
            notes: notes,
            durationMinutes: defaultDurationMinutes,
            exercises: activeExercises.map { exercise in
                ExerciseSnapshot(
                    id: exercise.id,
                    orderIndex: exercise.orderIndex,
                    name: exercise.name,
                    category: exercise.category,
                    defaultSets: exercise.defaultSets,
                    defaultReps: exercise.defaultReps,
                    defaultWeight: exercise.defaultWeight,
                    defaultDurationSeconds: exercise.defaultDurationSeconds,
                    defaultRestSeconds: exercise.defaultRestSeconds,
                    notes: exercise.notes
                )
            }
        )
    }
}

@Model
final class ExerciseTemplate {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var name: String
    var category: String
    var defaultSets: Int
    var defaultReps: Int?
    var defaultWeight: Double?
    var defaultDurationSeconds: Int?
    var defaultRestSeconds: Int?
    var notes: String

    var template: WorkoutTemplate?

    init(
        id: UUID = UUID(),
        orderIndex: Int = 0,
        name: String,
        category: String = "",
        defaultSets: Int = 3,
        defaultReps: Int? = 8,
        defaultWeight: Double? = nil,
        defaultDurationSeconds: Int? = nil,
        defaultRestSeconds: Int? = 90,
        notes: String = ""
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.name = name
        self.category = category
        self.defaultSets = defaultSets
        self.defaultReps = defaultReps
        self.defaultWeight = defaultWeight
        self.defaultDurationSeconds = defaultDurationSeconds
        self.defaultRestSeconds = defaultRestSeconds
        self.notes = notes
    }

    var measurementLine: String {
        var pieces: [String] = ["\(defaultSets) sets"]

        if let defaultReps {
            pieces.append("\(defaultReps) reps")
        }

        if let defaultWeight, defaultWeight > 0 {
            pieces.append("\(defaultWeight.formatted(.number.precision(.fractionLength(0...1)))) lb")
        }

        if let defaultDurationSeconds, defaultDurationSeconds > 0 {
            pieces.append("\(defaultDurationSeconds / 60) min")
        }

        return pieces.joined(separator: " • ")
    }
}
