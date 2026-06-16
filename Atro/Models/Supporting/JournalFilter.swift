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

    var normalizedTagSearch: String {
        tagSearch.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasActiveSelections: Bool {
        let hasTemplate = (selectedTemplateID?.isEmpty == false)
        return hasTemplate || favoritesOnly || dateRange != .all || !normalizedTagSearch.isEmpty
    }

    var activeSelectionCount: Int {
        var count = 0

        if selectedTemplateID?.isEmpty == false {
            count += 1
        }

        if favoritesOnly {
            count += 1
        }

        if dateRange != .all {
            count += 1
        }

        if !normalizedTagSearch.isEmpty {
            count += 1
        }

        return count
    }

    func matches(_ workout: LoggedWorkout, now: Date = .now, calendar: Calendar = .current) -> Bool {
        if favoritesOnly && !workout.isFavorite {
            return false
        }

        if let selectedTemplateID, !selectedTemplateID.isEmpty, workout.sourceTemplateID != selectedTemplateID {
            return false
        }

        if !normalizedTagSearch.isEmpty {
            let loweredTag = normalizedTagSearch.lowercased()
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
