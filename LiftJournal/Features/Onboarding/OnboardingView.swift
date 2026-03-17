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
                        Text("Lift Journal")
                            .font(.lift(.largeTitle, weight: .bold))

                        Text("A calm, native place to plan workouts, log sessions, and keep a lightweight record of how training feels.")
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
                        Toggle("Feeling check-ins", isOn: $settings.feelingCheckInsEnabled)
                        Toggle("Meal logging", isOn: $settings.mealsEnabled)
                    }
                    .toggleStyle(.switch)
                    .liftCardStyle()
                }
                .padding()
            }
            .background(Color.liftSurface.ignoresSafeArea())
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom) {
                Button("Continue") {
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
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
                .background(.ultraThinMaterial)
            }
        }
    }
}

#Preview {
    PreviewContainer {
        OnboardingView(settings: AppSettings()) {}
    }
}
