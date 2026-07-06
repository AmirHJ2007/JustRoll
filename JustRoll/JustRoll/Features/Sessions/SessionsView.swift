import SwiftUI

extension Notification.Name {
    static let sessionListNeedsRefresh = Notification.Name("sessionListNeedsRefresh")
}

struct SessionsView: View {
    @State private var viewModel: SessionsViewModel
    @State private var listVisible = false
    @State private var joinCode = ""
    @State private var otpShakeTrigger: Int = 0
    @State private var celebrationSession: Session? = nil
    @State private var showCelebration: Bool = false
    @State private var emptyRollSession: Session? = nil
    @State private var showEmptyRoll: Bool = false
    @FocusState private var otpFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var onRequestReview: ((String) -> Void)? = nil

    init(service: any SupabaseServiceProtocol = MockSupabaseService.shared,
         onRequestReview: ((String) -> Void)? = nil) {
        self._viewModel = State(initialValue: SessionsViewModel(service: service))
        self.onRequestReview = onRequestReview
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

                // MARK: Full-screen celebration overlay
                if showCelebration, let session = celebrationSession {
                    CelebrationOverlay(
                        sessionName: session.displayName,
                        isVisible: $showCelebration
                    )
                    .zIndex(10)
                    .ignoresSafeArea()
                }

                // MARK: Empty-roll overlay (zero photos found after stop rolling)
                if showEmptyRoll, let session = emptyRollSession {
                    EmptyRollOverlay(
                        sessionName: session.displayName,
                        isVisible: $showEmptyRoll
                    )
                    .zIndex(11)
                    .ignoresSafeArea()
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.load()
                withAnimation(reduceMotion ? .none : .spring(response: 0.45)) {
                    listVisible = true
                }
            }
            // Reload every time the tab reappears (e.g. switching back from another tab)
            // so member lists / rolling state don't go stale. `load()` no-ops while an
            // existing load is in flight and the loading spinner only shows when the
            // list is empty, so this stays silent when data is already on screen.
            .onAppear {
                Task { await viewModel.load() }
            }
            // Reload when the app returns to the foreground for the same reason.
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await viewModel.load() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .sessionListNeedsRefresh)) { _ in
                Task { await viewModel.load() }
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

    // MARK: - OTP Join Bar

    private var otpJoinBar: some View {
        VStack(spacing: 10) {
            // 5 individual character boxes
            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { i in
                    let char: Character? = i < joinCode.count
                        ? joinCode[joinCode.index(joinCode.startIndex, offsetBy: i)]
                        : nil
                    OTPCodeBox(
                        character: char,
                        isActive: i == joinCode.count && otpFocused
                    )
                }
            }
            // Shake keyframe applied to the whole row on error
            .keyframeAnimator(initialValue: CGFloat(0), trigger: otpShakeTrigger) { content, offset in
                content.offset(x: offset)
            } keyframes: { _ in
                LinearKeyframe(CGFloat(0),   duration: 0.04)
                CubicKeyframe(CGFloat(-9),   duration: 0.08)
                CubicKeyframe(CGFloat(9),    duration: 0.08)
                CubicKeyframe(CGFloat(-6),   duration: 0.07)
                CubicKeyframe(CGFloat(6),    duration: 0.07)
                CubicKeyframe(CGFloat(-3),   duration: 0.06)
                CubicKeyframe(CGFloat(0),    duration: 0.06)
            }
            // Hidden TextField drives the boxes
            .overlay {
                TextField("", text: $joinCode)
                    .foregroundColor(.clear)
                    .tint(.clear)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.characters)
                    .disableAutocorrection(true)
                    .focused($otpFocused)
                    .onChange(of: joinCode) { _, new in
                        let cleaned = String(
                            new.uppercased()
                                .filter { $0.isLetter || $0.isNumber }
                                .prefix(5)
                        )
                        joinCode = cleaned
                        if cleaned.count == 5 { attemptJoin() }
                    }
            }
            .onTapGesture { otpFocused = true }

            // Subtle hint line
            HStack(spacing: 4) {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 11, weight: .medium))
                Text("Enter a 5-character code to join a circle")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
            }
            .foregroundColor(Theme.Colors.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 20)
    }

    private func attemptJoin() {
        let code = joinCode.trimmingCharacters(in: .whitespaces)
        guard code.count >= 5 else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        otpFocused = false
        Task {
            do {
                _ = try await viewModel.joinSession(code: code)
                joinCode = ""
            } catch {
                otpShakeTrigger += 1
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    joinCode = ""
                }
            }
        }
    }

    // MARK: - Main scroll

    private var mainScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                otpJoinBar

                if !viewModel.activeSessions.isEmpty {
                    // Capture ordered IDs for the reorder animation
                    let orderedIds = viewModel.activeSessions.map(\.id)

                    VStack(spacing: 14) {
                        ForEach(Array(viewModel.activeSessions.enumerated()), id: \.element.id) { idx, session in
                            CircleCard(
                                session: session,
                                viewModel: viewModel,
                                onRollingStarted: { s in
                                    celebrationSession = s
                                    showCelebration = true
                                },
                                onRollingStoppedEmpty: { s in
                                    // If a celebration is showing, dismiss it first rather than
                                    // silently dropping the "Blank roll!" feedback.
                                    if showCelebration {
                                        withAnimation(
                                            reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.85)
                                        ) {
                                            showCelebration = false
                                        }
                                    }
                                    emptyRollSession = s
                                    showEmptyRoll = true
                                },
                                onRollingStoppedNonEmpty: { s in onRequestReview?(s.id) }
                            )
                            .padding(.horizontal, 16)
                            // Initial stagger-in appearance
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
                    // Reorder animation: cards glide to new positions when order changes
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8),
                        value: orderedIds
                    )
                }

                Spacer().frame(height: 40)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 0) {
            otpJoinBar

            Spacer()

            VStack(spacing: Theme.Spacing.xl) {
                CirclesEmptyAnimation()

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

// MARK: - CirclesEmptyAnimation (same motion as the Unsent empty state)

private struct CirclesEmptyAnimation: View {
    @State private var floating = false
    @State private var sparkle1 = false
    @State private var sparkle2 = false
    @State private var sparkle3 = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            sparkleView(offset: CGSize(width: -52, height: -30), visible: sparkle1)
            sparkleView(offset: CGSize(width: 54, height: -38), visible: sparkle2)
            sparkleView(offset: CGSize(width: 46, height: 28),  visible: sparkle3)

            ZStack {
                Circle()
                    .fill(Theme.Colors.accentTint)
                    .frame(width: 106, height: 106)
                Image(systemName: "person.3.sequence.fill")
                    .font(.system(size: 38))
                    .foregroundColor(Theme.Colors.accent)
            }
            .offset(y: floating ? -8 : 0)
            .shadow(color: Theme.Colors.accent.opacity(0.18), radius: floating ? 18 : 8, x: 0, y: floating ? 10 : 4)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { floating = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(0.0)) { sparkle1 = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(0.4)) { sparkle2 = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(0.8)) { sparkle3 = true }
        }
    }

    private func sparkleView(offset: CGSize, visible: Bool) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(Theme.Colors.accent.opacity(visible ? 0.8 : 0.2))
            .scaleEffect(visible ? 1 : 0.5)
            .offset(offset)
    }
}

