import Foundation
import SwiftData

enum MoodPhase: String, Codable, CaseIterable, Identifiable {
    case pre
    case post

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pre:
            "Before"
        case .post:
            "After"
        }
    }
}

@Model
final class MoodCheckIn {
    @Attribute(.unique) var id: UUID
    var phase: String
    var moodLevel: Int
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
        energyLevel: Int = 3,
        sorenessLevel: Int = 3,
        effortRating: Int = 3,
        confidenceRating: Int = 3,
        createdAt: Date = .now
    ) {
        self.id = id
        self.phase = phase.rawValue
        self.moodLevel = moodLevel
        self.energyLevel = energyLevel
        self.sorenessLevel = sorenessLevel
        self.effortRating = effortRating
        self.confidenceRating = confidenceRating
        self.createdAt = createdAt
    }

    var phaseValue: MoodPhase {
        MoodPhase(rawValue: phase) ?? .post
    }

    var moodTitle: String {
        switch moodLevel {
        case 1:
            "Low"
        case 2:
            "Off"
        case 3:
            "Steady"
        case 4:
            "Good"
        default:
            "Great"
        }
    }
}
