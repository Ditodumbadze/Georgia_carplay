import UIKit
import SwiftUI

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        _ = AudioPlayer.shared   // ბრძანებების ცენტრი ადრევე დარეგისტრირდეს
        return true
    }
    // სცენების კონფიგურაცია (Phone და CarPlay) Info.plist-შია — UIApplicationSceneManifest
}

/// ტელეფონის ეკრანი
final class PhoneSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: PhoneView())
        window.makeKeyAndVisible()
        self.window = window
    }
}
