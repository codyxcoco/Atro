import Foundation
import HealthKit

struct HealthTodaySummary: Equatable {
    var activeEnergyKilocalories: Double
    var exerciseMinutes: Double
    var workoutCount: Int

    static let empty = HealthTodaySummary(activeEnergyKilocalories: 0, exerciseMinutes: 0, workoutCount: 0)
}

enum HealthAuthorizationState: Equatable {
    case unavailable
    case notDetermined
    case authorized
    case denied
}

@MainActor
@Observable
final class HealthKitService {
    private enum HealthKitWriteError: Error {
        case workoutNotReturned
    }

    var authorizationState: HealthAuthorizationState = HKHealthStore.isHealthDataAvailable() ? .notDetermined : .unavailable
    var todaySummary: HealthTodaySummary = .empty

    private let healthStore = HKHealthStore()
    private let calendar = Calendar.autoupdatingCurrent

    func requestAuthorization(settings: AppSettings) async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationState = .unavailable
            return false
        }

        var shareTypes: Set<HKSampleType> = []
        var readTypes: Set<HKObjectType> = []

        readTypes.insert(HKObjectType.workoutType())

        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            readTypes.insert(activeEnergy)
        }

        if let exerciseTime = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            readTypes.insert(exerciseTime)
        }

        if settings.healthWorkoutWriteEnabled {
            shareTypes.insert(HKObjectType.workoutType())
        }

        if settings.healthMoodWriteEnabled {
            shareTypes.insert(HKObjectType.stateOfMindType())
        }

        do {
            try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
            authorizationState = .authorized
            return true
        } catch {
            authorizationState = .denied
            return false
        }
    }

    func refreshTodaySummaryIfNeeded(enabled: Bool) async {
        guard enabled, HKHealthStore.isHealthDataAvailable() else {
            todaySummary = .empty
            return
        }

        let startOfDay = calendar.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: .now, options: .strictStartDate)

        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)

        do {
            let activeEnergyKilocalories: Double
            if let energyType {
                let descriptor = HKStatisticsQueryDescriptor(
                    predicate: .quantitySample(type: energyType, predicate: predicate),
                    options: .cumulativeSum
                )
                activeEnergyKilocalories = try await descriptor.result(for: healthStore)?
                    .sumQuantity()?
                    .doubleValue(for: .kilocalorie()) ?? 0
            } else {
                activeEnergyKilocalories = 0
            }

            let exerciseMinutes: Double
            if let exerciseType {
                let descriptor = HKStatisticsQueryDescriptor(
                    predicate: .quantitySample(type: exerciseType, predicate: predicate),
                    options: .cumulativeSum
                )
                exerciseMinutes = try await descriptor.result(for: healthStore)?
                    .sumQuantity()?
                    .doubleValue(for: .minute()) ?? 0
            } else {
                exerciseMinutes = 0
            }

            let workoutDescriptor = HKSampleQueryDescriptor(
                predicates: [.workout(predicate)],
                sortDescriptors: [],
                limit: nil
            )
            let workouts = try await workoutDescriptor.result(for: healthStore)

            todaySummary = HealthTodaySummary(
                activeEnergyKilocalories: activeEnergyKilocalories,
                exerciseMinutes: exerciseMinutes,
                workoutCount: workouts.count
            )
            authorizationState = .authorized
        } catch {
            authorizationState = .denied
            todaySummary = .empty
        }
    }

    func writeWorkoutIfNeeded(_ workout: LoggedWorkout, settings: AppSettings) async {
        guard settings.healthIntegrationEnabled else {
            return
        }

        if settings.healthWorkoutWriteEnabled {
            do {
                _ = try await buildWorkoutSample(for: workout)
            } catch {
                authorizationState = .denied
            }
        }

        guard settings.healthMoodWriteEnabled else {
            return
        }

        let moodSamples = workout.moodCheckIns.map(makeStateOfMindSample(for:))
        for sample in moodSamples {
            do {
                try await save(sample)
            } catch {
                authorizationState = .denied
            }
        }
    }

    private func buildWorkoutSample(for workout: LoggedWorkout) async throws -> HKWorkout {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .unknown

        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: nil
        )

        try await beginCollection(for: builder, at: workout.startedAt)
        try await builder.addMetadata(workoutMetadata(for: workout))
        try await endCollection(for: builder, at: workout.endedAt)
        return try await finishWorkout(for: builder)
    }

    private func workoutMetadata(for workout: LoggedWorkout) -> [String: Any] {
        [
            HKMetadataKeyExternalUUID: workout.id.uuidString,
            HKMetadataKeyWorkoutBrandName: "Lift Journal"
        ]
    }

    private func makeStateOfMindSample(for checkIn: MoodCheckIn) -> HKStateOfMind {
        let valence = max(-1.0, min(Double(checkIn.moodLevel - 3) / 2.0, 1.0))
        let label: HKStateOfMind.Label = switch checkIn.moodLevel {
        case 1: .drained
        case 2: .anxious
        case 3: .calm
        case 4: .confident
        default: .happy
        }

        return HKStateOfMind(
            date: checkIn.createdAt,
            kind: .momentaryEmotion,
            valence: valence,
            labels: [label],
            associations: [.fitness]
        )
    }

    private func save(_ sample: HKSample) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(sample) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: NSError(domain: "LiftJournal.HealthKit", code: 1))
                }
            }
        }
    }

    private func beginCollection(for builder: HKWorkoutBuilder, at date: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: date) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: NSError(domain: "LiftJournal.HealthKit", code: 2))
                }
            }
        }
    }

    private func endCollection(for builder: HKWorkoutBuilder, at date: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: date) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: NSError(domain: "LiftJournal.HealthKit", code: 3))
                }
            }
        }
    }

    private func finishWorkout(for builder: HKWorkoutBuilder) async throws -> HKWorkout {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout, Error>) in
            builder.finishWorkout { workout, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let workout {
                    continuation.resume(returning: workout)
                } else {
                    continuation.resume(throwing: HealthKitWriteError.workoutNotReturned)
                }
            }
        }
    }
}
