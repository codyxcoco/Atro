import Foundation
import SwiftData

enum WorkoutBuddyWeekday: Int, CaseIterable, Identifiable, Codable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    func title(using calendar: Calendar = .autoupdatingCurrent) -> String {
        let index = max(min(rawValue - 1, calendar.weekdaySymbols.count - 1), 0)
        return calendar.weekdaySymbols[index]
    }

    func shortTitle(using calendar: Calendar = .autoupdatingCurrent) -> String {
        let index = max(min(rawValue - 1, calendar.shortWeekdaySymbols.count - 1), 0)
        return calendar.shortWeekdaySymbols[index]
    }
}

enum WorkoutBuddyInsightKind: String, Codable, CaseIterable {
    case workoutConsistency
    case foodPattern
    case recovery
    case journalTheme
    case routine
    case longTermTrend
    case fallback

    var title: String {
        switch self {
        case .workoutConsistency:
            "Workout consistency"
        case .foodPattern:
            "Meal pattern"
        case .recovery:
            "Recovery pattern"
        case .journalTheme:
            "Notes pattern"
        case .routine:
            "Routine pattern"
        case .longTermTrend:
            "Long-term pattern"
        case .fallback:
            "Keep logging"
        }
    }
}

enum WorkoutBuddyDataSource: String, Codable, CaseIterable, Hashable {
    case workouts
    case meals
    case bodyState
    case notes

    var title: String {
        switch self {
        case .workouts:
            "Workouts"
        case .meals:
            "Meals"
        case .bodyState:
            "State of Body"
        case .notes:
            "Notes"
        }
    }
}

enum WorkoutBuddyConfidenceDescriptor: String, Codable, CaseIterable {
    case emerging
    case steady
    case strong

    var title: String {
        switch self {
        case .emerging:
            "Emerging signal"
        case .steady:
            "Steady signal"
        case .strong:
            "Stronger signal"
        }
    }
}

enum WorkoutBuddyEffectTiming: String, Codable {
    case weekly
    case sameDay
    case nextDay
    case rolling
    case recentVsBaseline

    var title: String {
        switch self {
        case .weekly:
            "Weekly pattern"
        case .sameDay:
            "Same-day pattern"
        case .nextDay:
            "Next-day pattern"
        case .rolling:
            "Rolling pattern"
        case .recentVsBaseline:
            "Recent vs baseline"
        }
    }
}

struct WorkoutBuddyInsightPayload: Codable, Hashable {
    var kind: WorkoutBuddyInsightKind
    var message: String
    var supportingObservation: String
    var whyThisAppeared: String
    var analysisWindowDays: Int
    var analysisSummary: String
    var sampleSummary: String
    var sampleCount: Int
    var baselineSampleCount: Int
    var confidenceScore: Double
    var confidenceDescriptor: WorkoutBuddyConfidenceDescriptor
    var contributingDataSources: [WorkoutBuddyDataSource]
    var evidenceBullets: [String]
    var relatedTerms: [String]
    var timing: WorkoutBuddyEffectTiming
    var isFallback: Bool

    var cardMetadataText: String {
        if isFallback {
            return "Beta • Local trend analysis"
        }

        return "\(analysisSummary) • \(confidenceDescriptor.title)"
    }
}

@Model
final class WorkoutBuddyInsightSnapshot: Identifiable {
    @Attribute(.unique) var id: UUID
    var cadenceKey: String
    var publishDate: Date
    var generatedAt: Date
    var kindRawValue: String
    var message: String
    var analysisSummary: String
    var confidenceScore: Double
    var isFallback: Bool
    var payloadData: Data

    init(
        id: UUID = UUID(),
        cadenceKey: String,
        publishDate: Date,
        generatedAt: Date = .now,
        payload: WorkoutBuddyInsightPayload
    ) {
        self.id = id
        self.cadenceKey = cadenceKey
        self.publishDate = publishDate
        self.generatedAt = generatedAt
        self.kindRawValue = payload.kind.rawValue
        self.message = payload.message
        self.analysisSummary = payload.analysisSummary
        self.confidenceScore = payload.confidenceScore
        self.isFallback = payload.isFallback
        self.payloadData = (try? JSONEncoder().encode(payload)) ?? Data()
    }

