import SwiftUI

struct StartRollSheet: View {
    var viewModel: SessionsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode
    @State private var sessionName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showNearby = false

    // Friend picker state
    @State private var contacts: [Contact] = []
    @State private var selectedIds: Set<String>
    @State private var searchText = ""
    @State private var createTypeBeforePicker: Mode = .disposable

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Mode { case choose, disposable, lasting, friendPicker }

    init(viewModel: SessionsViewModel) {
        self.viewModel = viewModel
        self._mode = State(wrappedValue: .choose)
        self._selectedIds = State(wrappedValue: [])
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Group {
                switch mode {
                case .choose:      chooseView
                case .disposable:  createView(type: .disposable)
                case .lasting:     createView(type: .lasting)
                case .friendPicker: friendPickerView
                }
            }
            .transition(
                reduceMotion ? .opacity :
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal:   .opacity.combined(with: .move(edge: .leading))
                    )
            )
            .animation(reduceMotion ? .none : .spring(response: 0.38, dampingFraction: 0.82), value: mode)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .fullScreenCover(isPresented: $showNearby) { NearbyDiscoveryView() }
        .task { await loadContacts() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            if mode == .friendPicker {
                Button {
                    withAnimation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.75)) {
                        mode = createTypeBeforePicker
                        searchText = ""
                    }
                } label: { backIcon }
                .buttonStyle(SpringTapStyle(scaleAmount: 0.88))

                Spacer()

