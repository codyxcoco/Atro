import Foundation
import SwiftData
import SwiftUI

@Model
final class StreakCounter {
    @Attribute(.unique) var id: UUID
    var title: String
    var counterSubtitle: String
    var phrase: String
    var symbolName: String
    var iconColorRawValue: String?
    var themeRawValue: String
    var lastIncidentDate: Date
    var goalDays: Int?
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \StreakIncident.counter)
    var incidents: [StreakIncident]

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String = "",
        phrase: String = "current streak",
        symbolName: String = "checkmark.seal",
        iconColor: StreakIconColor = .accent,
        theme: StreakTheme = .recovery,
        lastIncidentDate: Date,
        goalDays: Int? = nil,
        isPinned: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        incidents: [StreakIncident] = []
    ) {
        self.id = id
        self.title = title
        self.counterSubtitle = subtitle
        self.phrase = phrase
        self.symbolName = symbolName
        self.iconColorRawValue = iconColor.rawValue
        self.themeRawValue = theme.rawValue
        self.lastIncidentDate = lastIncidentDate
        self.goalDays = goalDays
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.incidents = incidents
    }

    var subtitle: String? {
        let trimmed = counterSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var theme: StreakTheme {
        get { StreakTheme(rawValue: themeRawValue) ?? .recovery }
        set { themeRawValue = newValue.rawValue }
    }

    var iconColor: StreakIconColor {
        get { StreakIconColor(rawValue: iconColorRawValue ?? "") ?? .accent }
        set { iconColorRawValue = newValue.rawValue }
    }

    var displayPhrase: String {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
        if trimmed.isEmpty || normalized.hasPrefix("days without ") {
            return "current streak"
        }
        return trimmed
    }

    var currentStreakDays: Int {
        StreakCalculator.fullCalendarDays(from: lastIncidentDate)
    }

    var totalIncidents: Int {
        incidents.count
    }

    var longestStreakDays: Int {
        StreakCalculator.longestStreak(
            currentStreak: currentStreakDays,
            previousStreaks: incidents.map(\.previousStreakLength)
        )
    }

    var averageStreakDays: Double? {
        StreakCalculator.averageStreak(previousStreaks: incidents.map(\.previousStreakLength))
    }

    var progressToGoal: Double? {
        StreakCalculator.progress(currentStreak: currentStreakDays, goalDays: goalDays)
    }

    var goalStatusText: String? {
        guard let goalDays, goalDays > 0 else { return nil }

        if currentStreakDays >= goalDays {
            let beyondGoal = currentStreakDays - goalDays
            return beyondGoal == 0 ? "Goal reached" : "+\(beyondGoal) days beyond goal"
        }

        return "\(currentStreakDays) of \(goalDays) days"
    }

    var sortedIncidents: [StreakIncident] {
        incidents.sorted { $0.date > $1.date }
    }

    func touch() {
        updatedAt = .now
    }
}

@Model
final class StreakIncident {
    @Attribute(.unique) var id: UUID
    var date: Date
    var note: String
    var previousStreakLength: Int
    var createdAt: Date

    var counter: StreakCounter?

    init(
        id: UUID = UUID(),
        date: Date,
        note: String = "",
        previousStreakLength: Int,
        createdAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.note = note
        self.previousStreakLength = previousStreakLength
        self.createdAt = createdAt
    }
}

enum StreakIconColor: String, CaseIterable, Identifiable, Hashable {
    case accent
    case strength
    case body
    case health
    case focus
    case fitness
    case meals
    case glow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .accent:
            "Atro"
        case .strength:
            "Strength"
        case .body:
            "Body"
        case .health:
            "Health"
        case .focus:
            "Focus"
        case .fitness:
            "Fitness"
        case .meals:
            "Meals"
        case .glow:
            "Glow"
        }
    }

    var colorHex: String {
        switch self {
        case .accent:
            "#49C7C9"
        case .strength:
            "#52B3F1"
        case .body:
            "#29DBCA"
        case .health:
            "#FF4A73"
        case .focus:
            "#E176D6"
        case .fitness:
            "#BCF540"
        case .meals:
            "#439E63"
        case .glow:
            "#2684C5"
        }
    }

    var color: Color {
        switch self {
        case .accent:
            Color.accentColor
        case .strength:
            Color.liftStrength
        case .body:
            Color.liftBodyTint
        case .health:
            Color.liftHealthTint
        case .focus:
            Color.liftGuideTint
        case .fitness:
            Color.liftFitnessTint
        case .meals:
            Color.liftMealsTint
        case .glow:
            Color.liftGlow
        }
    }

    var softColor: Color {
        color.opacity(0.16)
    }
}

enum StreakTheme: String, CaseIterable, Identifiable, Hashable {
    case recovery
    case strength
    case body
    case health
    case focus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recovery:
            "Recovery"
        case .strength:
            "Strength"
        case .body:
            "Body"
        case .health:
            "Health"
        case .focus:
            "Focus"
        }
    }

    var color: Color {
        switch self {
        case .recovery:
            Color.accentColor
        case .strength:
            Color.liftStrength
        case .body:
            Color.liftBodyTint
        case .health:
            Color.liftHealthTint
        case .focus:
            Color.liftGuideTint
        }
    }

    var colorHex: String {
        switch self {
        case .recovery:
            "#5EA1FF"
        case .strength:
            "#9DD64B"
        case .body:
            "#F2A65A"
        case .health:
            "#55D6BE"
        case .focus:
            "#B49CFF"
        }
    }
}

enum StreakCalculator {
    static func fullCalendarDays(
        from startDate: Date,
        to endDate: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        // Streaks count completed local calendar days. A streak that starts today shows 0 days.
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(days, 0)
    }

    static func longestStreak(currentStreak: Int, previousStreaks: [Int]) -> Int {
        max(previousStreaks.max() ?? 0, currentStreak)
    }

    static func averageStreak(previousStreaks: [Int]) -> Double? {
        guard !previousStreaks.isEmpty else { return nil }
        return Double(previousStreaks.reduce(0, +)) / Double(previousStreaks.count)
    }

    static func progress(currentStreak: Int, goalDays: Int?) -> Double? {
        guard let goalDays, goalDays > 0 else { return nil }
        return min(Double(currentStreak) / Double(goalDays), 1)
    }
}

enum StreakElapsedFormatter {
    static func elapsedText(from startDate: Date, to endDate: Date = .now) -> String {
        let totalSeconds = max(0, Int(endDate.timeIntervalSince(startDate)))
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        return "\(days)d \(twoDigit(hours))h \(twoDigit(minutes))m \(twoDigit(seconds))s"
    }

    private static func twoDigit(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
