import Foundation

struct TemplateDraft: Identifiable, Hashable {
    var id: UUID
    var name: String
    var notes: String
    var defaultDurationMinutes: Int
    var exercises: [ExerciseDraft]

    init(template: WorkoutTemplate? = nil) {
        if let template {
            id = template.id
            name = template.name
            notes = template.notes
            defaultDurationMinutes = template.defaultDurationMinutes
            exercises = template.activeExercises.map(ExerciseDraft.init(template:))
        } else {
            id = UUID()
            name = ""
            notes = ""
            defaultDurationMinutes = 60
            exercises = [ExerciseDraft()]
        }
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && exercises.contains {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func apply(to template: WorkoutTemplate) {
        template.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        template.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        template.defaultDurationMinutes = defaultDurationMinutes
        template.exercises.removeAll()

        let mappedExercises = exercises.enumerated().map { index, exercise in
            exercise.makeModel(orderIndex: index)
        }

        template.exercises = mappedExercises
        template.touch()
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

    init(template: ExerciseTemplate? = nil) {
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
    }

    func makeModel(orderIndex: Int) -> ExerciseTemplate {
        ExerciseTemplate(
            id: id,
            orderIndex: orderIndex,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultSets: defaultSets,
            defaultReps: tracksDuration ? nil : defaultReps,
            defaultWeight: tracksWeight ? defaultWeight : nil,
            defaultDurationSeconds: tracksDuration ? defaultDurationMinutes * 60 : nil,
            defaultRestSeconds: defaultRestSeconds,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

struct WorkoutSessionDraft: Identifiable, Hashable {
    var id = UUID()
    var sourceTemplateID: String
    var sourceTemplateName: String
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

    var isValid: Bool {
        !workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !exercises.isEmpty
    }
}

struct LoggedExerciseDraft: Identifiable, Hashable {
    var id = UUID()
    var orderIndex: Int
    var name: String
    var category: String
    var notes: String
    var sets: [LoggedSetDraft]
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

enum WorkoutDraftFactory {
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

    static func makeLoggedWorkout(from draft: WorkoutSessionDraft, finishedAt: Date = .now) -> LoggedWorkout {
        let loggedWorkout = LoggedWorkout(
            sourceTemplateID: draft.sourceTemplateID,
            sourceTemplateName: draft.sourceTemplateName,
            plannedWorkoutID: draft.plannedWorkoutID,
            workoutName: draft.workoutName.trimmingCharacters(in: .whitespacesAndNewlines),
            startedAt: draft.startedAt,
            endedAt: finishedAt,
            notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines),
            tagText: draft.tagText,
            isFavorite: draft.isFavorite,
            loggedExercises: draft.exercises.enumerated().map { exerciseIndex, exercise in
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
}
