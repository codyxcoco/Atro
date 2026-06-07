import Foundation

struct TemplateDraft: Identifiable, Hashable {
    var id: UUID
    var name: String
    var notes: String
    var kindRawValue: String
    var defaultDurationMinutes: Int
    var exercises: [ExerciseDraft]

    init(template: WorkoutTemplate? = nil) {
        if let template {
            id = template.id
            name = template.name
            notes = template.notes
            kindRawValue = template.kind.rawValue
            defaultDurationMinutes = template.displayDurationMinutes
            exercises = template.activeExercises.map { ExerciseDraft(template: $0, kind: template.kind) }
        } else {
            id = UUID()
            name = ""
            notes = ""
            kindRawValue = WorkoutTemplateKind.workout.rawValue
            defaultDurationMinutes = 60
            exercises = [ExerciseDraft()]
        }
    }

    var kind: WorkoutTemplateKind {
        get { WorkoutTemplateKind(rawValue: kindRawValue) ?? .workout }
        set { kindRawValue = newValue.rawValue }
    }

    var canSave: Bool {
        !name.trimmedDraftValue.isEmpty && !savedExercises.isEmpty
    }

    func apply(to template: WorkoutTemplate) {
        template.name = name.trimmedDraftValue
        template.notes = notes.trimmedDraftValue
        template.kind = kind
        template.defaultDurationMinutes = kind == .stretch ? stretchDurationMinutes : defaultDurationMinutes
        template.exercises.removeAll()

        let mappedExercises = normalizedExercises.enumerated().map { index, exercise in
            exercise.makeModel(orderIndex: index, kind: kind)
        }

        template.exercises = mappedExercises
        template.touch()
    }

    private var savedExercises: [ExerciseDraft] {
        exercises.filter { !$0.name.trimmedDraftValue.isEmpty }
    }

    private var normalizedExercises: [ExerciseDraft] {
        savedExercises.map { exercise in
            var normalized = exercise
            normalized.normalize(for: kind)
            return normalized
        }
    }

    private var stretchDurationMinutes: Int {
        max(normalizedExercises.reduce(0) { $0 + max($1.defaultDurationMinutes, 1) }, 1)
    }
}

struct ExerciseDraft: Identifiable, Hashable {
    var id: UUID
    var name: String
    var category: String
    var defaultSets: Int
    var defaultReps: Int
    var tracksWeight: Bool
    var defaultWeight: Double
    var tracksDuration: Bool
    var defaultDurationMinutes: Int
    var defaultRestSeconds: Int
    var notes: String

    init(template: ExerciseTemplate? = nil, kind: WorkoutTemplateKind = .workout) {
        if let template {
            id = template.id
            name = template.name
            category = template.category
            defaultSets = template.defaultSets
            defaultReps = template.defaultReps ?? 8
            tracksWeight = template.defaultWeight != nil
            defaultWeight = template.defaultWeight ?? 0
            tracksDuration = template.defaultDurationSeconds != nil
            defaultDurationMinutes = max((template.defaultDurationSeconds ?? 0) / 60, 0)
            defaultRestSeconds = template.defaultRestSeconds ?? 90
            notes = template.notes
        } else {
            id = UUID()
            name = ""
            category = ""
            defaultSets = 3
            defaultReps = 8
            tracksWeight = false
            defaultWeight = 0
            tracksDuration = false
            defaultDurationMinutes = 0
            defaultRestSeconds = 90
            notes = ""
        }

        normalize(for: kind)
    }

    mutating func normalize(for kind: WorkoutTemplateKind) {
        guard kind == .stretch else {
            if tracksDuration == false && defaultDurationMinutes == 0 {
                defaultDurationMinutes = 0
            }
            return
        }

        category = ""
        defaultSets = 1
        defaultReps = 0
        tracksWeight = false
        defaultWeight = 0
        tracksDuration = true
        defaultDurationMinutes = max(defaultDurationMinutes, 1)
        defaultRestSeconds = 0
    }

    func makeModel(orderIndex: Int, kind: WorkoutTemplateKind) -> ExerciseTemplate {
        ExerciseTemplate(
            id: id,
            orderIndex: orderIndex,
            name: name.trimmedDraftValue,
            category: kind == .stretch ? "" : category.trimmedDraftValue,
            defaultSets: kind == .stretch ? 1 : defaultSets,
            defaultReps: kind == .stretch ? nil : (tracksDuration ? nil : defaultReps),
            defaultWeight: kind == .stretch ? nil : (tracksWeight ? defaultWeight : nil),
            defaultDurationSeconds: kind == .stretch ? max(defaultDurationMinutes, 1) * 60 : (tracksDuration ? defaultDurationMinutes * 60 : nil),
            defaultRestSeconds: kind == .stretch ? 0 : defaultRestSeconds,
            notes: notes.trimmedDraftValue
        )
    }
}

