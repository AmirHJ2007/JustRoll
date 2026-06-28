import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            SessionsView()
                .tabItem { Label("Sessions", systemImage: "film.stack") }

            ContactsView()
                .tabItem { Label("Contacts", systemImage: "person.2") }

            UnsentView()
                .tabItem { Label("Unsent", systemImage: "paperplane") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.Colors.accent)
        .toolbarBackground(Theme.Colors.surface, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
    }
}

#Preview {
    RootTabView()
}
