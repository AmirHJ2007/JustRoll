import SwiftUI

struct SettingsView: View {
    @State private var nudgesEnabled = true
    @State private var newPhotosEnabled = true

    var body: some View {
        NavigationStack {
            List {
                accountSection
                subscriptionSection
                notificationsSection
                permissionsSection
                signOutSection
            }
            .navigationTitle("Settings")
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.surface.ignoresSafeArea())
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        Section("Account") {
            settingsRow(icon: "person.circle", label: "Profile", value: "Amir")
            settingsRow(icon: "envelope",      label: "Email",   value: "amir@example.com")
        }
    }

    private var subscriptionSection: some View {
        Section("Subscription") {
            HStack {
                Label {
                    Text("Free trial")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.textPrimary)
                } icon: {
                    Image(systemName: "sparkles")
                        .foregroundColor(Theme.Colors.accent)
                }
                Spacer()
                Text("28 days left")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.accent)
            }

            HStack {
                Label {
                    Text("Upgrade to JustRoll+")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.textPrimary)
                } icon: {
                    Image(systemName: "dollarsign.circle")
                        .foregroundColor(Theme.Colors.accent)
                }
                Spacer()
                Text("$3/mo")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.textMuted)
            }
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle(isOn: $newPhotosEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New photos arrived")
                            .font(Theme.Typography.label)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("When friends' photos land in your roll")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                } icon: {
                    Image(systemName: "bell.fill")
                        .foregroundColor(Theme.Colors.accent)
                }
            }
            .tint(Theme.Colors.accent)

            Toggle(isOn: $nudgesEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Still hanging out?")
                            .font(Theme.Typography.label)
                            .foregroundColor(Theme.Colors.textPrimary)
                        Text("Nudge every 3–4 hrs to keep the roll open")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                } icon: {
                    Image(systemName: "clock.fill")
                        .foregroundColor(Theme.Colors.accent)
                }
            }
            .tint(Theme.Colors.accent)
        }
    }

    private var permissionsSection: some View {
        Section("Permissions") {
            settingsRow(icon: "photo.on.rectangle", label: "Photo library",        value: "Full access")
            settingsRow(icon: "location",           label: "Location",             value: "While using")
            settingsRow(icon: "bell.badge",         label: "Push notifications",   value: "Allowed")
        }
    }

    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                // TODO: call service.signOut()
            } label: {
                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(Theme.Typography.label)
            }
        }
    }

    // MARK: - Helper

    private func settingsRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label {
                Text(label)
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.textPrimary)
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(Theme.Colors.accent)
            }
            Spacer()
            Text(value)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }
}

#Preview {
    SettingsView()
}
