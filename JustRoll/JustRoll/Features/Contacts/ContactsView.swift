import SwiftUI

struct ContactsView: View {
    @State private var viewModel = ContactsViewModel()
    @State private var searchText = ""
    @State private var addUsername = ""
    @State private var isAdding = false
    @State private var addError: String?

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
                    searchBar
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if viewModel.contacts.isEmpty {
                        emptyState
                    } else {
                        contactList
                    }
                }
            }
            .navigationTitle("Contacts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { viewModel.showAddSheet = true } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Theme.Colors.accent)
                            .padding(9)
                            .background(Theme.Colors.accentTint)
                            .clipShape(Circle())
                    }
                }
            }
            .themedNavBar()
            .task { await viewModel.load() }
            .sheet(isPresented: $viewModel.showAddSheet) { addFriendSheet }
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
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
        .background(Theme.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Contact list

    private var contactList: some View {
        ScrollView {
            VStack(spacing: 12) {
                if !connected.isEmpty {
                    contactSection(
                        title: "\(connected.count) \(connected.count == 1 ? "friend" : "friends") on JustRoll",
                        contacts: connected
                    )
                }
                if !notConnected.isEmpty {
                    contactSection(title: "Invite them", contacts: notConnected)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private func contactSection(title: String, contacts: [Contact]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(contacts.enumerated()), id: \.element.id) { idx, contact in
                    ContactRowView(contact: contact) {
                        viewModel.showAddSheet = true // Start a roll — opens session flow
                    } onRemove: {
                        Task { await viewModel.removeContact(contact) }
                    }
                    .padding(.horizontal, 16)

                    if idx < contacts.count - 1 {
                        Divider()
                            .padding(.leading, 74)
                    }
                }
            }
            .background(Theme.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
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
                    Text(err)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.danger)
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

// MARK: - Row

struct ContactRowView: View {
    let contact: Contact
    let onStartRoll: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(name: contact.name, size: 46)

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
                Button {
                    onStartRoll()
                } label: {
                    Label("Start a roll", systemImage: "film.stack")
                }

                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Label("Remove contact", systemImage: "person.fill.xmark")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.Colors.textMuted)
                    .padding(8)
                    .background(Theme.Colors.surface)
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    ContactsView()
}
