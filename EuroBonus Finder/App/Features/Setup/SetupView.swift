import SwiftUI

// Setup — the app's first-run flow.
//
//   welcome → region → extension setup → verify → completed (or incomplete)
//
// A NavigationStack on the brand background, so pushes, the back button and
// the swipe-back gesture are the system's. Each screen is centered content
// with docked buttons and progress dots in place of a title. No step advances
// on its own — "Continue" moves on, or skips. Extension setup goes straight to
// incomplete while the extension is off (the Test page couldn't pass); verify
// goes to completed only once the Test page proved website access. A
// `setup/<screen>` deep link (the Test page's "Back to the app") opens that screen.

struct SetupView: View {
    let state: ExtensionState
    /// The last Setup deep link, if any; each new one opens its screen.
    var link: SetupLink?
    /// Called with `.completed` or `.incomplete` when the user leaves setup.
    let onFinish: (SetupState) -> Void

    /// Screens pushed over welcome.
    @State private var path: [Screen] = []
    @State private var verify = VerifyRun()
    @AppStorage(SharedDefaultsKey.market, store: .shared) private var market = Market.se

    private enum Screen: Hashable { case welcome, chooseRegion, extensionSetup, verify, completed, incomplete }

    var body: some View {
        NavigationStack(path: $path) {
            page(.welcome)
                .navigationDestination(for: Screen.self, destination: page)
        }
        .onAppear(perform: Market.preselectDeviceDefault)
        .onChange(of: link, initial: true) {
            if let link { open(link.screen) }
        }
    }

    // MARK: One screen: dots up top, centered content, docked buttons

    private func page(_ screen: Screen) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            content(for: screen)
            Spacer(minLength: 0)
            actions(for: screen)
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .navigation) { BrandBackground() }
        .toolbar {
            // Our own back button (the system one is pale glass on the brand
            // blue); `SwipeBack` keeps the gesture that hiding it would drop.
            if screen != .welcome {
                ToolbarItem(placement: .navigation) {
                    Button(action: { path.removeLast() }) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.Colors.primary)
                    .accessibilityLabel(Text("setup.back"))
                }
            }
            ToolbarItem(placement: .principal) {
                if let index = dotIndex(for: screen) {
                    ProgressDots(index: index, total: 4)
                }
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .navigationBarBackButtonHidden(screen != .welcome)
        .background(SwipeBack())
        .navigationBarTitleDisplayMode(.inline)
        .animation(.snappy, value: state.status)
        .animation(.snappy, value: state.hostPermission)
    }

    // Region picker, extension setup, verify, then the completed/incomplete screen.
    private func dotIndex(for screen: Screen) -> Int? {
        switch screen {
        case .welcome: nil
        case .chooseRegion: 0
        case .extensionSetup: 1
        case .verify: 2
        case .completed, .incomplete: 3
        }
    }

    // MARK: Centered content per screen

    @ViewBuilder
    private func content(for screen: Screen) -> some View {
        switch screen {
        case .welcome:
            welcome
        case .chooseRegion:
            chooseRegion
        case .extensionSetup:
            ExtensionSetupContent(state: state)
        case .verify:
            VerifyContent(state: state, run: $verify)
        case .completed:
            finish(title: "setup.completed.title") { CompletionCheck(size: 96) }
        case .incomplete:
            finish(title: "setup.incomplete.title", detail: "setup.incomplete.detail") {
                glyph("clock.arrow.circlepath")
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: 0) {
            EBAppIcon(size: 96, float: true)
            Text("setup.welcome.title")
                .brandTitle(BrandPalette.ink)
                .padding(.top, 30)
            Text("setup.welcome.detail")
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
            Text("setup.region.title")
                .brandTitle(BrandPalette.ink)
                .padding(.top, 30)
            Text("setup.region.detail")
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
    private func actions(for screen: Screen) -> some View {
        switch screen {
        case .welcome:
            SetupButton(title: "setup.welcome.button", trailingIcon: "arrow.right", shimmer: true) { goNext(from: screen) }
                .accessibilityIdentifier("setup.next")
        case .chooseRegion:
            SetupButton(title: "setup.continue", trailingIcon: "arrow.right") { goNext(from: screen) }
                .accessibilityIdentifier("setup.next")
        case .extensionSetup:
            ExtensionSetupActions(state: state) { goNext(from: screen) }
        case .verify:
            VerifyActions(state: state, run: $verify) { goNext(from: screen) }
        case .completed, .incomplete:
            SetupButton(title: "setup.finish", trailingIcon: "arrow.right", shimmer: true) { goNext(from: screen) }
        }
    }

    // MARK: Navigation

    private func goNext(from screen: Screen) {
        switch screen {
        case .welcome:
            push(.chooseRegion)
        case .chooseRegion:
            push(.extensionSetup)
        case .extensionSetup:
            push(state.status == .enabled ? .verify : .incomplete)
        case .verify:
            push(verify.status(state) == .working ? .completed : .incomplete)
        case .completed:
            onFinish(.completed)
        case .incomplete:
            onFinish(.incomplete)
        }
    }

    /// Verify starts a fresh run each time it's entered: only pings from then on count.
    private func push(_ screen: Screen) {
        if screen == .verify { verify = VerifyRun() }
        path.append(screen)
    }

    /// A deep link's screen, with the steps before it behind it. Already there
    /// (the Test page linking back to verify) is a no-op, keeping the run.
    private func open(_ target: SetupScreen) {
        let next: [Screen] = switch target {
        case .welcome: []
        case .region: [.chooseRegion]
        case .extension: [.chooseRegion, .extensionSetup]
        case .verify: [.chooseRegion, .extensionSetup, .verify]
        case .done: [.chooseRegion, .extensionSetup, .verify, state.isSetUp ? .completed : .incomplete]
        }
        guard next != path else { return }
        if next.last == .verify, path.last != .verify { verify = VerifyRun() }
        path = next
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
        .animation(.snappy, value: index)
    }
}
