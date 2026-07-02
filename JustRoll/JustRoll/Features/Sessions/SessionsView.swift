import SwiftUI

struct SessionsView: View {
    @State private var viewModel: SessionsViewModel
    @State private var listVisible = false
    @State private var joinCode = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(service: any SupabaseServiceProtocol = MockSupabaseService.shared) {
        self._viewModel = State(initialValue: SessionsViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Theme.Colors.surface.ignoresSafeArea()
                VStack(spacing: 0) {
                    header.zIndex(1)
                    if viewModel.isLoading && viewModel.sessions.isEmpty {
                        Spacer()
                        FilmReelSpinner()
                        Spacer()
                    } else if viewModel.sessions.isEmpty {
                        emptyState
                    } else {
                        mainScroll
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.load()
                withAnimation(reduceMotion ? .none : .spring(response: 0.45)) {
                    listVisible = true
                }
            }
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

    // MARK: - Header

    private var header: some View {
        PageHeader(title: "My Circles", subtitle: subtitleText) {
            Button { viewModel.showStartSheet = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Theme.Colors.accent)
                    .clipShape(Circle())
                    .shadow(color: Theme.Colors.accent.opacity(0.35), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(SpringTapStyle(scaleAmount: 0.86))
            .padding(.top, 4)
        }
    }

    private var subtitleText: String? {
        guard !viewModel.sessions.isEmpty else { return nil }
        let count = viewModel.sessions.filter { $0.status == .active }.count
        if count == 0 { return "No circles rolling" }
        return count == 1 ? "1 rolling now" : "\(count) rolling now"
    }

    // MARK: - Join bar

    private var joinBar: some View {
        HStack(spacing: 0) {
            TextField("Enter circle code to join", text: $joinCode)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(Theme.Colors.textPrimary)
                .textInputAutocapitalization(.characters)
                .disableAutocorrection(true)
                .padding(.leading, 18)
                .padding(.vertical, 15)

            Spacer(minLength: 8)

            Button {
                let code = joinCode.trimmingCharacters(in: .whitespaces)
                guard code.count >= 5 else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                Task {
                    do {
                        _ = try await viewModel.joinSession(code: code)
                        joinCode = ""
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
            } label: {
                let ready = joinCode.trimmingCharacters(in: .whitespaces).count >= 5
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(ready ? Theme.Colors.accent : Theme.Colors.textMuted)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: ready)
            }
            .buttonStyle(SpringTapStyle(scaleAmount: 0.88))
            .disabled(joinCode.trimmingCharacters(in: .whitespaces).count < 5)
            .padding(.trailing, 8)
        }
        .background(Theme.Colors.background)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.Colors.border, lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Main scroll

    private var mainScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                joinBar
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 20)

                if !viewModel.activeSessions.isEmpty {
                    SectionHeader(title: "Circles")
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)

                    VStack(spacing: 14) {
                        ForEach(Array(viewModel.activeSessions.enumerated()), id: \.element.id) { idx, session in
                            CircleCard(session: session, viewModel: viewModel)
                                .padding(.horizontal, 16)
                                .opacity(listVisible ? 1 : 0)
                                .offset(y: listVisible ? 0 : 22)
                                .animation(
                                    reduceMotion ? .none :
                                        .spring(response: 0.5, dampingFraction: 0.82)
                                        .delay(Double(idx) * 0.08),
                                    value: listVisible
                                )
                        }
                    }
                }

                Spacer().frame(height: 40)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 0) {
            joinBar
                .padding(.horizontal, 16)
                .padding(.top, 14)

            Spacer()

            VStack(spacing: Theme.Spacing.xl) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.accentTint)
                        .frame(width: 106, height: 106)
                    Image(systemName: "person.3.sequence.fill")
                        .font(.system(size: 38))
                        .foregroundColor(Theme.Colors.accent)
                }

                VStack(spacing: Theme.Spacing.sm) {
                    Text("No circles yet")
                        .font(Theme.Typography.title)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("Start one and everyone's photos\nfind their way to the whole crew.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
            }

            Spacer().frame(height: Theme.Spacing.xxl)

            Button { viewModel.showStartSheet = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("Start your first circle")
                        .font(Theme.Typography.label)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Theme.Colors.accent)
                .clipShape(Capsule())
                .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 16, x: 0, y: 6)
            }
            .buttonStyle(SpringTapStyle(scaleAmount: 0.97))
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

#Preview {
    SessionsView()
}