private extension String {
    var trimmedDraftValue: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct WorkoutSessionDraft: Identifiable, Hashable {
    var id = UUID()
    var sourceTemplateID: String
    var sourceTemplateName: String
    var templateKindRawValue: String
    var plannedWorkoutID: String
    var workoutName: String
    var startedAt: Date
    var notes: String
    var tagText: String
    var isFavorite: Bool
    var includePreCheckIn: Bool
    var includePostCheckIn: Bool
    var preCheckIn: MoodDraft
    var postCheckIn: MoodDraft
    var exercises: [LoggedExerciseDraft]

    var savedExercises: [LoggedExerciseDraft] {
        exercises.filter(\.hasNamedContent)
    }

    var templateKind: WorkoutTemplateKind {
        get { WorkoutTemplateKind(rawValue: templateKindRawValue) ?? .workout }
        set { templateKindRawValue = newValue.rawValue }
    }

    var isValid: Bool {
        !workoutName.trimmedDraftValue.isEmpty && !savedExercises.isEmpty
    }
}

struct LoggedExerciseDraft: Identifiable, Hashable {
    var id = UUID()
    var orderIndex: Int
    var name: String
    var category: String
    var notes: String
    var sets: [LoggedSetDraft]

    var hasNamedContent: Bool {
        !name.trimmedDraftValue.isEmpty
    }
}

struct LoggedSetDraft: Identifiable, Hashable {
    var id = UUID()
    var orderIndex: Int
    var isCompleted: Bool
    var plannedReps: Int
    var actualReps: Int
    var tracksWeight: Bool
    var plannedWeight: Double
    var actualWeight: Double
    var tracksDuration: Bool
    var plannedDurationSeconds: Int
    var actualDurationSeconds: Int
    var restSeconds: Int
}

extension WorkoutSessionDraft {
    @discardableResult
    mutating func applyWatchProgress(_ progress: WatchWorkoutProgressUpdate) -> Bool {
        guard !plannedWorkoutID.isEmpty,
              plannedWorkoutID == progress.plannedWorkoutID else {
            return false
        }

        var didChange = false

        if startedAt > progress.startedAt {
            startedAt = progress.startedAt
            didChange = true
        }

        for progressExercise in progress.exercises {
            let matchingExerciseIndex = exercises.firstIndex(where: { $0.id == progressExercise.id })
                ?? exercises.firstIndex(where: { $0.orderIndex == progressExercise.orderIndex })

            guard let exerciseIndex = matchingExerciseIndex else {
                continue
            }

            for progressSet in progressExercise.sets {
                guard let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.orderIndex == progressSet.orderIndex }),
                      exercises[exerciseIndex].sets[setIndex].isCompleted != progressSet.isCompleted else {
                    continue
                }

                exercises[exerciseIndex].sets[setIndex].isCompleted = progressSet.isCompleted
                didChange = true
            }
        }

        return didChange
    }
}

struct MoodDraft: Hashable {
    var moodLevel = 3
    var energyLevel = 3
    var sorenessLevel = 3
    var effortRating = 3
    var confidenceRating = 3

    func makeModel(phase: MoodPhase, date: Date) -> MoodCheckIn {
        MoodCheckIn(
            phase: phase,
            moodLevel: moodLevel,
            energyLevel: energyLevel,
            sorenessLevel: sorenessLevel,
            effortRating: effortRating,
            confidenceRating: confidenceRating,
            createdAt: date
        )
    }
}

struct StretchSessionLogSummary: Hashable {
    let draft: WorkoutSessionDraft
    let stretchCount: Int
    let completedStretchCount: Int
    let intervalDescription: String
    let activeTimeDescription: String
    let summaryLine: String
}

enum WorkoutDraftFactory {
    static func liveSession(named name: String = "Workout") -> WorkoutSessionDraft {
        WorkoutSessionDraft(
            sourceTemplateID: "",
            sourceTemplateName: "",
            templateKindRawValue: WorkoutTemplateKind.workout.rawValue,
            plannedWorkoutID: "",
            workoutName: name,
            startedAt: .now,
            notes: "",
            tagText: "",
            isFavorite: false,
            includePreCheckIn: false,
            includePostCheckIn: true,
            preCheckIn: MoodDraft(),
            postCheckIn: MoodDraft(),
            exercises: []
        )
    }

