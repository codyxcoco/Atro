import Foundation
import SwiftData

enum MoodPhase: String, Codable, CaseIterable, Identifiable {
    case pre
    case post
    case checkIn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pre:
            "Before"
        case .post:
            "After"
        case .checkIn:
            "State of Body"
        }
    }
}

@Model
final class MoodCheckIn {
    @Attribute(.unique) var id: UUID
    var phase: String
    var moodLevel: Int
    var tagText: String
    var energyLevel: Int
    var sorenessLevel: Int
    var effortRating: Int
    var confidenceRating: Int
    var createdAt: Date

    var workout: LoggedWorkout?

    init(
        id: UUID = UUID(),
        phase: MoodPhase,
        moodLevel: Int = 3,
        tagText: String = "",
        energyLevel: Int = 3,
        sorenessLevel: Int = 3,
        effortRating: Int = 3,
        confidenceRating: Int = 3,
        createdAt: Date = .now
    ) {
        self.id = id
        self.phase = phase.rawValue
        self.moodLevel = moodLevel
        self.tagText = tagText
        self.energyLevel = energyLevel
        self.sorenessLevel = sorenessLevel
        self.effortRating = effortRating
        self.confidenceRating = confidenceRating
        self.createdAt = createdAt
    }

    var phaseValue: MoodPhase {
        MoodPhase(rawValue: phase) ?? .checkIn
    }

    var tags: [String] {
        tagText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var moodTitle: String {
        switch moodLevel {
        case 1:
            "Very Bad"
        case 2:
            "Bad"
        case 3:
            "Neutral"
        case 4:
            "Good"
        default:
            "Very Good"
        }
    }
}
