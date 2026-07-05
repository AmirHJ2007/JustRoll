import SwiftUI

// MARK: - Private icon chip

private struct IconChip: View {
    let name: String
    var color: Color = Theme.Colors.accent
    var bgColor: Color = Theme.Colors.accentTint

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(color)
            .frame(width: 32, height: 32)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Reusable row

struct SettingsRow: View {
    let icon: String
    let label: String
    var iconColor: Color = Theme.Colors.accent
    var iconBg: Color = Theme.Colors.accentTint
    var value: String? = nil
    var valueColor: Color = Color(hex: 0x4A4F4D)
    var showChevron: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            IconChip(name: icon, color: iconColor, bgColor: iconBg)

            Text(label)
                .font(Theme.Typography.label)
                .foregroundColor(Theme.Colors.textPrimary)

            Spacer()

            if let v = value {
                Text(v)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(valueColor)
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: 0x6B716D))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

// MARK: - Reusable toggle row

struct SettingsToggleRow: View {
    let icon: String
    let label: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            IconChip(name: icon, color: Theme.Colors.accent, bgColor: Theme.Colors.accentTint)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Color(hex: 0x6B716D))
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.Colors.accent)
                .onChange(of: isOn) { _, _ in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

// MARK: - Settings view

struct SettingsView: View {
    var service: any SupabaseServiceProtocol = MockSupabaseService.shared
    var onSignOut: () -> Void = {}

    @State private var nudgesEnabled = true
    @State private var newPhotosEnabled = true
    @State private var profileName = ""
    @State private var profileEmail = ""
    @State private var profileAvatarId: Int? = nil
    @State private var showAvatarPicker = false
    @State private var appear = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Theme.Colors.surface.ignoresSafeArea()

                VStack(spacing: 0) {
                    header.zIndex(1)
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            profileCard
                                .cardEntrance(appear: appear, delay: 0.05, reduceMotion: reduceMotion)
                            notificationsCard
                                .cardEntrance(appear: appear, delay: 0.13, reduceMotion: reduceMotion)
                            permissionsCard
                                .cardEntrance(appear: appear, delay: 0.21, reduceMotion: reduceMotion)
                            signOutCard
                                .cardEntrance(appear: appear, delay: 0.29, reduceMotion: reduceMotion)
                            aboutFooter
                                .cardEntrance(appear: appear, delay: 0.37, reduceMotion: reduceMotion)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 110)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .task { await loadData() }
        .onAppear {
            withAnimation(reduceMotion
                ? .easeIn(duration: 0.15)
                : .spring(response: 0.5, dampingFraction: 0.78)
            ) {
                appear = true
            }
        }
        .onChange(of: nudgesEnabled)    { _, v in Task { try? await service.updatePreferences(nudges: v, newPhotos: newPhotosEnabled) } }
        .onChange(of: newPhotosEnabled) { _, v in Task { try? await service.updatePreferences(nudges: nudgesEnabled, newPhotos: v) } }
    }

    private func loadData() async {
        if let user = try? await service.fetchProfile() {
            profileName  = user.name
            profileEmail = user.email
            profileAvatarId = user.avatarId
        }
        if let prefs = try? await service.fetchPreferences() {
            nudgesEnabled    = prefs.nudges
            newPhotosEnabled = prefs.newPhotos
        }
    }

    // MARK: - Header

    private var header: some View {
        PageHeader(title: "Settings", subtitle: "Your account")
    }

    // MARK: - Helpers

    private var rowDivider: some View {
        Rectangle()
            .fill(Theme.Colors.border)
            .frame(height: 0.5)
            .padding(.leading, 62)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Theme.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(Theme.Colors.border, lineWidth: 0.5)
            )
    }

    // MARK: - Profile hero card

    private var profileCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showAvatarPicker = true
        } label: {
            VStack(spacing: 0) {
                // Top — gradient tint background
                ZStack {
                    LinearGradient(
                        colors: [Theme.Colors.accentTint, Theme.Colors.background],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    HStack(spacing: 18) {
                        // Avatar with accent ring
                        ZStack {
                            Circle()
                                .stroke(Theme.Colors.accent.opacity(0.22), lineWidth: 3)
                                .frame(width: 82, height: 82)
                            AvatarView(
                                name: profileName.isEmpty ? "?" : profileName,
                                size: 74,
                                avatarId: profileAvatarId
                            )
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text(profileName.isEmpty ? "—" : profileName)
                                .font(Theme.Typography.heading)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .lineLimit(1)
                            Text(verbatim: profileEmail.isEmpty ? "—" : profileEmail)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Color(hex: 0x4A4F4D))
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Theme.Colors.accent.opacity(0.65))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 20)
                }

                // Bottom hint strip
                HStack(spacing: 5) {
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                    Text("Tap to change your look")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundColor(Theme.Colors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Theme.Colors.accentTint.opacity(0.7))
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(Theme.Colors.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(SpringTapStyle(scaleAmount: 0.98))
        .sheet(isPresented: $showAvatarPicker) {
            AvatarPickerSheet(currentAvatarId: profileAvatarId) { newId in
                profileAvatarId = newId
                Task {
                    try? await service.updateAvatar(newId)
                    // Re-broadcast so nearby radars pick up the new look without an app restart.
                    if let user = service.currentUser {
                        NearbySessionManager.shared.startAdvertising(
                            displayName: user.name,
                            username: user.username,
                            avatarId: user.avatarId
                        )
                    }
                }
            }
        }
    }

    // MARK: - Notifications card

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Notifications")
            card {
                SettingsToggleRow(
                    icon: "photo.fill.on.rectangle.fill",
                    label: "New photos arrived",
                    subtitle: "Friends' shots land in your roll",
                    isOn: $newPhotosEnabled
                )
                rowDivider
                SettingsToggleRow(
                    icon: "clock.fill",
                    label: "Still hanging out?",
                    subtitle: "Nudge every 3–4 hrs to keep the roll open",
                    isOn: $nudgesEnabled
                )
            }
        }
    }

    // MARK: - Permissions card

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Permissions")
            card {
                SettingsRow(
                    icon: "photo.on.rectangle",
                    label: "Photo library",
                    value: "Full access"
                )
                rowDivider
                SettingsRow(
                    icon: "location.fill",
                    label: "Location",
                    value: "While using"
                )
                rowDivider
                SettingsRow(
                    icon: "bell.badge.fill",
                    label: "Notifications",
                    value: "Allowed"
                )
            }
        }
    }

    // MARK: - Sign out card

    private var signOutCard: some View {
        card {
            Button(role: .destructive) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task {
                    try? await service.signOut()
                    onSignOut()
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.Colors.danger)
                        .frame(width: 32, height: 32)
                        .background(Theme.Colors.danger.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sign out")
                            .font(Theme.Typography.label)
                            .foregroundColor(Theme.Colors.danger)
                        Text("Hang up the roll for now")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.danger.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(SpringTapStyle(scaleAmount: 0.98))
        }
    }

    // MARK: - About footer

    private var aboutFooter: some View {
        VStack(spacing: 5) {
            Image(systemName: "film.stack")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)
                .padding(.bottom, 2)

            Text("JustRoll")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: 0x4A4F4D))

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text("v\(version) (\(build))")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(Theme.Colors.textMuted)
            }

            Text("Hang out. Everyone taps in.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(Theme.Colors.textMuted)
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Card entrance animation

private extension View {
    func cardEntrance(appear: Bool, delay: Double, reduceMotion: Bool) -> some View {
        self
            .opacity(appear ? 1 : 0)
            .offset(y: (!reduceMotion && !appear) ? 20 : 0)
            .animation(
                reduceMotion
                    ? .easeIn(duration: 0.15).delay(delay)
                    : .spring(response: 0.45, dampingFraction: 0.72).delay(delay),
                value: appear
            )
    }
}

// MARK: - AvatarPickerSheet (change your look after sign-up)

struct AvatarPickerSheet: View {
    let currentAvatarId: Int?
    let onSave: (Int?) -> Void

    @State private var selection: Int?
    @Environment(\.dismiss) private var dismiss

    init(currentAvatarId: Int?, onSave: @escaping (Int?) -> Void) {
        self.currentAvatarId = currentAvatarId
        self.onSave = onSave
        self._selection = State(initialValue: currentAvatarId)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pick your look")
                        .font(Theme.Typography.title)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("Every roll needs a face. Choose yours.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)

                    AvatarPicker(selection: $selection)
                        .padding(.top, 24)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 28)
            }

            Button {
                onSave(selection)
                dismiss()
            } label: {
                Text("That's me")
                    .font(Theme.Typography.label)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(selection != nil ? Theme.Colors.accent : Theme.Colors.textMuted.opacity(0.28))
                    .clipShape(Capsule())
            }
            .buttonStyle(SpringTapStyle(scaleAmount: 0.97))
            .disabled(selection == nil)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
    }
}

#Preview {
    SettingsView()
}
