import SwiftUI
import AVFoundation
import UIKit
import UserNotifications

// MARK: - AppDelegate (background URL session + push registration)

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Delegate must be set before launch finishes so a tap on a push that
        // launched the app is still routed to the right tab.
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hexToken = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { try? await SupabaseService.shared.registerDeviceToken(hexToken) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Expected on simulators / without the push entitlement — local
        // notifications (nudge, unsent reminder) still work regardless.
        print("APNs registration failed: \(error.localizedDescription)")
    }

    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

@main
struct JustRollApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        configureAppearance()
    }

    @State private var currentUser: User?
    @State private var sessionRestored = false
    @State private var videoPlayedOnce = false

    private let service: any SupabaseServiceProtocol = SupabaseService.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if !sessionRestored || !videoPlayedOnce {
                    SplashView(onVideoPlayedOnce: { videoPlayedOnce = true })
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
            .preferredColorScheme(.light)   // light-only design — dark mode flips dynamic text to white on light backgrounds
            .animation(.easeInOut(duration: 0.35), value: sessionRestored && videoPlayedOnce)
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

// MARK: - Splash screen

private struct SplashView: View {
    var onVideoPlayedOnce: () -> Void = {}
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            // Matched to the video's background color (#567543, sampled from first frame)
            Color(hex: 0x567543).ignoresSafeArea()

            if let player {
                SplashVideoPlayer(player: player)
                    .frame(width: 280, height: 280)
            }
        }
        .onAppear { setupPlayer() }
        .onDisappear { player?.pause() }
    }

    private func setupPlayer() {
        guard let asset = NSDataAsset(name: "loading_page") else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("justroll_splash.mp4")
        try? asset.data.write(to: url, options: .atomic)
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.isMuted = true
        var playedOnce = false
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            if !playedOnce {
                playedOnce = true
                onVideoPlayedOnce()  // signal: at least one full play done
            }
            p.seek(to: .zero)
            p.play()  // keep looping until parent dismisses
        }
        player = p
        p.play()
    }
}

// UIView subclass whose layer IS an AVPlayerLayer — resizes automatically.
private final class SplashPlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            playerLayer.videoGravity = .resizeAspect
        }
    }
}

private struct SplashVideoPlayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> SplashPlayerUIView {
        let view = SplashPlayerUIView()
        view.player = player
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: SplashPlayerUIView, context: Context) {}
}
