import XCTest
@testable import Atro

@MainActor
final class GuidedStretchCoordinatorTests: XCTestCase {
    func testTickEmitsCountdownCuesAndAutoAdvances() {
        let cuePlayer = StretchCueSpy()
        var completedSteps: [Int] = []
        let coordinator = GuidedStretchCoordinator(
            steps: [
                GuidedStretchStep(id: UUID(), title: "Neck Roll", instructions: "", durationSeconds: 6),
                GuidedStretchStep(id: UUID(), title: "Hamstring Fold", instructions: "", durationSeconds: 3)
            ],
            cuePlayer: cuePlayer,
            onTimedStepCompletion: { completedSteps.append($0) }
        )

        for _ in 0..<6 {
            coordinator.tick()
        }

        XCTAssertEqual(cuePlayer.countdownCues, [5, 4, 3, 2, 1])
        XCTAssertEqual(cuePlayer.transitionCues, [false])
        XCTAssertEqual(completedSteps, [0])
        XCTAssertEqual(coordinator.currentStepIndex, 1)
        XCTAssertEqual(coordinator.remainingSeconds, 3)
        XCTAssertFalse(coordinator.isFinished)
    }

    func testPauseResumeAndManualNavigationBehavePredictably() {
        let coordinator = GuidedStretchCoordinator(
            steps: [
                GuidedStretchStep(id: UUID(), title: "Shoulder Opener", instructions: "", durationSeconds: 3),
                GuidedStretchStep(id: UUID(), title: "Quad Stretch", instructions: "", durationSeconds: 3)
            ],
            cuePlayer: StretchCueSpy()
        )

        coordinator.tick()
        XCTAssertEqual(coordinator.remainingSeconds, 2)

        coordinator.pause()
        coordinator.tick()
        XCTAssertEqual(coordinator.remainingSeconds, 2)

        coordinator.resume()
        coordinator.previousStep()
        XCTAssertEqual(coordinator.currentStepIndex, 0)
        XCTAssertEqual(coordinator.remainingSeconds, 3)

        coordinator.nextStepManually()
        XCTAssertEqual(coordinator.currentStepIndex, 1)
        XCTAssertEqual(coordinator.remainingSeconds, 3)
        XCTAssertFalse(coordinator.isFinished)

        coordinator.nextStepManually()
        XCTAssertTrue(coordinator.isFinished)
    }

    func testFinalStepCompletionUsesFinalTransitionCue() {
        let cuePlayer = StretchCueSpy()
        var completedSteps: [Int] = []
        let coordinator = GuidedStretchCoordinator(
            steps: [
                GuidedStretchStep(id: UUID(), title: "Breathing Reset", instructions: "", durationSeconds: 1)
            ],
            cuePlayer: cuePlayer,
            onTimedStepCompletion: { completedSteps.append($0) }
        )

        coordinator.tick()

        XCTAssertEqual(completedSteps, [0])
        XCTAssertEqual(cuePlayer.transitionCues, [true])
        XCTAssertTrue(coordinator.isFinished)
        XCTAssertEqual(coordinator.progress, 1)
    }

    func testStopStopsCuePlayer() {
        let cuePlayer = StretchCueSpy()
        let coordinator = GuidedStretchCoordinator(
            steps: [
                GuidedStretchStep(id: UUID(), title: "Reset", instructions: "", durationSeconds: 10)
            ],
            cuePlayer: cuePlayer
        )

        coordinator.start()
        coordinator.stop()

        XCTAssertEqual(cuePlayer.stopCalls, 1)
    }
}

@MainActor
final class StretchTimerControllerTests: XCTestCase {
    func testTickTracksOverallAndIntervalProgress() {
        let cuePlayer = StretchCueSpy()
        let controller = StretchTimerController(
            totalDurationSeconds: 65,
            intervalDurationSeconds: 15,
            cuePlayer: cuePlayer
        )

        controller.start()

        for _ in 0..<15 {
            controller.tick()
        }

        XCTAssertEqual(cuePlayer.countdownCues, [5, 4, 3, 2, 1])
        XCTAssertEqual(cuePlayer.transitionCues, [false])
        XCTAssertEqual(controller.totalRemainingSeconds, 50)
        XCTAssertEqual(controller.intervalRemainingSeconds, 15)
        XCTAssertEqual(controller.elapsedSeconds, 15)
        XCTAssertTrue(controller.isActive)
        XCTAssertFalse(controller.isFinished)
    }

