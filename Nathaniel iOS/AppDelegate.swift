//
//  AppDelegate.swift
//  Nathaniel iOS
//
//  Created by Ruairi O'Brien on 11/29/25.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Override point for customization after application launch.

        #if DEBUG
            // Start the game command server for agent testing
            GameCommandServer.shared.start()
            print("[AppDelegate] GameCommandServer started on port 8765")
        #endif

        return true
    }

    // MARK: - Orientation Support

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        // Force landscape for this game
        .landscape
    }
}
