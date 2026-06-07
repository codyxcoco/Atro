import Foundation
import SwiftData

@Model
final class LoggedWorkout {
    @Attribute(.unique) var id: UUID
    var sourceTemplateID: String
    var sourceTemplateName: String
    var templateKindRawValue: String?
    var plannedWorkoutID: String
    var healthKitWorkoutID: String
    var healthKitMetadataText: String
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
        templateKind: WorkoutTemplateKind = .workout,
        plannedWorkoutID: String = "",
        healthKitWorkoutID: String = "",
        healthKitMetadataText: String = "",
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
        self.templateKindRawValue = templateKind.rawValue
        self.plannedWorkoutID = plannedWorkoutID
        self.healthKitWorkoutID = healthKitWorkoutID
        self.healthKitMetadataText = healthKitMetadataText
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

    var templateKind: WorkoutTemplateKind {
        get { WorkoutTemplateKind(rawValue: templateKindRawValue ?? "") ?? .workout }
        set { templateKindRawValue = newValue.rawValue }
    }

    var durationMinutes: Int {
        max(Int(endedAt.timeIntervalSince(startedAt) / 60), 1)
    }

    var isImportedFromHealth: Bool {
        !healthKitWorkoutID.isEmpty
    }

    var isPureHealthImport: Bool {
        isImportedFromHealth && !hasExerciseData
    }

    var isHealthLinkedSession: Bool {
        isImportedFromHealth && hasExerciseData
    }

    var importedWorkoutSymbolName: String {
        if templateKind == .stretch {
            return "figure.cooldown"
        }

        return switch workoutName {
        case "Strength Training", "Functional Strength", "Core Training":
            "figure.strengthtraining.traditional"
        case "HIIT", "Mixed Cardio":
            "figure.highintensity.intervaltraining"
        case "Run":
            "figure.run"
        case "Walk":
            "figure.walk"
        case "Cycling":
            "figure.outdoor.cycle"
        case "Swimming":
            "figure.pool.swim"
        case "Hiking":
            "figure.hiking"
        case "Yoga":
            "figure.yoga"
        case "Rowing":
            "figure.rower"
        case "Stair Climb":
            "figure.step.training"
        case "Cooldown":
            "figure.cooldown"
        default:
            "figure.mixed.cardio"
        }
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

    var hasExerciseData: Bool {
        exerciseCount > 0
    }

    var importedMetadataFragments: [String] {
        guard isImportedFromHealth else { return [] }

        let metadataSource = healthKitMetadataText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? notes
            : healthKitMetadataText

        return metadataSource
            .split(separator: "•")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter {
                !$0.isEmpty &&
                $0.localizedCaseInsensitiveCompare("Imported from Apple Health") != .orderedSame
            }
    }

    var importedMetadataSummary: String {
        importedMetadataFragments.joined(separator: " • ")
    }

    var displayNotes: String {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if isImportedFromHealth {
            if isHealthLinkedSession {
                switch (trimmedNotes.isEmpty, importedMetadataSummary.isEmpty) {
                case (false, false):
                    return "\(trimmedNotes) • \(importedMetadataSummary)"
                case (false, true):
                    return trimmedNotes
                case (true, false):
                    return importedMetadataSummary
                case (true, true):
                    return ""
                }
            }

            return importedMetadataSummary
        }

        return trimmedNotes
    }

    var journalSummaryText: String {
        if templateKind == .stretch {
            let count = exerciseCount
            let noun = count == 1 ? "stretch" : "stretches"
            return "\(count) \(noun) • \(durationMinutes) min"
        }

        if hasExerciseData {
            return "\(exerciseCount) exercises • \(completedSetCount)/\(totalSetCount) sets • \(durationMinutes) min"
        }

        return "\(durationMinutes) min"
    }

    var detailSummaryText: String {
        if templateKind == .stretch {
            let count = exerciseCount
            let noun = count == 1 ? "stretch" : "stretches"
            return "\(completedSetCount)/\(count) \(noun) completed • \(durationMinutes) min"
        }

        if hasExerciseData {
            return "\(completedSetCount)/\(totalSetCount) sets completed • \(Int(totalVolume)) lb volume"
        }

        if isImportedFromHealth, !importedMetadataSummary.isEmpty {
            return "\(durationMinutes) min • \(importedMetadataSummary)"
        }

        return "\(durationMinutes) min"
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

    var detailMetricText: String {
        var fragments: [String] = []

        if let durationSeconds = actualDurationSeconds ?? plannedDurationSeconds, durationSeconds > 0 {
            fragments.append(Self.abbreviatedDurationText(for: durationSeconds))
        }

        if let reps = actualReps ?? plannedReps {
            fragments.append("\(reps) reps")
        }

        if let weight = actualWeight ?? plannedWeight {
            fragments.append("\(weight.formatted(.number.precision(.fractionLength(0...1)))) lb")
        }

        return fragments.joined(separator: " • ")
    }

    private static func abbreviatedDurationText(for seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = [.dropLeading]

        return formatter.string(from: TimeInterval(seconds)) ?? "\(seconds)s"
    }
}
