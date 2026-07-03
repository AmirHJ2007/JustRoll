import SwiftUI

// MARK: - Root

struct RootTabView: View {
    var onSignOut: () -> Void = {}
    var service: any SupabaseServiceProtocol = MockSupabaseService.shared

    @State private var selectedTab = 0
    @State private var showNearby  = false
    @State private var unsentVM: UnsentViewModel

    init(onSignOut: @escaping () -> Void = {}, service: any SupabaseServiceProtocol = MockSupabaseService.shared) {
        self.onSignOut = onSignOut
        self.service = service
        self._unsentVM = State(initialValue: UnsentViewModel(service: service))
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        ZStack {
            Theme.Colors.surface.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                SessionsView(service: service).tag(0)
                UnsentView(viewModel: unsentVM).tag(1)
                MemoryView(service: service).tag(2)
                SettingsView(service: service, onSignOut: onSignOut).tag(3)
            }
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CustomTabBar(
                    selectedTab: $selectedTab,
                    unsentBadgeCount: unsentVM.totalPhotoCount
                )
            }
        }
        .fullScreenCover(isPresented: $showNearby) {
            NearbyDiscoveryView()
        }
    }
}

// MARK: - Tab metadata

private struct TabItem {
    let label: String
    let outline: String
    let filled: String
}

private let tabItems: [TabItem] = [
    TabItem(label: "Circles",  outline: "person.3",   filled: "person.3.fill"),
    TabItem(label: "Unsent",   outline: "paperplane",  filled: "paperplane.fill"),
    TabItem(label: "Memory",   outline: "film.stack",  filled: "film.stack.fill"),
    TabItem(label: "Settings", outline: "gearshape",   filled: "gearshape.fill"),
]

// MARK: - Custom tab bar

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    var unsentBadgeCount: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Shared namespace that lets the accent pill glide smoothly between tab positions.
    @Namespace private var pillNamespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabItems.indices, id: \.self) { i in
                TabBarButton(
                    item: tabItems[i],
                    isSelected: selectedTab == i,
                    badgeCount: i == 1 ? unsentBadgeCount : 0,
                    namespace: pillNamespace,
                    reduceMotion: reduceMotion
                ) {
                    guard selectedTab != i else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(
                        reduceMotion
                            ? .none
                            : .spring(response: 0.35, dampingFraction: 0.65)
                    ) {
                        selectedTab = i
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.Colors.background)
                .shadow(color: .black.opacity(0.10), radius: 18, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Theme.Colors.border.opacity(0.6), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
    }
}

// MARK: - Tab badge

private struct TabBadge: View {
    let count: Int
    @State private var badgeScale: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if count > 0 {
            Text("\(min(count, 99))")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, count < 10 ? 4 : 5)
                .padding(.vertical, 2)
                .background(Theme.Colors.danger)
                .clipShape(Capsule())
                .scaleEffect(badgeScale)
                .onChange(of: count) { _, _ in
                    guard !reduceMotion else { return }
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.35)) { badgeScale = 1.5 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) { badgeScale = 1 }
                    }
                }
        }
    }
}

// MARK: - Individual button

private struct TabBarButton: View {
    let item: TabItem
    let isSelected: Bool
    var badgeCount: Int = 0
    var namespace: Namespace.ID
    let reduceMotion: Bool
    let action: () -> Void

    /// Incremented each time this tab becomes active, triggering the icon bounce effect.
    @State private var symbolBounce = 0

    var body: some View {
        Button(action: action) {
            // Icon (always) + label (active only) laid out horizontally inside the pill.
            // The active tab expands to fill leftover width; inactive tabs hug their icon,
            // so the label always has room and never truncates.
            HStack(spacing: 6) {

                // Icon with badge overlay anchored to its top-trailing corner
                ZStack(alignment: .topTrailing) {
                    Image(systemName: isSelected ? item.filled : item.outline)
                        .font(.system(size: 17, weight: .medium))
                        // Bounce fires when symbolBounce increments (only on becoming active)
                        .symbolEffect(.bounce, value: reduceMotion ? 0 : symbolBounce)

                    if badgeCount > 0 {
                        TabBadge(count: badgeCount)
                            .offset(x: 8, y: -7)
                    }
                }

                // Label slides in when active, fades out on deselect
                if isSelected {
                    Text(item.label)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .fixedSize()
                        .transition(
                            reduceMotion
                                ? .identity
                                : .asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.8, anchor: .leading)),
                                    removal:   .opacity
                                )
                        )
                }
            }
            .foregroundColor(isSelected ? .white : Theme.Colors.textMuted)
            .padding(.horizontal, 14)
            .frame(height: 44)                                   // fixed height — keeps the bar compact
            .frame(maxWidth: isSelected ? .infinity : nil)       // active tab stretches, inactive hug
            .background {
                // Accent pill — matchedGeometryEffect animates it gliding between tab positions.
                // The underdamped spring (dampingFraction 0.65) gives it a playful overshoot.
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(Theme.Colors.accent)
                        .matchedGeometryEffect(id: "activePill", in: namespace)
                }
            }
        }
        .buttonStyle(.plain)
        // Trigger bounce on the icon the moment this tab becomes active
        .onChange(of: isSelected) { _, newValue in
            guard newValue, !reduceMotion else { return }
            symbolBounce += 1
        }
    }
}

#Preview {
    RootTabView()
}
