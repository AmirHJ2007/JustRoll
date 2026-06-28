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
