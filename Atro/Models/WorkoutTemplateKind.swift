import Foundation

enum WorkoutTemplateKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case workout
    case stretch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workout:
            "Workout"
        case .stretch:
            "Stretch"
        }
    }

    var templateSectionTitle: String {
        switch self {
        case .workout:
            "Exercises"
        case .stretch:
            "Stretch Steps"
        }
    }

    var templateItemTitle: String {
        switch self {
        case .workout:
            "Exercise"
        case .stretch:
            "Stretch"
        }
    }

    var listSymbolName: String {
        switch self {
        case .workout:
            "square.stack.3d.up.fill"
        case .stretch:
            "figure.cooldown"
        }
    }

    var summaryItemName: String {
        switch self {
        case .workout:
            "exercise"
        case .stretch:
            "stretch"
        }
    }

    var sessionTitle: String {
        switch self {
        case .workout:
            "Workout"
        case .stretch:
            "Stretch Session"
        }
    }
}
