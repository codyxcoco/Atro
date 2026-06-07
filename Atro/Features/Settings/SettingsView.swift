import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Bindable var settings: AppSettings
    @State private var showsDeleteAllAlert = false
    @State private var isDeletingAllData = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                NavigationLink {
                    ModulesSettingsView(settings: settings)
                } label: {
                    SettingsNavigationCard(
                        title: "Modules",
                        systemImage: "square.grid.2x2.fill",
                        tint: .accentColor
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    CalendarSettingsView(settings: settings)
                } label: {
                    SettingsNavigationCard(
                        title: "Calendar",
                        systemImage: "calendar",
                        tint: .liftStrength,
                        value: settings.calendarSyncEnabled ? "On" : "Off"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    HealthSettingsView(settings: settings)
                } label: {
                    SettingsNavigationCard(
                        title: "Health",
                        systemImage: "heart.text.square.fill",
                        tint: .liftHealthTint,
                        value: settings.healthIntegrationEnabled ? "On" : "Off"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    GuideView()
                } label: {
                    SettingsNavigationCard(
                        title: "Guide",
                        systemImage: "book.pages.fill",
                        tint: .liftGuideTint
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    PrivacySupportView()
                } label: {
                    SettingsNavigationCard(
                        title: "Privacy & Support",
                        systemImage: "hand.raised.fill",
                        tint: .liftBodyTint
                    )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 16) {
                    Button(role: .destructive) {
                        showsDeleteAllAlert = true
                    } label: {
                        HStack {
                            Label("Delete All Data", systemImage: "trash")
                            Spacer()
                        }
                        .font(.lift(.body, weight: .semibold))
                    }
                    .tint(.red)
                    .disabled(isDeletingAllData)
                }
                .liftCardStyle()
            }
            .padding()
        }
        .liftScreenBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Delete all data?", isPresented: $showsDeleteAllAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All Data", role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text("This removes templates, schedules, journal entries, meals, and State of Body entries from this iPhone. Calendar or Health items already written by Atro stay where they were saved. This can’t be undone.")
        }
        .task(id: settings.healthIntegrationEnabled) {
            if settings.healthIntegrationEnabled {
                await refreshHealthAuthorization()
            }
        }
        .onChange(of: settings.calendarSyncEnabled) { _, isEnabled in
            if isEnabled {
                Task {
                    _ = await appModel.calendarService.requestWriteOnlyAccess()
                }
            }
            persist()
        }
        .onChange(of: settings.healthIntegrationEnabled) { _, isEnabled in
            persist()

            Task {
                if isEnabled {
                    await refreshHealthAuthorization()
                } else {
                    appModel.healthService.todaySummary = .empty
                }
            }
        }
        .onChange(of: settings.healthWorkoutWriteEnabled) { _, _ in
            persist()

            Task {
                await refreshHealthAuthorization()
            }
        }
        .onChange(of: settings.feelingCheckInsEnabled) { _, _ in persist() }
        .onChange(of: settings.mealsEnabled) { _, _ in persist() }
        .onChange(of: settings.defaultCalendarDurationMinutes) { _, _ in persist() }
    }

    private func persist() {
        settings.touch()
        try? modelContext.save()
    }

    private func refreshHealthAuthorization() async {
        guard settings.healthIntegrationEnabled else { return }

        _ = await appModel.healthService.requestAuthorization(settings: settings)
        await appModel.refreshIntegrations(using: settings, modelContext: modelContext)
    }

    private func deleteAllData() {
        guard !isDeletingAllData else { return }
        isDeletingAllData = true
        defer { isDeletingAllData = false }

        do {
            try DataResetService.resetAllData(in: modelContext, settings: settings)
            appModel.selectedTab = .today
            appModel.haptics.confirm()
            appModel.showBanner("All data deleted", systemImage: "trash.fill")

            Task {
                await appModel.refreshIntegrations(using: settings, modelContext: modelContext)
            }
        } catch {
            appModel.showBanner("Couldn’t delete data", systemImage: "exclamationmark.triangle.fill")
        }
    }
}

