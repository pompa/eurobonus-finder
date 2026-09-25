import SwiftUI

// EuroBonus Finder design system — a SwiftUI port of the shadcn / SwiftCN token model.
//
// Tokens live where SwiftUI can best express them:
//   • Colors      → asset catalog (light/dark), surfaced as typed Theme.Colors.*
//   • Spacing     → a 4-pt CGFloat scale (shadcn spacing ramp)
//   • Typography  → a `.typography(_:)` view modifier (font + tracking + line
//                   height — the two things `Font` alone can't carry)
//
// Asset-symbol generation stays OFF: the generated `Primary` / `Secondary`
// symbols collide with SwiftUI's own `Color.primary` / `.secondary`. Theme.Colors
// is the hand-rolled, collision-free, type-safe accessor over the same colorsets,
// so the asset catalog stays the single source of truth for the values.

enum Theme {}

// MARK: - Colors

extension Theme {
    /// Typed accessors for the colorsets in Assets.xcassets. Names mirror the
    /// CSS/shadcn tokens; each colorset carries its own light/dark appearances.
    enum Colors {
        static let brand = Color("Brand")
        static let brandForeground = Color("BrandForeground")
        static let primary = Color("Primary")
        static let primaryForeground = Color("PrimaryForeground")
        static let warning = Color("Warning")
    }
}

// MARK: - Spacing

extension Theme {
    /// shadcn 4-pt spacing scale. Use for padding / stack spacing instead of
    /// magic numbers.
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
}

// MARK: - Typography

extension Theme {
    /// The two text styles the app uses, on the system (SF) face. Fonts are
    /// Dynamic Type text styles; apply with `.typography(_:)`, which also
    /// carries the tracking and line height that a bare `Font` can't.
    enum TextStyle {
        /// Screen headline — semibold, tracking-tight.
        case title
        /// Running copy.
        case body

        var font: Font {
            switch self {
            case .title: .system(.title, weight: .semibold)
            case .body:  .body
            }
        }

        /// shadcn `tracking-tight` (≈ −0.025em) on headings; 0 elsewhere.
        var tracking: CGFloat {
            switch self {
            case .title: -0.75
            case .body:  0
            }
        }

        /// Extra leading for multi-line running copy.
        var lineSpacing: CGFloat {
            switch self {
            case .title: 0
            case .body:  2
            }
        }
    }
}

extension View {
    /// Apply a `Theme.TextStyle` — font, tracking and line height in one place.
    func typography(_ style: Theme.TextStyle) -> some View {
        modifier(TypographyModifier(style: style))
    }
}

private struct TypographyModifier: ViewModifier {
    let style: Theme.TextStyle

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .tracking(style.tracking)
            .lineSpacing(style.lineSpacing)
    }
}
