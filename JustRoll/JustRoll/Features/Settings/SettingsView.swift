import SwiftUI

// MARK: - Reusable row

struct SettingsRow: View {
    let icon: String
    let label: String
    var iconColor: Color = Theme.Colors.accent
    var value: String? = nil
    var valueColor: Color = Theme.Colors.textSecondary
    var showChevron: Bool = false
    var tinted: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(iconColor)
                .frame(width: 22, height: 22)

            Text(label)
                .font(Theme.Typography.label)
                .foregroundColor(Theme.Colors.textPrimary)

            Spacer()

            if let v = value {
                Text(v)
                    .font(Theme.Typography.caption)
                    .foregroundColor(valueColor)
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.Colors.textMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: 50)
        .background(tinted ? Theme.Colors.accentTint : Color.clear)
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
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(Theme.Colors.accent)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.Colors.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: 50)
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

    private let daysLeft = 28
    private let trialTotal = 30

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Theme.Colors.surface.ignoresSafeArea()

                VStack(spacing: 0) {
                    header.zIndex(1)
                    ScrollView {
                        VStack(spacing: 24) {
                            profileCard
                            subscriptionCard
                            notificationsCard
                            permissionsCard
                            signOutCard
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 110)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .task { await loadData() }
        .onChange(of: nudgesEnabled)    { _, v in Task { try? await service.updatePreferences(nudges: v, newPhotos: newPhotosEnabled) } }
        .onChange(of: newPhotosEnabled) { _, v in Task { try? await service.updatePreferences(nudges: nudgesEnabled, newPhotos: v) } }
    }

    private func loadData() async {
        if let user = try? await service.fetchProfile() {
            profileName  = user.name
            profileEmail = user.email
        }
        if let prefs = try? await service.fetchPreferences() {
            nudgesEnabled    = prefs.nudges
            newPhotosEnabled = prefs.newPhotos
        }
    }

    // MARK: - Header

    private var header: some View {
        PageHeader(title: "Settings", subtitle: "Account & preferences")
    }

    // MARK: - Helpers

    private var rowDivider: some View {
        Rectangle()
            .fill(Theme.Colors.border)
            .frame(height: 0.5)
            .padding(.leading, 52)
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

    // MARK: - Cards

    private var profileCard: some View {
        card {
            HStack(spacing: 16) {
                AvatarView(name: profileName.isEmpty ? "?" : profileName, size: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profileName.isEmpty ? "—" : profileName)
                        .font(Theme.Typography.heading)
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text(verbatim: profileEmail.isEmpty ? "—" : profileEmail)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.Colors.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
    }

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Subscription")
            card {
                // Free trial with progress indicator
                HStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.Colors.accent)
                        .frame(width: 22, height: 22)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Free trial")
                            .font(Theme.Typography.label)
                            .foregroundColor(Theme.Colors.textPrimary)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Theme.Colors.border)
                                    .frame(height: 3)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Theme.Colors.accent.opacity(0.7))
                                    .frame(
                                        width: geo.size.width * CGFloat(trialTotal - daysLeft) / CGFloat(trialTotal),
                                        height: 3
                                    )
                            }
                        }
                        .frame(height: 3)
                    }

                    Spacer()

                    Text("\(daysLeft) days left")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.accent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(minHeight: 50)

                rowDivider

                // Upgrade row — faint green tint signals the money action
                SettingsRow(
                    icon: "dollarsign.circle",
                    label: "Upgrade to JustRoll+",
                    value: "$3/mo",
                    showChevron: true,
                    tinted: true
                )
            }
        }
    }

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Notifications")
            card {
                SettingsToggleRow(
                    icon: "bell.fill",
                    label: "New photos arrived",
                    subtitle: "When friends' photos land in your roll",
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

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Permissions")
            card {
                SettingsRow(icon: "photo.on.rectangle", label: "Photo library",      value: "Full access")
                rowDivider
                SettingsRow(icon: "location",           label: "Location",           value: "While using")
                rowDivider
                SettingsRow(icon: "bell.badge",         label: "Push notifications", value: "Allowed")
            }
        }
    }

    private var signOutCard: some View {
        card {
            Button(role: .destructive) {
                Task {
                    try? await service.signOut()
                    onSignOut()
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.Colors.danger)
                        .frame(width: 22, height: 22)
                    Text("Sign out")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.danger)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(minHeight: 50)
                .contentShape(Rectangle())
            }
        }
    }
}

#Preview {
    SettingsView()
}
