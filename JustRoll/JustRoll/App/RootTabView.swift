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

private struct CustomTabBar: View {
    @Binding var selectedTab: Int

    private let items: [(label: String, outline: String, filled: String)] = [
        ("Sessions", "film.stack",   "film.stack.fill"),
        ("Contacts", "person.2",     "person.2.fill"),
        ("Unsent",   "paperplane",   "paperplane.fill"),
        ("Settings", "gearshape",    "gearshape.fill"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                let isSelected = selectedTab == i
                Button {
                    selectedTab = i
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: isSelected ? items[i].filled : items[i].outline)
                            .font(.system(size: 22))
                        Text(items[i].label)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(isSelected ? Theme.Colors.accent : Theme.Colors.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                }
            }
        }
        .padding(.bottom, 20)
        .background(Theme.Colors.surface.ignoresSafeArea(edges: .bottom))
        .overlay(Divider(), alignment: .top)
    }
}

#Preview {
    RootTabView()
}
