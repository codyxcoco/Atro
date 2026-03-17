import SwiftUI

struct EmptyStateCard: View {
    let symbol: String
    let title: String
    let message: String
    let primaryTitle: String?
    let primaryAction: (() -> Void)?

    init(
        symbol: String,
        title: String,
        message: String,
        primaryTitle: String? = nil,
        primaryAction: (() -> Void)? = nil
    ) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.primaryTitle = primaryTitle
        self.primaryAction = primaryAction
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundStyle(.tint)

            Text(title)
                .font(.lift(.title3, weight: .semibold))

            Text(message)
                .font(.lift(.body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let primaryTitle, let primaryAction {
                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity)
        .liftCardStyle()
    }
}
