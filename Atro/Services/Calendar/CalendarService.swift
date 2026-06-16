import EventKit
import Foundation

enum CalendarAccessState: Equatable {
    case notDetermined
    case writeOnly
    case fullAccess
    case denied
}

enum CalendarSyncOutcome: Equatable {
    case synced(CalendarSyncPayload)
    case manualFallback(URL)
}

struct CalendarSyncPayload: Equatable {
    let eventIdentifier: String
    let calendarIdentifier: String
    let title: String
    let notes: String
    let syncedAt: Date
}

@MainActor
final class CalendarService {
    private let eventStore = EKEventStore()
    private let builder = CalendarEventBuilder()
    private let exporter = ICSExporter()

    func accessState() -> CalendarAccessState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            .notDetermined
        case .writeOnly:
            .writeOnly
        case .fullAccess:
            .fullAccess
        case .restricted, .denied:
            .denied
        @unknown default:
            .denied
        }
    }

    func requestWriteOnlyAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            eventStore.requestWriteOnlyAccessToEvents { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func sync(plannedWorkout: PlannedWorkout, settings: AppSettings) async throws -> CalendarSyncOutcome {
        let state = accessState()
        if state == .notDetermined {
            let granted = await requestWriteOnlyAccess()
            if !granted {
                let payload = builder.payload(for: plannedWorkout, settings: settings)
                return .manualFallback(try exporter.export(payload: payload))
            }
        } else if state == .denied {
            let payload = builder.payload(for: plannedWorkout, settings: settings)
            return .manualFallback(try exporter.export(payload: payload))
        }

        let payload = builder.payload(for: plannedWorkout, settings: settings)
        let event: EKEvent

        if !plannedWorkout.calendarEventIdentifier.isEmpty,
           let existingEvent = eventStore.event(withIdentifier: plannedWorkout.calendarEventIdentifier) {
            event = existingEvent
        } else {
            event = EKEvent(eventStore: eventStore)
            event.calendar = eventStore.defaultCalendarForNewEvents
        }

        event.title = payload.title
        event.notes = payload.notes
        event.startDate = payload.startDate
        event.endDate = payload.endDate

        try eventStore.save(event, span: .thisEvent)

        return .synced(
            CalendarSyncPayload(
                eventIdentifier: event.eventIdentifier,
                calendarIdentifier: event.calendar.calendarIdentifier,
                title: payload.title,
                notes: payload.notes,
                syncedAt: .now
            )
        )
    }
}