// MARK: - OTPCodeBox

private struct OTPCodeBox: View {
    let character: Character?
    var isActive: Bool = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.Colors.background)
                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isActive
                        ? Theme.Colors.accent
                        : (character != nil ? Theme.Colors.accent.opacity(0.6) : Color(hex: 0x6B716D)),
                    lineWidth: isActive ? 2 : 1.2
                )
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isActive)

            if let char = character {
                Text(String(char))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .scaleEffect(appeared ? 1.0 : 0.3)
                    .animation(.spring(response: 0.25, dampingFraction: 0.5), value: appeared)
            } else if !isActive {
                Text("–")
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: 0x6B716D))
            }
        }
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .onAppear {
            appeared = character != nil
        }
        .onChange(of: character) { _, new in
            if new != nil {
                appeared = false
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                    appeared = true
                }
            } else {
                appeared = false
            }
        }
    }
}

// MARK: - CelebrationOverlay

private struct CelebrationOverlay: View {
    let sessionName: String
    @Binding var isVisible: Bool

    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0
    @State private var message: String = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let messages = [
        "Go make memories 📸",
        "Shoot away — we've got the sharing 🎞️",
        "Camera time! Everyone's photos find their way 🌿"
    ]

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            Theme.Colors.accent.opacity(0.18)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 18) {
                Text(message.isEmpty ? " " : message)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(sessionName)
                    .font(Theme.Typography.handwritten(size: 22))
                    .foregroundColor(Theme.Colors.accent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Theme.Colors.accentTint)
                    .clipShape(Capsule())
            }
            .padding(32)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            message = Self.messages.randomElement() ?? Self.messages[0]
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            if reduceMotion {
                withAnimation(.easeIn(duration: 0.2)) { opacity = 1.0 }
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }

            // Auto-dismiss after ~1.6s
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                if reduceMotion {
                    withAnimation(.easeOut(duration: 0.25)) { opacity = 0 }
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        scale = 0.9
                        opacity = 0
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isVisible = false
                }
            }
        }
    }
}