    var payload: WorkoutBuddyInsightPayload {
        if let decoded = try? JSONDecoder().decode(WorkoutBuddyInsightPayload.self, from: payloadData) {
            return decoded
        }

        return WorkoutBuddyInsightPayload(
            kind: .fallback,
            message: message,
            supportingObservation: "",
            whyThisAppeared: "",
            analysisWindowDays: 7,
            analysisSummary: analysisSummary,
            sampleSummary: "",
            sampleCount: 0,
            baselineSampleCount: 0,
            confidenceScore: confidenceScore,
            confidenceDescriptor: .emerging,
            contributingDataSources: [],
            evidenceBullets: [],
            relatedTerms: [],
            timing: .weekly,
            isFallback: isFallback
        )
    }

    var kind: WorkoutBuddyInsightKind {
        WorkoutBuddyInsightKind(rawValue: kindRawValue) ?? .fallback
    }
}

extension WorkoutBuddyInsightSnapshot {
    static var previewConsistency: WorkoutBuddyInsightSnapshot {
        WorkoutBuddyInsightSnapshot(
            cadenceKey: "preview-consistency",
            publishDate: .now,
            payload: WorkoutBuddyInsightPayload(
                kind: .workoutConsistency,
                message: "On weeks where you log 3+ workouts, your average body-state tends to be better.",
                supportingObservation: "Across 8 comparable weeks, your body-state averaged 4.1 / 5 on steady workout weeks versus 3.4 / 5 on lighter weeks.",
                whyThisAppeared: "Workout Buddy only surfaces repeated weekly patterns with enough State of Body check-ins on both sides.",
                analysisWindowDays: 90,
                analysisSummary: "Based on the last 90 days",
                sampleSummary: "8 comparable weeks",
                sampleCount: 8,
                baselineSampleCount: 8,
                confidenceScore: 0.78,
                confidenceDescriptor: .steady,
                contributingDataSources: [.workouts, .bodyState],
                evidenceBullets: [
                    "Steady weeks: 5",
                    "Lighter weeks: 3",
                    "Average difference: +0.7 mood points"
                ],
                relatedTerms: ["3+ workouts"],
                timing: .weekly,
                isFallback: false
            )
        )
    }

    static var previewFoodPattern: WorkoutBuddyInsightSnapshot {
        WorkoutBuddyInsightSnapshot(
            cadenceKey: "preview-food",
            publishDate: .now,
            payload: WorkoutBuddyInsightPayload(
                kind: .foodPattern,
                message: "When pizza shows up in your meal logs, your next-day body-state is often a little lower than usual.",
                supportingObservation: "Pizza appeared 5 times in the last 90 days, and 4 of those next-day check-ins landed below your usual average.",
                whyThisAppeared: "Workout Buddy waits for repeated meals with follow-up check-ins before surfacing a food pattern.",
                analysisWindowDays: 90,
                analysisSummary: "Based on the last 90 days",
                sampleSummary: "5 repeated meals with next-day check-ins",
                sampleCount: 5,
                baselineSampleCount: 18,
                confidenceScore: 0.74,
                confidenceDescriptor: .steady,
                contributingDataSources: [.meals, .bodyState],
                evidenceBullets: [
                    "Pizza occurrences: 5",
                    "Next-day average: 2.9 / 5",
                    "Your usual average: 3.5 / 5"
                ],
                relatedTerms: ["Pizza"],
                timing: .nextDay,
                isFallback: false
            )
        )
    }

    static var previewFallback: WorkoutBuddyInsightSnapshot {
        WorkoutBuddyInsightSnapshot(
            cadenceKey: "preview-fallback",
            publishDate: .now,
            payload: WorkoutBuddyInsightPayload(
                kind: .fallback,
                message: "Keep logging and Workout Buddy will learn your patterns over time.",
                supportingObservation: "There isn’t enough repeated history yet for a strong insight this week.",
                whyThisAppeared: "Workout Buddy stays quiet until it has enough workouts, meals, or State of Body check-ins to compare against your usual baseline.",
                analysisWindowDays: 30,
                analysisSummary: "Early beta read",
                sampleSummary: "Not enough repeated history yet",
                sampleCount: 0,
                baselineSampleCount: 0,
                confidenceScore: 0.24,
                confidenceDescriptor: .emerging,
                contributingDataSources: [.workouts, .bodyState],
                evidenceBullets: [
                    "More repeated logs will improve weekly reads.",
                    "State of Body entries help most."
                ],
                relatedTerms: [],
                timing: .weekly,
                isFallback: true
            )
        )
    }
}
