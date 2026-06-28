import SwiftUI

struct RollButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(Theme.Colors.background)
                } else {
                    Text(title)
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.background)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Theme.Colors.accent)
            .clipShape(Capsule())
        }
        .disabled(isLoading)
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
                .overlay(Capsule().stroke(Theme.Colors.danger, lineWidth: 0.5))
        }
    }
}

struct ActiveChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.textPrimary)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Theme.Colors.accentTint)
            .clipShape(Capsule())
    }
}

struct AvatarView: View {
    let name: String
    var size: CGFloat = 44

    private var initial: String { String(name.prefix(1)).uppercased() }

    var body: some View {
        Circle()
            .fill(Theme.Colors.accentTint)
            .frame(width: size, height: size)
            .overlay(
                Text(initial)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(Theme.Colors.accent)
            )
    }
}

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

#Preview("Components") {
    VStack(spacing: Theme.Spacing.lg) {
        RollButton(title: "Start a roll") {}
        RollButton(title: "Loading...", isLoading: true) {}
        DangerButton(title: "Done hanging out?") {}
        HStack(spacing: Theme.Spacing.sm) {
            ActiveChip(label: "Active")
            AvatarView(name: "Sara")
        }
    }
    .padding(Theme.Spacing.lg)
    .background(Theme.Colors.background)
}
