import SwiftUI

struct ContactsView: View {
    @State private var viewModel = ContactsViewModel()
    @State private var searchText = ""
    @State private var addUsername = ""
    @State private var isAdding = false
    @State private var addError: String?
    @State private var isScanning = false

    private var filtered: [Contact] {
        guard !searchText.isEmpty else { return viewModel.contacts }
        return viewModel.contacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    private var connected: [Contact]    { filtered.filter(\.isConnected) }
    private var notConnected: [Contact] { filtered.filter { !$0.isConnected } }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.surface.ignoresSafeArea()
                VStack(spacing: 0) {
                    header
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView().tint(Theme.Colors.accent)
                        Spacer()
                    } else if viewModel.contacts.isEmpty {
                        emptyState
                    } else {
                        contactList
                    }
                }
            }
            .navigationBarHidden(true)
            .task { await viewModel.load() }
            .sheet(isPresented: $viewModel.showAddSheet) { addFriendSheet }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Contacts")
                        .font(Theme.Typography.displayTitle)
                        .foregroundColor(Theme.Colors.textPrimary)
                    if !viewModel.contacts.isEmpty {
                        let n = connected.count
                        Text("\(n) \(n == 1 ? "friend" : "friends") on JustRoll")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                }
                Spacer()
                Button { viewModel.showAddSheet = true } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Theme.Colors.accent)
                        .padding(11)
                        .background(Theme.Colors.accentTint)
                        .clipShape(Circle())
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 14)

            // Avatar strip for connected friends
            if !connected.isEmpty && searchText.isEmpty {
                crewStrip
            }

            searchBar
        }
        .background(Theme.Colors.background)
    }

    // MARK: - Crew strip

    private var crewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(connected) { contact in
                    VStack(spacing: 6) {
                        gradientAvatar(name: contact.name, size: 52, seed: contact.id)
                        Text(contact.name.components(separatedBy: " ").first ?? contact.name)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(width: 58)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.Colors.textMuted)
            TextField("Find a friend", text: $searchText)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textPrimary)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.Colors.textMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    // MARK: - Contact list

    private var contactList: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !connected.isEmpty {
                    contactSection(
                        title: "On JustRoll",
                        contacts: connected
                    )
                }
                if !notConnected.isEmpty {
                    contactSection(title: "Invite them", contacts: notConnected)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 32)
        }
    }

    private func contactSection(title: String, contacts: [Contact]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.Typography.sectionHeader)
                .foregroundColor(Theme.Colors.accent)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(contacts.enumerated()), id: \.element.id) { idx, contact in
                    ContactRowView(
                        contact: contact,
                        seed: contact.id
                    ) {
                        viewModel.showAddSheet = true
                    } onRemove: {
                        Task { await viewModel.removeContact(contact) }
                    }
                    .padding(.horizontal, 16)

                    if idx < contacts.count - 1 {
                        Divider().padding(.leading, 76)
                    }
                }
            }
            .background(Theme.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }

    // MARK: - Gradient avatar (shared)

    static let avatarGradients: [[Color]] = [
        [Color(hex: 0x6DAA5A), Color(hex: 0x3A7D44)],
        [Color(hex: 0x5E7DC0), Color(hex: 0x3B4E9E)],
        [Color(hex: 0xC07B5E), Color(hex: 0x9E4E3B)],
        [Color(hex: 0x9E5EC0), Color(hex: 0x6B3B9E)],
        [Color(hex: 0xC0A05E), Color(hex: 0x9E7A3B)],
        [Color(hex: 0x5EAAC0), Color(hex: 0x3B7E9E)],
    ]

    @ViewBuilder
    func gradientAvatar(name: String, size: CGFloat, seed: String) -> some View {
        let idx = seed.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } % Self.avatarGradients.count
        let gradient = Self.avatarGradients[idx]
        Circle()
            .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            )
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            Image(systemName: "person.2")
                .font(.system(size: 52))
                .foregroundColor(Theme.Colors.textMuted)
            VStack(spacing: Theme.Spacing.sm) {
                Text("No contacts yet")
                    .font(Theme.Typography.heading)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("Add friends so they can join your rolls.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            RollButton(title: "Add a friend") { viewModel.showAddSheet = true }
                .padding(.horizontal, Theme.Spacing.xl)
            Spacer()
        }
    }

    // MARK: - Add friend sheet

    private var addFriendSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Spacer().frame(height: Theme.Spacing.sm)
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Username")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                    TextField("e.g. sarachen", text: $addUsername)
                        .textFieldStyle(ThemedTextFieldStyle())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                if let err = addError {
                    Text(err).font(Theme.Typography.caption).foregroundColor(Theme.Colors.danger)
                }
                RollButton(title: "Add friend", isLoading: isAdding) {
                    guard !addUsername.isEmpty else { return }
                    Task {
                        isAdding = true; addError = nil
                        do {
                            try await viewModel.addContact(username: addUsername)
                            viewModel.showAddSheet = false; addUsername = ""
                        } catch { addError = error.localizedDescription }
                        isAdding = false
                    }
                }
                orDivider
                nearbyButton
                Spacer()
            }
            .padding(Theme.Spacing.lg)
            .navigationTitle("Add a friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { viewModel.showAddSheet = false }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .themedNavBar()
        }
    }

    private var orDivider: some View {
        HStack(spacing: Theme.Spacing.md) {
            Rectangle().fill(Theme.Colors.border).frame(height: 0.5)
            Text("or").font(Theme.Typography.caption).foregroundColor(Theme.Colors.textMuted)
            Rectangle().fill(Theme.Colors.border).frame(height: 0.5)
        }
    }

    private var nearbyButton: some View {
        Button {
            isScanning = true
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                isScanning = false
            }
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                if isScanning {
                    ProgressView().tint(Theme.Colors.accent).scaleEffect(0.85)
                    Text("Looking for people nearby…").font(Theme.Typography.label).foregroundColor(Theme.Colors.accent)
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 16))
                        .foregroundColor(Theme.Colors.accent)
                    Text("They are nearby").font(Theme.Typography.label).foregroundColor(Theme.Colors.accent)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Theme.Colors.accentTint)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.Colors.accent.opacity(0.25), lineWidth: 1))
        }
        .disabled(isScanning)
        .animation(.easeInOut(duration: 0.2), value: isScanning)
    }
}

// MARK: - Contact row

struct ContactRowView: View {
    let contact: Contact
    let seed: String
    let onStartRoll: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            gradientAvatar(name: contact.name, size: 48, seed: seed)

            VStack(alignment: .leading, spacing: 3) {
                Text(contact.name)
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("@\(contact.username)")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textMuted)
            }

            Spacer()

            Menu {
                Button { onStartRoll() } label: {
                    Label("Start a roll", systemImage: "film.stack")
                }
                Button(role: .destructive) { onRemove() } label: {
                    Label("Remove contact", systemImage: "person.fill.xmark")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.Colors.textMuted)
                    .padding(9)
                    .background(Theme.Colors.surface)
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 13)
    }

    @ViewBuilder
    private func gradientAvatar(name: String, size: CGFloat, seed: String) -> some View {
        let idx = seed.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } % ContactsView.avatarGradients.count
        let gradient = ContactsView.avatarGradients[idx]
        Circle()
            .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            )
    }
}

#Preview {
    ContactsView()
}
