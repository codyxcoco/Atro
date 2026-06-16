import Foundation
import Observation

struct GuidedStretchStep: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let instructions: String
    let durationSeconds: Int

    init(id: UUID, title: String, instructions: String, durationSeconds: Int) {
        self.id = id
        self.title = title
        self.instructions = instructions
        self.durationSeconds = max(durationSeconds, 1)
    }

    init(exercise: LoggedExerciseDraft) {
        self.init(
            id: exercise.id,
            title: exercise.name.trimmingCharacters(in: .whitespacesAndNewlines),
            instructions: exercise.notes.trimmingCharacters(in: .whitespacesAndNewlines),
            durationSeconds: max(exercise.sets.first?.actualDurationSeconds ?? 0, 1)
        )
    }
}

@MainActor
@Observable
final class GuidedStretchCoordinator {
    private(set) var currentStepIndex = 0
    private(set) var remainingSeconds: Int
    private(set) var isPaused = false
    private(set) var isFinished = false

    let steps: [GuidedStretchStep]

    @ObservationIgnored private let cuePlayer: any StretchCuePlaying
    @ObservationIgnored private let onTimedStepCompletion: (Int) -> Void
    @ObservationIgnored private var timerTask: Task<Void, Never>?

    init(
        steps: [GuidedStretchStep],
        cuePlayer: (any StretchCuePlaying)? = nil,
        onTimedStepCompletion: @escaping (Int) -> Void = { _ in }
    ) {
        self.steps = steps
        self.cuePlayer = cuePlayer ?? StretchCuePlayer()
        self.onTimedStepCompletion = onTimedStepCompletion
        self.remainingSeconds = steps.first?.durationSeconds ?? 0
    }

    var currentStep: GuidedStretchStep? {
        guard steps.indices.contains(currentStepIndex) else { return nil }
        return steps[currentStepIndex]
    }

    var nextStep: GuidedStretchStep? {
        let nextIndex = currentStepIndex + 1
        guard steps.indices.contains(nextIndex) else { return nil }
        return steps[nextIndex]
    }

    var completedStepCount: Int {
        guard !steps.isEmpty else { return 0 }

        if isFinished {
            return steps.count
        }

        return currentStepIndex
    }

    var progress: Double {
        guard !steps.isEmpty else { return 0 }
        guard let currentStep else { return isFinished ? 1 : 0 }

        if isFinished {
            return 1
        }

        let elapsedFraction = 1 - (Double(remainingSeconds) / Double(max(currentStep.durationSeconds, 1)))
        return min(max((Double(currentStepIndex) + elapsedFraction) / Double(steps.count), 0), 1)
    }

    func start() {
        guard !steps.isEmpty else {
            isFinished = true
            return
        }

        timerTask?.cancel()
        isPaused = false
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    break
                }

                guard !Task.isCancelled else {
                    break
                }

                self?.tick()
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
        cuePlayer.stop()
    }

    func pause() {
        isPaused = true
    }

    func resume() {
        guard !isFinished else { return }
        isPaused = false
    }

    func togglePause() {
        isPaused.toggle()
    }

    func tick() {
        guard !isPaused, !isFinished, !steps.isEmpty else {
            return
        }

        guard remainingSeconds > 1 else {
            remainingSeconds = 0
            completeCurrentStep()
            return
        }

        remainingSeconds -= 1

        if (1...5).contains(remainingSeconds) {
            cuePlayer.playCountdownCue(remainingSeconds: remainingSeconds)
        }
    }

    func previousStep() {
        guard !steps.isEmpty else { return }

        if currentStepIndex == 0 {
            remainingSeconds = currentStep?.durationSeconds ?? 0
            isFinished = false
            return
        }

        currentStepIndex -= 1
        remainingSeconds = currentStep?.durationSeconds ?? 0
        isFinished = false
    }

    func nextStepManually() {
        guard !steps.isEmpty else { return }

        if currentStepIndex == steps.count - 1 {
            isFinished = true
            stop()
            return
        }

        currentStepIndex += 1
        remainingSeconds = currentStep?.durationSeconds ?? 0
    }

    private func completeCurrentStep() {
        onTimedStepCompletion(currentStepIndex)

        let isFinalStep = currentStepIndex == steps.count - 1
        cuePlayer.playTransitionCue(isFinalStep: isFinalStep)

        if isFinalStep {
            isFinished = true
            stop()
            return
        }

        currentStepIndex += 1
        remainingSeconds = currentStep?.durationSeconds ?? 0
    }
}
