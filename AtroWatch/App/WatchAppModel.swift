import Foundation
import Observation
import WatchConnectivity

@MainActor
@Observable
final class WatchAppModel: NSObject, WCSessionDelegate {
    var snapshot: WatchWorkoutSnapshot?
    var activeSession: WatchSessionState?
    var isRefreshing = false
    var errorMessage: String?

    @ObservationIgnored private let encoder = JSONEncoder()
    @ObservationIgnored private let decoder = JSONDecoder()
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let snapshotDefaultsKey = "AtroWatch.snapshotData"
    @ObservationIgnored private let sessionDefaultsKey = "AtroWatch.sessionData"
    @ObservationIgnored private let progressPayloadKey = "progressData"

    override init() {
        super.init()
        loadPersistedState()
        activateSession()
    }

    func refresh() {
        guard WCSession.isSupported() else {
            errorMessage = "Watch sync is unavailable on this device."
            return
        }

        let session = WCSession.default
        isRefreshing = true
        errorMessage = nil

        applySnapshotContext(session.applicationContext)

        guard session.activationState == .activated else {
            isRefreshing = false
            return
        }

        if session.isReachable {
            session.sendMessage(["request": "snapshot"]) { [weak self] reply in
                Task { @MainActor in
                    guard let self else { return }
                    self.isRefreshing = false
                    self.applySnapshotReply(reply)
                }
            } errorHandler: { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.isRefreshing = false
                    if self.snapshot == nil {
                        self.errorMessage = "Open Atro on your iPhone to sync the latest workout."
                    }
                }
            }
        } else {
            isRefreshing = false
            if snapshot == nil {
                errorMessage = "Open Atro on your iPhone to sync the latest workout."
            }
        }
    }

    func startSession() {
        guard let workout = snapshot?.workout, !workout.isRestDay else { return }

        activeSession = WatchSessionState(workout: workout)
        persistSession()
        pushProgressUpdate()
    }

    func toggleSet(exerciseID: UUID, setID: UUID) {
        guard let exerciseIndex = activeSession?.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = activeSession?.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else {
            return
        }

        activeSession?.exercises[exerciseIndex].sets[setIndex].isCompleted.toggle()
        persistSession()
        pushProgressUpdate()
    }

    func finishSession() {
        guard activeSession?.finishedAt == nil else { return }

        activeSession?.finishedAt = .now
        persistSession()
        pushProgressUpdate()
    }

    func clearSession() {
        activeSession = nil
        defaults.removeObject(forKey: sessionDefaultsKey)
    }

    private func activateSession() {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        session.delegate = self
        session.activate()
        applySnapshotContext(session.applicationContext)
    }

    private func loadPersistedState() {
        if let snapshotData = defaults.data(forKey: snapshotDefaultsKey),
           let decodedSnapshot = try? decoder.decode(WatchWorkoutSnapshot.self, from: snapshotData) {
            snapshot = decodedSnapshot
        }

        if let sessionData = defaults.data(forKey: sessionDefaultsKey),
           let decodedSession = try? decoder.decode(WatchSessionState.self, from: sessionData) {
            activeSession = decodedSession
        }
    }

    private func persistSnapshot(_ snapshot: WatchWorkoutSnapshot, rawData: Data) {
        self.snapshot = snapshot
        defaults.set(rawData, forKey: snapshotDefaultsKey)
    }

    private func persistSession() {
        guard let activeSession, let data = try? encoder.encode(activeSession) else {
            defaults.removeObject(forKey: sessionDefaultsKey)
            return
        }

        defaults.set(data, forKey: sessionDefaultsKey)
    }

    private func pushProgressUpdate() {
        guard let activeSession,
              WCSession.isSupported(),
              let data = try? encoder.encode(activeSession.makeProgressUpdate()) else {
            return
        }

        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let payload = [progressPayloadKey: data]
        session.transferUserInfo(payload)

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }

    private func applySnapshotContext(_ context: [String: Any]) {
        guard let data = context["snapshotData"] as? Data else { return }
        applySnapshotData(data)
    }

    private func applySnapshotReply(_ reply: [String: Any]) {
        guard let data = reply["snapshotData"] as? Data else { return }
        applySnapshotData(data)
    }

    private func applySnapshotData(_ data: Data) {
        guard let decodedSnapshot = try? decoder.decode(WatchWorkoutSnapshot.self, from: data) else {
            errorMessage = "The latest phone sync could not be read."
            return
        }

        persistSnapshot(decodedSnapshot, rawData: data)
        errorMessage = nil
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let errorMessage = error?.localizedDescription
        let snapshotData = session.applicationContext["snapshotData"] as? Data

        Task { @MainActor in
            if let errorMessage {
                self.errorMessage = errorMessage
            }

            if let snapshotData {
                self.applySnapshotData(snapshotData)
            }

            self.pushProgressUpdate()
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String : Any]
    ) {
        let snapshotData = applicationContext["snapshotData"] as? Data

        Task { @MainActor in
            if let snapshotData {
                self.applySnapshotData(snapshotData)
            }
        }
    }
}

struct WatchSessionState: Codable, Hashable, Identifiable {
    var id = UUID()
    var workout: WatchWorkoutSummary
    var startedAt = Date()
    var finishedAt: Date?
    var exercises: [WatchSessionExerciseState]

    init(workout: WatchWorkoutSummary) {
        self.workout = workout
        self.exercises = workout.exercises.map(WatchSessionExerciseState.init)
    }

    var completedSetCount: Int {
        exercises.reduce(0) { partialResult, exercise in
            partialResult + exercise.sets.filter(\.isCompleted).count
        }
    }

    var totalSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    var completionText: String {
        "\(completedSetCount)/\(totalSetCount) sets"
    }

    func makeProgressUpdate(updatedAt: Date = .now) -> WatchWorkoutProgressUpdate {
        WatchWorkoutProgressUpdate(
            id: id,
            workoutID: workout.id,
            plannedWorkoutID: workout.plannedWorkoutID,
            sourceTemplateID: workout.sourceTemplateID,
            workoutTitle: workout.title,
            startedAt: startedAt,
            finishedAt: finishedAt,
            updatedAt: updatedAt,
            exercises: exercises.enumerated().map { exerciseIndex, exercise in
                WatchWorkoutProgressExercise(
                    id: exercise.id,
                    orderIndex: exerciseIndex,
                    sets: exercise.sets.map { set in
                        WatchWorkoutProgressSet(
                            id: set.id,
                            orderIndex: set.orderIndex,
                            isCompleted: set.isCompleted
                        )
                    }
                )
            }
        )
    }
}

struct WatchSessionExerciseState: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var category: String
    var notes: String
    var sets: [WatchSessionSetState]

    init(exercise: WatchWorkoutExercise) {
        id = exercise.id
        name = exercise.name
        category = exercise.category
        notes = exercise.notes
        sets = exercise.sets.map(WatchSessionSetState.init)
    }

    var completionText: String {
        let completed = sets.filter(\.isCompleted).count
        return "\(completed)/\(sets.count) sets"
    }
}

struct WatchSessionSetState: Codable, Hashable, Identifiable {
    var id: UUID
    var orderIndex: Int
    var plannedReps: Int?
    var plannedWeight: Double?
    var plannedDurationSeconds: Int?
    var restSeconds: Int
    var isCompleted = false

    init(set: WatchWorkoutSet) {
        id = set.id
        orderIndex = set.orderIndex
        plannedReps = set.plannedReps
        plannedWeight = set.plannedWeight
        plannedDurationSeconds = set.plannedDurationSeconds
        restSeconds = set.restSeconds
    }
}