    static func session(from template: WorkoutTemplate) -> WorkoutSessionDraft {
        session(from: template.makeSnapshot())
    }

    static func session(from plannedWorkout: PlannedWorkout) -> WorkoutSessionDraft {
        if let snapshot = plannedWorkout.snapshot {
            var draft = session(from: snapshot)
            draft.plannedWorkoutID = plannedWorkout.id.uuidString
            draft.workoutName = plannedWorkout.displayName
            return draft
        }

        return WorkoutSessionDraft(
            sourceTemplateID: plannedWorkout.sourceTemplateID,
            sourceTemplateName: plannedWorkout.templateName,
            templateKindRawValue: plannedWorkout.templateKind.rawValue,
            plannedWorkoutID: plannedWorkout.id.uuidString,
            workoutName: plannedWorkout.displayName,
            startedAt: .now,
            notes: "",
            tagText: "",
            isFavorite: false,
            includePreCheckIn: false,
            includePostCheckIn: true,
            preCheckIn: MoodDraft(),
            postCheckIn: MoodDraft(),
            exercises: []
        )
    }

    static func session(from snapshot: TemplateSnapshot) -> WorkoutSessionDraft {
        WorkoutSessionDraft(
            sourceTemplateID: snapshot.sourceTemplateID,
            sourceTemplateName: snapshot.name,
            templateKindRawValue: snapshot.kind.rawValue,
            plannedWorkoutID: "",
            workoutName: snapshot.name,
            startedAt: .now,
            notes: "",
            tagText: "",
            isFavorite: false,
            includePreCheckIn: false,
            includePostCheckIn: true,
            preCheckIn: MoodDraft(),
            postCheckIn: MoodDraft(),
            exercises: snapshot.exercises.enumerated().map { index, exercise in
                LoggedExerciseDraft(
                    id: exercise.id,
                    orderIndex: index,
                    name: exercise.name,
                    category: exercise.category,
                    notes: exercise.notes,
                    sets: (0..<max(exercise.defaultSets, 1)).map { setIndex in
                        LoggedSetDraft(
                            orderIndex: setIndex,
                            isCompleted: false,
                            plannedReps: exercise.defaultReps ?? 0,
                            actualReps: exercise.defaultReps ?? 0,
                            tracksWeight: exercise.defaultWeight != nil,
                            plannedWeight: exercise.defaultWeight ?? 0,
                            actualWeight: exercise.defaultWeight ?? 0,
                            tracksDuration: exercise.defaultDurationSeconds != nil,
                            plannedDurationSeconds: exercise.defaultDurationSeconds ?? 0,
                            actualDurationSeconds: exercise.defaultDurationSeconds ?? 0,
                            restSeconds: exercise.defaultRestSeconds ?? 90
                        )
                    }
                )
            }
        )
    }

    static func blankExercise(orderIndex: Int) -> LoggedExerciseDraft {
        LoggedExerciseDraft(
            orderIndex: orderIndex,
            name: "",
            category: "",
            notes: "",
            sets: [blankSet(orderIndex: 0)]
        )
    }

    static func blankSet(
        orderIndex: Int,
        tracksWeight: Bool = true,
        tracksDuration: Bool = false
    ) -> LoggedSetDraft {
        LoggedSetDraft(
            orderIndex: orderIndex,
            isCompleted: false,
            plannedReps: 8,
            actualReps: 8,
            tracksWeight: tracksWeight,
            plannedWeight: 0,
            actualWeight: 0,
            tracksDuration: tracksDuration,
            plannedDurationSeconds: tracksDuration ? 300 : 0,
            actualDurationSeconds: tracksDuration ? 300 : 0,
            restSeconds: 90
        )
    }

