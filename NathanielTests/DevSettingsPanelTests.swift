//
//  DevSettingsPanelTests.swift
//  NathanielTests
//
//  Checks developer panel input state during interrupted dismissals.
//

@testable import Nathaniel
import SpriteKit
import XCTest

@MainActor
final class DevSettingsPanelTests: XCTestCase {
    func testDismissalStopsInputImmediatelyAndReopeningCancelsOldCompletion() async throws {
        let frame = CGRect(x: 0, y: 0, width: 800, height: 480)
        let view = SKView(frame: frame)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = view
        let scene = SKScene(size: frame.size)
        let panel = DevSettingsPanel(size: frame.size)
        scene.addChild(panel)
        view.presentScene(scene)
        window.orderFront(nil)
        defer {
            view.presentScene(nil)
            window.orderOut(nil)
        }
        panel.show()
        var obsoleteCompletion = false
        panel.hide { obsoleteCompletion = true }

        XCTAssertFalse(panel.isVisible)
        XCTAssertFalse(panel.handleTouch(at: .zero))
        panel.show()
        try await Task.sleep(for: .seconds(0.6))

        XCTAssertTrue(panel.isVisible)
        XCTAssertFalse(panel.isHidden)
        XCTAssertFalse(obsoleteCompletion)
    }
}
