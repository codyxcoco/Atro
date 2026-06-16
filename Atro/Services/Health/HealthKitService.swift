import Foundation
import HealthKit
import SwiftData

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

    private struct PlannedWorkoutMatch {
        let plannedWorkout: PlannedWorkout
        let sourceTemplateID: String
        let sourceTemplateName: String
    }

    var authorizationState: HealthAuthorizationState = HKHealthStore.isHealthDataAvailable() ? .notDetermined : .unavailable
    var todaySummary: HealthTodaySummary = .empty

    private let healthStore = HKHealthStore()
    private let calendar = Calendar.autoupdatingCurrent
    private let importLookbackDays = 90
    private let plannedWorkoutMatchWindow: TimeInterval = 6 * 60 * 60
    private let healthLinkWindow: TimeInterval = 4 * 60 * 60
    private let manualAttachmentWindow: TimeInterval = 18 * 60 * 60

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

        do {
            try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
            authorizationState = .notDetermined
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

    func importRecentWorkoutsIfNeeded(in modelContext: ModelContext, settings: AppSettings) async -> Int {
        guard settings.healthIntegrationEnabled, HKHealthStore.isHealthDataAvailable() else {
            return 0
        }

        let startDate = calendar.date(byAdding: .day, value: -importLookbackDays, to: .now) ?? .distantPast
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: .now, options: .strictStartDate)

        do {
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.workout(predicate)],
                sortDescriptors: [],
                limit: nil
            )
            let workouts = try await descriptor.result(for: healthStore)
            let loggedWorkouts = try modelContext.fetch(FetchDescriptor<LoggedWorkout>())
            let plannedWorkouts = try modelContext.fetch(FetchDescriptor<PlannedWorkout>())

            var importedIDs = Set(
                loggedWorkouts.compactMap { workout in
                    workout.healthKitWorkoutID.isEmpty ? nil : workout.healthKitWorkoutID
                }
            )

            var syncedCount = 0
            var mutableLoggedWorkouts = loggedWorkouts

            for workout in workouts.sorted(by: { $0.endDate < $1.endDate }) {
                guard shouldConsiderImport(workout, importedIDs: importedIDs, existingWorkouts: mutableLoggedWorkouts) else {
                    continue
                }

                let matchedPlan = matchPlannedWorkout(for: workout, from: plannedWorkouts, existingWorkouts: loggedWorkouts)
                let metadataText = await importedWorkoutNotes(
                    activityType: workout.workoutActivityType,
                    startDate: workout.startDate,
                    endDate: workout.endDate,
                    matchedPlan: matchedPlan
                )

                if let linkedWorkout = bestAttachmentTarget(
                    forImportedWorkoutStartingAt: workout.startDate,
                    endingAt: workout.endDate,
                    among: mutableLoggedWorkouts,
                    maxGap: healthLinkWindow
                ) {
                    try attachHealthMetadata(
                        workoutID: workout.uuid.uuidString,
                        metadataText: metadataText,
                        to: linkedWorkout,
                        matchedPlan: matchedPlan,
                        in: modelContext
                    )
                    importedIDs.insert(workout.uuid.uuidString)
                    syncedCount += 1
                    continue
                }

                let importedWorkout = buildLoggedWorkout(from: workout, matchedPlan: matchedPlan, metadataText: metadataText)
                modelContext.insert(importedWorkout)
                mutableLoggedWorkouts.append(importedWorkout)
                importedIDs.insert(workout.uuid.uuidString)

                if let matchedPlan {
                    matchedPlan.plannedWorkout.completedLoggedWorkoutID = importedWorkout.id.uuidString
                    matchedPlan.plannedWorkout.updatedAt = Date.now
                }

                syncedCount += 1
            }

            if syncedCount > 0 {
                try modelContext.save()
            }

            authorizationState = .authorized
            return syncedCount
        } catch {
            authorizationState = .denied
            return 0
        }
    }

    func writeWorkoutIfNeeded(_ workout: LoggedWorkout, settings: AppSettings) async {
        guard settings.healthIntegrationEnabled, workout.healthKitWorkoutID.isEmpty else {
            return
        }

        if settings.healthWorkoutWriteEnabled {
            do {
                _ = try await buildWorkoutSample(for: workout)
            } catch {
                authorizationState = .denied
            }
        }
    }

    func attachExistingImportedWorkoutIfPossible(to loggedWorkout: LoggedWorkout, in context: ModelContext) throws -> Bool {
        guard loggedWorkout.healthKitWorkoutID.isEmpty else {
            return false
        }

        let allWorkouts = try context.fetch(FetchDescriptor<LoggedWorkout>())
        let importedWorkout = allWorkouts
            .filter { $0.id != loggedWorkout.id && $0.isPureHealthImport }
            .compactMap { candidate -> (LoggedWorkout, TimeInterval)? in
                guard let score = attachmentScore(
                    candidate: loggedWorkout,
                    importedStartDate: candidate.startedAt,
                    importedEndDate: candidate.endedAt,
                    maxGap: healthLinkWindow
                ) else {
                    return nil
                }

                return (candidate, score)
            }
            .sorted { lhs, rhs in
                lhs.1 < rhs.1
            }
            .first?
            .0

        guard let importedWorkout else {
            return false
        }

        try attachImportedWorkout(importedWorkout, to: loggedWorkout, in: context)
        return true
    }

    func attachmentCandidates(for importedWorkout: LoggedWorkout, among workouts: [LoggedWorkout]) -> [LoggedWorkout] {
        guard importedWorkout.isPureHealthImport else {
            return []
        }

        return workouts
            .filter { $0.id != importedWorkout.id && !$0.isImportedFromHealth }
            .compactMap { candidate -> (LoggedWorkout, TimeInterval)? in
                guard let score = attachmentScore(
                    candidate: candidate,
                    importedStartDate: importedWorkout.startedAt,
                    importedEndDate: importedWorkout.endedAt,
                    maxGap: manualAttachmentWindow
                ) else {
                    return nil
                }

                return (candidate, score)
            }
            .sorted { lhs, rhs in
                lhs.1 < rhs.1
            }
            .map(\.0)
    }

    func attachImportedWorkout(_ importedWorkout: LoggedWorkout, to targetWorkout: LoggedWorkout, in context: ModelContext) throws {
        guard importedWorkout.isImportedFromHealth else {
            return
        }

        try attachHealthMetadata(
            workoutID: importedWorkout.healthKitWorkoutID,
            metadataText: importedWorkout.healthKitMetadataText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? importedWorkout.notes
                : importedWorkout.healthKitMetadataText,
            to: targetWorkout,
            sourceWorkout: importedWorkout,
            matchedPlan: nil,
            in: context
        )
        context.delete(importedWorkout)
        try context.save()
    }

    private func buildWorkoutSample(for workout: LoggedWorkout) async throws -> HKWorkout {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workout.workoutActivityType
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
            HKMetadataKeyWorkoutBrandName: "Atro"
        ]
    }

    private func shouldConsiderImport(_ workout: HKWorkout, importedIDs: Set<String>, existingWorkouts: [LoggedWorkout]) -> Bool {
        if importedIDs.contains(workout.uuid.uuidString) {
            return false
        }

        if let brand = workout.metadata?[HKMetadataKeyWorkoutBrandName] as? String,
           brand.caseInsensitiveCompare("Atro") == .orderedSame {
            return false
        }

        if let externalUUID = workout.metadata?[HKMetadataKeyExternalUUID] as? String,
           existingWorkouts.contains(where: { $0.id.uuidString == externalUUID }) {
            return false
        }

        return true
    }

    private func matchPlannedWorkout(
        for workout: HKWorkout,
        from plannedWorkouts: [PlannedWorkout],
        existingWorkouts: [LoggedWorkout]
    ) -> PlannedWorkoutMatch? {
        let candidates = plannedWorkouts.filter { plannedWorkout in
            guard !plannedWorkout.isRestDay else { return false }
            guard calendar.isDate(plannedWorkout.scheduledFor, inSameDayAs: workout.startDate) else { return false }

            if !plannedWorkout.completedLoggedWorkoutID.isEmpty {
                return false
            }

            let alreadyLinked = existingWorkouts.contains { $0.plannedWorkoutID == plannedWorkout.id.uuidString }
            return !alreadyLinked
        }

        guard !candidates.isEmpty else {
            return nil
        }

        if candidates.count == 1, let onlyCandidate = candidates.first {
            return PlannedWorkoutMatch(
                plannedWorkout: onlyCandidate,
                sourceTemplateID: onlyCandidate.sourceTemplateID,
                sourceTemplateName: onlyCandidate.templateName
            )
        }

        let sortedCandidates = candidates.sorted {
            abs($0.scheduledFor.timeIntervalSince(workout.startDate)) < abs($1.scheduledFor.timeIntervalSince(workout.startDate))
        }

        guard let bestCandidate = sortedCandidates.first,
              abs(bestCandidate.scheduledFor.timeIntervalSince(workout.startDate)) <= plannedWorkoutMatchWindow else {
            return nil
        }

        return PlannedWorkoutMatch(
            plannedWorkout: bestCandidate,
            sourceTemplateID: bestCandidate.sourceTemplateID,
            sourceTemplateName: bestCandidate.templateName
        )
    }

    private func buildLoggedWorkout(from workout: HKWorkout, matchedPlan: PlannedWorkoutMatch?, metadataText: String) -> LoggedWorkout {
        let workoutID = workout.uuid.uuidString
        let activityType = workout.workoutActivityType
        let startDate = workout.startDate
        let endDate = workout.endDate

        return LoggedWorkout(
            sourceTemplateID: matchedPlan?.sourceTemplateID ?? "",
            sourceTemplateName: matchedPlan?.sourceTemplateName ?? "",
            plannedWorkoutID: matchedPlan?.plannedWorkout.id.uuidString ?? "",
            healthKitWorkoutID: workoutID,
            healthKitMetadataText: metadataText,
            workoutName: workoutTitle(for: activityType),
            startedAt: startDate,
            endedAt: endDate,
            notes: "",
            tagText: "Apple Health",
            isFavorite: false,
            createdAt: endDate,
            loggedExercises: [],
            moodCheckIns: []
        )
    }

    private func bestAttachmentTarget(
        forImportedWorkoutStartingAt startDate: Date,
        endingAt endDate: Date,
        among workouts: [LoggedWorkout],
        maxGap: TimeInterval
    ) -> LoggedWorkout? {
        workouts
            .filter { !$0.isImportedFromHealth }
            .compactMap { candidate -> (LoggedWorkout, TimeInterval)? in
                guard let score = attachmentScore(
                    candidate: candidate,
                    importedStartDate: startDate,
                    importedEndDate: endDate,
                    maxGap: maxGap
                ) else {
                    return nil
                }

                return (candidate, score)
            }
            .sorted { lhs, rhs in
                lhs.1 < rhs.1
            }
            .first?
            .0
    }

    private func attachmentScore(
        candidate: LoggedWorkout,
        importedStartDate: Date,
        importedEndDate: Date,
        maxGap: TimeInterval
    ) -> TimeInterval? {
        guard candidate.healthKitWorkoutID.isEmpty else {
            return nil
        }

        let sharesDay =
            calendar.isDate(candidate.startedAt, inSameDayAs: importedStartDate) ||
            calendar.isDate(candidate.endedAt, inSameDayAs: importedEndDate)
        guard sharesDay else {
            return nil
        }

        let startGap = abs(candidate.startedAt.timeIntervalSince(importedStartDate))
        let endGap = abs(candidate.endedAt.timeIntervalSince(importedEndDate))
        let overlap = intervalOverlap(
            startA: candidate.startedAt,
            endA: candidate.endedAt,
            startB: importedStartDate,
            endB: importedEndDate
        )
        let minimumGap = min(startGap, endGap)

        guard overlap > 15 * 60 || minimumGap <= maxGap else {
            return nil
        }

        let candidateDuration = candidate.endedAt.timeIntervalSince(candidate.startedAt)
        let importedDuration = importedEndDate.timeIntervalSince(importedStartDate)
        let durationGap = abs(candidateDuration - importedDuration)
        let overlapBonus = min(overlap, 75 * 60) * 0.65

        return max(startGap + endGap + (durationGap * 0.45) - overlapBonus, 0)
    }

    private func intervalOverlap(
        startA: Date,
        endA: Date,
        startB: Date,
        endB: Date
    ) -> TimeInterval {
        let overlapStart = max(startA, startB)
        let overlapEnd = min(endA, endB)
        return max(overlapEnd.timeIntervalSince(overlapStart), 0)
    }

    private func attachHealthMetadata(
        workoutID: String,
        metadataText: String,
        to targetWorkout: LoggedWorkout,
        sourceWorkout: LoggedWorkout? = nil,
        matchedPlan: PlannedWorkoutMatch?,
        in context: ModelContext
    ) throws {
        targetWorkout.healthKitWorkoutID = workoutID

        let trimmedMetadata = metadataText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedMetadata.isEmpty {
            targetWorkout.healthKitMetadataText = trimmedMetadata
        }

        targetWorkout.tagText = mergedTags(
            existing: targetWorkout.tags,
            adding: ["Apple Health"] + (sourceWorkout?.tags ?? [])
        )

        if targetWorkout.sourceTemplateID.isEmpty {
            targetWorkout.sourceTemplateID = sourceWorkout?.sourceTemplateID ?? matchedPlan?.sourceTemplateID ?? ""
        }

        if targetWorkout.sourceTemplateName.isEmpty {
            targetWorkout.sourceTemplateName = sourceWorkout?.sourceTemplateName ?? matchedPlan?.sourceTemplateName ?? ""
        }

        if targetWorkout.plannedWorkoutID.isEmpty {
            targetWorkout.plannedWorkoutID = sourceWorkout?.plannedWorkoutID ?? matchedPlan?.plannedWorkout.id.uuidString ?? ""
        }

        try updatePlannedWorkoutLink(from: sourceWorkout, matchedPlan: matchedPlan, to: targetWorkout, in: context)
    }

    private func updatePlannedWorkoutLink(
        from sourceWorkout: LoggedWorkout?,
        matchedPlan: PlannedWorkoutMatch?,
        to targetWorkout: LoggedWorkout,
        in context: ModelContext
    ) throws {
        if let matchedPlan {
            matchedPlan.plannedWorkout.completedLoggedWorkoutID = targetWorkout.id.uuidString
            matchedPlan.plannedWorkout.updatedAt = .now
            return
        }

        guard let sourceWorkout, !sourceWorkout.plannedWorkoutID.isEmpty else {
            return
        }

        let plannedWorkouts = try context.fetch(FetchDescriptor<PlannedWorkout>())
        if let plannedWorkout = plannedWorkouts.first(where: { $0.id.uuidString == sourceWorkout.plannedWorkoutID }) {
            plannedWorkout.completedLoggedWorkoutID = targetWorkout.id.uuidString
            plannedWorkout.updatedAt = .now
        }
    }

    private func mergedTags(existing: [String], adding newTags: [String]) -> String {
        var seen = Set<String>()
        let merged = (existing + newTags).filter { tag in
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return false
            }

            let key = trimmed.lowercased()
            guard !seen.contains(key) else {
                return false
            }

            seen.insert(key)
            return true
        }

        return merged.joined(separator: ", ")
    }

    private func importedWorkoutNotes(
        activityType: HKWorkoutActivityType,
        startDate: Date,
        endDate: Date,
        matchedPlan: PlannedWorkoutMatch?
    ) async -> String {
        var fragments = ["Imported from Apple Health"]

        if let matchedPlan {
            fragments.append("linked to \(matchedPlan.sourceTemplateName)")
        }

        let activeEnergy = await activeEnergyKilocalories(startDate: startDate, endDate: endDate)
        if activeEnergy > 0 {
            fragments.append("\(Int(activeEnergy.rounded())) active kcal")
        }

        let distance = await distanceMiles(for: activityType, startDate: startDate, endDate: endDate)
        if distance > 0.05 {
            fragments.append("\(distance.formatted(.number.precision(.fractionLength(1)))) mi")
        }

        return fragments.joined(separator: " • ")
    }

    private func activeEnergyKilocalories(startDate: Date, endDate: Date) async -> Double {
        guard let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return 0
        }

        return await cumulativeQuantityValue(
            for: activeEnergyType,
            unit: .kilocalorie(),
            startDate: startDate,
            endDate: endDate
        )
    }

    private func distanceMiles(for activityType: HKWorkoutActivityType, startDate: Date, endDate: Date) async -> Double {
        guard let distanceType = distanceQuantityType(for: activityType) else {
            return 0
        }

        return await cumulativeQuantityValue(
            for: distanceType,
            unit: .mile(),
            startDate: startDate,
            endDate: endDate
        )
    }

    private func distanceQuantityType(for activityType: HKWorkoutActivityType) -> HKQuantityType? {
        let identifier: HKQuantityTypeIdentifier

        switch activityType {
        case .running, .walking, .hiking:
            identifier = .distanceWalkingRunning
        case .cycling:
            identifier = .distanceCycling
        case .swimming:
            identifier = .distanceSwimming
        case .rowing:
            identifier = .distanceRowing
        case .downhillSkiing, .snowboarding:
            identifier = .distanceDownhillSnowSports
        default:
            return nil
        }

        return HKQuantityType.quantityType(forIdentifier: identifier)
    }

    private func cumulativeQuantityValue(
        for quantityType: HKQuantityType,
        unit: HKUnit,
        startDate: Date,
        endDate: Date
    ) async -> Double {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: quantityType, predicate: predicate),
            options: .cumulativeSum
        )

        do {
            return try await descriptor.result(for: healthStore)?
                .sumQuantity()?
                .doubleValue(for: unit) ?? 0
        } catch {
            return 0
        }
    }

    private func workoutTitle(for activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .traditionalStrengthTraining:
            "Strength Training"
        case .functionalStrengthTraining:
            "Functional Strength"
        case .highIntensityIntervalTraining:
            "HIIT"
        case .running:
            "Run"
        case .walking:
            "Walk"
        case .cycling:
            "Cycling"
        case .swimming:
            "Swimming"
        case .hiking:
            "Hiking"
        case .yoga:
            "Yoga"
        case .rowing:
            "Rowing"
        case .stairClimbing:
            "Stair Climb"
        case .mixedCardio:
            "Mixed Cardio"
        case .coreTraining:
            "Core Training"
        case .cooldown:
            "Cooldown"
        default:
            "Workout"
        }
    }

    private func save(_ sample: HKSample) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(sample) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: NSError(domain: "Atro.HealthKit", code: 1))
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
                    continuation.resume(throwing: NSError(domain: "Atro.HealthKit", code: 2))
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
                    continuation.resume(throwing: NSError(domain: "Atro.HealthKit", code: 3))
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

extension LoggedWorkout {
    var workoutActivityType: HKWorkoutActivityType {
        switch templateKind {
        case .workout:
            .traditionalStrengthTraining
        case .stretch:
            .cooldown
        }
    }
}