                Text("Add friends")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)

                Spacer()

                // Placeholder to keep title centred
                Color.clear.frame(width: 34, height: 34)
            } else {
                Spacer()
                Button {
                    if mode == .choose {
                        dismiss()
                    } else {
                        withAnimation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.75)) {
                            mode = .choose
                            sessionName = ""
                            errorMessage = nil
                        }
                    }
                } label: {
                    Image(systemName: mode == .choose ? "xmark" : "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.Colors.textMuted)
                        .frame(width: 34, height: 34)
                        .background(Theme.Colors.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(SpringTapStyle(scaleAmount: 0.88))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, mode == .friendPicker ? 12 : 0)
    }

    private var backIcon: some View {
        Image(systemName: "chevron.left")
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(Theme.Colors.textMuted)
            .frame(width: 34, height: 34)
            .background(Theme.Colors.surface)
            .clipShape(Circle())
    }

    // MARK: - Choose type

    private var chooseView: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 10)
            typeCard(icon: "bolt.fill", iconColor: Color(hex: 0xE07B39),
                     title: "Disposable circle",
                     subtitle: "One hangout. Everyone shares, then it's gone.") {
                withAnimation { mode = .disposable }
            }
            typeCard(icon: "person.3.fill", iconColor: Theme.Colors.accent,
                     title: "Lasting circle",
                     subtitle: "A standing group — your crew, always ready to roll.") {
                withAnimation { mode = .lasting }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    private func typeCard(icon: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(iconColor.opacity(0.12)).frame(width: 48, height: 48)
                    Image(systemName: icon).font(.system(size: 20)).foregroundColor(iconColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(Theme.Typography.label).foregroundColor(Theme.Colors.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.Colors.textMuted)
            }
            .padding(18)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.Colors.border, lineWidth: 0.5))
        }
        .buttonStyle(SpringTapStyle(scaleAmount: 0.97))
    }

    // MARK: - Create screen

    private func createView(type: Mode) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(type == .disposable ? "Disposable circle" : "Lasting circle")
                    .font(Theme.Typography.title).foregroundColor(Theme.Colors.textPrimary)
                Text(type == .disposable
                     ? "Names are optional — \"Saturday\" works fine."
                     : "Give your crew a name they'll recognise.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text("Name (optional)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.Colors.textMuted)
                    .padding(.horizontal, 20)
                TextField(type == .disposable ? "e.g. Friday night" : "e.g. The Crew", text: $sessionName)
                    .font(Theme.Typography.body).foregroundColor(Theme.Colors.textPrimary)
                    .padding(14)
                    .background(Theme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.border, lineWidth: 0.5))
                    .padding(.horizontal, 20)
                    .autocorrectionDisabled()
            }

            if let msg = errorMessage {
                Text(msg).font(Theme.Typography.caption).foregroundColor(Theme.Colors.danger)
                    .padding(.horizontal, 20).padding(.top, 8)
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Rectangle().fill(Theme.Colors.border).frame(height: 0.5)
                    Text("add people")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.Colors.textMuted).fixedSize()
                    Rectangle().fill(Theme.Colors.border).frame(height: 0.5)
                }
                .padding(.horizontal, 20)

                addPeopleCard(icon: "sensor.tag.radiowaves.forward.fill", iconColor: Theme.Colors.accent,
                              title: "People around",
                              subtitle: "Tap in with whoever's physically nearby right now") {
                    Task { await handleCreate(then: .nearby) }
                }

                addPeopleCard(icon: "person.2.fill", iconColor: Color(hex: 0x6B7FD4),
                              title: "Add your friends",
                              subtitle: "Invite people from your contacts") {
                    withAnimation(reduceMotion ? .none : .spring(response: 0.38, dampingFraction: 0.82)) {
                        createTypeBeforePicker = type
                        mode = .friendPicker
                    }
                    Task { await loadContacts() }
                }

                Button { Task { await handleCreate(then: .none) } } label: {
                    Group {
                        if isLoading { ProgressView().tint(Theme.Colors.accent) }
                        else {
                            Text("Create without adding people")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.Colors.accent)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Theme.Colors.accentTint)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Theme.Colors.accent.opacity(0.25), lineWidth: 1))
                    .padding(.horizontal, 20)
                }
                .buttonStyle(SpringTapStyle(scaleAmount: 0.97))
                .disabled(isLoading)
            }
            .padding(.top, 24)

            Spacer()
        }
    }

    private func addPeopleCard(icon: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(iconColor.opacity(0.12)).frame(width: 44, height: 44)
                    Image(systemName: icon).font(.system(size: 18)).foregroundColor(iconColor)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(Theme.Colors.textPrimary)
                    Text(subtitle).font(.system(size: 12, weight: .regular, design: .rounded)).foregroundColor(Theme.Colors.textSecondary)
                }
                Spacer()
                Image(systemName: "arrow.right").font(.system(size: 13, weight: .semibold)).foregroundColor(iconColor.opacity(0.7))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.border, lineWidth: 0.5))
            .padding(.horizontal, 20)
        }
        .buttonStyle(SpringTapStyle(scaleAmount: 0.97))
        .disabled(isLoading)
    }

    // MARK: - Friend picker

    private var filteredContacts: [Contact] {
        let connected = contacts.filter(\.isConnected)
        guard !searchText.isEmpty else { return connected }
        return connected.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var selectedContacts: [Contact] {
        contacts.filter { selectedIds.contains($0.id) }
    }

    private var friendPickerView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.Colors.textMuted)
                TextField("Search friends…", text: $searchText)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.Colors.textMuted)
                            .font(.system(size: 15))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.border, lineWidth: 0.5))
            .padding(.horizontal, 20)

            // Selected avatars strip
            if !selectedContacts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(selectedContacts) { contact in
                            VStack(spacing: 5) {
                                ZStack(alignment: .topTrailing) {
                                    AvatarView(name: contact.name, size: 48)
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            _ = selectedIds.remove(contact.id)
                                        }
                                    } label: {
                                        ZStack {
                                            Circle().fill(Theme.Colors.textPrimary).frame(width: 18, height: 18)
                                            Image(systemName: "xmark")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .offset(x: 5, y: -5)
                                }
                                Text(firstName(contact.name))
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.72), value: selectedContacts.map(\.id))

                Rectangle().fill(Theme.Colors.border).frame(height: 0.5).padding(.horizontal, 20)
            }

            // Contact list
            ScrollView {
                VStack(spacing: 0) {
                    if filteredContacts.isEmpty {
                        Text(contacts.isEmpty ? "Loading…" : "No friends found")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                            .padding(.top, 40)
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(filteredContacts) { contact in
                            contactRow(contact)
                        }
                    }
                }
                .padding(.bottom, 16)
            }

            // Create button
            VStack(spacing: 0) {
                Rectangle().fill(Theme.Colors.border).frame(height: 0.5)
                let canCreate = !selectedIds.isEmpty
                Button { Task { await handleCreate(then: .none) } } label: {
                    Group {
                        if isLoading { ProgressView().tint(.white) }
                        else {
                            Text(canCreate
                                 ? "Create with \(selectedIds.count) friend\(selectedIds.count == 1 ? "" : "s")"
                                 : "Select at least one friend")
                                .font(Theme.Typography.label).foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(canCreate ? Theme.Colors.accent : Theme.Colors.textMuted.opacity(0.4))
                    .clipShape(Capsule())
                    .shadow(color: Theme.Colors.accent.opacity(canCreate ? 0.28 : 0), radius: 10, x: 0, y: 4)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
                .buttonStyle(SpringTapStyle(scaleAmount: canCreate ? 0.97 : 1.0))
                .disabled(isLoading || !canCreate)
                .animation(.easeInOut(duration: 0.2), value: canCreate)
            }
            .background(Theme.Colors.background)
        }
    }

    private func contactRow(_ contact: Contact) -> some View {
        let selected = selectedIds.contains(contact.id)
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if selected { selectedIds.remove(contact.id) }
                else { selectedIds.insert(contact.id) }
            }
        } label: {
            HStack(spacing: 14) {
                AvatarView(name: contact.name, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("@\(contact.username)")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(Theme.Colors.textMuted)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(selected ? Color.clear : Theme.Colors.border, lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    Circle()
                        .fill(selected ? Theme.Colors.accent : Color.clear)
                        .frame(width: 24, height: 24)
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.7), value: selected)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .background(selected ? Theme.Colors.accentTint.opacity(0.5) : Color.clear)
            .animation(.easeInOut(duration: 0.15), value: selected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func firstName(_ name: String) -> String {
        String(name.split(separator: " ").first ?? Substring(name))
    }

    private func loadContacts() async {
        do { contacts = try await MockSupabaseService.shared.fetchContacts() } catch {}
    }

    // MARK: - Create + route

    private enum NextAction { case nearby, none }

    private func handleCreate(then next: NextAction = .none) async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await viewModel.createSession(name: sessionName)
            isLoading = false
            switch next {
            case .nearby: showNearby = true
            case .none:   dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
