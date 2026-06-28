import SwiftUI

enum Theme {
    enum Colors {
        static let accent        = Color(hex: 0x5E7D4F)
        static let accentPressed = Color(hex: 0x4D6A40)
        static let accentTint    = Color(hex: 0xEDF1E9)
        static let background    = Color(hex: 0xFFFFFF)
        static let surface       = Color(hex: 0xF6F7F5)
        static let textPrimary   = Color(hex: 0x1C1F1D)
        static let textSecondary = Color(hex: 0x6B716D)
        static let textMuted     = Color(hex: 0x9AA09C)
        static let border        = Color(hex: 0xE3E6E3)
        static let danger        = Color(hex: 0xD8533A)
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
