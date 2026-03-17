import Foundation
import SwiftData

@Model
final class LoggedWorkout {
    @Attribute(.unique) var id: UUID
    var sourceTemplateID: String
    var sourceTemplateName: String
    var plannedWorkoutID: String
    var workoutName: String
    var startedAt: Date
    var endedAt: Date
    var notes: String
    var tagText: String
    var isFavorite: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \LoggedExercise.workout)
    var loggedExercises: [LoggedExercise]

    @Relationship(deleteRule: .cascade, inverse: \MoodCheckIn.workout)
    var moodCheckIns: [MoodCheckIn]

    init(
        id: UUID = UUID(),
        sourceTemplateID: String = "",
        sourceTemplateName: String = "",
        plannedWorkoutID: String = "",
        workoutName: String,
        startedAt: Date,
        endedAt: Date,
        notes: String = "",
        tagText: String = "",
        isFavorite: Bool = false,
        createdAt: Date = .now,
        loggedExercises: [LoggedExercise] = [],
        moodCheckIns: [MoodCheckIn] = []
    ) {
        self.id = id
        self.sourceTemplateID = sourceTemplateID
        self.sourceTemplateName = sourceTemplateName
        self.plannedWorkoutID = plannedWorkoutID
        self.workoutName = workoutName
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.notes = notes
        self.tagText = tagText
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.loggedExercises = loggedExercises.sorted(using: SortDescriptor(\.orderIndex))
        self.moodCheckIns = moodCheckIns.sorted(using: SortDescriptor(\.createdAt))
    }

    var durationMinutes: Int {
        max(Int(endedAt.timeIntervalSince(startedAt) / 60), 1)
    }

    var exerciseCount: Int {
        loggedExercises.count
    }

    var totalSetCount: Int {
        loggedExercises.reduce(0) { $0 + $1.loggedSets.count }
    }

    var completedSetCount: Int {
        loggedExercises.reduce(0) { partialResult, exercise in
            partialResult + exercise.loggedSets.filter(\.isCompleted).count
        }
    }

    var totalVolume: Double {
        loggedExercises.reduce(0) { $0 + $1.volume }
    }

    var tags: [String] {
        tagText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func mood(for phase: MoodPhase) -> MoodCheckIn? {
        moodCheckIns.first { $0.phase == phase.rawValue }
    }
}

@Model
final class LoggedExercise {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var name: String
    var category: String
    var notes: String

    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.exercise)
    var loggedSets: [LoggedSet]

    var workout: LoggedWorkout?

    init(
        id: UUID = UUID(),
        orderIndex: Int = 0,
        name: String,
        category: String = "",
        notes: String = "",
        loggedSets: [LoggedSet] = []
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.name = name
        self.category = category
        self.notes = notes
        self.loggedSets = loggedSets.sorted(using: SortDescriptor(\.orderIndex))
    }

    var volume: Double {
        loggedSets.reduce(0) { partialResult, set in
            partialResult + (set.actualWeight ?? set.plannedWeight ?? 0) * Double(set.actualReps ?? set.plannedReps ?? 0)
        }
    }
}

@Model
final class LoggedSet {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var isCompleted: Bool
    var plannedReps: Int?
    var actualReps: Int?
    var plannedWeight: Double?
    var actualWeight: Double?
    var plannedDurationSeconds: Int?
    var actualDurationSeconds: Int?
    var restSeconds: Int?

    var exercise: LoggedExercise?

    init(
        id: UUID = UUID(),
        orderIndex: Int = 0,
        isCompleted: Bool = false,
        plannedReps: Int? = nil,
        actualReps: Int? = nil,
        plannedWeight: Double? = nil,
        actualWeight: Double? = nil,
        plannedDurationSeconds: Int? = nil,
        actualDurationSeconds: Int? = nil,
        restSeconds: Int? = nil
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.isCompleted = isCompleted
        self.plannedReps = plannedReps
        self.actualReps = actualReps
        self.plannedWeight = plannedWeight
        self.actualWeight = actualWeight
        self.plannedDurationSeconds = plannedDurationSeconds
        self.actualDurationSeconds = actualDurationSeconds
        self.restSeconds = restSeconds
    }
}
