import SwiftUI

@main
struct JustRollApp: App {

    init() {
        configureAppearance()
    }

    @State private var currentUser: User?
    @State private var sessionRestored = false

    private let service: any SupabaseServiceProtocol = SupabaseService.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if !sessionRestored {
                    Color(Theme.Colors.background).ignoresSafeArea()
                } else if currentUser != nil {
                    RootTabView(
                        onSignOut: {
                            withAnimation(.easeInOut(duration: 0.35)) { currentUser = nil }
                        },
                        service: service
                    )
                    .transition(.opacity)
                } else {
                    AuthView(service: service) { user in
                        withAnimation(.easeInOut(duration: 0.35)) { currentUser = user }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: sessionRestored)
            .animation(.easeInOut(duration: 0.35), value: currentUser != nil)
            .task {
                let user = await service.restoreSession()
                withAnimation(.easeInOut(duration: 0.35)) {
                    currentUser = user
                    sessionRestored = true
                }
            }
        }
    }

    private func configureAppearance() {
        let oliveColor = UIColor(red: 94/255, green: 125/255, blue: 79/255, alpha: 1) // #5E7D4F

        // Navigation bar — system light appearance, olive tint for buttons/back
        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        nav.shadowColor = UIColor(red: 227/255, green: 230/255, blue: 227/255, alpha: 1)
        UINavigationBar.appearance().standardAppearance   = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance    = nav
        UINavigationBar.appearance().tintColor            = oliveColor

        // Tab bar — olive tint for selected item
        UITabBar.appearance().tintColor         = oliveColor
        UITabBar.appearance().unselectedItemTintColor = UIColor(red: 154/255, green: 160/255, blue: 156/255, alpha: 1)

        // List backgrounds
        UITableView.appearance().backgroundColor     = .clear
        UITableViewCell.appearance().backgroundColor = .clear
    }
}
