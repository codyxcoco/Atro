import Foundation

enum StreakWidgetSnapshotStore {
    private static let userDefaultsKey = "atro-streak-widget-snapshot-payload"

    static func loadSnapshots() -> [StreakWidgetSnapshot] {
        guard let data = loadSnapshotData() else {
            return []
        }

        do {
            let payload = try JSONDecoder.atroWidget.decode(StreakWidgetSnapshotPayload.self, from: data)
            return payload.counters
        } catch {
            return []
        }
    }

    static func saveSnapshots(_ snapshots: [StreakWidgetSnapshot]) throws {
        let payload = StreakWidgetSnapshotPayload(generatedAt: Date(), counters: snapshots)
        let data = try JSONEncoder.atroWidget.encode(payload)

        var saved = false
        if let url = snapshotURL() {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic])
            saved = true
        }

        if let defaults = UserDefaults(suiteName: AtroWidgetConstants.appGroupIdentifier) {
            defaults.set(data, forKey: userDefaultsKey)
            defaults.synchronize()
            saved = true
        }

        if !saved {
            throw StreakWidgetSnapshotStoreError.sharedStorageUnavailable
        }
    }

    static func snapshotURL() -> URL? {
        if let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AtroWidgetConstants.appGroupIdentifier
        ) {
            return appGroupURL.appendingPathComponent(AtroWidgetConstants.snapshotFileName)
        }

        guard let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        return supportURL
            .appendingPathComponent("Atro", isDirectory: true)
            .appendingPathComponent(AtroWidgetConstants.snapshotFileName)
    }

    private static func loadSnapshotData() -> Data? {
        if let url = snapshotURL(),
           FileManager.default.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url) {
            return data
        }

        return UserDefaults(suiteName: AtroWidgetConstants.appGroupIdentifier)?.data(forKey: userDefaultsKey)
    }
}

private enum StreakWidgetSnapshotStoreError: LocalizedError {
    case sharedStorageUnavailable

    var errorDescription: String? {
        "Streak widget shared storage is unavailable."
    }
}

private extension JSONEncoder {
    static var atroWidget: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var atroWidget: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
