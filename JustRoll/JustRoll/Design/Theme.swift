import SwiftUI

enum Theme {
    enum Colors {
        static let accent        = Color(hex: 0x5E7D4F)   // olive — primary action, active states
        static let accentPressed = Color(hex: 0x4D6A40)   // darker olive — press state
        static let accentTint    = Color(hex: 0xEDF1E9)   // pale sage — chips, badges, tints
        static let background    = Color(hex: 0xFFFFFF)   // white — page background, cards
        static let surface       = Color(hex: 0xF4F6F2)   // very light sage — sections, inputs
        static let textPrimary   = Color(hex: 0x1C1F1D)   // warm charcoal — headlines, body
        static let textSecondary = Color(hex: 0x6B716D)   // medium gray — subtitles, metadata
        static let textMuted     = Color(hex: 0x9AA09C)   // light gray — hints, placeholders
        static let border        = Color(hex: 0xE3E6E3)   // hairline — card borders, dividers
        static let danger        = Color(hex: 0xD8533A)   // red — leave, end, delete
    }

    enum Radius {
        static let control: CGFloat = 12
        static let card: CGFloat    = 16
        static let pill: CGFloat    = 999
    }

    enum Spacing {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 12
        static let lg: CGFloat  = 16
        static let xl: CGFloat  = 24
        static let xxl: CGFloat = 32
    }

    enum Typography {
        // MARK: Handwritten — Caveat Medium — display & section headers ONLY
        static func handwritten(size: CGFloat) -> Font {
            Font.custom("Caveat-Medium", size: size)
        }
        static let displayTitle  = Font.custom("Caveat-Medium", size: 52)   // page title
        static let sectionHeader = Font.custom("Caveat-Medium", size: 20)   // "On JustRoll" etc.

        // MARK: SF Rounded — all body / UI text
        static let title   = Font.system(size: 28, weight: .bold,     design: .rounded)
        static let heading = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let body    = Font.system(size: 16, weight: .regular,  design: .rounded)
        static let label   = Font.system(size: 15, weight: .medium,   design: .rounded)
        static let caption = Font.system(size: 13, weight: .regular,  design: .rounded)
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:     Double((hex >> 16) & 0xFF) / 255,
            green:   Double((hex >> 8)  & 0xFF) / 255,
            blue:    Double(hex         & 0xFF) / 255,
            opacity: alpha
        )
    }
}
