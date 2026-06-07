import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppModel.self) private var appModel

    @Bindable var settings: AppSettings
    let onContinue: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Image("AtroLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 92, height: 92)
                            .shadow(color: Color.accentColor.opacity(0.18), radius: 20, y: 10)

                        Text("Atro")
                            .font(.lift(.largeTitle, weight: .bold))

                        Text("A calm, native place to plan workouts, log sessions, and keep a lightweight read on how your body is doing.")
                            .font(.lift(.body))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .liftCardStyle()

                    VStack(alignment: .leading, spacing: 18) {
                        Text("Choose your modules")
                            .font(.lift(.headline, weight: .semibold))

                        Toggle("Calendar sync", isOn: $settings.calendarSyncEnabled)
                        Toggle("Health integration", isOn: $settings.healthIntegrationEnabled)
                        Toggle("State of Body", isOn: $settings.feelingCheckInsEnabled)
                        Toggle("Meal logging", isOn: $settings.mealsEnabled)
                    }
                    .toggleStyle(.switch)
                    .liftCardStyle()

                    OnboardingPrivacyCard()
                }
                .padding()
            }
            .liftScreenBackground()
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task {
                        if settings.calendarSyncEnabled {
                            _ = await appModel.calendarService.requestWriteOnlyAccess()
                        }

                        if settings.healthIntegrationEnabled {
                            _ = await appModel.healthService.requestAuthorization(settings: settings)
                            await appModel.refreshIntegrations(using: settings)
                        }

                        settings.hasCompletedOnboarding = true
                        settings.touch()
                        try? modelContext.save()
                        onContinue()
                        dismiss()
                    }
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
    }
}

private struct OnboardingPrivacyCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Privacy at a glance", systemImage: "hand.raised.fill")
                .font(.lift(.caption, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(Color.liftBodyTint)

            VStack(alignment: .leading, spacing: 12) {
                PrivacyNoticeRow("Calendar sync uses write-only access for planned workouts.")
                PrivacyNoticeRow("Health can read workouts, active energy, and exercise minutes when you enable it.")
                PrivacyNoticeRow("Writing workouts back to Health stays optional in Settings.")
                PrivacyNoticeRow("Your journal, meals, and notes stay on this iPhone unless you choose to sync or share them.")
            }
        }
        .liftCardStyle()
    }
}

private struct PrivacyNoticeRow: View {
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
        OnboardingView(settings: AppSettings()) {}
    }
}
