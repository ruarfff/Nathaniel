//
//  HermesControlTests.swift
//  NathanielTests
//
//  Verifies Hermes follow and build controls through scene input.
//

@testable import Nathaniel
import SpriteKit
import XCTest

@MainActor
final class HermesControlTests: XCTestCase {
    func testFollowButtonStartsVisibleAndStartsFollowingOnTap() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let scene = GameScene.newGameScene()
        view.presentScene(scene)
        defer { view.presentScene(nil) }
        let hermes = try XCTUnwrap(scene.internalHermes)
        let button = try followButton(in: scene)

        XCTAssertEqual(hermes.mode, .independent)
        XCTAssertFalse(button.isHidden)
        XCTAssertTrue(self.buttonLabels(button).contains("FOLLOW"))

        scene.handleTap(at: scene.convert(.zero, from: button))

        XCTAssertEqual(hermes.mode, .following)
        XCTAssertFalse(button.isHidden)
        XCTAssertTrue(self.buttonLabels(button).contains("STOP"))
    }

    func testSelectingEitherCharacterPreservesFollowing() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let scene = GameScene.newGameScene()
        view.presentScene(scene)
        defer { view.presentScene(nil) }
        let hermes = try XCTUnwrap(scene.internalHermes)
        let nathaniel = try XCTUnwrap(scene.internalNathaniel)
        scene.setHermesMode(.following)

        scene.handleTap(at: hermes.position)

        XCTAssertEqual(hermes.mode, .following)
        XCTAssertFalse(try self.followButton(in: scene).isHidden)

        scene.handleTap(at: nathaniel.position)

        XCTAssertEqual(hermes.mode, .following)
        XCTAssertFalse(try self.followButton(in: scene).isHidden)
    }

    func testStoppingWhileHermesIsSelectedShowsBuildButton() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let scene = GameScene.newGameScene()
        view.presentScene(scene)
        defer { view.presentScene(nil) }
        let hermes = try XCTUnwrap(scene.internalHermes)
        scene.setHermesMode(.following)
        scene.handleTap(at: hermes.position)
        let button = try followButton(in: scene)

        scene.handleTap(at: scene.convert(.zero, from: button))

        XCTAssertEqual(hermes.mode, .independent)
        XCTAssertTrue(self.buttonLabels(button).contains("FOLLOW"))
        let buildButton = try XCTUnwrap(scene.internalHUD?.childNode(withName: "buildButton"))
        XCTAssertFalse(buildButton.isHidden)
    }

    func testKeyboardToggleUpdatesModeAndFollowButton() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let scene = GameScene.newGameScene()
        view.presentScene(scene)
        defer { view.presentScene(nil) }
        let hermes = try XCTUnwrap(scene.internalHermes)
        scene.handleTap(at: hermes.position)
        let button = try followButton(in: scene)

        XCTAssertTrue(scene.handleKeyDown(keyCode: 15))

        XCTAssertEqual(hermes.mode, .following)
        XCTAssertFalse(button.isHidden)
        XCTAssertTrue(self.buttonLabels(button).contains("STOP"))

        XCTAssertTrue(scene.handleKeyDown(keyCode: 15))

        XCTAssertEqual(hermes.mode, .independent)
        XCTAssertTrue(self.buttonLabels(button).contains("FOLLOW"))
    }

    private func followButton(in scene: GameScene) throws -> SKNode {
        try XCTUnwrap(scene.internalHUD?.childNode(withName: "followModeButton"))
    }

    private func buttonLabels(_ button: SKNode) -> [String] {
        button.children.compactMap { ($0 as? SKLabelNode)?.text }
    }
}
