import SwiftUI

struct StartRollSheet: View {
    var viewModel: SessionsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .choose
    @State private var sessionName = ""
    @State private var joinCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum Mode { case choose, start, join }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                switch mode {
                case .choose: chooseView
                case .start:  startView
                case .join:   joinView
                }
                Spacer()
            }
            .padding(Theme.Spacing.lg)
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(mode == .choose ? "Cancel" : "Back") {
                        if mode == .choose { dismiss() } else { mode = .choose }
                    }
                    .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .background(Theme.Colors.background.ignoresSafeArea())
        }
    }

    private var navTitle: String {
        switch mode {
        case .choose: return "What do you want to do?"
        case .start:  return "Start a roll"
        case .join:   return "Join a roll"
        }
    }

    // MARK: - Choose screen

    private var chooseView: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer().frame(height: Theme.Spacing.lg)
            choiceCard(
                icon: "plus.circle.fill",
                title: "Start a roll",
                subtitle: "Create a new roll and share the code with your crew"
            ) { mode = .start }

            choiceCard(
                icon: "arrow.right.circle.fill",
                title: "Join a roll",
                subtitle: "Got a code from someone? Type it in and you're on the roll"
            ) { mode = .join }
        }
    }

    private func choiceCard(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(Theme.Colors.accent)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Colors.textMuted)
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).stroke(Theme.Colors.border, lineWidth: 0.5))
        }
    }

    // MARK: - Start screen

    private var startView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            Spacer().frame(height: Theme.Spacing.sm)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Give it a name (optional)")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textMuted)
                TextField("e.g. Friday night", text: $sessionName)
                    .textFieldStyle(ThemedTextFieldStyle())
                    .autocorrectionDisabled()
            }

            errorText

            RollButton(title: "Start the roll", isLoading: isLoading) {
                Task { await handleCreate() }
            }
        }
    }

    private func handleCreate() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await viewModel.createSession(name: sessionName)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Join screen

    private var joinView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            Spacer().frame(height: Theme.Spacing.sm)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Enter the roll code")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textMuted)

                TextField("e.g. 4F9K2", text: $joinCode)
                    .font(.system(size: 32, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .tracking(4)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control).stroke(Theme.Colors.border, lineWidth: 0.5))
                    .onChange(of: joinCode) { _, new in
                        joinCode = String(new.uppercased().prefix(5))
                    }

                if joinCode.count < 5 {
                    Text("Codes are 5 characters")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                }
            }

            errorText

            RollButton(title: "Jump in", isLoading: isLoading) {
                guard joinCode.count == 5 else { return }
                Task { await handleJoin() }
            }
            .opacity(joinCode.count == 5 ? 1 : 0.5)
        }
    }

    private func handleJoin() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await viewModel.joinSession(code: joinCode)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Shared

    @ViewBuilder
    private var errorText: some View {
        if let msg = errorMessage {
            Text(msg)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.danger)
        }
    }
}
