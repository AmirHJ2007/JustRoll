// MARK: - Contacts feature disabled (re-enable when adding friend graph in a future version)
#if false

import SwiftUI

// MARK: - Scroll offset key (pull-to-refresh)

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - View

struct ContactsView: View {
    @State private var viewModel: ContactsViewModel
    @State private var searchText = ""

    init(service: any SupabaseServiceProtocol = MockSupabaseService.shared) {
        self._viewModel = State(initialValue: ContactsViewModel(service: service))
    }
    @FocusState private var searchFocused: Bool
    @State private var addUsername = ""
    @State private var isAdding = false
    @State private var addError: String?
    @State private var showNearbyFromContacts = false

    // Animation
    @State private var listVisible = false
    @State private var showFilmDrop = false
    @State private var pullOffset: CGFloat = 0
    @State private var isRefreshing = false
    @State private var addBtnScale: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var filtered: [Contact] {
        guard !searchText.isEmpty else { return viewModel.contacts }
        return viewModel.contacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    private var incoming:  [Contact] { filtered.filter { $0.isPending && $0.isIncoming } }
    private var connected: [Contact] { filtered.filter(\.isConnected) }
    private var invited:   [Contact] { filtered.filter { $0.isPending && !$0.isIncoming } }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Theme.Colors.surface.ignoresSafeArea()

                VStack(spacing: 0) {
                    header.zIndex(1)
                    if viewModel.isLoading && viewModel.contacts.isEmpty {
                        Spacer()
                        FilmReelSpinner()
                        Spacer()
                    } else if viewModel.contacts.isEmpty {
                        emptyState
                    } else {
                        contactList
                    }

                }

                // Film-drop celebration (anchored near add button)
                if showFilmDrop {
                    FilmDropOverlay(visible: $showFilmDrop)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 24)
                        .padding(.top, 20)
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.load()
                if !listVisible {
                    withAnimation(reduceMotion ? .none : .spring(response: 0.4)) {
                        listVisible = true
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddSheet) { addFriendSheet }
            .onTapGesture { searchFocused = false }
        }
    }

    // MARK: - Header

