import SwiftUI

struct StartRollSheet: View {
    var viewModel: SessionsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Step state

    private enum Step: Int, Equatable {
        case kind = 0    // pick disposable / lasting
        case name = 1    // give it a name (optional)
        case reveal = 2  // hero code reveal
    }

    @State private var step: Step = .kind
    @State private var selectedKind: SessionKind? = nil
    @State private var sessionName = ""
    @State private var namePlaceholder = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var createdSession: Session?
    @State private var codeCopied = false
    @State private var showNearby = false
    @FocusState private var nameFocused: Bool

    // MARK: - Friend picker state (disabled — re-enable with contacts feature)
    // @State private var contacts: [Contact] = []
    // @State private var selectedIds: Set<String>
    // @State private var searchText = ""

    private static let disposablePlaceholders = [
        "Friday night", "Beach day", "Taco Tuesday", "Rooftop thing", "Birthday chaos"
    ]
    private static let lastingPlaceholders = [
        "The Crew", "Sunday Squad", "Roomies", "The Usual Suspects", "Coffee Club"
    ]

    private var stepAnimation: Animation? {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.82)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Group {
                switch step {
                case .kind:   kindStep
                case .name:   nameStep
                case .reveal: revealStep
                }
            }
            .transition(
                reduceMotion ? .opacity :
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal:   .opacity.combined(with: .move(edge: .leading))
                    )
            )
            .animation(stepAnimation, value: step)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isLoading)
        .fullScreenCover(isPresented: $showNearby) {
            NearbyDiscoveryView(
                currentUserName: viewModel.currentUser?.name ?? "Me",
                currentUserUsername: viewModel.currentUser?.username ?? "",
                currentUserAvatarId: viewModel.currentUser?.avatarId,
                sessionCode: createdSession?.code,
                sessionDisplayName: createdSession?.displayName,
                onConfirm: { selectedPeople in
                    guard let sessionId = createdSession?.id else { return }
                    let usernames = selectedPeople.map(\.username)
                    Task { await viewModel.inviteMembersToSession(sessionId: sessionId, usernames: usernames) }
                }
            )
        }
        .onChange(of: showNearby) { _, isShowing in
            // After radar closes (session already created), advance to the code reveal.
            if !isShowing, createdSession != nil, step == .name {
                withAnimation(stepAnimation) { step = .reveal }
            }
        }
        // .task { await loadContacts() }  // contacts feature disabled
    }

    // MARK: - Top bar (progress dots + close / back)

    private var topBar: some View {
        ZStack {
            progressDots

            HStack {
                Spacer()
                Button {
                    if step == .name {
                        nameFocused = false
                        withAnimation(stepAnimation) {
                            step = .kind
                            sessionName = ""
                            errorMessage = nil
                        }
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: step == .name ? "chevron.left" : "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.Colors.textMuted)
                        .frame(width: 34, height: 34)
                        .background(Theme.Colors.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(SpringTapStyle(scaleAmount: 0.88))
                .disabled(isLoading)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i <= step.rawValue ? Theme.Colors.accent : Theme.Colors.border)
                    .frame(width: i == step.rawValue ? 20 : 6, height: 6)
            }
        }
        .animation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.8), value: step)
    }

    // MARK: - Step 1 · Pick the kind

    private var kindStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Start a circle")
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("What kind of hangout is this?")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 24)

            VStack(spacing: 14) {
                kindCard(
                    kind: .disposable,
                    icon: "bolt.fill",
                    iconColor: Color(hex: 0xE07B39),
                    title: "Disposable",
                    subtitle: "One night only — gone in 24h."
                )
                kindCard(
                    kind: .lasting,
                    icon: "person.3.fill",
                    iconColor: Theme.Colors.accent,
                    title: "Lasting",
                    subtitle: "A circle that sticks around."
                )
            }
            .padding(.horizontal, 20)

            Spacer()

            continueButton(title: "Next", enabled: selectedKind != nil) {
                advanceToName()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private func kindCard(kind: SessionKind, icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        let selected = selectedKind == kind
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.32, dampingFraction: 0.62)) {
                selectedKind = kind
            }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(selected ? 0.18 : 0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.system(size: 23))
                        .foregroundColor(iconColor)
                        .symbolEffect(.bounce, value: selected)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .stroke(selected ? Theme.Colors.accent : Theme.Colors.border, lineWidth: selected ? 0 : 1.5)
                        .frame(width: 24, height: 24)
                    if selected {
                        Circle()
                            .fill(Theme.Colors.accent)
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                    }
                }
            }
            .padding(20)
            .background(selected ? Theme.Colors.accentTint : Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        selected ? Theme.Colors.accent : Theme.Colors.border,
                        lineWidth: selected ? 2 : 0.5
                    )
            )
            .shadow(
                color: selected ? Theme.Colors.accent.opacity(0.22) : .clear,
                radius: 12, x: 0, y: 5
            )
            .scaleEffect(selected && !reduceMotion ? 1.02 : 1)
        }
        .buttonStyle(SpringTapStyle(scaleAmount: 0.96))
    }

    // MARK: - Step 2 · Name it

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(selectedKind == .lasting ? "Name your crew" : "Name the night")
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(selectedKind == .lasting
                     ? "Something the whole crew will recognise."
                     : "Totally optional — \"\(namePlaceholder)\" works fine.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 28)

            TextField("Give it a name…", text: $sessionName)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.Colors.textPrimary)
                .tint(Theme.Colors.accent)
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(nameFocused ? Theme.Colors.accent : Theme.Colors.border,
                                lineWidth: nameFocused ? 1.5 : 0.5)
                        .animation(.easeInOut(duration: 0.15), value: nameFocused)
                )
                .padding(.horizontal, 20)
                .focused($nameFocused)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit { Task { await handleCreate() } }

            HStack(spacing: 5) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 11, weight: .medium))
                Text("Try \"\(namePlaceholder)\" — or leave it blank.")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
            }
            .foregroundColor(Theme.Colors.textMuted)
            .padding(.horizontal, 24)
            .padding(.top, 10)

            if let msg = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .medium))
                    Text(msg)
                        .font(Theme.Typography.caption)
                }
                .foregroundColor(Theme.Colors.danger)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .transition(.opacity)
            }

            Spacer()

            VStack(spacing: 12) {
                RollButton(
                    title: sessionName.trimmingCharacters(in: .whitespaces).isEmpty
                        ? "Create circle" : "Create \"\(sessionName.trimmingCharacters(in: .whitespaces))\"",
                    isLoading: isLoading
                ) {
                    Task { await handleCreate() }
                }

                // MARK: People-around shortcut (creates, then opens nearby discovery)
                Button { Task { await handleCreate(then: .nearby) } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sensor.tag.radiowaves.forward.fill")
                            .font(.system(size: 13, weight: .medium))
                        Text("Create & tap in with people around")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(Theme.Colors.accent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SpringTapStyle(scaleAmount: 0.97))
                .disabled(isLoading)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Step 3 · Code reveal (the payoff)

    private var revealStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            if let session = createdSession {
                VStack(spacing: 8) {
                    Text("Your circle is live!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text(session.displayName)
                        .font(Theme.Typography.handwritten(size: 22))
                        .foregroundColor(Theme.Colors.accent)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 6)
                        .background(Theme.Colors.accentTint)
                        .clipShape(Capsule())
                }

                Spacer(minLength: 16)

                // MARK: Hero code — staggered pop-in, tap to copy, sparkle accents
                VStack(spacing: 14) {
                    Text("SHARE THIS CODE")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(Theme.Colors.textMuted)

                    Button {
                        UIPasteboard.general.string = session.code
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3)) { codeCopied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { codeCopied = false }
                        }
                    } label: {
                        HStack(spacing: 9) {
                            ForEach(Array(session.code.enumerated()), id: \.offset) { i, char in
                                RevealCodeBox(character: char, delay: 0.35 + Double(i) * 0.12)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .topTrailing) {
                        SparkleAccent(size: 16, delay: 1.05, xOffset: 22, yOffset: -18)
                    }
                    .overlay(alignment: .bottomLeading) {
                        SparkleAccent(size: 12, delay: 1.2, xOffset: -20, yOffset: 14)
                    }
                    .overlay(alignment: .topLeading) {
                        SparkleAccent(size: 10, delay: 1.35, xOffset: -14, yOffset: -12)
                    }

                    HStack(spacing: 5) {
                        Image(systemName: codeCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.system(size: 11, weight: .medium))
                        Text(codeCopied ? "Copied!" : "Tap the code to copy")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(codeCopied ? Theme.Colors.accent : Theme.Colors.textMuted)
                    .animation(.spring(response: 0.25), value: codeCopied)
                }

                Spacer(minLength: 16)

                Text("Friends type it in on their Circles page\nand they're on the roll.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Spacer(minLength: 20)

                VStack(spacing: 12) {
                    // MARK: Share button — matches InviteCodePanel style
                    ShareLink(
                        item: "Join my circle \"\(session.displayName)\" on JustRoll! Code: \(session.code) — https://justroll.app/join/\(session.code)"
                    ) {
                        HStack(spacing: 7) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .bold))
                            Text("Share")
                                .font(Theme.Typography.label)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Theme.Colors.accent)
                        .clipShape(Capsule())
                        .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 16, x: 0, y: 6)
                    }
                    .buttonStyle(SpringTapStyle(scaleAmount: 0.97))

                    Button { showNearby = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sensor.tag.radiowaves.forward.fill")
                                .font(.system(size: 13, weight: .medium))
                            Text("They're right here? Tap in nearby")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(Theme.Colors.accent)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Theme.Colors.accentTint)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.Colors.accent.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(SpringTapStyle(scaleAmount: 0.97))

                    Button { dismiss() } label: {
                        Text("Done")
                            .font(Theme.Typography.label)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(SpringTapStyle(scaleAmount: 0.97))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            // Success haptic timed to land as the last character pops in
            let delay = reduceMotion ? 0.1 : 0.85
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    // MARK: - Shared controls

    private func continueButton(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.label)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Theme.Colors.accent.opacity(enabled ? 1 : 0.35))
                .clipShape(Capsule())
                .shadow(color: Theme.Colors.accent.opacity(enabled ? 0.3 : 0), radius: 16, x: 0, y: 6)
        }
        .buttonStyle(SpringTapStyle(scaleAmount: 0.97))
        .disabled(!enabled)
        .animation(.easeInOut(duration: 0.2), value: enabled)
    }

    // MARK: - Navigation + create

    private func advanceToName() {
        guard let kind = selectedKind else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let pool = kind == .lasting ? Self.lastingPlaceholders : Self.disposablePlaceholders
        namePlaceholder = pool.randomElement() ?? pool[0]
        withAnimation(stepAnimation) { step = .name }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { nameFocused = true }
    }

    private enum NextAction { case reveal, nearby }

    private func handleCreate(then next: NextAction = .reveal) async {
        guard let kind = selectedKind, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let session = try await viewModel.createSession(
                name: sessionName.trimmingCharacters(in: .whitespaces),
                kind: kind,
                invitedContacts: []  // contacts feature disabled
            )
            isLoading = false
            nameFocused = false
            createdSession = session
            switch next {
            case .nearby:
                showNearby = true
            case .reveal:
                withAnimation(stepAnimation) { step = .reveal }
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    // MARK: - Friend picker (disabled — re-enable with contacts feature)
    //
    // private var filteredContacts: [Contact] { ... }
    // private var friendPickerView: some View { ... }
    // private func loadContacts() async { ... }
}

// MARK: - RevealCodeBox (single hero character, staggered pop-in)

private struct RevealCodeBox: View {
    let character: Character
    let delay: Double
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(String(character))
            .font(.system(size: 30, weight: .bold, design: .monospaced))
            .foregroundColor(Theme.Colors.textPrimary)
            .frame(width: 54, height: 66)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.Colors.background)
                    .shadow(color: Color.black.opacity(0.07), radius: 5, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.Colors.accent.opacity(0.55), lineWidth: 1.4)
            )
            .scaleEffect(shown ? 1 : 0.3)
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 10)
            .onAppear {
                if reduceMotion {
                    withAnimation(.easeIn(duration: 0.2).delay(delay * 0.3)) { shown = true }
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.55).delay(delay)) { shown = true }
                }
            }
    }
}

// MARK: - SparkleAccent (tasteful pop + gentle pulse around the code)

private struct SparkleAccent: View {
    let size: CGFloat
    let delay: Double
    var xOffset: CGFloat = 0
    var yOffset: CGFloat = 0
    @State private var shown = false
    @State private var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .medium))
            .foregroundColor(Theme.Colors.accent.opacity(0.75))
            .scaleEffect(shown ? (pulsing ? 1.15 : 0.9) : 0.1)
            .opacity(shown ? (pulsing ? 1 : 0.55) : 0)
            .offset(x: xOffset, y: yOffset)
            .allowsHitTesting(false)
            .onAppear {
                if reduceMotion {
                    shown = true
                    return
                }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(delay)) {
                    shown = true
                }
                withAnimation(
                    .easeInOut(duration: 1.4).repeatForever(autoreverses: true).delay(delay + 0.4)
                ) {
                    pulsing = true
                }
            }
    }
}