    func testFinalTickUsesCompletionCueAndFinishesSession() {
        let cuePlayer = StretchCueSpy()
        let controller = StretchTimerController(
            totalDurationSeconds: 3,
            intervalDurationSeconds: 30,
            cuePlayer: cuePlayer
        )

        controller.start()

        controller.tick()
        controller.tick()
        controller.tick()

        XCTAssertEqual(cuePlayer.transitionCues, [true])
        XCTAssertEqual(controller.totalRemainingSeconds, 0)
        XCTAssertEqual(controller.intervalRemainingSeconds, 0)
        XCTAssertEqual(controller.elapsedSeconds, 3)
        XCTAssertTrue(controller.isFinished)
        XCTAssertFalse(controller.isActive)
    }

    func testStopResetsSessionStateAndStopsCuePlayer() {
        let cuePlayer = StretchCueSpy()
        let controller = StretchTimerController(
            totalDurationSeconds: 120,
            intervalDurationSeconds: 30,
            cuePlayer: cuePlayer
        )

        controller.start()
        controller.tick()
        controller.stop()

        XCTAssertEqual(cuePlayer.stopCalls, 3)
        XCTAssertEqual(controller.totalRemainingSeconds, 120)
        XCTAssertEqual(controller.intervalRemainingSeconds, 30)
        XCTAssertEqual(controller.elapsedSeconds, 0)
        XCTAssertFalse(controller.isActive)
        XCTAssertFalse(controller.isFinished)
    }
}

final class StretchDurationDialModelTests: XCTestCase {
    func testSupportedMinutesCoverEveryMinuteUpToMaximum() {
        XCTAssertEqual(StretchDurationDialModel.supportedMinutes.first, 0)
        XCTAssertEqual(StretchDurationDialModel.supportedMinutes.last, 120)
        XCTAssertEqual(StretchDurationDialModel.supportedMinutes.count, 121)
        XCTAssertEqual(StretchDurationDialModel.supportedMinutes, Array(0...120))
    }

    func testClampRespectsSupportedRange() {
        XCTAssertEqual(StretchDurationDialModel.clampedMinute(-5), 0)
        XCTAssertEqual(StretchDurationDialModel.clampedMinute(0), 0)
        XCTAssertEqual(StretchDurationDialModel.clampedMinute(1), 1)
        XCTAssertEqual(StretchDurationDialModel.clampedMinute(60), 60)
        XCTAssertEqual(StretchDurationDialModel.clampedMinute(120), 120)
        XCTAssertEqual(StretchDurationDialModel.clampedMinute(121), 120)
    }

    func testSecondsAndMinutesRoundTripAcrossKeySelections() {
        for minute in [0, 1, 60, 120] {
            let seconds = StretchDurationDialModel.seconds(for: minute)
            XCTAssertEqual(StretchDurationDialModel.minutes(for: seconds), minute)
        }
    }

    func testReadoutFormattingMatchesSelectedMinute() {
        XCTAssertEqual(StretchDurationDialModel.readoutText(for: 0), "0:00")
        XCTAssertEqual(StretchDurationDialModel.readoutText(for: 1), "1:00")
        XCTAssertEqual(StretchDurationDialModel.readoutText(for: 60), "60:00")
        XCTAssertEqual(StretchDurationDialModel.readoutText(for: 120), "120:00")
    }

    func testMajorTickClassificationUsesFiveMinuteBoundaries() {
        XCTAssertTrue(StretchDurationDialModel.isMajorTick(0))
        XCTAssertFalse(StretchDurationDialModel.isMajorTick(1))
        XCTAssertFalse(StretchDurationDialModel.isMajorTick(4))
        XCTAssertTrue(StretchDurationDialModel.isMajorTick(5))
        XCTAssertTrue(StretchDurationDialModel.isMajorTick(120))
    }

    func testCanStartRequiresAtLeastOneMinute() {
        XCTAssertFalse(StretchDurationDialModel.canStart(minutes: 0))
        XCTAssertTrue(StretchDurationDialModel.canStart(minutes: 1))
        XCTAssertTrue(StretchDurationDialModel.canStart(minutes: 120))
    }
}

@MainActor
private final class StretchCueSpy: StretchCuePlaying {
    private(set) var countdownCues: [Int] = []
    private(set) var transitionCues: [Bool] = []
    private(set) var stopCalls = 0

    func playCountdownCue(remainingSeconds: Int) {
        countdownCues.append(remainingSeconds)
    }

    func playTransitionCue(isFinalStep: Bool) {
        transitionCues.append(isFinalStep)
    }

    func stop() {
        stopCalls += 1
    }
}
