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
    TabItem(label: "Circles", outline: "person.3",    filled: "person.3.fill"),
    TabItem(label: "Unsent",  outline: "paperplane",  filled: "paperplane.fill"),
    TabItem(label: "Memory",  outline: "film.stack",  filled: "film.stack.fill"),
    TabItem(label: "Settings", outline: "gearshape", filled: "gearshape.fill"),
]

// MARK: - Custom tab bar

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    var unsentBadgeCount: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabItems.indices, id: \.self) { i in
                TabBarButton(
                    item: tabItems[i],
                    isSelected: selectedTab == i,
                    badgeCount: i == 1 ? unsentBadgeCount : 0,
                    reduceMotion: reduceMotion
                ) { selectedTab = i }
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(Theme.Colors.border.opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 2)
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
    let reduceMotion: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Theme.Colors.accentTint)
                            .frame(width: 40, height: 26)
                            .scaleEffect(isSelected ? 1 : 0.65)
                            .opacity(isSelected ? 1 : 0)

                        Image(systemName: isSelected ? item.filled : item.outline)
                            .font(.system(size: 20))
                            .scaleEffect(isSelected ? 1.1 : 1.0)
                    }
                    .frame(width: 40, height: 26)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.6),
                        value: isSelected
                    )

                    if badgeCount > 0 {
                        TabBadge(count: badgeCount)
                            .offset(x: 10, y: -7)
                    }
                }

                Text(item.label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .animation(nil, value: isSelected)
            }
            .foregroundColor(isSelected ? Theme.Colors.accent : Theme.Colors.textMuted)
            .animation(
                reduceMotion ? .none : .easeInOut(duration: 0.18),
                value: isSelected
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RootTabView()
}
