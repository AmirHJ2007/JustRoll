import SwiftUI

// MARK: - MemberAvatar

struct MemberAvatar: View {
    let member: SessionMember
    var isCurrentUserRolling: Bool = false  // local override from CircleCard's @State
    @State private var appeared = false

    private static let avatarSize: CGFloat = 64
    private static let dotSize:    CGFloat = 14

    private var dotColor: Color {
        // Rolling state takes priority — if you're rolling you're clearly still in the session
        if member.isRolling || isCurrentUserRolling { return Color(hex: 0x50C878) }
        if !member.isActive { return Theme.Colors.textMuted.opacity(0.5) }
        return Theme.Colors.textMuted.opacity(0.45)
    }

    var body: some View {
        VStack(spacing: 7) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(name: member.name, size: Self.avatarSize)

                Circle()
                    .fill(dotColor)
                    .frame(width: Self.dotSize, height: Self.dotSize)
                    .overlay(Circle().stroke(Theme.Colors.background, lineWidth: 2.5))
                    .scaleEffect(appeared ? 1 : 0.2)
                    .animation(.spring(response: 0.4, dampingFraction: 0.55), value: dotColor)
            }
            Text(firstName(member.name))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Theme.Colors.textSecondary)
                .lineLimit(1)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
        }
    }

    private func firstName(_ name: String) -> String {
        String(name.split(separator: " ").first ?? Substring(name))
    }
}

// MARK: - ElapsedTimerLabel

struct ElapsedTimerLabel: View {
    let startDate: Date

    var body: some View {
        TimelineView(.periodic(from: startDate, by: 1.0)) { ctx in
            Text(elapsed(from: startDate, to: ctx.date))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(Theme.Colors.accent)
                .contentTransition(.numericText())
        }
    }

    private func elapsed(from start: Date, to now: Date) -> String {
        let s = max(0, Int(now.timeIntervalSince(start)))
        let h = s / 3600; let m = (s % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return String(format: "%d:%02d", m, s % 60)
    }
}

// MARK: - CircleCountdownView

struct CircleCountdownView: View {
    let startDate: Date
    private let totalSeconds = 300
    var onExpire: () -> Void
    @State private var fired = false

    var body: some View {
        TimelineView(.periodic(from: startDate, by: 1.0)) { ctx in
            let elapsed  = max(0, Int(ctx.date.timeIntervalSince(startDate)))
            let remaining = max(0, totalSeconds - elapsed)
            let fraction = CGFloat(remaining) / CGFloat(totalSeconds)
            countdownFace(remaining: remaining, fraction: fraction)
                .onChange(of: remaining) { _, r in
                    if r == 0 && !fired { fired = true; onExpire() }
                }
        }
    }

    @ViewBuilder
    private func countdownFace(remaining: Int, fraction: CGFloat) -> some View {
        let urgent = fraction <= 0.33
        ZStack {
            Circle()
                .stroke(Theme.Colors.border, lineWidth: 2.5)
                .frame(width: 50, height: 50)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    urgent ? Theme.Colors.danger : Theme.Colors.accent,
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 50, height: 50)
                .animation(.linear(duration: 1), value: fraction)
            Text(timeStr(remaining))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(urgent ? Theme.Colors.danger : Theme.Colors.textSecondary)
        }
    }

    private func timeStr(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
}

// MARK: - InviteCodePanel

struct InviteCodePanel: View {
    let code: String
    @State private var codeStartDate = Date()
    @State private var expired = false
    @State private var copied = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Invite code")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.Colors.textMuted)

                if expired {
                    Button {
                        codeStartDate = Date()
                        withAnimation(.spring(response: 0.3)) { expired = false }
                    } label: {
                        Text("Generate new code")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.Colors.accent)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        UIPasteboard.general.string = code
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3)) { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { copied = false }
                        }
                    } label: {
                        HStack(spacing: 9) {
                            Text(copied ? "Copied!" : code)
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .tracking(copied ? 0 : 3.5)
                                .foregroundColor(copied ? Theme.Colors.accent : Theme.Colors.textPrimary)
                            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(copied ? Theme.Colors.accent : Theme.Colors.textMuted)
                        }
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.25), value: copied)
                }
            }

            Spacer()

            if !expired {
                CircleCountdownView(startDate: codeStartDate, onExpire: {
                    withAnimation { expired = true }
                })
                .id(codeStartDate)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.Colors.border, lineWidth: 0.5)
        )
        .transition(
            reduceMotion
                ? .opacity
                : .asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal:   .opacity.combined(with: .move(edge: .top))
                )
        )
    }
}

// MARK: - CircleCard

struct CircleCard: View {
    let session: Session
    var viewModel: SessionsViewModel

    @State private var isRolling: Bool
    @State private var myUserId: String?
    @State private var showInviteCode = false
    @State private var showDeleteAlert = false
    @State private var showStopDisposableAlert = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var showCodeOnAppear: Bool = false

    init(session: Session, viewModel: SessionsViewModel, showCodeOnAppear: Bool = false) {
        self.session = session
        self.viewModel = viewModel
        self._isRolling = State(initialValue: session.status == .active)
        self.showCodeOnAppear = showCodeOnAppear
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
                .padding(.horizontal, 16)
                .padding(.top, 16)

            memberRow
                .padding(.top, 14)

            Rectangle()
                .fill(Theme.Colors.border)
                .frame(height: 0.5)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            actionRow
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, showInviteCode ? 10 : 16)

