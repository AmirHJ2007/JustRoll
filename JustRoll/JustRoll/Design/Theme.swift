import SwiftUI

enum Theme {
    enum Colors {
        static let accent        = Color(hex: 0xFFFFFF)   // white — primary button fill, key highlights
        static let accentPressed = Color(hex: 0xECF0E8)   // warm off-white press state
        static let accentTint    = Color(hex: 0x6B8B5A)   // mid olive — chips, badges on green bg
        static let background    = Color(hex: 0x5E7D4F)   // olive green page background
        static let surface       = Color(hex: 0x4D6A40)   // darker olive — cards, sections
        static let textPrimary   = Color(hex: 0xFFFFFF)   // white
        static let textSecondary = Color(hex: 0xC5D4BE)   // sage-tinted white
        static let textMuted     = Color(hex: 0x8FAB80)   // muted olive-light
        static let border        = Color(hex: 0x7A9A6A)   // lighter olive hairline
        static let danger        = Color(hex: 0xFF8F80)   // coral — visible on green
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
        static let title   = Font.system(size: 28, weight: .semibold)
        static let heading = Font.system(size: 20, weight: .semibold)
        static let body    = Font.system(size: 16, weight: .regular)
        static let label   = Font.system(size: 15, weight: .medium)
        static let caption = Font.system(size: 13, weight: .regular)
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
