import Foundation

enum JournalDateRange: String, Codable, CaseIterable, Identifiable {
    case all
    case last7Days
    case last30Days
    case last90Days

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "All"
        case .last7Days:
            "7 Days"
        case .last30Days:
            "30 Days"
        case .last90Days:
            "90 Days"
        }
    }
}

struct JournalFilter: Hashable {
    var selectedTemplateID: String?
    var favoritesOnly = false
    var dateRange: JournalDateRange = .all
    var tagSearch = ""

    func matches(_ workout: LoggedWorkout, now: Date = .now, calendar: Calendar = .current) -> Bool {
        if favoritesOnly && !workout.isFavorite {
            return false
        }

        if let selectedTemplateID, !selectedTemplateID.isEmpty, workout.sourceTemplateID != selectedTemplateID {
            return false
        }

        if !tagSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let loweredTag = tagSearch.lowercased()
            let hasMatch = workout.tags.contains { $0.lowercased().contains(loweredTag) }
            if !hasMatch {
                return false
            }
        }

        guard dateRange != .all else {
            return true
        }

        let daysBack: Int
        switch dateRange {
        case .all:
            daysBack = 0
        case .last7Days:
            daysBack = 7
        case .last30Days:
            daysBack = 30
        case .last90Days:
            daysBack = 90
        }

        guard let earliestDate = calendar.date(byAdding: .day, value: -daysBack, to: now) else {
            return true
        }

        return workout.endedAt >= earliestDate
    }
}
