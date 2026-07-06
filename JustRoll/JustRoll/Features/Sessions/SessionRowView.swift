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
                AvatarView(name: member.name, size: Self.avatarSize, avatarId: member.avatarId)

                Circle()
                    .fill(dotColor)
                    .frame(width: Self.dotSize, height: Self.dotSize)
                    .overlay(Circle().stroke(Theme.Colors.background, lineWidth: 2.5))
                    .scaleEffect(appeared ? 1 : 0.2)
                    .animation(.spring(response: 0.4, dampingFraction: 0.55), value: dotColor)
            }
            Text(firstName(member.name))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: 0x4A4F4D))
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

// MARK: - CompactMemberBubble (overlapping avatar in CircleCard member row)

private struct CompactMemberBubble: View {
    let member: SessionMember
    var isRolling: Bool
    var index: Int
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let size: CGFloat = 36
    private static let dotSize: CGFloat = 9

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AvatarView(name: member.name, size: Self.size, avatarId: member.avatarId)
                .overlay(Circle().stroke(Theme.Colors.background, lineWidth: 2))

            if isRolling {
                Circle()
                    .fill(Color(hex: 0x50C878))
                    .frame(width: Self.dotSize, height: Self.dotSize)
                    .overlay(Circle().stroke(Theme.Colors.background, lineWidth: 1.5))
                    .scaleEffect(appeared ? 1 : 0.2)
                    .animation(.spring(response: 0.4, dampingFraction: 0.55), value: appeared)
            }
        }
        .scaleEffect(appeared ? 1 : 0.5)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            let delay = reduceMotion ? 0.0 : Double(index) * 0.06
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62).delay(delay)) {
                appeared = true
            }
        }
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

// MARK: - DisposableCountdownBadge

struct DisposableCountdownBadge: View {
    let createdAt: Date
    private let lifetime: TimeInterval = 24 * 3600

