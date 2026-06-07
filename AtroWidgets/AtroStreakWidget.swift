import AppIntents
import SwiftUI
import WidgetKit

struct AtroStreakWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: AtroWidgetConstants.streakWidgetKind,
            intent: AtroCounterSelectionIntent.self,
            provider: AtroStreakTimelineProvider()
        ) { entry in
            AtroStreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Atro Streak")
        .description("See one Atro streak at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct AtroStreakWidgetEntry: TimelineEntry {
    var date: Date
    var snapshot: StreakWidgetSnapshot?
}

struct AtroStreakTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> AtroStreakWidgetEntry {
        AtroStreakWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func snapshot(for configuration: AtroCounterSelectionIntent, in context: Context) async -> AtroStreakWidgetEntry {
        AtroStreakWidgetEntry(date: .now, snapshot: selectedSnapshot(for: configuration))
    }

    func timeline(for configuration: AtroCounterSelectionIntent, in context: Context) async -> Timeline<AtroStreakWidgetEntry> {
        let now = Date()
        let entry = AtroStreakWidgetEntry(
            date: now,
            snapshot: selectedSnapshot(for: configuration)?.recalculated(at: now)
        )
        return Timeline(entries: [entry], policy: .after(StreakWidgetDateCalculator.nextMidnight(after: now)))
    }

    private func selectedSnapshot(for configuration: AtroCounterSelectionIntent) -> StreakWidgetSnapshot? {
        let snapshots = StreakWidgetSnapshotStore.loadSnapshots()
            .map { $0.recalculated() }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
                return lhs.updatedAt > rhs.updatedAt
            }

        if let selectedID = configuration.counter?.id,
           let selectedUUID = UUID(uuidString: selectedID),
           let snapshot = snapshots.first(where: { $0.counterId == selectedUUID }) {
            return snapshot
        }

        return snapshots.first
    }
}

private extension StreakWidgetSnapshot {
    static let placeholder = StreakWidgetSnapshot(
        counterId: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
        title: "Training Streak",
        subtitle: "Steady training rhythm",
        phrase: "current streak",
        symbolName: "figure.strengthtraining.traditional",
        themeName: "strength",
        colorHex: "#9DD64B",
        lastIncidentDate: Calendar.current.date(byAdding: .day, value: -23, to: .now) ?? .now,
        goalDays: 90,
        currentStreakDays: 23,
        totalIncidents: 1,
        isPinned: true,
        updatedAt: .now
    )
}

#Preview(as: .systemSmall) {
    AtroStreakWidget()
} timeline: {
    AtroStreakWidgetEntry(date: .now, snapshot: .placeholder)
}
