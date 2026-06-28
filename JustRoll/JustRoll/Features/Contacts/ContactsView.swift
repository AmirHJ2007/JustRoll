import SwiftUI

// MARK: - Avatar palette

private struct AvatarTone {
    let background: Color
    let foreground: Color
}

private let avatarPalette: [AvatarTone] = [
    AvatarTone(background: Color(hex: 0xD4E8CC), foreground: Color(hex: 0x2D4A24)),
    AvatarTone(background: Color(hex: 0xDDE6C8), foreground: Color(hex: 0x3A4A24)),
    AvatarTone(background: Color(hex: 0xE0EAD4), foreground: Color(hex: 0x34502A)),
    AvatarTone(background: Color(hex: 0xE8E2D4), foreground: Color(hex: 0x4A4030)),
    AvatarTone(background: Color(hex: 0xD8EDD2), foreground: Color(hex: 0x2E4A2C)),
    AvatarTone(background: Color(hex: 0xE4DFD0), foreground: Color(hex: 0x46402C)),
]

private func avatarTone(for name: String) -> AvatarTone {
    avatarPalette[name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) } % avatarPalette.count]
}

// MARK: - View

struct ContactsView: View {
    @State private var viewModel = ContactsViewModel()
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool
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
            .onTapGesture { searchFocused = false }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Contacts")
                        .font(Theme.Typography.displayTitle)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineSpacing(-2)
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.Colors.accent)
                        .frame(width: 40, height: 40)
                        .background(Theme.Colors.accentTint)
                        .clipShape(Circle())
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

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
            HStack(spacing: 18) {
                ForEach(connected) { contact in
                    VStack(spacing: 6) {
                        avatarCircle(name: contact.name, size: 46)
                        Text(contact.name.components(separatedBy: " ").first ?? contact.name)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(width: 52)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(searchFocused ? Theme.Colors.accent : Theme.Colors.textMuted)
                .animation(.easeInOut(duration: 0.2), value: searchFocused)
            TextField("Find a friend", text: $searchText)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textPrimary)
                .focused($searchFocused)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.Colors.textMuted)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(searchFocused ? Theme.Colors.background : Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(
            color: searchFocused ? .black.opacity(0.08) : .clear,
            radius: searchFocused ? 10 : 0,
            x: 0, y: searchFocused ? 3 : 0
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    searchFocused ? Theme.Colors.accent.opacity(0.35) : Color.clear,
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: searchFocused)
    }

    // MARK: - Contact list

    private var contactList: some View {
        ScrollView {
            VStack(spacing: 24) {
                if !connected.isEmpty {
                    contactSection(title: "On JustRoll", contacts: connected, muted: false)
                }
                if !notConnected.isEmpty {
                    contactSection(title: "Invite them", contacts: notConnected, muted: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 4).onChanged { _ in searchFocused = false }
        )
    }

    private func contactSection(title: String, contacts: [Contact], muted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(0.9)
                    .foregroundColor(Theme.Colors.textMuted)
                if muted {
                    Text("·  not on JustRoll yet")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(Theme.Colors.textMuted.opacity(0.6))
                }
            }
            .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(contacts.enumerated()), id: \.element.id) { idx, contact in
                    ContactRowView(contact: contact) {
                        viewModel.showAddSheet = true
                    } onRemove: {
                        Task { await viewModel.removeContact(contact) }
                    }
                    .padding(.horizontal, 16)
                    .background(muted ? Theme.Colors.background.opacity(0.92) : Theme.Colors.background)

                    if idx < contacts.count - 1 {
                        Rectangle()
                            .fill(Theme.Colors.border)
                            .frame(height: 0.5)
                            .padding(.leading, 74)
                    }
                }
            }
            .background(muted ? Theme.Colors.surface : Theme.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(muted ? Theme.Colors.border : Color.clear, lineWidth: 0.5)
            )
            .shadow(
                color: muted ? .clear : .black.opacity(0.04),
                radius: 8, x: 0, y: 2
            )
            .opacity(muted ? 0.85 : 1)
        }
    }

    // MARK: - Avatar helper

    @ViewBuilder
    func avatarCircle(name: String, size: CGFloat) -> some View {
        let tone = avatarTone(for: name)
        Circle()
            .fill(tone.background)
            .frame(width: size, height: size)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundColor(tone.foreground)
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
                HStack(spacing: Theme.Spacing.md) {
                    Rectangle().fill(Theme.Colors.border).frame(height: 0.5)
                    Text("or").font(Theme.Typography.caption).foregroundColor(Theme.Colors.textMuted)
                    Rectangle().fill(Theme.Colors.border).frame(height: 0.5)
                }
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
}

// MARK: - Contact row

struct ContactRowView: View {
    let contact: Contact
    let onStartRoll: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            avatarCircle

            VStack(alignment: .leading, spacing: 3) {
                Text(contact.name)
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("@\(contact.username)")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Spacer()

            if !contact.isConnected {
                Text("Invite")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.Colors.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Theme.Colors.accentTint)
                    .clipShape(Capsule())
            }

            Menu {
                if contact.isConnected {
                    Button { onStartRoll() } label: {
                        Label("Start a roll", systemImage: "film.stack")
                    }
                } else {
                    Button { onStartRoll() } label: {
                        Label("Invite to JustRoll", systemImage: "envelope")
                    }
                }
                Button(role: .destructive) { onRemove() } label: {
                    Label("Remove contact", systemImage: "person.fill.xmark")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.Colors.textMuted)
                    .frame(width: 32, height: 32)
                    .background(Theme.Colors.surface)
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var avatarCircle: some View {
        let tone = avatarTone(for: contact.name)
        return Circle()
            .fill(tone.background)
            .frame(width: 46, height: 46)
            .overlay(
                Text(String(contact.name.prefix(1)).uppercased())
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(tone.foreground)
            )
    }
}

#Preview {
    ContactsView()
}
