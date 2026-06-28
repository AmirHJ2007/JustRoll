import SwiftUI

struct RootTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            SessionsView()
                .tabItem { Label("Sessions", systemImage: selectedTab == 0 ? "film.stack.fill" : "film.stack") }
                .tag(0)

            ContactsView()
                .tabItem { Label("Contacts", systemImage: selectedTab == 1 ? "person.2.fill" : "person.2") }
                .tag(1)

            UnsentView()
                .tabItem { Label("Unsent", systemImage: selectedTab == 2 ? "paperplane.fill" : "paperplane") }
                .tag(2)

            SettingsView()
                .tabItem { Label("Settings", systemImage: selectedTab == 3 ? "gearshape.fill" : "gearshape") }
                .tag(3)
        }
        .tint(Theme.Colors.accent)
        .toolbarBackground(Theme.Colors.surface, for: .tabBar)
        .toolbarColorScheme(.light, for: .tabBar)
    }
}

#Preview {
    RootTabView()
}
