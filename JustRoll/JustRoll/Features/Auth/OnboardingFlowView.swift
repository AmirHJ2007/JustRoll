import SwiftUI
import UIKit

// MARK: - View model

@Observable
@MainActor
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case name, username, avatar, credentials
    }

    var step: Step = .name
    var goingForward = true

    var name = ""
    var username = ""
    var avatarId: Int? = nil
    var email = ""
    var password = ""

    var isLoading = false
    var errorMessage: String?

    private var lastSuggestion = ""
    private let service: any SupabaseServiceProtocol

    init(service: any SupabaseServiceProtocol) {
        self.service = service
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    var trimmedUsername: String {
        username.trimmingCharacters(in: .whitespaces).lowercased()
    }
    var trimmedEmail: String { email.trimmingCharacters(in: .whitespaces) }

    var canContinue: Bool {
        switch step {
        case .name:     return !trimmedName.isEmpty
        case .username: return !trimmedUsername.isEmpty
        case .avatar:   return avatarId != nil
        case .credentials:
            return trimmedEmail.contains("@")
                && trimmedEmail.contains(".")
                && password.count >= 6
        }
    }

    func advance() {
        guard canContinue, let next = Step(rawValue: step.rawValue + 1) else { return }
        if step == .name { suggestUsernameIfNeeded() }
        goingForward = true
        errorMessage = nil
        step = next
    }

    /// Avatar step is skippable — "I'll pick later".
    func skipAvatar() {
        guard step == .avatar else { return }
        avatarId = nil
        goingForward = true
        errorMessage = nil
        step = .credentials
    }

    func goBack() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        goingForward = false
        errorMessage = nil
        step = previous
    }

    /// Returns true if the handle is free to claim. On "taken", sets the inline
    /// error. If the check itself fails (offline etc.) we let the user through —
    /// the DB unique constraint still catches duplicates at sign-up.
    func checkUsernameAvailable() async -> Bool {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            if try await service.isUsernameTaken(trimmedUsername) {
                errorMessage = "@\(trimmedUsername) is already taken. Try another one."
                return false
            }
        } catch {
            return true
        }
        return true
    }

    private func suggestUsernameIfNeeded() {
        let suggestion = trimmedName.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
        // Only overwrite if the user hasn't typed their own handle
        if username.isEmpty || username == lastSuggestion {
            username = suggestion
        }
        lastSuggestion = suggestion
    }

    func createAccount(onSuccess: @escaping (User) -> Void) async {
        errorMessage = nil
        isLoading = true
        do {
            // The one and only place the account is actually created.
            let user = try await service.signUp(
                name: trimmedName,
                username: trimmedUsername,
                email: trimmedEmail,
                password: password,
                avatarId: avatarId
            )
            onSuccess(user)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Onboarding flow (name → username → avatar → credentials)

struct OnboardingFlowView: View {
    let onAuthenticated: (User) -> Void
    let onSignIn: () -> Void

    @State private var vm: OnboardingViewModel
    @FocusState private var focus: Field?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Field: Hashable { case name, username, email, password }

    init(service: any SupabaseServiceProtocol,
         onAuthenticated: @escaping (User) -> Void,
         onSignIn: @escaping () -> Void) {
        self.onAuthenticated = onAuthenticated
        self.onSignIn = onSignIn
        self._vm = State(initialValue: OnboardingViewModel(service: service))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 20)
                .padding(.top, 12)

            ZStack {
                switch vm.step {
                case .name:        nameStep.transition(stepTransition)
                case .username:    usernameStep.transition(stepTransition)
                case .avatar:      avatarStep.transition(stepTransition)
                case .credentials: credentialsStep.transition(stepTransition)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .onAppear { focusCurrentField(after: 0.6) }
        .onChange(of: vm.step) { _, _ in focusCurrentField(after: 0.45) }
    }

    // MARK: Top bar — back chevron + progress

    private var topBar: some View {
        ZStack {
            OnboardingProgressBar(
                stepCount: OnboardingViewModel.Step.allCases.count,
                currentIndex: vm.step.rawValue
            )
            .frame(maxWidth: 160)

            HStack {
                Button {
                    withAnimation(stepSpring) { vm.goBack() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .frame(width: 38, height: 38)
                        .background(Theme.Colors.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(SpringTapStyle())
                .opacity(vm.step == .name ? 0 : 1)
                .disabled(vm.step == .name || vm.isLoading)
                .animation(.easeInOut(duration: 0.2), value: vm.step)

                Spacer()
            }
        }
        .frame(height: 44)
    }

    // MARK: Step 1 — name

    private var nameStep: some View {
        stepScaffold(
            title: "What should we call you?",
            subtitle: "Your name, the way your friends say it."
        ) {
            AuthTextField(
                label: "Name", placeholder: "Your name",
                text: $vm.name, isFocused: focus == .name,
                capitalization: .words
            )
            .textContentType(.name)
            .focused($focus, equals: .name)
            .submitLabel(.next)
            .onSubmit { advance() }
        } footer: {
            continueButton(title: "Continue")

            Button(action: onSignIn) {
                (Text("Already rolling? ").foregroundColor(Theme.Colors.textSecondary)
                 + Text("Sign in").foregroundColor(Theme.Colors.accent).bold())
                    .font(.system(size: 14, weight: .regular, design: .rounded))
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
        }
    }

    // MARK: Step 2 — username

    private var usernameStep: some View {
        stepScaffold(
            title: "Claim your handle",
            subtitle: "It's how friends find you. We took a guess, make it yours."
        ) {
            AuthTextField(
                label: "Username", placeholder: "yourname",
                text: $vm.username, isFocused: focus == .username,
                prefix: "@"
            )
            .textContentType(.username)
            .focused($focus, equals: .username)
            .submitLabel(.next)
            .onSubmit { advance() }
            .onChange(of: vm.username) { _, newValue in
                let cleaned = newValue.lowercased().replacingOccurrences(of: " ", with: "")
                if cleaned != newValue { vm.username = cleaned }
                vm.errorMessage = nil
            }
        } footer: {
            continueButton(title: "Continue")
        }
    }

    // MARK: Step 3 — avatar (the showpiece)

    private var avatarStep: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    stepHeading(
                        title: "Pick your look",
                        subtitle: "Every roll needs a face. Choose yours."
                    )
                    .padding(.top, 28)
                    .padding(.bottom, 24)

                    AvatarPicker(selection: $vm.avatarId)
                }
                .padding(.horizontal, 24)
            }

            VStack(spacing: 0) {
                continueButton(title: "That's me")

                Button {
                    withAnimation(stepSpring) { vm.skipAvatar() }
                } label: {
                    Text("I'll pick later")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(Theme.Colors.textMuted)
                        .underline()
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: Step 4 — credentials

    private var credentialsStep: some View {
        stepScaffold(
            title: "Last step, promise",
            subtitle: "An email and a password — then you're rolling."
        ) {
            VStack(spacing: 12) {
                AuthTextField(
                    label: "Email", placeholder: "you@example.com",
                    text: $vm.email, isFocused: focus == .email
                )
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .focused($focus, equals: .email)
                .submitLabel(.next)
                .onSubmit { focus = .password }

                AuthSecureField(
                    label: "Password (6+ characters)", placeholder: "Password",
                    text: $vm.password, isFocused: focus == .password
                )
                .textContentType(.newPassword)
                .focused($focus, equals: .password)
                .submitLabel(.go)
                .onSubmit { createAccount() }
            }
        } footer: {
            Button {
                createAccount()
            } label: {
                ZStack {
                    if vm.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Let's roll")
                            .font(Theme.Typography.label)
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(vm.canContinue ? Theme.Colors.accent : Theme.Colors.textMuted.opacity(0.28))
                .clipShape(Capsule())
                .shadow(
                    color: vm.canContinue ? Theme.Colors.accent.opacity(0.32) : .clear,
                    radius: 14, x: 0, y: 6
                )
            }
            .buttonStyle(SpringTapStyle(scaleAmount: 0.97))
            .disabled(!vm.canContinue || vm.isLoading)
            .animation(.easeInOut(duration: 0.18), value: vm.canContinue)
        }
    }

    // MARK: Shared step scaffolding

    private func stepHeading(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.Typography.title)
                .foregroundColor(Theme.Colors.textPrimary)
            Text(subtitle)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func stepScaffold<Input: View, Footer: View>(
        title: String,
        subtitle: String,
        @ViewBuilder input: () -> Input,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        VStack(spacing: 0) {
            stepHeading(title: title, subtitle: subtitle)
                .padding(.top, 36)
                .padding(.bottom, 28)

            input()

            if let err = vm.errorMessage {
                Text(err)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.danger)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer(minLength: 20)

            footer()
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.2), value: vm.errorMessage)
    }

    private func continueButton(title: String) -> some View {
        Button {
            advance()
        } label: {
            ZStack {
                if vm.isLoading {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(Theme.Typography.label)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(vm.canContinue ? Theme.Colors.accent : Theme.Colors.textMuted.opacity(0.28))
            .clipShape(Capsule())
            .shadow(
                color: vm.canContinue ? Theme.Colors.accent.opacity(0.32) : .clear,
                radius: 14, x: 0, y: 6
            )
        }
        .buttonStyle(SpringTapStyle(scaleAmount: 0.97))
        .disabled(!vm.canContinue || vm.isLoading)
        .animation(.easeInOut(duration: 0.18), value: vm.canContinue)
    }

    // MARK: Motion & flow helpers

    private var stepSpring: Animation {
        reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.4, dampingFraction: 0.85)
    }

    private var stepTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: vm.goingForward ? .trailing : .leading).combined(with: .opacity),
            removal:   .move(edge: vm.goingForward ? .leading  : .trailing).combined(with: .opacity)
        )
    }

    private func advance() {
        guard vm.canContinue, !vm.isLoading else { return }
        if vm.step == .username {
            // Handle must be unclaimed before moving on.
            Task {
                guard await vm.checkUsernameAvailable() else { return }
                withAnimation(stepSpring) { vm.advance() }
            }
        } else {
            withAnimation(stepSpring) { vm.advance() }
        }
    }

    private func createAccount() {
        guard vm.canContinue, !vm.isLoading else { return }
        focus = nil
        Task { await vm.createAccount(onSuccess: onAuthenticated) }
    }

    private func focusCurrentField(after delay: Double) {
        let target: Field?
        switch vm.step {
        case .name:        target = .name
        case .username:    target = .username
        case .avatar:      target = nil
        case .credentials: target = .email
        }
        guard let target else { focus = nil; return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            focus = target
        }
    }
}

// MARK: - Progress bar (animated filling segments)

private struct OnboardingProgressBar: View {
    let stepCount: Int
    let currentIndex: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<stepCount, id: \.self) { i in
                Capsule()
                    .fill(i <= currentIndex ? Theme.Colors.accent : Theme.Colors.border)
                    .frame(width: i == currentIndex ? 26 : 14, height: 5)
            }
        }
        .animation(
            reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.65),
            value: currentIndex
        )
    }
}

// MARK: - Avatar picker (the centerpiece)

struct AvatarPicker: View {
    @Binding var selection: Int?

    @State private var appeared = false
    @Namespace private var ringNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let allAvatarIds = Array(1...12)
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        VStack(spacing: 30) {
            preview
            grid
        }
        .onAppear {
            haptic.prepare()
            if reduceMotion {
                withAnimation(.easeInOut(duration: 0.3)) { appeared = true }
            } else {
                appeared = true   // per-cell springs carry their own delays
            }
        }
    }

    // Big circular preview with springy pop on change
    private var preview: some View {
        ZStack {
            Circle()
                .stroke(Theme.Colors.accentTint, lineWidth: 5)
                .frame(width: 138, height: 138)

            if let id = selection {
                Image("\(id)")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 124, height: 124)
                    .clipShape(Circle())
                    .shadow(color: Theme.Colors.accent.opacity(0.30), radius: 16, x: 0, y: 6)
                    .id(id)   // new identity per selection → pop transition
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.55).combined(with: .opacity)
                    )
            } else {
                Circle()
                    .fill(Theme.Colors.surface)
                    .frame(width: 124, height: 124)
                    .overlay(
                        Image(systemName: "face.smiling")
                            .font(.system(size: 44, weight: .light))
                            .foregroundColor(Theme.Colors.textMuted)
                    )
                    .transition(.opacity)
            }
        }
        .animation(
            reduceMotion
                ? .easeInOut(duration: 0.2)
                : .spring(response: 0.35, dampingFraction: 0.55),
            value: selection
        )
    }

    // 4×3 grid of circular options with staggered entrance
    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 18) {
            ForEach(Array(allAvatarIds.enumerated()), id: \.element) { index, id in
                avatarCell(id: id)
                    .scaleEffect(entranceScale)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        reduceMotion
                            ? .easeInOut(duration: 0.3)
                            : .spring(response: 0.45, dampingFraction: 0.6)
                                .delay(Double(index) * 0.05),
                        value: appeared
                    )
            }
        }
    }

    private var entranceScale: CGFloat {
        if reduceMotion { return 1 }
        return appeared ? 1 : 0.4
    }

    private func avatarCell(id: Int) -> some View {
        let isSelected = selection == id

        return Button {
            haptic.impactOccurred()
            withAnimation(
                reduceMotion
                    ? .easeInOut(duration: 0.2)
                    : .spring(response: 0.35, dampingFraction: 0.65)
            ) {
                selection = id
            }
        } label: {
            Image("\(id)")
                .resizable()
                .scaledToFill()
                .frame(width: 66, height: 66)
                .clipShape(Circle())
                .opacity(isSelected || selection == nil ? 1 : 0.55)
                .scaleEffect(isSelected && !reduceMotion ? 1.10 : 1)
                .overlay {
                    if isSelected {
                        Circle()
                            .stroke(Theme.Colors.accent, lineWidth: 3)
                            .matchedGeometryEffect(id: "avatarRing", in: ringNamespace)
                    }
                }
                .shadow(
                    color: isSelected ? Theme.Colors.accent.opacity(0.38) : .clear,
                    radius: 10, x: 0, y: 4
                )
        }
        .buttonStyle(SpringTapStyle())
        .accessibilityLabel("Avatar \(id)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    OnboardingFlowView(
        service: MockSupabaseService.shared,
        onAuthenticated: { _ in },
        onSignIn: {}
    )
}
