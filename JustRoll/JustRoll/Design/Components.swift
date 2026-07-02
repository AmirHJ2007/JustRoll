import SwiftUI

// MARK: - Primary button (olive pill, white text)

struct RollButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(Theme.Typography.label)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.Colors.accent)
            .clipShape(Capsule())
            .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 16, x: 0, y: 6)
        }
        .buttonStyle(SpringTapStyle(scaleAmount: 0.97))
        .disabled(isLoading)
    }
}

// MARK: - Danger button

struct DangerButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.label)
                .foregroundColor(Theme.Colors.danger)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Theme.Colors.background)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.Colors.danger, lineWidth: 1))
        }
    }
}

// MARK: - Active chip

struct ActiveChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.accentPressed)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Theme.Colors.accentTint)
            .clipShape(Capsule())
    }
}

// MARK: - Avatar palette (deterministic, shared across features)

private struct _AvatarTone { let bg: Color; let fg: Color }
private let _palette: [_AvatarTone] = [
    _AvatarTone(bg: Color(hex: 0xD4E8CC), fg: Color(hex: 0x2D4A24)),
    _AvatarTone(bg: Color(hex: 0xDDE6C8), fg: Color(hex: 0x3A4A24)),
    _AvatarTone(bg: Color(hex: 0xE0EAD4), fg: Color(hex: 0x34502A)),
    _AvatarTone(bg: Color(hex: 0xE8E2D4), fg: Color(hex: 0x4A4030)),
    _AvatarTone(bg: Color(hex: 0xD8EDD2), fg: Color(hex: 0x2E4A2C)),
    _AvatarTone(bg: Color(hex: 0xE4DFD0), fg: Color(hex: 0x46402C)),
]
func avatarColors(for name: String) -> (bg: Color, fg: Color) {
    let t = _palette[name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } % _palette.count]
    return (t.bg, t.fg)
}

// MARK: - AvatarView

struct AvatarView: View {
    let name: String
    var size: CGFloat = 40

    var body: some View {
        let c = avatarColors(for: name)
        Circle()
            .fill(c.bg)
            .frame(width: size, height: size)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundColor(c.fg)
            )
    }
}

// MARK: - AvatarCluster (overlapping, with overflow count)

struct AvatarCluster: View {
    let names: [String]
    var size: CGFloat = 28
    var maxVisible: Int = 4

    private var visible: [String] { Array(names.prefix(maxVisible)) }
    private var overflow: Int    { max(0, names.count - maxVisible) }

    var body: some View {
        HStack(spacing: -(size * 0.28)) {
            ForEach(Array(visible.enumerated()), id: \.offset) { _, name in
                AvatarView(name: name, size: size)
                    .overlay(Circle().stroke(Theme.Colors.background, lineWidth: 1.5))
            }
            if overflow > 0 {
                Circle()
                    .fill(Theme.Colors.surface)
                    .frame(width: size, height: size)
                    .overlay(Circle().stroke(Theme.Colors.background, lineWidth: 1.5))
                    .overlay(
                        Text("+\(overflow)")
                            .font(.system(size: size * 0.32, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.Colors.textMuted)
                    )
            }
        }
    }
}

// MARK: - PageHeader (reusable across all 4 tabs — top-sheet panel)

struct PageHeader<Trailing: View, Footer: View>: View {
    let title: String
    var subtitle: String? = nil
    // Bottom padding on the title row — reduced when a footer follows.
    var titleBottomPad: CGFloat = 22
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(Theme.Typography.displayTitle)
                            .foregroundColor(Theme.Colors.textPrimary)
                        SwooshUnderline()
                            .frame(height: 8)
                    }
                    if let subtitle {
                        HStack(spacing: 4) {
                            HStack(spacing: 2) {
                                Circle().fill(Theme.Colors.accent.opacity(0.6)).frame(width: 4, height: 4)
                                Circle().fill(Theme.Colors.accent.opacity(0.6)).frame(width: 4, height: 4)
                            }
                            Text(subtitle)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.Colors.accent)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.Colors.accentTint)
                        .clipShape(Capsule())
                    }
                }
                Spacer(minLength: 8)
                trailing()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, titleBottomPad)

            footer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 28,
                bottomTrailingRadius: 28,
                topTrailingRadius: 0
            )
            .fill(Theme.Colors.background)
            .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 5)
            .ignoresSafeArea(edges: .top)
        }
    }
}

// No trailing, no footer (Settings, Unsent)
extension PageHeader where Trailing == EmptyView, Footer == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.title = title; self.subtitle = subtitle
        self.titleBottomPad = 22
        self.trailing = { EmptyView() }; self.footer = { EmptyView() }
    }
}

// Trailing only, no footer (Sessions)
extension PageHeader where Footer == EmptyView {
    init(title: String, subtitle: String? = nil, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title; self.subtitle = subtitle
        self.titleBottomPad = 22
        self.trailing = trailing; self.footer = { EmptyView() }
    }
}

// Trailing + footer (Contacts — crew strip and search bar inside the panel)
extension PageHeader {
    init(title: String, subtitle: String? = nil,
         @ViewBuilder trailing: @escaping () -> Trailing,
         @ViewBuilder footer: @escaping () -> Footer) {
        self.title = title; self.subtitle = subtitle
        self.titleBottomPad = 10
        self.trailing = trailing; self.footer = footer
    }
}

// MARK: - Swoosh underline (olive brush stroke Path)