    static func makeLoggedWorkout(from draft: WorkoutSessionDraft, finishedAt: Date = .now) -> LoggedWorkout {
        let savedExercises = draft.savedExercises
        let loggedWorkout = LoggedWorkout(
            sourceTemplateID: draft.sourceTemplateID,
            sourceTemplateName: draft.sourceTemplateName,
            templateKind: draft.templateKind,
            plannedWorkoutID: draft.plannedWorkoutID,
            healthKitMetadataText: "",
            workoutName: draft.workoutName.trimmingCharacters(in: .whitespacesAndNewlines),
            startedAt: draft.startedAt,
            endedAt: finishedAt,
            notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines),
            tagText: draft.tagText,
            isFavorite: draft.isFavorite,
            loggedExercises: savedExercises.enumerated().map { exerciseIndex, exercise in
                LoggedExercise(
                    orderIndex: exerciseIndex,
                    name: exercise.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    category: exercise.category.trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: exercise.notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    loggedSets: exercise.sets.enumerated().map { setIndex, set in
                        LoggedSet(
                            orderIndex: setIndex,
                            isCompleted: set.isCompleted,
                            plannedReps: set.plannedReps > 0 ? set.plannedReps : nil,
                            actualReps: set.actualReps > 0 ? set.actualReps : nil,
                            plannedWeight: set.tracksWeight ? set.plannedWeight : nil,
                            actualWeight: set.tracksWeight ? set.actualWeight : nil,
                            plannedDurationSeconds: set.tracksDuration ? set.plannedDurationSeconds : nil,
                            actualDurationSeconds: set.tracksDuration ? set.actualDurationSeconds : nil,
                            restSeconds: set.restSeconds
                        )
                    }
                )
            },
            moodCheckIns: makeMoodCheckIns(from: draft, finishedAt: finishedAt)
        )

