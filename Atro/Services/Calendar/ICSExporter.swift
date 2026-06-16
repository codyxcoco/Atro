import Foundation

struct ICSExporter {
    func export(payload: CalendarEventPayload) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Atro-\(UUID().uuidString).ics")
        try contents(for: payload).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func contents(for payload: CalendarEventPayload) -> String {
        """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Atro//EN
        BEGIN:VEVENT
        UID:\(UUID().uuidString)
        DTSTAMP:\(utcString(from: .now))
        DTSTART:\(utcString(from: payload.startDate))
        DTEND:\(utcString(from: payload.endDate))
        SUMMARY:\(escaped(payload.title))
        DESCRIPTION:\(escaped(payload.notes))
        END:VEVENT
        END:VCALENDAR
        """
    }

    private func utcString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    private func escaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
