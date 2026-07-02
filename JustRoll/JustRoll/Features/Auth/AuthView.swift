import SwiftUI

// MARK: - View Model

@Observable
@MainActor
private final class AuthViewModel {
    enum Mode { case signIn, signUp }

    var mode: Mode = .signIn
    var name = ""
    var username = ""
    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?

    private let service: any SupabaseServiceProtocol

    init(service: any SupabaseServiceProtocol = MockSupabaseService.shared) {
        self.service = service
    }

    var canSubmit: Bool {
        let base = !email.trimmingCharacters(in: .whitespaces).isEmpty && password.count >= 1
        guard mode == .signUp else { return base }
        return base
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !username.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func submit(onSuccess: @escaping (User) -> Void) async {
        errorMessage = nil
        isLoading = true
        do {
            let user: User
            if mode == .signIn {
                user = try await service.signIn(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            } else {
                user = try await service.signUp(
                    name: name.trimmingCharacters(in: .whitespaces),
                    username: username.trimmingCharacters(in: .whitespaces).lowercased(),
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            }
            onSuccess(user)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Auth View

struct AuthView: View {
    let onAuthenticated: (User) -> Void
    var service: any SupabaseServiceProtocol = MockSupabaseService.shared

    @State private var vm: AuthViewModel
    @FocusState private var focus: Field?

    init(service: any SupabaseServiceProtocol = MockSupabaseService.shared,
         onAuthenticated: @escaping (User) -> Void) {
        self.service = service
        self.onAuthenticated = onAuthenticated
        self._vm = State(initialValue: AuthViewModel(service: service))
    }

    enum Field: Hashable { case name, username, email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                brandHeader
                    .padding(.top, 72)
                    .padding(.bottom, 40)

                modeSegment
                    .padding(.horizontal, 24)
                    .padding(.bottom, 22)

                formFields
                    .padding(.horizontal, 24)

                if let err = vm.errorMessage {
                    Text(err)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.danger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                primaryButton
                    .padding(.horizontal, 24)
                    .padding(.top, 22)

                toggleLink
                    .padding(.top, 18)
                    .padding(.bottom, 60)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.Colors.background.ignoresSafeArea())
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: vm.mode)
        .animation(.easeInOut(duration: 0.2), value: vm.errorMessage)
    }

    // MARK: Brand header

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
                Text("Hang out. Everyone shares.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }

    // MARK: Mode segment

    private var modeSegment: some View {
        HStack(spacing: 0) {
            segmentTab(label: "Sign in", active: vm.mode == .signIn) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    vm.mode = .signIn
                    vm.errorMessage = nil
                }
            }
            segmentTab(label: "Create account", active: vm.mode == .signUp) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    vm.mode = .signUp
                    vm.errorMessage = nil
                }
            }
        }
        .padding(4)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func segmentTab(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: active ? .semibold : .regular, design: .rounded))
                .foregroundColor(active ? Theme.Colors.textPrimary : Theme.Colors.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if active {
                            RoundedRectangle(cornerRadius: 11)
                                .fill(Theme.Colors.background)
                                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: active)
    }

    // MARK: Form fields

    private var formFields: some View {
        VStack(spacing: 12) {
            if vm.mode == .signUp {
                authField("Name", placeholder: "Your full name",
                          text: $vm.name, field: .name,
                          keyboard: .default, capitalize: .words)

                authField("Username", placeholder: "yourname",
                          text: $vm.username, field: .username,
                          keyboard: .default, prefix: "@")
            }

            authField("Email", placeholder: "you@example.com",
                      text: $vm.email, field: .email,
                      keyboard: .emailAddress)

            passwordField()
        }
    }

    @ViewBuilder
    private func authField(
        _ label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboard: UIKeyboardType,
        capitalize: TextInputAutocapitalization = .never,
        prefix: String? = nil
    ) -> some View {
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
                TextField(placeholder, text: text)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .keyboardType(keyboard)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(capitalize)
                    .focused($focus, equals: field)
                    .submitLabel(.next)
                    .onSubmit { advanceFocus(from: field) }
                    .padding(.leading, prefix == nil ? 14 : 6)
                    .padding(.trailing, 14)
                    .padding(.vertical, 14)
            }
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        focus == field ? Theme.Colors.accent.opacity(0.55) : Theme.Colors.border,
                        lineWidth: focus == field ? 1.2 : 0.5
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: focus == field)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    @ViewBuilder
    private func passwordField() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Password")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Theme.Colors.textMuted)

            SecureField("Password", text: $vm.password)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textPrimary)
                .focused($focus, equals: .password)
                .submitLabel(.go)
                .onSubmit {
                    focus = nil
                    Task { await vm.submit(onSuccess: onAuthenticated) }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            focus == .password ? Theme.Colors.accent.opacity(0.55) : Theme.Colors.border,
                            lineWidth: focus == .password ? 1.2 : 0.5
                        )
                )
                .animation(.easeInOut(duration: 0.15), value: focus == .password)
        }
    }

    // MARK: Primary button

    private var primaryButton: some View {
        Button {
            focus = nil
            Task { await vm.submit(onSuccess: onAuthenticated) }
        } label: {
            ZStack {
                if vm.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(vm.mode == .signIn ? "Sign in" : "Create account")
                        .font(Theme.Typography.label)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(vm.canSubmit ? Theme.Colors.accent : Theme.Colors.textMuted.opacity(0.28))
            .clipShape(Capsule())
            .shadow(
                color: vm.canSubmit ? Theme.Colors.accent.opacity(0.32) : .clear,
                radius: 14, x: 0, y: 6
            )
        }
        .buttonStyle(SpringTapStyle(scaleAmount: 0.97))
        .disabled(!vm.canSubmit || vm.isLoading)
        .animation(.easeInOut(duration: 0.18), value: vm.canSubmit)
    }

    // MARK: Toggle link

    private var toggleLink: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                vm.mode = (vm.mode == .signIn) ? .signUp : .signIn
                vm.errorMessage = nil
            }
        } label: {
            Group {
                if vm.mode == .signIn {
                    Text("No account? ").foregroundColor(Theme.Colors.textSecondary)
                    + Text("Create one").foregroundColor(Theme.Colors.accent).bold()
                } else {
                    Text("Already have an account? ").foregroundColor(Theme.Colors.textSecondary)
                    + Text("Sign in").foregroundColor(Theme.Colors.accent).bold()
                }
            }
            .font(.system(size: 14, weight: .regular, design: .rounded))
        }
        .buttonStyle(.plain)
    }

    // MARK: Keyboard flow

    private func advanceFocus(from field: Field) {
        switch field {
        case .name:     focus = .username
        case .username: focus = .email
        case .email:    focus = .password
        case .password:
            focus = nil
            Task { await vm.submit(onSuccess: onAuthenticated) }
        }
    }
}

#Preview {
    AuthView { _ in }
}
