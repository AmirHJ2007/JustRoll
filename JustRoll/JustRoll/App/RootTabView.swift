import SwiftUI

struct RootTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            SessionsView().tag(0)
            ContactsView().tag(1)
            UnsentView().tag(2)
            SettingsView().tag(3)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(selectedTab: $selectedTab)
        }
    }
}

// MARK: - Custom tab bar

private struct TabItemData {
    let label: String
    let outline: String
    let filled: String
}

private let tabItems: [TabItemData] = [
    TabItemData(label: "Sessions", outline: "film.stack",  filled: "film.stack.fill"),
    TabItemData(label: "Contacts", outline: "person.2",    filled: "person.2.fill"),
    TabItemData(label: "Unsent",   outline: "paperplane",  filled: "paperplane.fill"),
    TabItemData(label: "Settings", outline: "gearshape",   filled: "gearshape.fill"),
]

private struct CustomTabBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabItems.indices, id: \.self) { i in
                TabBarButton(item: tabItems[i], isSelected: selectedTab == i) {
                    selectedTab = i
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 24)
        .background(Theme.Colors.surface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

private struct TabBarButton: View {
    let item: TabItemData
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? item.filled : item.outline)
                    .font(.system(size: 22))
                    .frame(height: 24)
                Text(item.label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(isSelected ? Theme.Colors.accent : Theme.Colors.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.Colors.accentTint)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    RootTabView()
}
