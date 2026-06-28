import SwiftUI

struct RollButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.label)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Theme.Colors.accent)
                .clipShape(Capsule())
        }
    }
}

struct DangerButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.label)
                .foregroundColor(Theme.Colors.danger)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Theme.Colors.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Theme.Colors.danger, lineWidth: 0.5)
                )
        }
    }
}

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

#Preview {
    VStack(spacing: Theme.Spacing.lg) {
        RollButton(title: "Start a roll") {}
        DangerButton(title: "Done hanging out?") {}
        ActiveChip(label: "Active")
    }
    .padding(Theme.Spacing.lg)
    .background(Theme.Colors.background)
}