// MARK: - EmptyRollOverlay

private struct EmptyRollOverlay: View {
    let sessionName: String
    @Binding var isVisible: Bool

    // Animation state — icon, title, and session pill each stagger in
    @State private var iconScale: CGFloat   = 0.25
    @State private var iconRotation: Double = -20
    @State private var iconOpacity: Double  = 0
    @State private var titleOffset: CGFloat = 24
    @State private var titleOpacity: Double = 0
    @State private var pillOpacity: Double  = 0
    @State private var subtitle: String     = ""
    @State private var dismissFired         = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let subtitles = [
        "The roll came back empty — nothing shot this time.",
        "Camera shy? No photos or videos found on this roll.",
        "Blank roll — no shots taken during this one.",
    ]

    var body: some View {
        ZStack {
            // Background: blurred material + bold danger tint (mirrors CelebrationOverlay green tint)
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            Theme.Colors.danger.opacity(0.18)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 20) {
                // MARK: Icon — camera with X badge
                ZStack {
                    Circle()
                        .fill(Theme.Colors.danger.opacity(0.14))
                        .frame(width: 100, height: 100)
                    Circle()
                        .fill(Theme.Colors.danger.opacity(0.09))
                        .frame(width: 70, height: 70)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(Theme.Colors.danger)
                    // X-mark badge in the top-right of the icon
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.white, Theme.Colors.danger)
                        .offset(x: 26, y: -24)
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
                .rotationEffect(.degrees(iconRotation))

                // MARK: Title + subtitle
                VStack(spacing: 8) {
                    Text("Blank roll!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.danger)

                    Text(subtitle.isEmpty ? " " : subtitle)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 8)
                }
                .offset(y: titleOffset)
                .opacity(titleOpacity)

                // MARK: Session name pill (mirrors CelebrationOverlay)
                Text(sessionName)
                    .font(Theme.Typography.handwritten(size: 21))
                    .foregroundColor(Theme.Colors.danger)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Theme.Colors.danger.opacity(0.12))
                    .clipShape(Capsule())
                    .opacity(pillOpacity)
            }
            .padding(32)
        }
        .onTapGesture { triggerDismiss() }
        .onAppear {
            subtitle = Self.subtitles.randomElement() ?? Self.subtitles[0]
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            animateIn()
            // Auto-dismiss after 2.2s — slightly longer than celebration so the message reads
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { triggerDismiss() }
        }
    }

    // MARK: - Animations

    private func animateIn() {
        if reduceMotion {
            iconScale = 1; iconRotation = 0; iconOpacity = 1
            titleOffset = 0; titleOpacity = 1; pillOpacity = 1
            return
        }
        // Icon bounces in with a satisfying overshoot spring
        withAnimation(.spring(response: 0.52, dampingFraction: 0.52)) {
            iconScale    = 1.0
            iconRotation = 0
            iconOpacity  = 1.0
        }
        // Title slides up 120ms later
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72).delay(0.12)) {
            titleOffset  = 0
            titleOpacity = 1.0
        }
        // Session pill fades in last
        withAnimation(.easeOut(duration: 0.3).delay(0.26)) {
            pillOpacity = 1.0
        }
    }

    private func triggerDismiss() {
        guard !dismissFired else { return }
        dismissFired = true

        if reduceMotion {
            withAnimation(.easeOut(duration: 0.22)) {
                iconOpacity = 0; titleOpacity = 0; pillOpacity = 0
            }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                iconScale    = 0.82
                iconOpacity  = 0
                titleOffset  = -12
                titleOpacity = 0
                pillOpacity  = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { isVisible = false }
    }
}

#Preview {
    SessionsView()
}