private struct SettingsStatusRow: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(title)
                .font(.lift(.subheadline, weight: .semibold))

            Spacer(minLength: 12)

            Text(value)
                .font(.lift(.footnote, weight: .semibold))
                .foregroundStyle(tint)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct SettingsCardSection<Content: View>: View {
    let title: String
    let systemImage: String
    var tint: Color = .accentColor
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text(title)
                    .font(.lift(.caption, weight: .bold))
                    .textCase(.uppercase)
            } icon: {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(tint)

            content
        }
        .liftCardStyle()
    }
}

private struct SettingsRowDivider: View {
    var body: some View {
        Divider()
            .overlay(.white.opacity(0.08))
            .padding(.vertical, 10)
    }
}

private struct SettingsNavigationCard: View {
    let title: String
    let systemImage: String
    let tint: Color
    var value: String? = nil
    var message: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.lift(.body, weight: .semibold))

                if let message, !message.isEmpty {
                    Text(message)
                        .font(.lift(.footnote))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer()

            if let value, !value.isEmpty {
                Text(value)
                    .font(.lift(.footnote, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liftCardStyle()
    }
}

private struct ModulesSettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsCardSection(title: "Modules", systemImage: "square.grid.2x2.fill") {
                    VStack(spacing: 0) {
                        Toggle("State of Body", isOn: $settings.feelingCheckInsEnabled)
                        SettingsRowDivider()
                        Toggle("Meal logging", isOn: $settings.mealsEnabled)
                    }
                    .toggleStyle(.switch)
                }
            }
            .padding()
        }
        .liftScreenBackground()
        .navigationTitle("Modules")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CalendarSettingsView: View {
    @Environment(AppModel.self) private var appModel
    @Bindable var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsCardSection(title: "Calendar Sync", systemImage: "calendar", tint: .liftStrength) {
                    Toggle("Enable Calendar sync", isOn: $settings.calendarSyncEnabled)
                        .toggleStyle(.switch)

                    if settings.calendarSyncEnabled {
                        SettingsRowDivider()

                        VStack(alignment: .leading, spacing: 14) {
                            Stepper(value: $settings.defaultCalendarDurationMinutes, in: 15...180, step: 15) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Default event length")
                                        .font(.lift(.body, weight: .semibold))
                                    Text("\(settings.defaultCalendarDurationMinutes) min")
                                        .font(.lift(.footnote))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            SettingsStatusRow(
                                title: "Calendar access",
                                value: calendarAccessDescription,
                                tint: .liftStrength
                            )

                            Text("Atro uses write-only Calendar access to add a workout title, date, duration, and notes when you choose to sync.")
                                .font(.lift(.footnote))
                                .foregroundStyle(.secondary)

                            Text("If access stays off, you can still export an .ics file and add it yourself.")
                                .font(.lift(.footnote))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Turn this on when you want planned workouts to flow into Calendar or fall back to .ics export.")
                            .font(.lift(.footnote))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .liftScreenBackground()
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var calendarAccessDescription: String {
        switch appModel.calendarService.accessState() {
        case .notDetermined:
            "Not requested yet"
        case .writeOnly:
            "Write-only access granted"
        case .fullAccess:
            "Full access granted"
        case .denied:
            "Access denied"
        }
    }
}

private struct HealthSettingsView: View {
    @Environment(AppModel.self) private var appModel
    @Bindable var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsCardSection(title: "Health", systemImage: "heart.text.square.fill", tint: .liftHealthTint) {
                    Toggle("Enable Health integration", isOn: $settings.healthIntegrationEnabled)
                        .toggleStyle(.switch)

                    if settings.healthIntegrationEnabled {
                        SettingsRowDivider()

                        VStack(alignment: .leading, spacing: 14) {
                            Toggle("Write completed workouts", isOn: $settings.healthWorkoutWriteEnabled)
                                .toggleStyle(.switch)

                            SettingsStatusRow(
                                title: "Health access",
                                value: healthAccessDescription,
                                tint: .liftHealthTint
                            )

                            Text("Atro can read workouts, active energy, and exercise minutes to personalize Today and help match imported workouts in Journal.")
                                .font(.lift(.footnote))
                                .foregroundStyle(.secondary)

                            Text("Writing saved workouts back to Health stays optional and only happens when `Write completed workouts` is turned on.")
                                .font(.lift(.footnote))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Turn this on when you want Today and Journal to use workout and activity context from Apple Health.")
                            .font(.lift(.footnote))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .liftScreenBackground()
        .navigationTitle("Health")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var healthAccessDescription: String {
        switch appModel.healthService.authorizationState {
        case .unavailable:
            "Health not available on this device"
        case .notDetermined:
            "Not requested yet"
        case .authorized:
            "Access granted"
        case .denied:
            "Access denied"
        }
    }
}

private struct PrivacySupportView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PrivacyHeroCard()

                PrivacySupportSection(
                    title: "On This iPhone",
                    systemImage: "iphone",
                    tint: .accentColor
                ) {
                    PrivacyBulletRow("Templates, planned workouts, journal entries, streaks, meals, and settings are stored locally on this iPhone.")
                    PrivacyBulletRow("Atro doesn’t ship third-party analytics or advertising SDKs.")
                    PrivacyBulletRow("Your data stays local unless you explicitly sync to Calendar, write a workout to Health, or export something yourself.")
                }

                PrivacySupportSection(
                    title: "Health",
                    systemImage: "heart.text.square.fill",
                    tint: .liftHealthTint
                ) {
                    PrivacyBulletRow("When Health is enabled, Atro can read workouts, active energy, and exercise minutes.")
                    PrivacyBulletRow("Those reads are used to personalize Today and help link imported workouts inside Journal.")
                    PrivacyBulletRow("Saved workouts are written to Health only when you opt into workout export.")
                }

                PrivacySupportSection(
                    title: "Calendar",
                    systemImage: "calendar.badge.plus",
                    tint: .liftStrength
                ) {
                    PrivacyBulletRow("Calendar sync uses write-only access, so Atro can add planned workouts without needing full read access.")
                    PrivacyBulletRow("Synced events include the workout title, timing, notes, and a deep link back into Atro.")
                    PrivacyBulletRow("If Calendar access is denied, Atro can export an .ics file instead.")
                }

                PrivacySupportSection(
                    title: "Support",
                    systemImage: "lifepreserver.fill",
                    tint: .liftGuideTint
                ) {
                    if let privacyPolicyURL = AppReleaseInfo.privacyPolicyURL {
                        PrivacyLinkRow(title: "Privacy Policy", destination: privacyPolicyURL)
                    }

                    if let supportURL = AppReleaseInfo.supportURL {
                        PrivacyLinkRow(title: "Support Website", destination: supportURL)
                    }

                    if let supportMailURL = AppReleaseInfo.supportMailURL {
                        PrivacyLinkRow(title: "Email Support", destination: supportMailURL)
                    }

                    if !AppReleaseInfo.hasConfiguredSupportLinks {
                        Text("Atro’s App Store listing can publish support and privacy links for release builds, even if those links aren’t configured in this local build yet.")
                            .font(.lift(.footnote))
                            .foregroundStyle(.secondary)
                    }
                }

                PrivacySupportSection(
                    title: "App Info",
                    systemImage: "info.circle.fill",
                    tint: .secondary
                ) {
                    SettingsStatusRow(
                        title: "Version",
                        value: AppReleaseInfo.versionDescription,
                        tint: .white
                    )
                }
            }
            .padding()
        }
        .liftScreenBackground()
        .navigationTitle("Privacy & Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacyHeroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Atro is designed to stay simple about your data.")
                .font(.lift(.title3, weight: .bold))
                .foregroundStyle(.white)

            Text("Workouts, notes, meals, and settings stay local by default. Health and Calendar are optional, and both are explained here before you turn them on.")
                .font(.lift(.body))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liftCardStyle()
    }
}

private struct PrivacySupportSection<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text(title)
                    .font(.lift(.caption, weight: .bold))
                    .textCase(.uppercase)
            } icon: {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
        .liftCardStyle()
    }
}