        return loggedWorkout
    }

    static func stretchTimerLogSummary(
        title: String,
        intervalSeconds: Int,
        elapsedSeconds: Int,
        endedAt: Date = .now,
        sourceDraft: WorkoutSessionDraft? = nil
    ) -> StretchSessionLogSummary? {
        let safeElapsedSeconds = max(elapsedSeconds, 0)
        guard safeElapsedSeconds > 0 else { return nil }

        let safeIntervalSeconds = max(intervalSeconds, 15)
        let loggedExercises = buildStretchLogExercises(
            elapsedSeconds: safeElapsedSeconds,
            intervalSeconds: safeIntervalSeconds,
            sourceDraft: sourceDraft
        )

        guard !loggedExercises.isEmpty else { return nil }

        let stretchCount = loggedExercises.count
        let completedStretchCount = loggedExercises.reduce(0) { partialResult, exercise in
            partialResult + exercise.sets.filter(\.isCompleted).count
        }
        let intervalDescription = stretchIntervalDescription(for: loggedExercises, fallbackIntervalSeconds: safeIntervalSeconds)
        let activeTimeDescription = abbreviatedDurationText(for: safeElapsedSeconds)
        let summaryLine = stretchSummaryLine(
            stretchCount: stretchCount,
            intervalDescription: intervalDescription,
            activeTimeDescription: activeTimeDescription
        )

        var draft = sourceDraft ?? WorkoutSessionDraft(
            sourceTemplateID: "",
            sourceTemplateName: "",
            templateKindRawValue: WorkoutTemplateKind.stretch.rawValue,
            plannedWorkoutID: "",
            workoutName: title.trimmedDraftValue.isEmpty ? "Stretch" : title.trimmedDraftValue,
            startedAt: endedAt.addingTimeInterval(-TimeInterval(safeElapsedSeconds)),
            notes: "",
            tagText: "",
            isFavorite: false,
            includePreCheckIn: false,
            includePostCheckIn: false,
            preCheckIn: MoodDraft(),
            postCheckIn: MoodDraft(),
            exercises: []
        )

        draft.templateKind = .stretch
        draft.workoutName = title.trimmedDraftValue.isEmpty ? "Stretch" : title.trimmedDraftValue
        draft.startedAt = endedAt.addingTimeInterval(-TimeInterval(safeElapsedSeconds))
        draft.notes = summaryLine
        draft.includePreCheckIn = false
        draft.includePostCheckIn = false
        draft.exercises = loggedExercises

        return StretchSessionLogSummary(
            draft: draft,
            stretchCount: stretchCount,
            completedStretchCount: completedStretchCount,
            intervalDescription: intervalDescription,
            activeTimeDescription: activeTimeDescription,
            summaryLine: summaryLine
        )
    }

    private static func makeMoodCheckIns(from draft: WorkoutSessionDraft, finishedAt: Date) -> [MoodCheckIn] {
        var items: [MoodCheckIn] = []

        if draft.includePreCheckIn {
            items.append(draft.preCheckIn.makeModel(phase: .pre, date: draft.startedAt))
        }

        if draft.includePostCheckIn {
            items.append(draft.postCheckIn.makeModel(phase: .post, date: finishedAt))
        }

        return items
    }

    private static func buildStretchLogExercises(
        elapsedSeconds: Int,
        intervalSeconds: Int,
        sourceDraft: WorkoutSessionDraft?
    ) -> [LoggedExerciseDraft] {
        if let sourceDraft, !sourceDraft.savedExercises.isEmpty {
            let sourceExercises = sourceDraft.savedExercises
            var remainingSeconds = elapsedSeconds
            var loggedExercises: [LoggedExerciseDraft] = []

            for (index, exercise) in sourceExercises.enumerated() {
                guard remainingSeconds > 0 else { break }

                let plannedDurationSeconds = max(plannedStretchDuration(for: exercise, fallbackIntervalSeconds: intervalSeconds), 1)
                let actualDurationSeconds = min(plannedDurationSeconds, remainingSeconds)

                loggedExercises.append(
                    LoggedExerciseDraft(
                        id: exercise.id,
                        orderIndex: index,
                        name: exercise.name.trimmedDraftValue,
                        category: "",
                        notes: exercise.notes.trimmedDraftValue,
                        sets: [
                            stretchLogSet(
                                orderIndex: 0,
                                plannedDurationSeconds: plannedDurationSeconds,
                                actualDurationSeconds: actualDurationSeconds
                            )
                        ]
                    )
                )

                remainingSeconds -= actualDurationSeconds
            }

            if !loggedExercises.isEmpty {
                return loggedExercises
            }
        }

        let intervalCount = max(Int(ceil(Double(elapsedSeconds) / Double(intervalSeconds))), 1)
        var loggedExercises: [LoggedExerciseDraft] = []

        for index in 0..<intervalCount {
            let consumedSeconds = index * intervalSeconds
            let actualDurationSeconds = min(intervalSeconds, max(elapsedSeconds - consumedSeconds, 0))
            guard actualDurationSeconds > 0 else { continue }

            loggedExercises.append(
                LoggedExerciseDraft(
                    orderIndex: index,
                    name: "Stretch \(index + 1)",
                    category: "",
                    notes: "",
                    sets: [
                        stretchLogSet(
                            orderIndex: 0,
                            plannedDurationSeconds: intervalSeconds,
                            actualDurationSeconds: actualDurationSeconds
                        )
                    ]
                )
            )
        }

        return loggedExercises
    }

    private static func stretchLogSet(
        orderIndex: Int,
        plannedDurationSeconds: Int,
        actualDurationSeconds: Int
    ) -> LoggedSetDraft {
        LoggedSetDraft(
            orderIndex: orderIndex,
            isCompleted: actualDurationSeconds >= plannedDurationSeconds,
            plannedReps: 0,
            actualReps: 0,
            tracksWeight: false,
            plannedWeight: 0,
            actualWeight: 0,
            tracksDuration: true,
            plannedDurationSeconds: plannedDurationSeconds,
            actualDurationSeconds: actualDurationSeconds,
            restSeconds: 0
        )
    }

    private static func plannedStretchDuration(for exercise: LoggedExerciseDraft, fallbackIntervalSeconds: Int) -> Int {
        guard let firstSet = exercise.sets.first else {
            return fallbackIntervalSeconds
        }

        let configuredDuration = firstSet.plannedDurationSeconds > 0
            ? firstSet.plannedDurationSeconds
            : firstSet.actualDurationSeconds

        return max(configuredDuration, 1)
    }

    private static func stretchIntervalDescription(
        for exercises: [LoggedExerciseDraft],
        fallbackIntervalSeconds: Int
    ) -> String {
        let plannedDurations = exercises.compactMap { exercise in
            exercise.sets.first.map { max($0.plannedDurationSeconds, 1) }
        }

        guard let firstDuration = plannedDurations.first else {
            return intervalLabel(for: fallbackIntervalSeconds)
        }

        if plannedDurations.allSatisfy({ $0 == firstDuration }) {
            return intervalLabel(for: firstDuration)
        }

        return "guided sequence"
    }

    private static func stretchSummaryLine(
        stretchCount: Int,
        intervalDescription: String,
        activeTimeDescription: String
    ) -> String {
        let noun = stretchCount == 1 ? "stretch" : "stretches"
        let intervalSummary = intervalDescription == "guided sequence"
            ? intervalDescription
            : "\(intervalDescription) interval\(stretchCount == 1 ? "" : "s")"

        return [
            "\(stretchCount) \(noun)",
            intervalSummary,
            "\(activeTimeDescription) active time"
        ].joined(separator: " • ")
    }

    private static func intervalLabel(for seconds: Int) -> String {
        abbreviatedDurationText(for: max(seconds, 1))
    }

    private static func abbreviatedDurationText(for seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = [.dropLeading]

        return formatter.string(from: TimeInterval(max(seconds, 1))) ?? "\(seconds)s"
    }
}
