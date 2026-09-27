import SwiftUI

/// A row in the app's inset-grouped lists: optional leading SF Symbol or image
/// asset (an app-icon tile, as in iOS Settings), title, secondary value, warning
/// mark and trailing accessory.
struct SettingsRow: View {
    var symbol: String? = nil
    var image: String? = nil
    let title: LocalizedStringKey
    var detail: Text? = nil
    var warning: Bool = false
    var trailing: Trailing = .none

    enum Trailing { case none, external }

    // iOS Settings' 29pt icon tiles; symbols center in the same column.
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 29

    var body: some View {
        HStack(spacing: 12) {
            if let image {
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.225, style: .continuous))
            } else if let symbol {
                Image(systemName: symbol)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: iconSize, alignment: .center)
            }
            Text(title)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            if let detail {
                detail.foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            if warning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .accessibilityLabel(Text("settings.extension.warning"))
            }
            trailingIcon
        }
        // Plain-style buttons only hit-test drawn content; make the Spacer tappable too.
        .contentShape(.rect)
    }

    @ViewBuilder
    private var trailingIcon: some View {
        switch trailing {
        case .none:
            EmptyView()
        case .external:
            Image(systemName: "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}
