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
        // Explicit UIColor values — avoids SwiftUI Color conversion issues
        let bgColor      = UIColor(red: 58/255,  green: 85/255,  blue: 48/255,  alpha: 1) // #3A5530
        let surfaceColor = UIColor(red: 94/255,  green: 125/255, blue: 79/255,  alpha: 1) // #5E7D4F
        let mutedColor   = UIColor(red: 135/255, green: 168/255, blue: 122/255, alpha: 1) // #87A87A

        // MARK: Navigation bar
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor                = bgColor
        nav.shadowColor                    = .clear
        nav.titleTextAttributes            = [.foregroundColor: UIColor.white]
        nav.largeTitleTextAttributes       = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance   = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance    = nav
        UINavigationBar.appearance().tintColor            = .white

        // MARK: Tab bar
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = surfaceColor
        tab.shadowColor     = .clear

        let item = UITabBarItemAppearance()
        item.selected.iconColor = .white
        item.selected.titleTextAttributes   = [.foregroundColor: UIColor.white]
        item.normal.iconColor   = mutedColor
        item.normal.titleTextAttributes     = [.foregroundColor: mutedColor]

        tab.stackedLayoutAppearance      = item
        tab.inlineLayoutAppearance       = item
        tab.compactInlineLayoutAppearance = item

        UITabBar.appearance().standardAppearance   = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        // MARK: List / table
        UITableView.appearance().backgroundColor     = bgColor
        UITableViewCell.appearance().backgroundColor = .clear
    }
}
