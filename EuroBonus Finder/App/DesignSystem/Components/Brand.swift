import SwiftUI

// Brand surface shared by onboarding and the extension setup screen: a fixed
// deep-blue atmosphere with light ink, its marks and its capsule buttons.

// MARK: - Palette (brand-derived, light/dark)

/// The brand atmosphere (onboarding + extension setup) — a deep-blue brand wash (`Brand → Primary →
/// Brand`) with ambient `Primary`/`Brand` glows. Text, icons and dots use the
/// `BrandForeground` pair so they read light on it. A fixed brand moment: it
/// looks the same in light and dark (these colors don't flip).
enum BrandPalette {
    static var pageGradient: LinearGradient {
        LinearGradient(colors: [Theme.Colors.brand, Theme.Colors.primary, Theme.Colors.brand],
                       startPoint: .top, endPoint: .bottom)
    }
    /// Text, glyphs, chip labels and the active progress dot.
    static let ink = Theme.Colors.brandForeground
    static let sub = ink.opacity(0.72)
    static let chipBackground = ink.opacity(0.12)
    static let dotInactive = ink.opacity(0.4)

    struct Blob: Identifiable {
        let id: Int
        let color: Color
        let size: CGFloat
        let alignment: Alignment
        let offset: CGSize
        let opacity: Double
    }

    /// Ambient blurred glows of the brand tokens over the gradient.
    static let blobs = [
        Blob(id: 0, color: Theme.Colors.primary, size: 360, alignment: .topTrailing,   offset: CGSize(width: 80, height: -90), opacity: 0.35),
        Blob(id: 1, color: Theme.Colors.brand,   size: 320, alignment: .leading,        offset: CGSize(width: -100, height: 0), opacity: 0.32),
        Blob(id: 2, color: Theme.Colors.primary, size: 260, alignment: .bottomTrailing, offset: CGSize(width: 60, height: 70), opacity: 0.26),
    ]
}

// MARK: - Atmosphere

struct BrandBackground: View {
    var body: some View {
        ZStack {
            BrandPalette.pageGradient
            ForEach(BrandPalette.blobs) { blob in
                Circle()
                    .fill(blob.color)
                    .frame(width: blob.size, height: blob.size)
                    .blur(radius: 48)
                    .opacity(blob.opacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: blob.alignment)
                    .offset(blob.offset)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Marks

/// The EB app icon (the gradient mark) — rendered straight from the `EBIcon`
/// image asset, the same artwork as `AppIcon.icon`, rather than recomposing the
/// gradient + monogram in code. (iOS can't render an Icon Composer `.icon` as an
/// in-app `Image`, so the artwork is bundled as a vector imageset.)
struct EBAppIcon: View {
    var size: CGFloat = 96
    var float: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image("EBIcon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 15, x: 0, y: 10)
            // A single phase never animates, so this rests when floating is off.
            .phaseAnimator(float && !reduceMotion ? [0, -8] : [0]) { content, lift in
                content.offset(y: lift)
            } animation: { _ in
                .easeInOut(duration: 2.5)
            }
    }
}

/// Completion check — an iOS system-green disc with a white checkmark. Green is
/// the native "done" affordance (the design system's `--ok`), deliberately
/// distinct from the brand mint `success` (the "is a partner" card).
struct CompletionCheck: View {
    var size: CGFloat = 96
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.46, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: .green.opacity(0.33), radius: 12, x: 0, y: 4)
            // One-shot pop on appear (not a loop), so plain state + withAnimation.
            .scaleEffect(shown || reduceMotion ? 1 : 0.72)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { shown = true }
            }
    }
}

// MARK: - Buttons

/// Full-width capsule button on the brand background.
struct BrandButton: View {
    enum Variant { case primary, ghost }

    private let titleKey: LocalizedStringKey
    private let variant: Variant
    private let showArrow: Bool
    private let shimmer: Bool
    private let action: () -> Void

    init(_ titleKey: LocalizedStringKey, variant: Variant = .primary,
         showArrow: Bool = false, shimmer: Bool = false,
         action: @escaping () -> Void) {
        self.titleKey = titleKey
        self.variant = variant
        self.showArrow = showArrow
        self.shimmer = shimmer
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(titleKey)
                    .kerning(0.6)
                if showArrow {
                    Image(systemName: "arrow.right")
                }
            }
        }
        .buttonStyle(BrandButtonStyle(variant: variant, shimmer: shimmer))
    }
}

private struct BrandButtonStyle: ButtonStyle {
    let variant: BrandButton.Variant
    let shimmer: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        styled(configuration.label
            // Tabular digits so the rate-limit countdown doesn't shift the title as it ticks.
            .font(.subheadline.bold().monospacedDigit())
            .frame(maxWidth: .infinity, minHeight: 54))
            .opacity(isEnabled ? 1 : 0.6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }

    @ViewBuilder
    private func styled(_ label: some View) -> some View {
        switch variant {
        case .primary:
            label
                .foregroundStyle(Theme.Colors.primaryForeground)
                .background(Theme.Colors.primary)
                .overlay { if shimmer && !reduceMotion { ShimmerSweep() } }
                .clipShape(.capsule)
                .shadow(color: Theme.Colors.primary.opacity(0.40), radius: 13, x: 0, y: 10)
        case .ghost:
            label
                .foregroundStyle(Theme.Colors.brandForeground)
                .contentShape(.capsule)
        }
    }
}

/// A highlight that sweeps left to right across the button, then restarts.
private struct ShimmerSweep: View {
    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(LinearGradient(colors: [.clear, .white.opacity(0.5), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: geo.size.width * 0.4)
                .keyframeAnimator(initialValue: -1.2, repeating: true) { content, x in
                    content.offset(x: x * geo.size.width)
                } keyframes: { _ in
                    LinearKeyframe(1.4, duration: 2.6, timingCurve: .easeInOut)
                }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Helpers

extension Text {
    func brandTitle(_ color: Color) -> some View {
        self.typography(.title)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    func brandBody(_ color: Color) -> some View {
        self.typography(.body)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}
