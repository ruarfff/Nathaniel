//
//  MenuStateTests.swift
//  NathanielTests
//
//  Verifies modal navigation and result presentation through scene input.
//

@testable import Nathaniel
import SpriteKit
import XCTest

@MainActor
final class MenuStateTests: XCTestCase {
    func testEscapeClosesSettingsBeforeResuming() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let scene = GameScene.newGameScene()
        view.presentScene(scene)
        defer { view.presentScene(nil) }
        let level = try XCTUnwrap(scene.internalLevelManager)

        scene.pauseGame()
        XCTAssertTrue(scene.executeAction(name: "openSettings", params: nil).success)
        XCTAssertTrue(scene.handleKeyDown(keyCode: 53))

        XCTAssertEqual(level.state, .paused)
        XCTAssertFalse(try XCTUnwrap(scene.internalSettingsMenu).isVisible)
        XCTAssertTrue(try XCTUnwrap(scene.internalPauseMenu).isVisible)
        XCTAssertTrue(scene.handleKeyDown(keyCode: 53))
        XCTAssertEqual(level.state, .playing)
        XCTAssertFalse(try XCTUnwrap(scene.internalPauseMenu).isVisible)
    }

    func testCommandsPauseForMenusAndResumeClearsEveryMenu() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let scene = GameScene.newGameScene()
        view.presentScene(scene)
        defer { view.presentScene(nil) }
        let level = try XCTUnwrap(scene.internalLevelManager)

        for action in ["openSettings", "showSaveSlotSelector"] {
            XCTAssertTrue(scene.executeAction(name: action, params: nil).success)
            XCTAssertEqual(level.state, .paused, action)
            XCTAssertFalse(scene.handleSecondaryClick(at: CGPoint(x: 500, y: 300)))
            scene.resumeGame()
            XCTAssertEqual(level.state, .playing)
            XCTAssertFalse(try XCTUnwrap(scene.internalPauseMenu).isVisible)
            XCTAssertFalse(try XCTUnwrap(scene.internalSettingsMenu).isVisible)
            XCTAssertFalse(try XCTUnwrap(scene.internalSaveSlotSelector).isVisible)
        }
    }

    func testPointerMenuActionsTakeEffectBeforeAnimationsFinish() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let scene = GameScene.newGameScene()
        view.presentScene(scene)
        defer { view.presentScene(nil) }
        scene.pauseGame()
        let pause = try XCTUnwrap(scene.internalPauseMenu)
        let resume = try XCTUnwrap(pause.menuPanel?.childNode(withName: "resumeButton"))
        _ = scene.handlePointerDown(at: scene.convert(.zero, from: resume))
        XCTAssertEqual(scene.internalLevelManager?.state, .playing)

        scene.showSettings()
        let settings = try XCTUnwrap(scene.internalSettingsMenu)
        let back = try XCTUnwrap(settings.menuPanel?.childNode(withName: "backButton"))
        _ = scene.handlePointerDown(at: scene.convert(.zero, from: back))
        XCTAssertFalse(settings.isVisible)
        _ = scene.handleKeyDown(keyCode: 53)
        XCTAssertEqual(scene.internalLevelManager?.state, .playing)
    }

    func testTerminalResultCannotBeReplacedByAMenu() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let scene = GameScene.newGameScene()
        view.presentScene(scene)
        defer { view.presentScene(nil) }
        let level = try XCTUnwrap(scene.internalLevelManager)
        level.triggerGameOver()

        _ = scene.executeAction(name: "openSettings", params: nil)
        _ = scene.executeAction(name: "showSaveSlotSelector", params: nil)
        scene.resumeGame()

        XCTAssertEqual(level.state, .gameOver)
        XCTAssertFalse(try XCTUnwrap(scene.internalSettingsMenu).isVisible)
        XCTAssertFalse(try XCTUnwrap(scene.internalSaveSlotSelector).isVisible)
    }

    func testOldLifeLossAnimationCannotHideTerminalResult() async throws {
        let frame = CGRect(x: 0, y: 0, width: 800, height: 480)
        let view = SKView(frame: frame)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = view
        let scene = SKScene(size: frame.size)
        view.presentScene(scene)
        window.orderFront(nil)
        defer {
            view.presentScene(nil)
            window.orderOut(nil)
        }
        let victory = GameOverlay(size: frame.size)
        let gameOver = GameOverlay(size: frame.size)
        scene.addChild(victory)
        scene.addChild(gameOver)
        victory.showLifeLost(remainingLives: 1)
        gameOver.showLifeLost(remainingLives: 1)
        victory.showVictory(score: 10, time: 1, hasNextLevel: true)
        gameOver.showGameOver(score: 10, time: 1)
        var didContinue = false
        var didRetry = false
        victory.onNextLevel = { didContinue = true }
        gameOver.onRetry = { didRetry = true }

        try await Task.sleep(for: .seconds(2.5))

        XCTAssertEqual(victory.state, .victory)
        XCTAssertEqual(gameOver.state, .gameOver)
        XCTAssertFalse(victory.isHidden)
        XCTAssertFalse(gameOver.isHidden)
        victory.handleInteraction()
        gameOver.handleInteraction()
        XCTAssertTrue(didContinue)
        XCTAssertTrue(didRetry)
    }

    func testReopeningMenuCancelsOldDismissal() async throws {
        let frame = CGRect(x: 0, y: 0, width: 800, height: 480)
        let view = SKView(frame: frame)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = view
        let scene = SKScene(size: frame.size)
        let menu = PauseMenu(size: frame.size)
        scene.addChild(menu)
        view.presentScene(scene)
        window.orderFront(nil)
        defer {
            view.presentScene(nil)
            window.orderOut(nil)
        }
        menu.show()
        var obsoleteCompletion = false
        menu.hide { obsoleteCompletion = true }
        menu.show()

        try await Task.sleep(for: .seconds(0.6))

        XCTAssertTrue(menu.isVisible)
        XCTAssertFalse(menu.isHidden)
        XCTAssertFalse(obsoleteCompletion)
    }
}
