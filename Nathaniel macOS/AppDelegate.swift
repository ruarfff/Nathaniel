//
//  AppDelegate.swift
//  Nathaniel macOS
//
//  Created by Ruairi O'Brien on 11/29/25.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if SmokeTestRunner.isEnabled {
            let exitCode = SmokeTestRunner.runForProcessExit()
            exit(exitCode)
        }

        #if DEBUG
        // Start the game command server for agent testing
        GameCommandServer.shared.start()
        print("[AppDelegate] GameCommandServer started on port 8765")
        #endif
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }


}
