 # THEME.md — JustRoll

Visual identity: **white-dominant, charcoal text, fresh green accent.**
Direction: clean and modern (not heavy retro-film). Friendly, light, effortless.

---

## Color

### Core palette

| Role            | Hex       | Use                                              |
|-----------------|-----------|--------------------------------------------------|
| Accent (green)  | `#1F9E5A` | Primary action — "Start a roll", active state, key highlights |
| Accent pressed  | `#178049` | Pressed / darker green for button active state   |
| Accent tint     | `#E7F5EE` | Light green fill — badges, active session chip bg |
| Background      | `#FFFFFF` | App background, cards                             |
| Surface         | `#F6F7F5` | Secondary surface, grouped sections, input bg    |
| Text primary    | `#1C1F1D` | Headlines, body — warm charcoal, not pure black  |
| Text secondary  | `#6B716D` | Subtitles, metadata ("3 people", timestamps)     |
| Text muted      | `#9AA09C` | Hints, placeholders, disabled                    |
| Border          | `#E3E6E3` | Hairline dividers, card borders (use thin: 0.5pt)|
| Success         | `#1F9E5A` | Same as accent (sent / delivered states)         |
| Danger          | `#D8533A` | Leave / end / delete actions                     |

### Optional warm-green alternative

If the fresh green feels too cool, swap the accent for a warmer **sage/olive**
`#5E7D4F` (pressed `#4D6A40`, tint `#EDF1E9`). Better thematic fit, slightly
more muted. Pick one accent and stick to it.

### Rules

- **White is the soul. Green is the accent, not the wallpaper.** Green appears
  on the primary action and active states — not large filled backgrounds.
- One green only. Don't mix fresh green and sage in the same build.
- Text on green fills uses white (`#FFFFFF`).
- Text on green *tint* (`#E7F5EE`) uses the dark green `#178049`, never gray.
- Avoid cold blues — they make a friends-app feel like a banking app.

---

## Typography

- **Font:** system font (SF Pro on iOS). Clean, native, friendly.
- **Weights:** Regular (400) for body, Medium (500) for emphasis/labels,
  Semibold (600) for the few big numbers/titles. Avoid heavy/black weights.
- **Case:** sentence case everywhere. Never Title Case, never ALL CAPS.

| Style        | Size | Weight | Use                                  |
|--------------|------|--------|--------------------------------------|
| Title        | 28   | 600    | Page title (e.g. "Sessions")         |
| Heading      | 20   | 600    | Section / card headers               |
| Body         | 16   | 400    | Default text                         |
| Label        | 15   | 500    | Buttons, row titles                  |
| Caption      | 13   | 400    | Metadata, timestamps, hints          |

---

## Shape & spacing

- **Corners:** rounded everything. Cards `16`, controls `12`, the primary
  button is a **pill** (`fully rounded`). Avatars are circles.
- **Border width:** `0.5pt` hairlines — thin and refined, not chunky.
- **Spacing scale:** 4, 8, 12, 16, 24, 32. Use generous whitespace.
- **Primary button:** pill, green fill, white text, full-width-ish, satisfying
  tap target (min 48pt tall).

---

## Motion — the magic moment

The emotional payoff is photos landing in the camera roll. Give it a small,
warm animation (photos gently "gathering" / dropping in). Keep all other motion
quiet and quick. Don't over-animate the rest of the app.

---

## SwiftUI snippet

```swift
import SwiftUI

enum Theme {
    enum Colors {
        static let accent        = Color(hex: 0x1F9E5A)
        static let accentPressed = Color(hex: 0x178049)
        static let accentTint    = Color(hex: 0xE7F5EE)
        static let background     = Color(hex: 0xFFFFFF)
        static let surface        = Color(hex: 0xF6F7F5)
        static let textPrimary    = Color(hex: 0x1C1F1D)
        static let textSecondary  = Color(hex: 0x6B716D)
        static let textMuted      = Color(hex: 0x9AA09C)
        static let border         = Color(hex: 0xE3E6E3)
        static let danger         = Color(hex: 0xD8533A)
    }

    enum Radius {
        static let control: CGFloat = 12
        static let card: CGFloat    = 16
        static let pill: CGFloat    = 999
    }

    enum Spacing {
        static let xs: CGFloat = 4,  sm: CGFloat = 8,  md: CGFloat = 12
        static let lg: CGFloat = 16, xl: CGFloat = 24, xxl: CGFloat = 32
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// Primary "Start a roll" button
struct RollButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Theme.Colors.accent)
                .clipShape(Capsule())
        }
    }
}
```

## CSS snippet (if any web surface is needed)

```css
:root {
  --accent: #1F9E5A;
  --accent-pressed: #178049;
  --accent-tint: #E7F5EE;
  --bg: #FFFFFF;
  --surface: #F6F7F5;
  --text-primary: #1C1F1D;
  --text-secondary: #6B716D;
  --text-muted: #9AA09C;
  --border: #E3E6E3;
  --danger: #D8533A;
  --radius-control: 12px;
  --radius-card: 16px;
}
```
