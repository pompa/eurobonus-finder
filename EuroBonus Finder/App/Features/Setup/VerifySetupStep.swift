import SwiftUI

// Verify — the Setup step that opens the Test page in Safari and waits for the
// extension's permission ping to come back (`VerifyContent` + `VerifyActions`
// fill the Setup's content and button slots; `VerifyRun` tracks the round trip).

/// One round trip to the Test page. Success needs a ping newer than the step
/// itself: older pings don't cover settings changed since.
struct VerifyRun {
    let enteredAt = Date.now
    var opened = false
    var returnedAt: Date?
    var now = Date.now

    /// The extension pings from Safari, but can land a moment after the app is active again.
    static let grace: TimeInterval = 3

    enum Status { case idle, checking, working, notDetected }

    func status(_ state: ExtensionState) -> Status {
        if state.hasAllWebsitesAccess(since: enteredAt) { return .working }
        guard opened else { return .idle }
        guard let returnedAt, now.timeIntervalSince(returnedAt) >= Self.grace else { return .checking }
        return .notDetected
    }
}

/// Icon, copy and the live website-access row; the troubleshoot link and sheet
/// once nothing was detected.
struct VerifyContent: View {
    let state: ExtensionState
    @Binding var run: VerifyRun
    @Environment(\.scenePhase) private var scenePhase
    @State private var troubleshooting = false

    var body: some View {
        let status = run.status(state)
        VStack(spacing: 0) {
            Image(systemName: "safari")
                .font(.system(size: 80, weight: .light))
                .foregroundStyle(BrandPalette.ink)
                .frame(height: 104)

            Text("setup.verify.title")
                .brandTitle(BrandPalette.ink)
                .padding(.top, 30)

            Text("setup.verify.detail")
                .brandBody(BrandPalette.sub)
                .frame(maxWidth: 320)
                .padding(.top)

            AccessCard(status: status)
                .padding(.top, 22)

            switch status {
            case .working:
                Text("setup.verify.successDetail")
                    .font(.footnote)
                    .foregroundStyle(BrandPalette.sub)
                    .frame(maxWidth: 320)
                    .padding(.top)
            case .notDetected:
                Text("setup.verify.troubleshoot")
                    .font(.footnote)
                    .foregroundStyle(BrandPalette.sub)
                    .tint(BrandPalette.ink)
                    .environment(\.openURL, OpenURLAction { _ in
                        troubleshooting = true
                        return .handled
                    })
                    .frame(maxWidth: 320)
                    .padding(.top)
            case .idle, .checking:
                EmptyView()
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal)
        .animation(.snappy, value: status)
        .sheet(isPresented: $troubleshooting) { TroubleshootSheet() }
        .onChange(of: scenePhase) {
            if scenePhase == .active, run.opened { run.returnedAt = .now }
        }
        // The ping lands in the App Group from Safari's process and the grace
        // window is time-based, so keep both fresh while the step is on screen.
        .task {
            while !Task.isCancelled {
                state.readPermissionPing()
                run.now = .now
                try? await Task.sleep(for: .seconds(0.5))
            }
        }
    }
}

/// Until the Test page proves access: "Open in Safari" with "Skip" (ghost)
/// below. Once it has: "Open in Safari" (ghost) above a shimmering "Continue".
/// Either way the user can leave; skipping leaves Setup incomplete.
struct VerifyActions: View {
    let state: ExtensionState
    @Binding var run: VerifyRun
    let onContinue: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        let working = run.status(state) == .working
        VStack(spacing: 14) {
            if working {
                SetupButton(title: "setup.verify.button", role: .ghost, icon: "safari", action: openTestPage)
                SetupButton(title: "setup.continue", trailingIcon: "arrow.right", shimmer: true, action: onContinue)
            } else {
                SetupButton(title: "setup.verify.button", icon: "safari", action: openTestPage)
                SetupButton(title: "setup.skip", role: .skip, action: onContinue)
            }
        }
        .animation(.snappy, value: working)
    }

    private func openTestPage() {
        run.opened = true
        openURL(TestPage.url(setup: true))
    }
}

/// "Website access" and what the Test page has shown so far.
private struct AccessCard: View {
    let status: VerifyRun.Status

    var body: some View {
        HStack(spacing: 12) {
            Text("setup.verify.access")
            Spacer(minLength: 8)
            switch status {
            case .idle:
                Text("setup.verify.idle")
            case .checking:
                ProgressView()
                    .tint(BrandPalette.ink)
                Text("setup.verify.checking")
            case .working:
                Image(systemName: "checkmark.circle.fill")
                Text("setup.verify.working")
                    .fontWeight(.semibold)
            case .notDetected:
                WarningMark()
                Text("setup.verify.notDetected")
                    .fontWeight(.semibold)
            }
        }
        .font(.footnote.weight(.medium))
        .padding(.horizontal)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .setupCard()
    }
}
