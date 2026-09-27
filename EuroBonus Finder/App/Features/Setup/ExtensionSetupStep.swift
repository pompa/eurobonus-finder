import SwiftUI

// Extension setup — the Setup step that turns the extension on and allows
// it on all websites (`ExtensionSetupContent` + `ExtensionSetupActions` fill the
// Setup's content and button slots). Everything reflects the live
// `ExtensionState`; after Setup, `ExtensionSettingsView` covers the same.

/// Icon, copy, extension status and permissions.
struct ExtensionSetupContent: View {
    let state: ExtensionState

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 80, weight: .light))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(BrandPalette.ink)
                .frame(height: 104)

            Text("setup.extension.title")
                .brandTitle(BrandPalette.ink)
                .padding(.top, 30)

            Text("setup.extension.detail")
                .brandBody(BrandPalette.sub)
                .frame(maxWidth: 320)
                .padding(.top)

            // Always shown, even when everything is set: the cards are the step.
            VStack(spacing: 12) {
                ExtensionStatusCard(status: state.status)
                PermissionsCard(state: state)
                // The rate-limit fallback matters more than the next-step hint.
                if state.isRateLimited {
                    Text("extension.settingsPath")
                        .font(.footnote)
                        .foregroundStyle(BrandPalette.sub)
                        .tint(BrandPalette.ink)
                        .opensSettingsApps()
                        .frame(maxWidth: 320)
                } else if state.openedSettings, state.isGranted(.allWebsites) == nil {
                    Text("setup.extension.testHint")
                        .font(.footnote)
                        .foregroundStyle(BrandPalette.sub)
                        .frame(maxWidth: 320)
                }
            }
            .padding(.top, 22)

            if let error = state.errorMessage {
                Text(verbatim: error)
                    .font(.footnote)
                    .foregroundStyle(BrandPalette.sub.opacity(0.8))
                    .padding(.top)
                    .frame(maxWidth: 300)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal)
        .task { await state.refresh() }
    }
}

/// While the extension is off: "Open Extension Settings" leads, "Skip" below.
/// Once it's on: "Open Extension Settings" (ghost) above "Continue". The user
/// can always move on: permission detection waits on the Test page anyway.
struct ExtensionSetupActions: View {
    let state: ExtensionState
    let onContinue: () -> Void

    private var isOff: Bool {
        switch state.status {
        case .disabled, .error: true
        case .enabled, .unknown: false
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            if isOff {
                settingsButton(role: .primary)
                SetupButton(title: "setup.skip", role: .skip, action: onContinue)
            } else {
                settingsButton(role: .ghost)
                SetupButton(title: "setup.continue", trailingIcon: "arrow.right", shimmer: state.isSetUp, action: onContinue)
            }
        }
        .animation(.snappy, value: isOff)
    }

    @ViewBuilder
    private func settingsButton(role: SetupButton.Role) -> some View {
        if state.isRateLimited {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                SetupButton(title: "setup.extension.buttonWait \(state.settingsCountdown(at: context.date))",
                            role: role, action: {})
                    .disabled(true)
            }
        } else {
            SetupButton(title: "setup.extension.button", role: role) {
                Task { await state.openSafariExtensionPreferences() }
            }
        }
    }
}

// MARK: - Cards

/// Mirrors Safari's "Permissions for EuroBonus Finder" list: every domain
/// should be set to Allow.
private struct PermissionsCard: View {
    let state: ExtensionState

    var body: some View {
        VStack(spacing: 0) {
            ForEach(ExtensionPermission.allCases) { permission in
                if permission != ExtensionPermission.allCases.first {
                    Divider().overlay(BrandPalette.ink.opacity(0.2))
                }
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(permission.title)
                            .lineLimit(1)
                        Text(permission.detail)
                            .font(.caption)
                            .foregroundStyle(BrandPalette.sub)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    // Safari only reveals Allow, and only once a page has loaded
                    // with the extension — so nothing is known here yet. The
                    // verify step finds out; only a reported Ask/Deny warns.
                    switch state.isGranted(permission) {
                    case true:
                        Text("setup.permissions.allowed")
                    case false:
                        WarningMark()
                        Text("setup.permissions.allow")
                            .fontWeight(.semibold)
                    case nil:
                        Text("setup.permissions.pending")
                    }
                }
                .font(.footnote.weight(.medium))
                .padding(.horizontal)
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
            }
        }
        .multilineTextAlignment(.leading)
        .setupCard()
    }
}

/// The extension's enabled/disabled state (Safari's "Allow Extension" switch),
/// grouped apart from the permissions list.
private struct ExtensionStatusCard: View {
    let status: ExtensionStatus

    var body: some View {
        HStack(spacing: 12) {
            Text("settings.extension")
            Spacer(minLength: 8)
            switch status {
            case .enabled:
                Text("setup.extension.enabled")
            case .disabled, .error:
                WarningMark()
                Text("setup.extension.disabled")
            case .unknown:
                EmptyView()
            }
        }
        .font(.footnote.weight(.medium))
        .padding(.horizontal)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .setupCard()
    }
}

extension View {
    /// The chip the Setup steps show their status rows in.
    func setupCard() -> some View {
        foregroundStyle(BrandPalette.ink)
            .background(BrandPalette.chipBackground, in: .rect(cornerRadius: 14, style: .continuous))
            .frame(maxWidth: 320)
    }
}

/// Draws attention to a value that isn't set correctly; sits left of the value.
struct WarningMark: View {
    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
    }
}
