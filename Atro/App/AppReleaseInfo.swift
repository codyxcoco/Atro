import Foundation

enum AppReleaseInfo {
    static var supportURL: URL? {
        url(forInfoDictionaryKey: "ATROSupportURL")
    }

    static var privacyPolicyURL: URL? {
        url(forInfoDictionaryKey: "ATROPrivacyPolicyURL")
    }

    static var supportMailURL: URL? {
        guard let supportEmail else { return nil }
        return URL(string: "mailto:\(supportEmail)")
    }

    static var hasConfiguredSupportLinks: Bool {
        supportURL != nil || privacyPolicyURL != nil || supportMailURL != nil
    }

    static var versionDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    private static var supportEmail: String? {
        trimmedString(forInfoDictionaryKey: "ATROSupportEmail")
    }

    private static func trimmedString(forInfoDictionaryKey key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private static func url(forInfoDictionaryKey key: String) -> URL? {
        guard let string = trimmedString(forInfoDictionaryKey: key) else {
            return nil
        }

        return URL(string: string)
    }
}
