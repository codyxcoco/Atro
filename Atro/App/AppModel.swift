import SwiftUI
import SwiftData

@MainActor
@Observable
final class AppModel {
    var selectedTab: AppTab = .today
    var pendingBanner: BannerMessage?
    var pendingStreakCounterID: UUID?
    var watchWorkoutProgressRevision = 0
    @ObservationIgnored private var bannerDismissTask: Task<Void, Never>?
    @ObservationIgnored private let watchProgressDefaultsKey = "Atro.watchWorkoutProgressUpdates"
    @ObservationIgnored private let watchProgressEncoder = JSONEncoder()
    @ObservationIgnored private let watchProgressDecoder = JSONDecoder()
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var watchWorkoutProgressByPlannedWorkoutID: [String: WatchWorkoutProgressUpdate] = [:]

    let calendarService = CalendarService()
    let healthService = HealthKitService()
    let haptics = HapticClient()
    #if os(iOS)
    let watchSyncService = WatchSyncService()
    #endif

    init() {
        loadPersistedWatchProgress()

        #if os(iOS)
        watchSyncService.onProgressUpdate = { [weak self] progress in
            self?.receiveWatchWorkoutProgress(progress)
        }
        #endif
    }

    func refreshIntegrations(using settings: AppSettings, modelContext: ModelContext? = nil) async {
        if settings.healthIntegrationEnabled {
            await healthService.refreshTodaySummaryIfNeeded(enabled: true)

            if let modelContext {
                let syncedCount = await healthService.importRecentWorkoutsIfNeeded(in: modelContext, settings: settings)

                if syncedCount > 0 {
                    let title = syncedCount == 1
                        ? "Synced 1 Health workout"
                        : "Synced \(syncedCount) Health workouts"
                    haptics.confirm()
                    showBanner(title, systemImage: "heart.text.square.fill")
                }
            }
        } else {
            healthService.todaySummary = .empty
        }
    }

    #if os(iOS)
    func activateWatchSync() {
        watchSyncService.activate()
    }

    func pushWatchSnapshot(using modelContext: ModelContext) {
        watchSyncService.sync(using: modelContext)
    }
    #endif

    func watchProgress(for plannedWorkoutID: String) -> WatchWorkoutProgressUpdate? {
        guard !plannedWorkoutID.isEmpty else { return nil }
        return watchWorkoutProgressByPlannedWorkoutID[plannedWorkoutID]
    }

    func receiveWatchWorkoutProgress(_ progress: WatchWorkoutProgressUpdate) {
        guard !progress.plannedWorkoutID.isEmpty else { return }

        if let existing = watchWorkoutProgressByPlannedWorkoutID[progress.plannedWorkoutID],
           existing.updatedAt >= progress.updatedAt {
            return
        }

        watchWorkoutProgressByPlannedWorkoutID[progress.plannedWorkoutID] = progress
        watchWorkoutProgressRevision += 1
        persistWatchProgress()
    }

    func clearWatchProgress(for plannedWorkoutID: String) {
        guard !plannedWorkoutID.isEmpty,
              watchWorkoutProgressByPlannedWorkoutID.removeValue(forKey: plannedWorkoutID) != nil else {
            return
        }

        watchWorkoutProgressRevision += 1
        persistWatchProgress()
    }

    deinit {
        bannerDismissTask?.cancel()
    }

    func showBanner(
        _ title: String,
        systemImage: String = "checkmark.circle.fill",
        duration: Duration = .seconds(2)
    ) {
        bannerDismissTask?.cancel()

        let banner = BannerMessage(title: title, systemImage: systemImage)
        pendingBanner = banner

        bannerDismissTask = Task { [weak self, banner] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled, let self, self.pendingBanner?.id == banner.id else { return }

            self.pendingBanner = nil
            self.bannerDismissTask = nil
        }
    }

    private func loadPersistedWatchProgress() {
        guard let data = defaults.data(forKey: watchProgressDefaultsKey),
              let updates = try? watchProgressDecoder.decode([WatchWorkoutProgressUpdate].self, from: data) else {
            return
        }

        for update in updates where !update.plannedWorkoutID.isEmpty {
            if let existing = watchWorkoutProgressByPlannedWorkoutID[update.plannedWorkoutID],
               existing.updatedAt >= update.updatedAt {
                continue
            }

            watchWorkoutProgressByPlannedWorkoutID[update.plannedWorkoutID] = update
        }
    }

    private func persistWatchProgress() {
        let updates = Array(watchWorkoutProgressByPlannedWorkoutID.values)
        guard let data = try? watchProgressEncoder.encode(updates) else { return }

        defaults.set(data, forKey: watchProgressDefaultsKey)
    }

    func handleDeepLink(_ url: URL) {
        guard url.scheme == "atro" else { return }

        switch url.host {
        case "streak", "streaks":
            selectedTab = .streaks

            if let idString = url.pathComponents.dropFirst().first,
               let id = UUID(uuidString: idString) {
                pendingStreakCounterID = id
            }
        case "planned-workout":
            selectedTab = .plan
        default:
            break
        }
    }
}

enum AppTab: Hashable {
    case today
    case streaks
    case plan
    case journal
    case settings
}

struct BannerMessage: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let systemImage: String
}