    private var header: some View {
        PageHeader(
            title: "Contacts",
            subtitle: nil,
            trailing: {
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { addBtnScale = 0.88 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { addBtnScale = 1 }
                    }
                    viewModel.showAddSheet = true
                } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(Theme.Colors.accent)
                        .clipShape(Circle())
                        .shadow(color: Theme.Colors.accent.opacity(0.35), radius: 8, x: 0, y: 3)
                }
                .scaleEffect(reduceMotion ? 1 : addBtnScale)
                .padding(.top, 4)
            },
            footer: { searchBar }
        )
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
                    Image(systemName: "xmark.circle.fill").foregroundColor(Theme.Colors.textMuted)
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(searchFocused ? Theme.Colors.background : Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: searchFocused ? .black.opacity(0.08) : .clear,
                radius: searchFocused ? 10 : 0, x: 0, y: searchFocused ? 3 : 0)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(searchFocused ? Theme.Colors.accent.opacity(0.35) : Color.clear, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: searchFocused)
    }

    // MARK: - Contact list

    private var contactList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Pull-to-refresh offset detector
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ScrollOffsetKey.self,
                        value: geo.frame(in: .named("contactsScroll")).minY
                    )
                }
                .frame(height: 0)

                // Film reel pull indicator
                if isRefreshing || pullOffset > 8 {
                    HStack {
                        Spacer()
                        FilmReelSpinner(
                            isSpinning: isRefreshing,
                            progress: isRefreshing ? 1 : min(pullOffset / 60, 1)
                        )
                        Spacer()
                    }
                    .frame(height: isRefreshing ? 64 : min(pullOffset, 64))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isRefreshing)
                }

                if !incoming.isEmpty {
                    incomingSection
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                if !connected.isEmpty {
                    contactSection(title: nil, contacts: connected)
                        .padding(.horizontal, 16)
                        .padding(.top, incoming.isEmpty ? 8 : 20)
                }

                if !invited.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Invited")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.Colors.textMuted)
                            .padding(.horizontal, 16)
                        contactSection(title: nil, contacts: invited)
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, (incoming.isEmpty && connected.isEmpty) ? 8 : 20)
                }

                Spacer().frame(height: 40)
            }
        }
        .coordinateSpace(name: "contactsScroll")
        .onPreferenceChange(ScrollOffsetKey.self) { offset in
            guard !isRefreshing else { return }
            pullOffset = max(0, offset)
            if pullOffset > 64 { triggerRefresh() }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 4).onChanged { _ in searchFocused = false }
        )
    }

    private func triggerRefresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            await viewModel.load()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isRefreshing = false
                pullOffset = 0
            }
        }
    }

    // MARK: - Incoming requests section

    private var incomingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Theme.Colors.accent)
                    .frame(width: 7, height: 7)
                Text("Friend requests")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.Colors.accent)
            }
            VStack(spacing: 0) {
                ForEach(Array(incoming.enumerated()), id: \.element.id) { idx, contact in
                    IncomingRequestRow(contact: contact) {
                        Task { await viewModel.acceptContact(contact) }
                    } onReject: {
                        Task { await viewModel.rejectContact(contact) }
                    }
                    if idx < incoming.count - 1 {
                        Rectangle()
                            .fill(Theme.Colors.border)
                            .frame(height: 0.5)
                            .padding(.leading, 74)
                    }
                }
            }
            .background(Theme.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Theme.Colors.accent.opacity(0.10), radius: 10, x: 0, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.Colors.accent.opacity(0.18), lineWidth: 1)
            )
        }
    }

    // MARK: - Section builder

    private func contactSection(title: String?, contacts: [Contact]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(contacts.enumerated()), id: \.element.id) { idx, contact in
                let delay = Double(idx) * 0.04

                ContactRowView(
                    contact: contact,
                    animationDelay: delay
                ) {
                    viewModel.showAddSheet = true
                } onRemove: {
                    Task { await viewModel.removeContact(contact) }
                }
                .padding(.horizontal, 16)
                .background(Theme.Colors.background)
                .opacity(listVisible ? 1 : 0)
                .offset(y: listVisible ? 0 : 18)
                .animation(
                    reduceMotion ? .none :
                        .spring(response: 0.5, dampingFraction: 0.82).delay(delay),
                    value: listVisible
                )

                if idx < contacts.count - 1 {
                    Rectangle()
                        .fill(Theme.Colors.border)
                        .frame(height: 0.5)
                        .padding(.leading, 74)
                }
            }
        }
        .background(Theme.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
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
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Spacer()
                Button { viewModel.showAddSheet = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.Colors.textMuted)
                        .frame(width: 34, height: 34)
                        .background(Theme.Colors.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(SpringTapStyle(scaleAmount: 0.88))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Text("Add a friend")
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.top, 8)

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
                            viewModel.showAddSheet = false
                            addUsername = ""
                            showFilmDrop = true
                        } catch {
                            addError = error.localizedDescription
                        }
                        isAdding = false
                    }
                }
                HStack(spacing: Theme.Spacing.md) {
                    Rectangle().fill(Theme.Colors.border).frame(height: 0.5)
                    Text("or").font(Theme.Typography.caption).foregroundColor(Theme.Colors.textMuted)
                    Rectangle().fill(Theme.Colors.border).frame(height: 0.5)
                }
                Button { showNearbyFromContacts = true } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 16))
                            .foregroundColor(Theme.Colors.accent)
                        Text("They are nearby").font(Theme.Typography.label).foregroundColor(Theme.Colors.accent)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Theme.Colors.accentTint)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Theme.Colors.accent.opacity(0.25), lineWidth: 1))
                }
                Spacer()
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .fullScreenCover(isPresented: $showNearbyFromContacts) {
            NearbyDiscoveryView(mode: .addFriend)
        }
    }
}

// MARK: - Contact row

struct ContactRowView: View {
    let contact: Contact
    var animationDelay: Double = 0
    let onStartRoll: () -> Void
    let onRemove: () -> Void

    @State private var avatarScale: CGFloat = 0.55
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(name: contact.name, size: 46)
                .scaleEffect(avatarScale)
                .onAppear {
                    guard !reduceMotion else { avatarScale = 1; return }
                    withAnimation(
                        .spring(response: 0.4, dampingFraction: 0.6)
                        .delay(animationDelay + 0.08)
                    ) { avatarScale = 1 }
                }

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
        .rowPressEffect()
    }

}

// MARK: - Incoming request row

struct IncomingRequestRow: View {
    let contact: Contact
    let onAccept: () -> Void
    let onReject: () -> Void

    @State private var avatarScale: CGFloat = 0.55

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(name: contact.name, size: 46)
                .scaleEffect(avatarScale)
                .onAppear {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.05)) {
                        avatarScale = 1
                    }
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(contact.name)
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("@\(contact.username)")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Spacer()

            // Reject
            Button(action: onReject) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.Colors.danger)
                    .frame(width: 36, height: 36)
                    .background(Theme.Colors.danger.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(SpringTapStyle(scaleAmount: 0.88))

            // Accept
            Button(action: onAccept) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Theme.Colors.accent)
                    .clipShape(Circle())
                    .shadow(color: Theme.Colors.accent.opacity(0.35), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(SpringTapStyle(scaleAmount: 0.88))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

#Preview {
    ContactsView()
}

#endif
