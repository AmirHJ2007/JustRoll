import SwiftUI

struct SessionRowView: View {
    let session: Session
    var viewModel: SessionsViewModel

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                headerRow
                codeRow

                if session.status == .active {
                    Divider().background(Theme.Colors.border)
                    actionRow
                }
            }
            .padding(Theme.Spacing.lg)
        }
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(session.displayName)
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.textPrimary)

                let count = session.members.count
                Text("\(count) \(count == 1 ? "person" : "people") on the roll")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            Spacer()
            statusBadge
        }
    }

    private var statusBadge: some View {
        Group {
            if session.status == .active {
                ActiveChip(label: "Active")
            } else {
                Text("Ended")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textMuted)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Theme.Colors.surface)
                    .clipShape(Capsule())
            }
        }
    }

    private var codeRow: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text("Code")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)
            Text(session.code)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(Theme.Colors.textSecondary)
                .tracking(1.5)
        }
    }

    private var actionRow: some View {
        HStack {
            Button("Who's on the roll?") {}
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.accent)

            Spacer()

            Button("Done hanging out?") {
                Task { await viewModel.leaveSession(session) }
            }
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.danger)
        }
    }
}
