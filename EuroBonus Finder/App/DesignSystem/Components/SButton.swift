import SwiftUI

// SwiftCN-style primary button, vendored locally. The visual engine is a
// `ButtonStyle` (it gets press state and `isEnabled` for free); `SButton` is the
// ergonomic wrapper so call sites read like the rest of SwiftCN.
//
// Shape is a full-width capsule to match the app's CTA language (onboarding +
// guided test). ponytail: one variant and size because there's one call site;
// bring shadcn's variants back when a second look is needed.

struct SButton: View {
    private let title: LocalizedStringKey
    private let systemImage: String?
    private let action: () -> Void

    init(_ title: LocalizedStringKey, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
        .buttonStyle(SButtonStyle())
    }
}

// MARK: - Style

private struct SButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, Theme.Spacing.lg)
            .foregroundStyle(Theme.Colors.primaryForeground)
            .background(Theme.Colors.primary)
            .clipShape(.capsule)
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Theme.Spacing.lg) {
        SButton("Primary", systemImage: "magnifyingglass", action: {})
        SButton("Disabled", action: {}).disabled(true)
    }
    .padding()
}
