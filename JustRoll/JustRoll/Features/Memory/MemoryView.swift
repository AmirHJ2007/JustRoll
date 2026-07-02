import SwiftUI

struct MemoryView: View {
    private let service: any SupabaseServiceProtocol
    @State private var sessions: [Session] = []
    @State private var isLoading = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(service: any SupabaseServiceProtocol = MockSupabaseService.shared) {
        self.service = service
    }

    private var pastSessions: [Session] {
        sessions
            .filter { $0.status == .ended }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Theme.Colors.surface.ignoresSafeArea()
                VStack(spacing: 0) {
                    PageHeader(title: headerTitle, subtitle: headerSubtitle)
                    if isLoading && sessions.isEmpty {
                        Spacer()
                        FilmReelSpinner()
                        Spacer()
                    } else if pastSessions.isEmpty {
                        emptyState
                    } else {
                        rollList
                    }
                }
            }
            .navigationBarHidden(true)
            .task { await load() }
        }
    }

    // MARK: - Header subtitle

    private var headerTitle: String {
        if let name = service.currentUser?.name.components(separatedBy: " ").first, !name.isEmpty {
            return "\(name)'s Memory"
        }
        return "Memory"
    }

    private var headerSubtitle: String? {
        guard !pastSessions.isEmpty else { return nil }
        return pastSessions.count == 1 ? "1 roll" : "\(pastSessions.count) rolls"
    }

    // MARK: - Roll list

    private var rollList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Array(pastSessions.enumerated()), id: \.element.id) { idx, session in
                    MemoryRollCard(session: session)
                        .padding(.horizontal, 16)
                        .opacity(isLoading ? 0.5 : 1)
                        .animation(.easeInOut(duration: 0.2), value: isLoading)
                }
                Spacer().frame(height: 28)
            }
            .padding(.top, 14)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.Colors.accentTint)
                    .frame(width: 106, height: 106)
                Image(systemName: "film.stack")
                    .font(.system(size: 40))
                    .foregroundColor(Theme.Colors.accent)
            }
            VStack(spacing: Theme.Spacing.sm) {
                Text("No memories yet")
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("When a circle ends, it lands here.\nYour rolls, your people, all in one place.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            Spacer()
        }
        .padding(.horizontal, 36)
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        sessions = (try? await service.fetchSessions()) ?? []
        isLoading = false
    }
}

// MARK: - Memory roll card

private struct MemoryRollCard: View {
    let session: Session

    private var memberNames: String {
        let others = session.members.filter { $0.leftAt != nil || true }
        let names = others.prefix(3).map { $0.name.components(separatedBy: " ").first ?? $0.name }
        let rest = others.count - names.count
        var result = names.joined(separator: ", ")
        if rest > 0 { result += " +\(rest)" }
        return result
    }

    private var duration: String {
        guard let first = session.members.map(\.joinedAt).min(),
              let last  = session.members.compactMap(\.leftAt).max() else { return "" }
        let mins = Int(last.timeIntervalSince(first) / 60)
        if mins < 60 { return "\(mins)m" }
        let h = mins / 60; let m = mins % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    var body: some View {
        HStack(spacing: 16) {
            // Film frame icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.Colors.accentTint)
                    .frame(width: 52, height: 52)
                Image(systemName: "film.stack.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Theme.Colors.accent)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(session.name.isEmpty ? "Untitled roll" : session.name)
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textMuted)
                    Text(memberNames)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text(session.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                    if !duration.isEmpty {
                        Text("·")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                        Text(duration)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.Colors.textMuted)
        }
        .padding(16)
        .background(Theme.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.Colors.border, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    MemoryView()
}
