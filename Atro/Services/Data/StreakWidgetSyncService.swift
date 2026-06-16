import SwiftData
import WidgetKit

@MainActor
enum StreakWidgetSyncService {
    static func sync(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<StreakCounter>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        do {
            let counters = try modelContext.fetch(descriptor)
            try sync(counters: counters)
        } catch {
            assertionFailure("Streak widget sync failed: \(error.localizedDescription)")
        }
    }

    static func sync(counters: [StreakCounter]) throws {
        let snapshots = counters
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
                return lhs.updatedAt > rhs.updatedAt
            }
            .map { $0.widgetSnapshot() }

        try StreakWidgetSnapshotStore.saveSnapshots(snapshots)
        WidgetCenter.shared.reloadTimelines(ofKind: AtroWidgetConstants.streakWidgetKind)
    }
}

private extension StreakCounter {
    func widgetSnapshot() -> StreakWidgetSnapshot {
        StreakWidgetSnapshot(
            counterId: id,
            title: title,
            subtitle: counterSubtitle,
            phrase: displayPhrase,
            symbolName: symbolName,
            themeName: theme.rawValue,
            colorHex: theme.colorHex,
            iconColorHex: iconColor.colorHex,
            lastIncidentDate: lastIncidentDate,
            goalDays: goalDays,
            currentStreakDays: currentStreakDays,
            totalIncidents: totalIncidents,
            isPinned: isPinned,
            updatedAt: updatedAt
        )
    }
}
