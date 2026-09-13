//
//  GameCommandDispatchTests.swift
//  NathanielTests
//
//  Verifies scene registration and game actions used by the command server.
//

@testable import Nathaniel
import SpriteKit
import XCTest

@MainActor
final class GameCommandDispatchTests: XCTestCase {
    func testScenesRegisterThemselvesWithTheCommandServer() {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        defer { view.presentScene(nil) }
        let scenes: [SKScene & GameCommandDelegate] = [
            MainMenuScene.newMenuScene(),
            LevelSelectScene.newLevelSelectScene(),
            OptionsScene.newOptionsScene(),
            CreditsScene.newCreditsScene(),
            GameScene.newGameScene(),
        ]

        for scene in scenes {
            view.presentScene(scene)
            XCTAssertTrue(GameCommandServer.shared.delegate === scene)
        }
    }

    func testActionsDispatchToTheCurrentScene() async throws {
        let frame = CGRect(x: 0, y: 0, width: 800, height: 480)
        let view = SKView(frame: frame)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = view
        let scene = GameScene.newGameScene()
        view.presentScene(scene)
        window.orderFront(nil)
        defer {
            view.presentScene(nil)
            window.orderOut(nil)
        }
        let hermes = try XCTUnwrap(scene.internalHermes)
        let level = try XCTUnwrap(scene.internalLevelManager)

        for action in ["selectHermes", "getTowerInfo", "getCurrentSettings", "getSaveSlots", "getCombatState"] {
            XCTAssertTrue(scene.executeAction(name: action, params: nil).success, action)
        }

        XCTAssertTrue(scene.executeAction(name: "setHermesMode", params: ["mode": "following"]).success)
        XCTAssertEqual(hermes.mode, .following)

        XCTAssertTrue(scene.executeAction(name: "showPauseMenu", params: nil).success)
        XCTAssertEqual(level.state, .paused)
        let resumed = expectation(
            for: NSPredicate { _, _ in level.state == .playing },
            evaluatedWith: nil
        )
        XCTAssertTrue(scene.executeAction(name: "hidePauseMenu", params: nil).success)
        await fulfillment(of: [resumed], timeout: 3)
        XCTAssertEqual(level.state, .playing)

        let unknown = scene.executeAction(name: "missingAction", params: nil)
        XCTAssertFalse(unknown.success)
        XCTAssertEqual(unknown.error, "Unknown action: missingAction")
    }
}
