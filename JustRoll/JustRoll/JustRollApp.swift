import SwiftUI

@main
struct JustRollApp: App {

    init() {
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }

    private func configureAppearance() {
        let bg = UIColor(Theme.Colors.background)
        let surface = UIColor(Theme.Colors.surface)
        let white = UIColor.white
        let textMuted = UIColor(Theme.Colors.textMuted)

        // Navigation bar — olive background, white title/buttons
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = bg
        navAppearance.titleTextAttributes          = [.foregroundColor: white]
        navAppearance.largeTitleTextAttributes     = [.foregroundColor: white]
        navAppearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance   = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance    = navAppearance
        UINavigationBar.appearance().tintColor            = white

        // Tab bar — olive background, white selected / muted unselected
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = surface

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.selected.iconColor    = white
        itemAppearance.selected.titleTextAttributes   = [.foregroundColor: white]
        itemAppearance.normal.iconColor      = textMuted
        itemAppearance.normal.titleTextAttributes     = [.foregroundColor: textMuted]
        tabAppearance.stackedLayoutAppearance   = itemAppearance
        tabAppearance.inlineLayoutAppearance    = itemAppearance
        tabAppearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance   = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // List / table view backgrounds
        UITableView.appearance().backgroundColor = bg
        UITableViewCell.appearance().backgroundColor = .clear
    }
}
