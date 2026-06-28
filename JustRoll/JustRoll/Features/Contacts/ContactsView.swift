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

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.contacts.isEmpty {
                    emptyState
                } else {
                    contactsList
                }
            }
            .navigationTitle("Contacts")
            .background(Theme.Colors.background.ignoresSafeArea())
            .searchable(text: $searchText, prompt: "Find a friend")
            .task { await viewModel.load() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showAddSheet = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(Theme.Colors.accent)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddSheet) {
                addFriendSheet
            }
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
            }
            Spacer()
        }
    }

    // MARK: - Contacts list

    private var contactsList: some View {
        List(filtered) { contact in
            ContactRowView(contact: contact)
                .listRowBackground(Theme.Colors.surface)
                .listRowSeparatorTint(Theme.Colors.border)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background)
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
                        isAdding = true
                        addError = nil
                        do {
                            try await viewModel.addContact(username: addUsername)
                            viewModel.showAddSheet = false
                            addUsername = ""
                        } catch {
                            addError = error.localizedDescription
                        }
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
        }
    }
}

// MARK: - Row

struct ContactRowView: View {
    let contact: Contact

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            AvatarView(name: contact.name)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(contact.name)
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("@\(contact.username)")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Spacer()

            if contact.isConnected {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Colors.accent)
            } else {
                Text("Invite")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.accent)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Theme.Colors.accentTint)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

#Preview {
    ContactsView()
}