private struct PrivacyBulletRow: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.white.opacity(0.55))
                .frame(width: 6, height: 6)
                .padding(.top, 7)

            Text(text)
                .font(.lift(.body))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PrivacyLinkRow: View {
    let title: String
    let destination: URL

    var body: some View {
        Link(destination: destination) {
            HStack(spacing: 14) {
                Text(title)
                    .font(.lift(.body, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct GuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GuideIntroCard()

                GuideSectionCard(title: "Today", systemImage: "sun.max.fill", tint: .accentColor) {
                    GuideBulletRow("Use `Log Workout Now` to start without a template.")
                    GuideBulletRow("Use `Plan Workout` for something on the calendar.")
                    GuideBulletRow("Use `Create Template` for workouts you want to reuse.")
                    GuideBulletRow("Log `State of Body` and meals from the same screen.")
                }

                GuideSectionCard(title: "Plan", systemImage: "calendar.badge.clock", tint: .liftStrength) {
                    GuideBulletRow("`Schedule` is for upcoming workouts and rest days.")
                    GuideBulletRow("Swipe a workout to start, duplicate, sync, or edit it.")
                    GuideBulletRow("`Templates` stores reusable workout setups.")
                    GuideBulletRow("Use `Copy Week` when your schedule repeats.")
                }

                GuideSectionCard(title: "Journal", systemImage: "book.closed.fill", tint: .liftMealsTint) {
                    GuideBulletRow("Journal is one timeline, newest first.")
                    GuideBulletRow("Tap a card for more detail.")
                    GuideBulletRow("Use search and filters to narrow the view.")
                    GuideBulletRow("Imported Apple Health workouts show up here too.")
                }

                GuideSectionCard(title: "Settings", systemImage: "gearshape.fill", tint: .secondary) {
                    GuideBulletRow("Turn Calendar, Health, State of Body, and Meals on or off.")
                    GuideBulletRow("Calendar and Health are optional.")
                    GuideBulletRow("Enable Health writing to send saved workouts out to Health.")
                    GuideBulletRow("Come back here anytime for a quick refresher.")
                }

                GuideSectionCard(title: "How It Fits Together", systemImage: "sparkles", tint: .liftBodyTint) {
                    GuideBulletRow("You can plan ahead or log in the moment.")
                    GuideBulletRow("Finished workouts always save to Journal.")
                    GuideBulletRow("Think of it as `Today` for now, `Plan` for later, and `Journal` for history.")
                }
            }
            .padding()
        }
        .liftScreenBackground()
        .navigationTitle("Guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GuideIntroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image("AtroLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
                .shadow(color: Color.accentColor.opacity(0.16), radius: 18, y: 8)

            Text("How to Use Atro")
                .font(.lift(.title3, weight: .bold))
                .foregroundStyle(.white)

            Text("Plan ahead, log live, and review everything in one place.")
                .font(.lift(.body))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liftCardStyle()
    }
}

private struct GuideSectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text(title)
                    .font(.lift(.caption, weight: .bold))
                    .textCase(.uppercase)
            } icon: {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
        .liftCardStyle()
    }
}

private struct GuideBulletRow: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.white.opacity(0.55))
                .frame(width: 6, height: 6)
                .padding(.top, 7)

            Text(text)
                .font(.lift(.body))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    PreviewContainer {
        NavigationStack {
            SettingsView(settings: AppSettings())
        }
    }
}
