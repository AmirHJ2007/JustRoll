import SwiftUI

struct StartRollSheet: View {
    var viewModel: SessionsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode
    @State private var sessionName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showNearby = false

    // MARK: - Friend picker state (disabled — re-enable with contacts feature)
    // @State private var contacts: [Contact] = []
    // @State private var selectedIds: Set<String>
    // @State private var searchText = ""
    // @State private var createTypeBeforePicker: Mode = .disposable

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Mode { case choose, disposable, lasting }
    // friendPicker case removed — re-enable with contacts feature

    init(viewModel: SessionsViewModel) {
        self.viewModel = viewModel
        self._mode = State(wrappedValue: .choose)
        // self._selectedIds = State(wrappedValue: [])
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Group {
                switch mode {
                case .choose:     chooseView
                case .disposable: createView(type: .disposable)
                case .lasting:    createView(type: .lasting)
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
        // .task { await loadContacts() }  // contacts feature disabled
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
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
        .padding(.horizontal, 20)
        .padding(.top, 18)
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

                // "Add your friends" card disabled — re-enable with contacts feature
                // addPeopleCard(icon: "person.2.fill", iconColor: Color(hex: 0x6B7FD4),
                //               title: "Add your friends",
                //               subtitle: "Invite people from your contacts") {
                //     withAnimation(...) { mode = .friendPicker }
                // }

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

    // MARK: - Friend picker (disabled — re-enable with contacts feature)
    //
    // private var filteredContacts: [Contact] { ... }
    // private var selectedContacts: [Contact] { ... }
    // private var friendPickerView: some View { ... }
    // private func contactRow(_ contact: Contact) -> some View { ... }
    // private func firstName(_ name: String) -> String { ... }
    // private func loadContacts() async { ... }

    // MARK: - Create + route

    private enum NextAction { case nearby, none }

    private func handleCreate(then next: NextAction = .none) async {
        isLoading = true
        errorMessage = nil
        do {
            let kind: SessionKind = mode == .lasting ? .lasting : .disposable
            _ = try await viewModel.createSession(
                name: sessionName,
                kind: kind,
                invitedContacts: []  // contacts feature disabled
            )
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
