import SwiftData
import SwiftUI

@MainActor
@Observable
final class WorkoutSessionViewModel {
    var draft: WorkoutSessionDraft
    var restTimerEndDate: Date?
    var showsSummary = false

    private weak var plannedWorkout: PlannedWorkout?

    init(draft: WorkoutSessionDraft, plannedWorkout: PlannedWorkout? = nil) {
        self.draft = draft
        self.plannedWorkout = plannedWorkout
    }

    @discardableResult
    func addExercise() -> UUID {
        let exercise = WorkoutDraftFactory.blankExercise(orderIndex: draft.exercises.count)
        draft.exercises.append(exercise)
        return exercise.id
    }

    func removeExercise(_ exerciseID: UUID) {
        guard let exerciseIndex = draft.exercises.firstIndex(where: { $0.id == exerciseID }) else {
            return
        }

        draft.exercises.remove(at: exerciseIndex)
        reindexExercises()
    }

    @discardableResult
    func addSet(to exerciseID: UUID) -> UUID? {
        guard let exerciseIndex = draft.exercises.firstIndex(where: { $0.id == exerciseID }) else {
            return nil
        }

        let nextIndex = draft.exercises[exerciseIndex].sets.count
        let lastSet = draft.exercises[exerciseIndex].sets.last
        let set = LoggedSetDraft(
            orderIndex: nextIndex,
            isCompleted: false,
            plannedReps: lastSet?.plannedReps ?? 8,
            actualReps: lastSet?.actualReps ?? 8,
            tracksWeight: lastSet?.tracksWeight ?? false,
            plannedWeight: lastSet?.plannedWeight ?? 0,
            actualWeight: lastSet?.actualWeight ?? 0,
            tracksDuration: lastSet?.tracksDuration ?? false,
            plannedDurationSeconds: lastSet?.plannedDurationSeconds ?? 0,
            actualDurationSeconds: lastSet?.actualDurationSeconds ?? 0,
            restSeconds: lastSet?.restSeconds ?? 90
        )
        draft.exercises[exerciseIndex].sets.append(set)
        return set.id
    }

    func removeSet(_ setID: UUID, from exerciseID: UUID) {
        guard let exerciseIndex = draft.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = draft.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }),
              draft.exercises[exerciseIndex].sets.count > 1 else {
            return
        }

        draft.exercises[exerciseIndex].sets.remove(at: setIndex)
        for index in draft.exercises[exerciseIndex].sets.indices {
            draft.exercises[exerciseIndex].sets[index].orderIndex = index
        }
    }

    func startRestTimer(seconds: Int) {
        guard seconds > 0 else {
            restTimerEndDate = nil
            return
        }

        restTimerEndDate = .now.addingTimeInterval(TimeInterval(seconds))
    }

    @discardableResult
    func applyWatchProgress(_ progress: WatchWorkoutProgressUpdate) -> Bool {
        draft.applyWatchProgress(progress)
    }

    @discardableResult
    func completeSet(in exerciseID: UUID, setID: UUID) -> Bool? {
        guard let exerciseIndex = draft.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = draft.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else {
            return nil
        }

        draft.exercises[exerciseIndex].sets[setIndex].isCompleted.toggle()
        return draft.exercises[exerciseIndex].sets[setIndex].isCompleted
    }

    func finish(using modelContext: ModelContext, settings: AppSettings, appModel: AppModel) async throws -> LoggedWorkout {
        let loggedWorkout = WorkoutDraftFactory.makeLoggedWorkout(from: draft)
        modelContext.insert(loggedWorkout)

        if let plannedWorkout {
            plannedWorkout.completedLoggedWorkoutID = loggedWorkout.id.uuidString
            plannedWorkout.updatedAt = .now
        }

        try modelContext.save()
        _ = try appModel.healthService.attachExistingImportedWorkoutIfPossible(to: loggedWorkout, in: modelContext)
        await appModel.healthService.writeWorkoutIfNeeded(loggedWorkout, settings: settings)
        appModel.haptics.confirm()
        appModel.showBanner(draft.templateKind == .stretch ? "Stretch session saved" : "Workout saved")
        return loggedWorkout
    }

    private func reindexExercises() {
        for index in draft.exercises.indices {
            draft.exercises[index].orderIndex = index
        }
    }
}
