import Foundation

struct CalendarEventPayload: Hashable {
    let title: String
    let notes: String
    let startDate: Date
    let endDate: Date
    let deepLink: URL?
}

struct CalendarEventBuilder {
    private let calendar = Calendar.autoupdatingCurrent

    func payload(for plannedWorkout: PlannedWorkout, settings: AppSettings) -> CalendarEventPayload {
        let duration = plannedWorkout.durationMinutes > 0 ? plannedWorkout.durationMinutes : settings.defaultCalendarDurationMinutes
        let endDate = calendar.date(byAdding: .minute, value: duration, to: plannedWorkout.scheduledFor) ?? plannedWorkout.scheduledFor.addingTimeInterval(3600)
        let deepLink = URL(string: "liftjournal://planned-workout/\(plannedWorkout.id.uuidString)")

        return CalendarEventPayload(
            title: plannedWorkout.displayName,
            notes: notes(for: plannedWorkout, deepLink: deepLink),
            startDate: plannedWorkout.scheduledFor,
            endDate: endDate,
            deepLink: deepLink
        )
    }

    func notes(for plannedWorkout: PlannedWorkout, deepLink: URL?) -> String {
        var lines: [String] = []

        if let snapshot = plannedWorkout.snapshot {
            lines.append(snapshot.summaryLine)

            if !snapshot.notes.isEmpty {
                lines.append(snapshot.notes)
            }

            let exerciseSummary = snapshot.exercises.prefix(5).map(\.name).joined(separator: ", ")
            if !exerciseSummary.isEmpty {
                lines.append("Exercises: \(exerciseSummary)")
            }
        } else if !plannedWorkout.notes.isEmpty {
            lines.append(plannedWorkout.notes)
        }

        if let deepLink {
            lines.append("Open in Lift Journal: \(deepLink.absoluteString)")
        }

        return lines.joined(separator: "\n\n")
    }
}
