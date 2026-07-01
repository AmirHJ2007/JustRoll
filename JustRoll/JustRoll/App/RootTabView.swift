import SwiftUI

// MARK: - Root

struct RootTabView: View {
    @State private var selectedTab  = 0
    @State private var showNearby   = true

    init() {
        // .toolbar(.hidden, for: .tabBar) alone is insufficient on iOS 26 —
        // the new liquid-glass tab bar still renders. Suppress it globally.
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        ZStack {
            // Single surface colour bleeds into every safe area — no seam anywhere.
            Theme.Colors.surface.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                ContactsView().tag(0)
                UnsentView().tag(1)
                SessionsView().tag(2)
                SettingsView().tag(3)
            }
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CustomTabBar(selectedTab: $selectedTab)
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
    TabItem(label: "Contacts", outline: "person.2",   filled: "person.2.fill"),
    TabItem(label: "Unsent",   outline: "paperplane", filled: "paperplane.fill"),
    TabItem(label: "Sessions", outline: "film.stack", filled: "film.stack.fill"),
    TabItem(label: "Settings", outline: "gearshape",  filled: "gearshape.fill"),
]

// MARK: - Custom tab bar

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabItems.indices, id: \.self) { i in
                TabBarButton(
                    item: tabItems[i],
                    isSelected: selectedTab == i,
                    reduceMotion: reduceMotion
                ) { selectedTab = i }
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 6)
        // Clip to shape FIRST so the shadow follows the rounded pill, not the rectangular frame.
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(Theme.Colors.border.opacity(0.5), lineWidth: 0.5)
        )
        // Small y-offset + generous blur = soft, even shadow; no corner blobs.
        .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 2)
        .padding(.horizontal, 22)
        // 12 pt gives the shadow room below before the home-indicator area.
        .padding(.bottom, 12)
    }
}

// MARK: - Individual button

private struct TabBarButton: View {
    let item: TabItem
    let isSelected: Bool
    let reduceMotion: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack {
                    // Highlight capsule: animates fill/opacity per tap.
                    // No matchedGeometryEffect — avoids ghost-pill rendering bugs.
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
