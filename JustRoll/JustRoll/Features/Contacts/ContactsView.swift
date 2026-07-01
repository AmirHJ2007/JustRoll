import SwiftUI

// MARK: - Scroll offset key (pull-to-refresh)

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
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
    private var connected: [Contact]    { filtered.filter(\.isConnected) }
    private var notConnected: [Contact] { filtered.filter { !$0.isConnected } }

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
            subtitle: viewModel.contacts.isEmpty ? nil : "\(connected.count) \(connected.count == 1 ? "friend" : "friends") on JustRoll",
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
                        .foregroundColor(Theme.Colors.accent)
                        .frame(width: 40, height: 40)
                        .background(Theme.Colors.accentTint)
                        .clipShape(Circle())
                }
                .scaleEffect(reduceMotion ? 1 : addBtnScale)
                .padding(.top, 4)
            },
            footer: {
                if !connected.isEmpty && searchText.isEmpty {
                    crewStrip
                }
                searchBar
            }
        )
    }

    // MARK: - Crew strip

    private var crewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(Array(connected.enumerated()), id: \.element.id) { idx, contact in
                    VStack(spacing: 6) {
                        AvatarView(name: contact.name, size: 46)
                        Text(contact.name.components(separatedBy: " ").first ?? contact.name)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(width: 52)
                    .opacity(listVisible ? 1 : 0)
                    .offset(x: listVisible ? 0 : 12)
                    .animation(
                        reduceMotion ? .none :
                            .spring(response: 0.45, dampingFraction: 0.8)
                            .delay(0.05 + Double(idx) * 0.05),
                        value: listVisible
                    )
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

                VStack(spacing: 24) {
                    if !connected.isEmpty {
                        contactSection(title: "On JustRoll",
                                       contacts: connected,
                                       globalOffset: 0,
                                       muted: false)
                    }
                    if !notConnected.isEmpty {
                        contactSection(title: "Invite them",
                                       contacts: notConnected,
                                       globalOffset: connected.count,
                                       muted: true)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
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

    // MARK: - Section builder

    private func contactSection(
        title: String,
        contacts: [Contact],
        globalOffset: Int,
        muted: Bool
    ) -> some View {
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
                    let delay = Double(globalOffset + idx) * 0.04

                    ContactRowView(
                        contact: contact,
                        animationDelay: delay
                    ) {
                        viewModel.showAddSheet = true
                    } onRemove: {
                        Task { await viewModel.removeContact(contact) }
                    }
                    .padding(.horizontal, 16)
                    .background(muted ? Theme.Colors.background.opacity(0.92) : Theme.Colors.background)
                    // Stagger entrance
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
            .background(muted ? Theme.Colors.surface : Theme.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(muted ? Theme.Colors.border : Color.clear, lineWidth: 0.5)
            )
            .shadow(color: muted ? .clear : .black.opacity(0.04), radius: 8, x: 0, y: 2)
            .opacity(muted ? 0.85 : 1)
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
                            showFilmDrop = true          // 🎞 celebrate
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

#Preview {
    ContactsView()
}
