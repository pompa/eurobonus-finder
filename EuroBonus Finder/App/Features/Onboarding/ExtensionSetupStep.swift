import SwiftUI

// Extension setup — the onboarding step that turns the extension on and allows
// it on all websites (`ExtensionSetupContent` + `ExtensionSetupActions` fill the
// onboarding's content and button slots). Everything reflects the live
// `ExtensionState`; after onboarding, `ExtensionSettingsView` covers the same.

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

            Text("onboarding.setup.title")
                .brandTitle(BrandPalette.ink)
                .padding(.top, 30)

            Text("onboarding.setup.detail")
                .brandBody(BrandPalette.sub)
                .frame(maxWidth: 320)
                .padding(.top, 14)

            // Always shown, even when everything is set: the cards are the step.
            VStack(spacing: 12) {
                ExtensionStatusCard(status: state.status)
                PermissionsCard(state: state)
                if state.isRateLimited {
                    Text("extension.settingsPath")
                        .font(.footnote)
                        .foregroundStyle(BrandPalette.sub)
                        .tint(BrandPalette.ink)
                        .opensSettingsApps()
                        .frame(maxWidth: 320)
                }
            }
            .padding(.top, 22)

            if let error = state.errorMessage {
                Text(verbatim: error)
                    .font(.footnote)
                    .foregroundStyle(BrandPalette.sub.opacity(0.8))
                    .padding(.top, 14)
                    .frame(maxWidth: 300)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 30)
        .task { await state.refresh() }
    }
}

/// "Open Extension Settings" above "Continue". Continue is always available:
/// permission detection waits on the extension's next page load, so never
/// trap the user here.
struct ExtensionSetupActions: View {
    let state: ExtensionState
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            if state.isRateLimited {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    BrandButton("onboarding.setup.buttonWait \(state.settingsCountdown(at: context.date))",
                                variant: .ghost, action: {})
                        .disabled(true)
                }
            } else {
                BrandButton("onboarding.setup.button", variant: .ghost) {
                    Task { await state.openSafariExtensionPreferences() }
                }
            }
            BrandButton("onboarding.continue", variant: .primary,
                        showArrow: true, shimmer: state.isSetUp, action: onContinue)
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
                    // Safari only reveals Allow; Ask, Deny and not-yet-reported
                    // all need the user's attention.
                    if state.isGranted(permission) == true {
                        Text("onboarding.permissions.allowed")
                    } else {
                        WarningMark()
                        Text("onboarding.permissions.allow")
                            .fontWeight(.semibold)
                    }
                }
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
            }
        }
        .foregroundStyle(BrandPalette.ink)
        .multilineTextAlignment(.leading)
        .background(BrandPalette.chipBackground, in: .rect(cornerRadius: 14, style: .continuous))
        .frame(maxWidth: 320)
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
                Text("onboarding.extension.enabled")
            case .disabled, .error:
                WarningMark()
                Text("onboarding.extension.disabled")
            case .unknown:
                EmptyView()
            }
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(BrandPalette.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .background(BrandPalette.chipBackground, in: .rect(cornerRadius: 14, style: .continuous))
        .frame(maxWidth: 320)
    }
}

/// Draws attention to a value that isn't set correctly; sits left of the value.
private struct WarningMark: View {
    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(Theme.Colors.warning)
    }
}
