import Foundation

struct WatchWorkoutSnapshot: Codable, Hashable, Sendable {
    var generatedAt: Date
    var label: String
    var workout: WatchWorkoutSummary?
}

struct WatchWorkoutSummary: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var plannedWorkoutID: String
    var sourceTemplateID: String
    var title: String
    var notes: String
    var scheduledFor: Date
    var durationMinutes: Int
    var isRestDay: Bool
    var exercises: [WatchWorkoutExercise]

    var exerciseCount: Int {
        exercises.count
    }

    var setCount: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    var summaryLine: String {
        if isRestDay {
            return "Recovery and reset day"
        }

        return "\(exerciseCount) exercises • \(durationMinutes) min"
    }
}

struct WatchWorkoutExercise: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var orderIndex: Int
    var name: String
    var category: String
    var notes: String
    var sets: [WatchWorkoutSet]
}

struct WatchWorkoutSet: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var orderIndex: Int
    var plannedReps: Int?
    var plannedWeight: Double?
    var plannedDurationSeconds: Int?
    var restSeconds: Int
}

struct WatchWorkoutProgressUpdate: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var workoutID: UUID
    var plannedWorkoutID: String
    var sourceTemplateID: String
    var workoutTitle: String
    var startedAt: Date
    var finishedAt: Date?
    var updatedAt: Date
    var exercises: [WatchWorkoutProgressExercise]

    var completedSetCount: Int {
        exercises.reduce(0) { partialResult, exercise in
            partialResult + exercise.sets.filter(\.isCompleted).count
        }
    }

    var totalSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }
}

struct WatchWorkoutProgressExercise: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var orderIndex: Int
    var sets: [WatchWorkoutProgressSet]
}

struct WatchWorkoutProgressSet: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var orderIndex: Int
    var isCompleted: Bool
}
