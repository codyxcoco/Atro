import Foundation

enum AtroWidgetConstants {
    static let appGroupIdentifier = "group.com.codex.Atro"
    static let streakWidgetKind = "AtroStreakWidget"
    static let snapshotFileName = "atro-streak-widget-snapshots.json"
}

struct StreakWidgetSnapshot: Codable, Hashable, Identifiable {
    var counterId: UUID
    var title: String
    var subtitle: String
    var phrase: String
    var symbolName: String
    var themeName: String
    var colorHex: String
    var iconColorHex: String?
    var lastIncidentDate: Date
    var goalDays: Int?
    var currentStreakDays: Int
    var totalIncidents: Int
    var isPinned: Bool
    var updatedAt: Date

    var id: UUID { counterId }

    var displayPhrase: String {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
        if trimmed.isEmpty || normalized.hasPrefix("days without ") {
            return "current streak"
        }
        return trimmed
    }

    func recalculated(at date: Date = Date(), calendar: Calendar = .current) -> StreakWidgetSnapshot {
        var copy = self
        copy.currentStreakDays = StreakWidgetDateCalculator.fullCalendarDays(
            from: lastIncidentDate,
            to: date,
            calendar: calendar
        )
        return copy
    }
}

struct StreakWidgetSnapshotPayload: Codable {
    var generatedAt: Date
    var counters: [StreakWidgetSnapshot]
}

enum StreakWidgetDateCalculator {
    static func fullCalendarDays(
        from startDate: Date,
        to endDate: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(days, 0)
    }

    static func nextMidnight(after date: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.nextDate(after: date, matching: DateComponents(hour: 0), matchingPolicy: .nextTime)
            ?? calendar.date(byAdding: .day, value: 1, to: date)
            ?? date.addingTimeInterval(60 * 60 * 24)
    }

    static func progress(currentStreak: Int, goalDays: Int?) -> Double? {
        guard let goalDays, goalDays > 0 else { return nil }
        return min(Double(currentStreak) / Double(goalDays), 1)
    }
}
