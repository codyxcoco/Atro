#if os(iOS)
import Foundation
import SwiftData
import WatchConnectivity

final class WatchSyncService: NSObject, WCSessionDelegate {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let snapshotPayloadKey = "snapshotData"
    private let progressPayloadKey = "progressData"
    private var latestSnapshotData: Data?
    var onProgressUpdate: (@MainActor (WatchWorkoutProgressUpdate) -> Void)?

    func activate() {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    @MainActor
    func sync(using modelContext: ModelContext) {
        guard WCSession.isSupported() else { return }

        let snapshot = WatchWorkoutSnapshotBuilder.makeSnapshot(using: modelContext)
        guard let data = try? encoder.encode(snapshot) else { return }

        latestSnapshotData = data
        pushApplicationContextIfPossible(data: data, session: WCSession.default)
    }

    private func pushApplicationContextIfPossible(data: Data, session: WCSession) {
        guard session.activationState == .activated else { return }
        guard session.isPaired, session.isWatchAppInstalled else { return }

        try? session.updateApplicationContext([snapshotPayloadKey: data])
    }

    private func snapshotContext() -> [String: Any]? {
        guard let latestSnapshotData else {
            return nil
        }

        return [snapshotPayloadKey: latestSnapshotData]
    }

    private func receiveProgressData(_ data: Data) {
        guard let update = try? decoder.decode(WatchWorkoutProgressUpdate.self, from: data) else {
            return
        }

        guard let onProgressUpdate else { return }

        Task { @MainActor in
            onProgressUpdate(update)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated, let latestSnapshotData else { return }
        pushApplicationContextIfPossible(data: latestSnapshotData, session: session)
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        guard let latestSnapshotData else { return }
        pushApplicationContextIfPossible(data: latestSnapshotData, session: session)
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String : Any],
        replyHandler: @escaping ([String : Any]) -> Void
    ) {
        if let data = message[progressPayloadKey] as? Data {
            receiveProgressData(data)
            replyHandler(["accepted": true])
            return
        }

        guard message["request"] as? String == "snapshot" else {
            replyHandler([:])
            return
        }

        replyHandler(snapshotContext() ?? [:])
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String : Any]
    ) {
        guard let data = message["progressData"] as? Data else { return }
        receiveProgressData(data)
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String : Any] = [:]
    ) {
        guard let data = userInfo["progressData"] as? Data else { return }
        receiveProgressData(data)
    }
}

@MainActor
enum WatchWorkoutSnapshotBuilder {
    static func makeSnapshot(using modelContext: ModelContext) -> WatchWorkoutSnapshot {
        let descriptor = FetchDescriptor<PlannedWorkout>(
            sortBy: [SortDescriptor(\.scheduledFor)]
        )
        let plannedWorkouts = (try? modelContext.fetch(descriptor)) ?? []
        let calendar = Calendar.current

        let todaysWorkout = plannedWorkouts.first {
            calendar.isDateInToday($0.scheduledFor) && $0.completedLoggedWorkoutID.isEmpty
        }
        let nextWorkout = plannedWorkouts.first {
            $0.scheduledFor >= .now &&
            !calendar.isDateInToday($0.scheduledFor) &&
            $0.completedLoggedWorkoutID.isEmpty
        }

        if let todaysWorkout {
            return WatchWorkoutSnapshot(
                generatedAt: .now,
                label: "Today",
                workout: makeSummary(from: todaysWorkout)
            )
        }

        if let nextWorkout {
            return WatchWorkoutSnapshot(
                generatedAt: .now,
                label: "Next Up",
                workout: makeSummary(from: nextWorkout)
            )
        }

        return WatchWorkoutSnapshot(generatedAt: .now, label: "Today", workout: nil)
    }

    private static func makeSummary(from plannedWorkout: PlannedWorkout) -> WatchWorkoutSummary {
        let exercises = plannedWorkout.snapshot?.exercises.sorted { $0.orderIndex < $1.orderIndex } ?? []

        return WatchWorkoutSummary(
            id: plannedWorkout.id,
            plannedWorkoutID: plannedWorkout.id.uuidString,
            sourceTemplateID: plannedWorkout.sourceTemplateID,
            title: plannedWorkout.displayName,
            notes: plannedWorkout.notes,
            scheduledFor: plannedWorkout.scheduledFor,
            durationMinutes: plannedWorkout.durationMinutes,
            isRestDay: plannedWorkout.isRestDay,
            exercises: exercises.map { exercise in
                WatchWorkoutExercise(
                    id: exercise.id,
                    orderIndex: exercise.orderIndex,
                    name: exercise.name,
                    category: exercise.category,
                    notes: exercise.notes,
                    sets: (0..<max(exercise.defaultSets, 1)).map { setIndex in
                        WatchWorkoutSet(
                            id: UUID(),
                            orderIndex: setIndex,
                            plannedReps: exercise.defaultReps,
                            plannedWeight: exercise.defaultWeight,
                            plannedDurationSeconds: exercise.defaultDurationSeconds,
                            restSeconds: exercise.defaultRestSeconds ?? 90
                        )
                    }
                )
            }
        )
    }
}
#endif
