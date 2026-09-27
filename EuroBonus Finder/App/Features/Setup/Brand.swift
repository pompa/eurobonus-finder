import SwiftUI

// Setup's brand surface: a fixed deep-blue atmosphere with light ink, its marks
// and its capsule buttons. Setup is the one branded screen; everything after it
// is native lists on the system tint.

// MARK: - Palette (brand-derived, light/dark)

/// The brand atmosphere — a deep-blue wash (`brand → brandAccent → brand`)
/// with ambient `brandAccent`/`brand` glows. Text, icons and dots use
/// `brandForeground` so they read light on it. A fixed brand moment: it
/// looks the same in light and dark (these colors don't flip).
enum BrandPalette {
    static var pageGradient: LinearGradient {
        LinearGradient(colors: [Color.brand, Color.brandAccent, Color.brand],
                       startPoint: .top, endPoint: .bottom)
    }
    /// Text, glyphs, chip labels and the active progress dot.
    static let ink = Color.brandForeground
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
        Blob(id: 0, color: Color.brandAccent, size: 360, alignment: .topTrailing,   offset: CGSize(width: 80, height: -90), opacity: 0.35),
        Blob(id: 1, color: Color.brand,   size: 320, alignment: .leading,        offset: CGSize(width: -100, height: 0), opacity: 0.32),
        Blob(id: 2, color: Color.brandAccent, size: 260, alignment: .bottomTrailing, offset: CGSize(width: 60, height: 70), opacity: 0.26),
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
    @State private var shown = false
    @State private var lifted = false

    var body: some View {
        Image("EBIcon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 15, x: 0, y: 10)
            // Fades in where it sits, then bobs. Plain state instead of `phaseAnimator`,
            // which flew the icon in from above the screen when Setup replaced the main view.
            .opacity(shown ? 1 : 0)
            .offset(y: lifted ? -8 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) { shown = true }
                guard float && !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(0.6)) { lifted = true }
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
/// A full-width Setup button: prominent glass in the brand blue, with an
/// optional shimmer for the step's main action; bare text for a secondary one;
/// or muted text with a chevron for skipping the step.
struct SetupButton: View {
    enum Role { case primary, ghost, skip }

    let title: LocalizedStringKey
    var role: Role = .primary
    var icon: String? = nil
    var trailingIcon: String? = nil
    var shimmer = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch role {
        case .primary:
            Button(action: action) { label }
                .buttonStyle(.glassProminent)
                .tint(.brandAccent)
                .overlay { if shimmer && !reduceMotion { ShimmerSweep().clipShape(.capsule).allowsHitTesting(false) } }
                .shadow(color: Color.brandAccent.opacity(0.40), radius: 13, x: 0, y: 10)
        case .ghost:
            Button(action: action) { label.padding(.vertical, 10) }
                .buttonStyle(.plain)
                .foregroundStyle(.brandForeground)
        case .skip:
            Button(action: action) { label.padding(.vertical, 10) }
                .buttonStyle(.plain)
                .foregroundStyle(BrandPalette.sub)
        }
    }

    private var label: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
            }
            Text(title)
            if let trailingIcon = trailingIcon ?? (role == .skip ? "chevron.right" : nil) {
                Image(systemName: trailingIcon)
            }
        }
        // Tabular digits so the rate-limit countdown doesn't shift the title as it ticks.
        .font(.subheadline.bold().monospacedDigit())
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
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
    /// Screen headline on the brand background: the system title style, semibold.
    func brandTitle(_ color: Color) -> some View {
        self.font(.title.weight(.semibold))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Running copy on the brand background.
    func brandBody(_ color: Color) -> some View {
        self.font(.body)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}
