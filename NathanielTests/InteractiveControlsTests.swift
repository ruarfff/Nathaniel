//
//  InteractiveControlsTests.swift
//  NathanielTests
//
//  Verifies that visible controls can be discovered and tapped in scene coordinates.
//

@testable import Nathaniel
import SpriteKit
import XCTest

@MainActor
final class InteractiveControlsTests: XCTestCase {
    func testHUDTapUsesHUDCoordinatesAtEveryZoom() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let scene = GameScene.newGameScene()
        view.presentScene(scene)
        defer { view.presentScene(nil) }
        let hud = try XCTUnwrap(scene.internalHUD)
        let pause = try XCTUnwrap(hud.childNode(withName: "pauseButton"))
        let level = try XCTUnwrap(scene.internalLevelManager)

        for zoom: CGFloat in [0.5, 1, 2] {
            scene.setZoom(zoom)
            XCTAssertTrue(scene.injectTap(at: scene.convert(.zero, from: pause)))
            XCTAssertEqual(level.state, .paused, "zoom \(zoom)")
            scene.resumeGame()
        }
    }

    func testNamedHUDAndModalControlsMatchTheirInputTargets() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let scene = GameScene.newGameScene()
        view.presentScene(scene)
        defer { view.presentScene(nil) }
        let hermes = try XCTUnwrap(scene.internalHermes)
        scene.setZoom(2)
        let initialMode = hermes.mode
        try self.tap("followModeButton", in: scene)
        XCTAssertNotEqual(hermes.mode, initialMode)
        try self.tap("pauseButton", in: scene)
        XCTAssertEqual(scene.internalLevelManager?.state, .paused)
        XCTAssertFalse(scene.getInteractiveNodes().contains { $0.name == "nathaniel" })
        try self.tap("settingsButton", in: scene)
        let settingsNames = Set(scene.getInteractiveNodes().map(\.name))
        XCTAssertTrue(settingsNames.isSuperset(of: ["soundEffectsToggle", "musicToggle", "backButton"]))
        XCTAssertFalse(settingsNames.contains("resumeButton"))
        _ = scene.handleKeyDown(keyCode: 53)
        try self.tap("saveGameButton", in: scene)
        XCTAssertEqual(Set(scene.getInteractiveNodes().map(\.name)), ["slot_1", "slot_2", "slot_3", "cancelButton"])
        _ = scene.handleKeyDown(keyCode: 53)
        try self.tap("exitToMenuButton", in: scene)
        XCTAssertEqual(Set(scene.getInteractiveNodes().map(\.name)), ["cancelExit", "confirmExit"])
        try self.tap("cancelExit", in: scene)
        XCTAssertFalse(try XCTUnwrap(scene.internalPauseMenu).isShowingConfirmation)
    }

    func testNamedBackTargetsTheNestedDeveloperPanel() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let scene = GameScene.newGameScene()
        view.presentScene(scene)
        defer { view.presentScene(nil) }
        scene.showSettings()
        let settings = try XCTUnwrap(scene.internalSettingsMenu)
        let developerPanel = try XCTUnwrap(settings.children.compactMap { $0 as? DevSettingsPanel }.first)
        try self.tap("devSettingsButton", in: scene)
        XCTAssertTrue(developerPanel.isVisible)
        XCTAssertTrue(scene.getInteractiveNodes().contains { $0.name == "tab_Player" })

        try self.tap("backButton", in: scene)

        XCTAssertFalse(developerPanel.isVisible)
        XCTAssertTrue(settings.isVisible)
        XCTAssertEqual(scene.internalLevelManager?.state, .paused)
    }

    func testBuildMenuExportsTowerDragTargets() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let scene = GameScene.newGameScene()
        view.presentScene(scene)
        defer { view.presentScene(nil) }
        _ = scene.handleKeyDown(keyCode: 49)
        try self.tap("buildButton", in: scene)
        XCTAssertTrue(scene.isBuildMenuVisible)
        for tower in TowerType.allCases {
            XCTAssertTrue(scene.getInteractiveNodes().contains { $0.name == "buildMenuItem_\(tower.rawValue)" })
        }
    }

    func testMainMenuExportsOnlyLoadSelectorWhileItIsOpen() async throws {
        let frame = CGRect(x: 0, y: 0, width: 800, height: 480)
        let view = SKView(frame: frame)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = view
        let scene = MainMenuScene.newMenuScene()
        view.presentScene(scene)
        window.orderFront(nil)
        defer {
            view.presentScene(nil)
            window.orderOut(nil)
        }
        let selector = try XCTUnwrap(scene.children.compactMap { $0 as? SaveSlotSelector }.first)
        selector.show(mode: .load)
        XCTAssertEqual(Set(scene.getInteractiveNodes().map(\.name)), ["slot_1", "slot_2", "slot_3", "cancelButton"])
        let cancelled = expectation(description: "Named cancel reaches the load selector")
        selector.onCancel = { cancelled.fulfill() }
        try self.tap("cancelButton", in: scene)
        await fulfillment(of: [cancelled], timeout: 3)
        XCTAssertTrue(scene.getInteractiveNodes().contains { $0.name == "startButton" })
    }

    private func tap(_ name: String, in scene: SKScene & GameCommandDelegate) throws {
        let node = try XCTUnwrap(scene.getInteractiveNodes().first { $0.name == name }, name)
        XCTAssertTrue(scene.injectTap(at: CGPoint(
            x: node.frame.x + node.frame.width / 2,
            y: node.frame.y + node.frame.height / 2
        )))
    }
}
