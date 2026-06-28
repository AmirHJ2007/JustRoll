import SwiftUI

struct SessionsView: View {
    @State private var viewModel = SessionsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.sessions.isEmpty {
                    emptyState
                } else {
                    sessionsList
                }
            }
            .navigationTitle("Sessions")
            .background(Theme.Colors.background.ignoresSafeArea())
            .task { await viewModel.load() }
            .sheet(isPresented: $viewModel.showStartSheet) {
                StartRollSheet(viewModel: viewModel)
            }
            .alert("Something went wrong", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: "camera.fill")
                .font(.system(size: 52))
                .foregroundColor(Theme.Colors.textMuted)

            VStack(spacing: Theme.Spacing.sm) {
                Text("No rolls yet")
                    .font(Theme.Typography.heading)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("Start one with your crew and photos will find their way to everyone automatically.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xxl)
            }

            RollButton(title: "Start a roll") {
                viewModel.showStartSheet = true
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()
        }
    }

    // MARK: - Sessions list

    private var sessionsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Always-visible CTA
                RollButton(title: "Start a roll") {
                    viewModel.showStartSheet = true
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)

                if !viewModel.activeSessions.isEmpty {
                    sectionLabel("Active")
                    ForEach(viewModel.activeSessions) { session in
                        SessionRowView(session: session, viewModel: viewModel)
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.bottom, Theme.Spacing.sm)
                    }
                    Spacer().frame(height: Theme.Spacing.lg)
                }

                if !viewModel.endedSessions.isEmpty {
                    sectionLabel("Past rolls")
                    ForEach(viewModel.endedSessions) { session in
                        SessionRowView(session: session, viewModel: viewModel)
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.bottom, Theme.Spacing.sm)
                    }
                }

                Spacer().frame(height: Theme.Spacing.xxl)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.textMuted)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xs)
    }
}

#Preview {
    SessionsView()
}