            if showInviteCode {
                InviteCodePanel(code: session.code)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)
            }
        }
        .background(Theme.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    isRolling ? Theme.Colors.accent.opacity(0.28) : Theme.Colors.border,
                    lineWidth: isRolling ? 1.5 : 0.5
                )
        )
        .shadow(
            color: isRolling ? Theme.Colors.accent.opacity(0.15) : Color.black.opacity(0.04),
            radius: isRolling ? 18 : 6,
            x: 0, y: isRolling ? 5 : 2
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: isRolling)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: showInviteCode)
        .onAppear {
            if showCodeOnAppear { showInviteCode = true }
            myUserId = viewModel.currentUserId
        }
        .alert("Delete circle?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteSession(session) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(session.displayName)\" will be removed for everyone. This can't be undone.")
        }
        .alert("Stop and delete circle?", isPresented: $showStopDisposableAlert) {
            Button("Stop & Delete", role: .destructive) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.7)) { isRolling = false }
                Task { await viewModel.leaveSession(session) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Stopping a disposable circle deletes it for everyone.")
        }
    }

    // MARK: Card header

    private var creatorLine: String {
        if session.creatorId == viewModel.currentUserId {
            return "You made this circle"
        }
        if let creator = session.members.first(where: { $0.id == session.creatorId }) {
            return "\(creator.name.components(separatedBy: " ").first ?? creator.name) made this circle"
        }
        return ""
    }

    private var cardHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayName)
                    .font(Theme.Typography.heading)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)

                if !creatorLine.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 9, weight: .semibold))
                        Text(creatorLine)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(Theme.Colors.textMuted)
                }

                if session.kind == .disposable {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("Disposable")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(Color(hex: 0xE07B39))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: 0xE07B39).opacity(0.12))
                    .clipShape(Capsule())
                }
            }

            Spacer()

            if isRolling {
                HStack(spacing: 6) {
                    LivePulseDot()
                    ElapsedTimerLabel(startDate: session.createdAt)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.Colors.accentTint)
                .clipShape(Capsule())
                .transition(.scale(scale: 0.78).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.72), value: isRolling)
    }

    // MARK: Member row

    @ViewBuilder
    private var memberRow: some View {
        let members = session.members
        if members.count <= 4 {
            // Spread evenly across the full card width
            HStack(spacing: 0) {
                ForEach(members) { member in
                    MemberAvatar(
                        member: member,
                        isCurrentUserRolling: isRolling && member.id == myUserId
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        } else {
            // Too many to spread — scroll horizontally
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(members) { member in
                        MemberAvatar(
                            member: member,
                            isCurrentUserRolling: isRolling && member.id == myUserId
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: Action row

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button { toggleRolling() } label: {
                HStack(spacing: 7) {
                    Image(systemName: isRolling ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 16))
                    Text(isRolling ? "Stop rolling" : "Start rolling")
                        .font(Theme.Typography.label)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(isRolling ? Theme.Colors.danger : Theme.Colors.accent)
                .clipShape(Capsule())
                .animation(.spring(response: 0.36, dampingFraction: 0.72), value: isRolling)
            }
            .buttonStyle(SpringTapStyle(scaleAmount: 0.96))

            Button {
                withAnimation(reduceMotion ? .none : .spring(response: 0.42, dampingFraction: 0.78)) {
                    showInviteCode.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: showInviteCode ? "xmark" : "key.fill")
                        .font(.system(size: showInviteCode ? 11 : 12, weight: .semibold))
                    Text(showInviteCode ? "Hide" : "Code")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .foregroundColor(Theme.Colors.accent)
                .padding(.horizontal, 16)
                .frame(height: 46)
                .background(Theme.Colors.accentTint)
                .clipShape(Capsule())
                .animation(.easeInOut(duration: 0.15), value: showInviteCode)
            }
            .buttonStyle(SpringTapStyle(scaleAmount: 0.92))

            if session.kind == .lasting {
                Button { showDeleteAlert = true } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Theme.Colors.danger)
                        .frame(width: 46, height: 46)
                        .background(Theme.Colors.danger.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(SpringTapStyle(scaleAmount: 0.88))
            }
        }
    }

    // MARK: Rolling toggle

    private func toggleRolling() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if isRolling {
            if session.kind == .disposable {
                showStopDisposableAlert = true
            } else {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.7)) { isRolling = false }
                Task { await viewModel.stopRolling(session) }
            }
        } else {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.7)) { isRolling = true }
            Task { await viewModel.startRolling(session) }
        }
    }
}

// MARK: - PastCircleRow

struct PastCircleRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayName)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.Colors.textSecondary)
                let count = session.members.count
                Text("\(count) \(count == 1 ? "person" : "people") · \(relativeDate(session.createdAt))")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(Theme.Colors.textMuted)
            }
            Spacer()
            AvatarCluster(names: session.members.map(\.name), size: 24, maxVisible: 3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Theme.Colors.background.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.Colors.border.opacity(0.6), lineWidth: 0.5)
        )
    }

    private func relativeDate(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: d, relativeTo: Date())
    }
}