    var body: some View {
        TimelineView(.periodic(from: createdAt, by: 60)) { ctx in
            let remaining = max(0, lifetime - ctx.date.timeIntervalSince(createdAt))
            let color = badgeColor(remaining: remaining)
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 9, weight: .bold))
                Text(label(remaining: remaining))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .contentTransition(.numericText())
            .animation(.spring(response: 0.3), value: label(remaining: remaining))
        }
    }

    private func badgeColor(remaining: TimeInterval) -> Color {
        if remaining > 16 * 3600 { return Theme.Colors.accent }           // first 8 h — green
        if remaining > 8  * 3600 { return Color(hex: 0xD4A017) }         // middle 8 h — yellow
        return Theme.Colors.danger                                          // last 8 h — red
    }

    private func label(remaining: TimeInterval) -> String {
        guard remaining > 0 else { return "Expired" }
        let h = Int(remaining) / 3600
        let m = (Int(remaining) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m left" }
        return "\(m)m left"
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
    let sessionName: String
    @State private var copied = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Invite code")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: 0x6B716D))

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
                            .foregroundColor(copied ? Theme.Colors.accent : Color(hex: 0x6B716D))
                    }
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.25), value: copied)
            }

            Spacer()

            ShareLink(
                item: "Join my circle \"\(sessionName)\" on JustRoll! Code: \(code) — https://justroll.app/join/\(code)"
            ) {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .bold))
                    Text("Share")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Theme.Colors.accent)
                .clipShape(Capsule())
                .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(SpringTapStyle(scaleAmount: 0.88))
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
    var onRollingStarted: ((Session) -> Void)? = nil
    /// Called (on main actor) after stop if the rolling window contained zero photos/videos.
    var onRollingStoppedEmpty: ((Session) -> Void)? = nil
    /// Called (on main actor) after stop if the rolling window contained at least one photo/video.
    var onRollingStoppedNonEmpty: ((Session) -> Void)? = nil

    @State private var isRolling: Bool
    @State private var myUserId: String?
    @State private var showInviteCode = false
    @State private var showDeleteAlert = false
    @State private var showAloneAlert = false
    // Glow border animation
    @State private var glowAngle: Double = 0
    // Breathing shadow
    @State private var shadowBreath: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var showCodeOnAppear: Bool = false

    init(session: Session, viewModel: SessionsViewModel, showCodeOnAppear: Bool = false,
         onRollingStarted: ((Session) -> Void)? = nil,
         onRollingStoppedEmpty: ((Session) -> Void)? = nil,
         onRollingStoppedNonEmpty: ((Session) -> Void)? = nil) {
        self.session = session
        self.viewModel = viewModel
        // Seed from MY member row, not the session-wide status — `.active` just means
        // *someone* is rolling, which could be a different member entirely. `viewModel`
        // is @MainActor-isolated and this init is not, so `myUserId` can't be resolved
        // synchronously here (same constraint `toggleRolling` works under) — default to
        // "not rolling" and correct both `myUserId` and `isRolling` together in onAppear,
        // before anything is interactive.
        self._isRolling = State(initialValue: false)
        self.showCodeOnAppear = showCodeOnAppear
        self.onRollingStarted = onRollingStarted
        self.onRollingStoppedEmpty = onRollingStoppedEmpty
        self.onRollingStoppedNonEmpty = onRollingStoppedNonEmpty
    }

    /// The current user's own member row's rolling flag, as last synced from the model.
    /// Used to resync local `isRolling` when the underlying session data changes (e.g.
    /// after a list reload) without fighting the optimistic local toggle.
    private var myMemberIsRolling: Bool {
        session.members.first(where: { $0.id == myUserId })?.isRolling ?? false
    }

    /// When the current user's active rolling window began — drives the "Rolling" badge
    /// timer. Falls back to now so a just-started roll reads 0:00, never the circle's age.
    private var myRollingStartDate: Date {
        session.members.first(where: { $0.id == myUserId })?.rollingStartedAt ?? Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
                .padding(.horizontal, 16)
                .padding(.top, 14)

            memberRow
                .padding(.top, 10)

            Rectangle()
                .fill(Theme.Colors.border)
                .frame(height: 0.5)
                .padding(.horizontal, 16)
                .padding(.top, 10)

            actionRow
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, showInviteCode ? 8 : 14)

            if showInviteCode {
                InviteCodePanel(code: session.code, sessionName: session.displayName)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)
            }
        }
        .background(Theme.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        // Static base border — hairline, fades out when rolling (glow takes over)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    isRolling ? Theme.Colors.accent.opacity(0.18) : Theme.Colors.border,
                    lineWidth: isRolling ? 0.5 : 0.5
                )
        )
        // Animated traveling glow border — rolling state only
        .overlay {
            if isRolling {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear,                               location: 0.0),
                                .init(color: Theme.Colors.accent.opacity(0.45),    location: 0.35),
                                .init(color: Theme.Colors.accent.opacity(0.95),    location: 0.5),
                                .init(color: Theme.Colors.accent.opacity(0.45),    location: 0.65),
                                .init(color: .clear,                               location: 1.0),
                            ]),
                            center: .center,
                            startAngle: .degrees(glowAngle - 60),
                            endAngle: .degrees(glowAngle + 60)
                        ),
                        lineWidth: 2
                    )
                    .transition(.opacity)
            }
        }
        // Breathing shadow
        .shadow(
            color: isRolling
                ? Theme.Colors.accent.opacity(shadowBreath ? 0.24 : 0.10)
                : Color.black.opacity(0.04),
            radius: isRolling ? (shadowBreath ? 22 : 10) : 6,
            x: 0,
            y: isRolling ? (shadowBreath ? 7 : 3) : 2
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: isRolling)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: showInviteCode)
        .onAppear {
            if showCodeOnAppear { showInviteCode = true }
            myUserId = viewModel.currentUserId
            // Now that we know which member row is "me", seed the real rolling state
            // (see the init comment above for why this can't happen synchronously there).
            isRolling = myMemberIsRolling
            updateGlowAnimation()
            updateBreathAnimation()
        }
        .onChange(of: isRolling) { _, _ in
            updateGlowAnimation()
            updateBreathAnimation()
        }
        // Resync local optimistic state if the model changes underneath us (e.g. a
        // silent list reload) — but only when it actually differs, so this doesn't
        // fight the optimistic toggle set at tap time.
        .onChange(of: myMemberIsRolling) { _, newValue in
            if isRolling != newValue { isRolling = newValue }
        }
        .alert("Leave circle?", isPresented: $showDeleteAlert) {
            Button("Leave", role: .destructive) {
                Task { await viewModel.deleteSession(session) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll leave \"\(session.displayName)\". Others in the circle can still use it.")
        }
        .alert("You're the only one here", isPresented: $showAloneAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Invite friends before you start rolling — there's no one to share shots with yet.")
        }
    }

    // MARK: - Animation helpers

    private func updateGlowAnimation() {
        guard !reduceMotion else {
            glowAngle = 0
            return
        }
        if isRolling {
            glowAngle = 0
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                glowAngle = 360
            }
        } else {
            withAnimation(.none) { glowAngle = 0 }
        }
    }

    private func updateBreathAnimation() {
        guard !reduceMotion else {
            shadowBreath = false
            return
        }
        if isRolling {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                shadowBreath = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) { shadowBreath = false }
        }
    }

    // MARK: - Card header

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
                    DisposableCountdownBadge(createdAt: session.createdAt)
                }
            }

            Spacer()

            if isRolling {
                // "● Rolling" badge with pulsing dot + elapsed timer
                HStack(spacing: 6) {
                    LivePulseDot()
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Rolling")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.Colors.accent)
                        ElapsedTimerLabel(startDate: myRollingStartDate)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.Colors.accentTint)
                .clipShape(Capsule())
                .transition(.scale(scale: 0.78).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.72), value: isRolling)
    }

    // MARK: - Member row

    @ViewBuilder
    private var memberRow: some View {
        let members = session.members
        let maxVisible = 5
        let visible = Array(members.prefix(maxVisible))
        let overflow = max(0, members.count - maxVisible)
        let firstNames = members.map { String($0.name.split(separator: " ").first ?? Substring($0.name)) }
        let memberLabel: String = {
            switch firstNames.count {
            case 0:  return ""
            case 1:  return firstNames[0]
            case 2:  return "\(firstNames[0]) & \(firstNames[1])"
            case 3:  return "\(firstNames[0]), \(firstNames[1]) & \(firstNames[2])"
            default: return "\(firstNames[0]), \(firstNames[1]) & \(firstNames.count - 2) more"
            }
        }()

        HStack(alignment: .center, spacing: 8) {
            // Overlapping avatar stack — leftmost avatar sits on top (descending zIndex)
            HStack(spacing: -10) {
                ForEach(Array(visible.enumerated()), id: \.offset) { idx, member in
                    let rolling = member.isRolling || (isRolling && member.id == myUserId)
                    CompactMemberBubble(member: member, isRolling: rolling, index: idx)
                        .zIndex(Double(maxVisible - idx))
                }
                if overflow > 0 {
                    Circle()
                        .fill(Theme.Colors.surface)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(Theme.Colors.background, lineWidth: 2))
                        .overlay(
                            Text("+\(overflow)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(Theme.Colors.textMuted)
                        )
                }
            }

            Text(memberLabel)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(Theme.Colors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

    // MARK: - Action row

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
                    Image(systemName: "rectangle.portrait.and.arrow.right")
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

    // MARK: - Rolling toggle

    private func toggleRolling() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if isRolling {
            // Capture the rolling window BEFORE stopRolling clears / overwrites state
            let windowStart = session.members.first(where: { $0.id == myUserId })?.rollingStartedAt
            let windowStop  = Date()

            withAnimation(.spring(response: 0.38, dampingFraction: 0.7)) { isRolling = false }
            Task {
                let succeeded = await viewModel.stopRolling(session)
                guard succeeded else {
                    // Server call failed — revert the optimistic toggle and bail out
                    // before touching asset counts / celebration callbacks.
                    await MainActor.run {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.7)) { isRolling = true }
                    }
                    return
                }

                // Count assets off the main thread so we never block the UI
                if let start = windowStart {
                    let count = await Task.detached(priority: .userInitiated) {
                        SessionsViewModel.countAssetsInWindow(from: start, to: windowStop)
                    }.value
                    // count == -1 means permission not granted — skip the overlay
                    if count == 0 {
                        await MainActor.run { onRollingStoppedEmpty?(session) }
                    } else if count > 0 {
                        await MainActor.run { onRollingStoppedNonEmpty?(session) }
                    }
                }
            }
        } else {
            guard session.activeMembers.count > 1 else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                showAloneAlert = true
                return
            }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.7)) { isRolling = true }
            onRollingStarted?(session)
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
            AvatarCluster(
                names: session.members.map(\.name), size: 24, maxVisible: 3,
                avatarIds: session.members.map(\.avatarId)
            )
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