struct SwooshUnderline: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            Path { p in
                // A gentle wave that reads as a hand-drawn marker stroke
                p.move(to: CGPoint(x: 0, y: 6))
                p.addCurve(
                    to: CGPoint(x: w * 0.55, y: 3),
                    control1: CGPoint(x: w * 0.15, y: 8),
                    control2: CGPoint(x: w * 0.35, y: 1)
                )
                p.addCurve(
                    to: CGPoint(x: w * 0.82, y: 5),
                    control1: CGPoint(x: w * 0.68, y: 5),
                    control2: CGPoint(x: w * 0.75, y: 7)
                )
            }
            .stroke(
                Theme.Colors.accent.opacity(0.7),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

// MARK: - SectionHeader (small-caps, consistent across tabs)

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(0.9)
            .foregroundColor(Theme.Colors.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
    }
}

// MARK: - LivePulseDot (pulsing olive dot for active sessions)

struct LivePulseDot: View {
    @State private var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.Colors.accent.opacity(0.28))
                .frame(width: 14, height: 14)
                .scaleEffect(pulsing ? 1.9 : 1)
                .opacity(pulsing ? 0 : 0.8)
            Circle()
                .fill(Theme.Colors.accent)
                .frame(width: 7, height: 7)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        }
    }
}

// MARK: - CodeBadge (copyable monospaced roll code)

struct CodeBadge: View {
    let code: String
    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = code
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeInOut(duration: 0.2)) { copied = false }
            }
        } label: {
            HStack(spacing: 5) {
                Text(copied ? "Copied!" : code)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(copied ? 0 : 2.5)
                    .foregroundColor(copied ? Theme.Colors.accent : Theme.Colors.textPrimary)
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(copied ? Theme.Colors.accent : Theme.Colors.textMuted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        copied ? Theme.Colors.accent.opacity(0.45) : Theme.Colors.border,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: copied)
    }
}

// MARK: - Card (white, rounded, hairline border)

struct CardView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(Theme.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(Theme.Colors.border, lineWidth: 0.5)
            )
    }
}

// MARK: - Text field

struct ThemedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(Theme.Typography.body)
            .foregroundColor(Theme.Colors.textPrimary)
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .stroke(Theme.Colors.border, lineWidth: 0.5)
            )
    }
}

// MARK: - Spring button style (springy scale on press)

struct SpringTapStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.94
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Row press modifier (0.97 scale on hold, spring release)

struct RowPressModifier: ViewModifier {
    @GestureState private var pressing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect((!reduceMotion && pressing) ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pressing)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($pressing) { _, state, _ in state = true }
            )
    }
}

extension View {
    func rowPressEffect() -> some View { modifier(RowPressModifier()) }
}

// MARK: - Film reel spinner (pull-to-refresh / loading indicator)

struct FilmReelSpinner: View {
    var isSpinning: Bool = true
    var progress: CGFloat = 1.0   // 0–1 for pull-reveal scale

    @State private var rotation: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Theme.Colors.accentTint, lineWidth: 3)
                .frame(width: 40, height: 40)

            // Sprocket holes
            ForEach(0..<8, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Theme.Colors.accent.opacity(0.65))
                    .frame(width: 3.5, height: 5.5)
                    .offset(y: -16)
                    .rotationEffect(.degrees(Double(i) * 45))
            }

            // Inner hub
            Circle()
                .fill(Theme.Colors.accentTint)
                .frame(width: 12, height: 12)

            // Centre pin
            Circle()
                .fill(Theme.Colors.accent)
                .frame(width: 5, height: 5)
        }
        .frame(width: 44, height: 44)
        .scaleEffect(progress)
        .rotationEffect(.degrees(rotation))
        .onAppear { startIfNeeded() }
        .onChange(of: isSpinning) { _, v in if v { startIfNeeded() } }
    }

    private func startIfNeeded() {
        guard isSpinning && !reduceMotion else { return }
        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }
}

// MARK: - Film frame drop (celebratory overlay when friend added)

struct FilmDropOverlay: View {
    @Binding var visible: Bool
    @State private var y: CGFloat = -10
    @State private var scale: CGFloat = 0.4
    @State private var opacity: Double = 0

    var body: some View {
        Image(systemName: "film.fill")
            .font(.system(size: 30, weight: .medium))
            .foregroundColor(Theme.Colors.accent)
            .scaleEffect(scale)
            .offset(y: y)
            .opacity(opacity)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                    scale = 1.15; opacity = 1; y = 14
                }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8).delay(0.3)) {
                    scale = 1; y = 22
                }
                withAnimation(.easeIn(duration: 0.25).delay(0.85)) {
                    opacity = 0; y = 52; scale = 0.8
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) { visible = false }
            }
    }
}

// MARK: - Navigation bar modifier

extension View {
    func themedNavBar() -> some View {
        self
            .toolbarBackground(Theme.Colors.background, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
    }
}

#Preview("Components") {
    VStack(spacing: Theme.Spacing.lg) {
        RollButton(title: "Start a roll") {}
        RollButton(title: "Loading...", isLoading: true) {}
        DangerButton(title: "Done hanging out?") {}
        HStack(spacing: Theme.Spacing.sm) {
            ActiveChip(label: "Active")
            AvatarView(name: "Sara")
        }
        CardView {
            Text("Sample card")
                .font(Theme.Typography.label)
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(Theme.Spacing.lg)
        }
    }
    .padding(Theme.Spacing.lg)
    .background(Theme.Colors.surface)
}
