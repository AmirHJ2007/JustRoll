import SwiftUI

// MARK: - AuthView (container: onboarding flow ↔ sign-in)
//
// New users land on the multi-step onboarding (name → username → avatar →
// email + password). Existing users hop over to the sign-in screen via
// "Already rolling? Sign in".

struct AuthView: View {
    let onAuthenticated: (User) -> Void
    private let service: any SupabaseServiceProtocol

    private enum Route { case onboarding, signIn }
    @State private var route: Route = .onboarding
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(service: any SupabaseServiceProtocol,
         onAuthenticated: @escaping (User) -> Void) {
        self.service = service
        self.onAuthenticated = onAuthenticated
    }

    var body: some View {
        ZStack {
            switch route {
            case .onboarding:
                OnboardingFlowView(
                    service: service,
                    onAuthenticated: onAuthenticated,
                    onSignIn: { switchTo(.signIn) }
                )
                .transition(routeTransition(edge: .leading))

            case .signIn:
                SignInView(
                    service: service,
                    onAuthenticated: onAuthenticated,
                    onCreateAccount: { switchTo(.onboarding) }
                )
                .transition(routeTransition(edge: .trailing))
            }
        }
        .background(Theme.Colors.background.ignoresSafeArea())
    }

    private func switchTo(_ newRoute: Route) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            route = newRoute
        }
    }

    private func routeTransition(edge: Edge) -> AnyTransition {
        reduceMotion
            ? .opacity
            : .move(edge: edge).combined(with: .opacity)
    }
}

// MARK: - Sign in (existing users)

private struct SignInView: View {
    let service: any SupabaseServiceProtocol
    let onAuthenticated: (User) -> Void
    let onCreateAccount: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focus: Field?

    private enum Field: Hashable { case email, password }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                brandHeader
                    .padding(.top, 72)
                    .padding(.bottom, 44)

                VStack(spacing: 12) {
                    AuthTextField(
                        label: "Email", placeholder: "you@example.com",
                        text: $email, isFocused: focus == .email
                    )
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .focused($focus, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }

                    AuthSecureField(
                        label: "Password", placeholder: "Password",
                        text: $password, isFocused: focus == .password
                    )
                    .textContentType(.password)
                    .focused($focus, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { submit() }
                }
                .padding(.horizontal, 24)

                if let err = errorMessage {
                    Text(err)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.danger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Button {
                    submit()
                } label: {
                    ZStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Sign in")
                                .font(Theme.Typography.label)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(canSubmit ? Theme.Colors.accent : Theme.Colors.textMuted.opacity(0.28))
                    .clipShape(Capsule())
                    .shadow(
                        color: canSubmit ? Theme.Colors.accent.opacity(0.32) : .clear,
                        radius: 14, x: 0, y: 6
                    )
                }
                .buttonStyle(SpringTapStyle(scaleAmount: 0.97))
                .disabled(!canSubmit || isLoading)
                .animation(.easeInOut(duration: 0.18), value: canSubmit)
                .padding(.horizontal, 24)
                .padding(.top, 22)

                Button(action: onCreateAccount) {
                    (Text("New here? ").foregroundColor(Theme.Colors.textSecondary)
                     + Text("Get rolling").foregroundColor(Theme.Colors.accent).bold())
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                }
                .buttonStyle(.plain)
                .padding(.top, 18)
                .padding(.bottom, 60)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.Colors.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focus = .email }
        }
    }

    private var brandHeader: some View {
        VStack(spacing: 20) {
            Image("cover3")
                .resizable()
                .scaledToFill()
                .frame(width: 140, height: 140)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)

            VStack(spacing: 10) {
                VStack(spacing: 4) {
                    Text("JustRoll")
                        .font(Font.custom("ShantellSans-Medium", size: 38))
                        .foregroundColor(Theme.Colors.textPrimary)
                    SwooshUnderline()
                        .frame(height: 8)
                }
                Text("Welcome back. Ready to roll?")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }

    private func submit() {
        guard canSubmit, !isLoading else { return }
        focus = nil
        errorMessage = nil
        isLoading = true
        Task {
            do {
                let user = try await service.signIn(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
                onAuthenticated(user)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Shared field chrome (used by sign-in + onboarding steps)

struct AuthTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isFocused: Bool = false
    var capitalization: TextInputAutocapitalization = .never
    var prefix: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Theme.Colors.textMuted)

            HStack(spacing: 0) {
                if let prefix {
                    Text(prefix)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textMuted)
                        .padding(.leading, 14)
                }
                TextField(placeholder, text: $text)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(capitalization)
                    .padding(.leading, prefix == nil ? 14 : 6)
                    .padding(.trailing, 14)
                    .padding(.vertical, 14)
            }
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isFocused ? Theme.Colors.accent.opacity(0.55) : Theme.Colors.border,
                        lineWidth: isFocused ? 1.2 : 0.5
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
    }
}

struct AuthSecureField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isFocused: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Theme.Colors.textMuted)

            SecureField(placeholder, text: $text)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isFocused ? Theme.Colors.accent.opacity(0.55) : Theme.Colors.border,
                            lineWidth: isFocused ? 1.2 : 0.5
                        )
                )
                .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
    }
}

#Preview {
    AuthView(service: MockSupabaseService.shared) { _ in }
}
