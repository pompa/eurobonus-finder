import SwiftUI

// Guided onboarding — the "EuroBonus Finder Onboarding — Guided" design.
//
//   welcome → region → extension setup → completed (or incomplete, if skipped)
//
// A forward-only flow (no back button) on the brand background: centered
// content, progress dots and docked buttons. The extension setup step is the
// shared `ExtensionSetupContent` / `ExtensionSetupActions`; it's always shown
// (even when already set up) and never advances on its own — "Continue" moves
// on, or skips it.

struct OnboardingView: View {
    let state: ExtensionState
    /// Called with `.completed` or `.incomplete` when the user leaves onboarding.
    let onFinish: (OnboardingState) -> Void

    @State private var screen: Screen = .welcome
    @AppStorage(SharedDefaultsKey.market, store: Market.store) private var market = Market.se

    private enum Screen: Hashable { case welcome, chooseRegion, extensionSetup, completed, incomplete }

    var body: some View {
        ZStack {
            BrandBackground()

            VStack(spacing: 0) {
                progressBar

                Spacer(minLength: 0)

                content
                    .id(screen)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                Spacer(minLength: 0)

                actions
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .padding(.bottom, 8)
            }
        }
        .animation(.snappy, value: screen)
        .animation(.snappy, value: state.status)
        .animation(.snappy, value: state.hostPermission)
        .onAppear(perform: Market.preselectDeviceDefault)
    }

    // MARK: Progress dots (forward-only, no back button)

    private var progressBar: some View {
        ZStack {
            if let index = dotIndex {
                ProgressDots(index: index, total: 3)
            }
        }
        .frame(height: 40)
        .padding(.top, 12)
    }

    // Region picker, extension setup, then the completed/incomplete screen.
    private var dotIndex: Int? {
        switch screen {
        case .welcome: return nil
        case .chooseRegion: return 0
        case .extensionSetup: return 1
        case .completed, .incomplete: return 2
        }
    }

    // MARK: Centered content per screen

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .welcome:
            welcome
        case .chooseRegion:
            chooseRegion
        case .extensionSetup:
            ExtensionSetupContent(state: state)
        case .completed:
            finish(title: "onboarding.completed.title") { CompletionCheck(size: 96) }
        case .incomplete:
            finish(title: "onboarding.incomplete.title", detail: "onboarding.incomplete.detail") {
                glyph("clock.arrow.circlepath")
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: 0) {
            EBAppIcon(size: 96, float: true)
            Text("onboarding.welcome.title")
                .brandTitle(BrandPalette.ink)
                .padding(.top, 30)
            Text("onboarding.welcome.detail")
                .brandBody(BrandPalette.sub)
                .frame(maxWidth: 300)
                .padding(.top, 16)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 26)
    }

    private var chooseRegion: some View {
        VStack(spacing: 0) {
            glyph("globe.europe.africa")
            Text("onboarding.region.title")
                .brandTitle(BrandPalette.ink)
                .padding(.top, 30)
            Text("onboarding.region.detail")
                .brandBody(BrandPalette.sub)
                .frame(maxWidth: 320)
                .padding(.top, 14)

            VStack(spacing: 8) {
                ForEach(Market.allCases) { option in
                    Button { market = option } label: {
                        HStack {
                            Text(verbatim: option.name)
                            Spacer()
                            if option == market {
                                Image(systemName: "checkmark")
                            }
                        }
                        .font(.subheadline.weight(option == market ? .bold : .medium))
                        .foregroundStyle(BrandPalette.ink)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 48)
                        .background(option == market ? BrandPalette.ink.opacity(0.24) : BrandPalette.chipBackground,
                                    in: .rect(cornerRadius: 14, style: .continuous))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(option == market ? .isSelected : [])
                }
            }
            .frame(maxWidth: 320)
            .padding(.top, 22)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 30)
    }

    /// The last screen: `.completed`, or `.incomplete` when setup was skipped.
    private func finish(title: LocalizedStringKey, detail: LocalizedStringKey? = nil,
                        @ViewBuilder mark: () -> some View) -> some View {
        VStack(spacing: 0) {
            mark()
                .frame(height: 104)
            Text(title)
                .brandTitle(BrandPalette.ink)
                .padding(.top, 30)
            if let detail {
                Text(detail)
                    .brandBody(BrandPalette.sub)
                    .frame(maxWidth: 300)
                    .padding(.top, 14)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 26)
    }

    private func glyph(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 80, weight: .light))
            .foregroundStyle(BrandPalette.ink)
            .frame(height: 104)
    }

    // MARK: Docked buttons per screen

    @ViewBuilder
    private var actions: some View {
        switch screen {
        case .welcome:
            BrandButton("onboarding.welcome.button", showArrow: true, shimmer: true, action: goNext)
                .accessibilityIdentifier("onboarding.next")
        case .chooseRegion:
            BrandButton("onboarding.continue", showArrow: true, action: goNext)
                .accessibilityIdentifier("onboarding.next")
        case .extensionSetup:
            ExtensionSetupActions(state: state, onContinue: goNext)
        case .completed, .incomplete:
            BrandButton("onboarding.finish", showArrow: true, shimmer: true, action: goNext)
        }
    }

    // MARK: Navigation (forward-only)

    private func goNext() {
        switch screen {
        case .welcome:
            screen = .chooseRegion
        case .chooseRegion:
            screen = .extensionSetup
        case .extensionSetup:
            screen = state.isSetUp ? .completed : .incomplete
        case .completed:
            onFinish(.completed)
        case .incomplete:
            onFinish(.incomplete)
        }
    }
}

// MARK: - Progress dots

private struct ProgressDots: View {
    let index: Int
    let total: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == index ? BrandPalette.ink : BrandPalette.dotInactive)
                    .frame(width: i == index ? 22 : 7, height: 7)
            }
        }
    }
}
