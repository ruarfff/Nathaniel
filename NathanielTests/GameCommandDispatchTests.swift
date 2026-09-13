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

    func testSetupCanLoadALevelWithoutMenuNavigation() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let menu = MainMenuScene.newMenuScene()
        view.presentScene(menu)
        defer { view.presentScene(nil) }
        XCTAssertTrue(menu.executeAction(name: "loadLevel", params: ["level": "2"]).success)
        let scene = try XCTUnwrap(view.scene as? GameScene)
        XCTAssertEqual(scene.internalLevelManager?.config.levelNumber, 2)
        XCTAssertTrue(GameCommandServer.shared.delegate === scene)
        XCTAssertFalse(scene.executeAction(name: "loadLevel", params: ["level": "99"]).success)
        XCTAssertTrue(view.scene === scene)
        XCTAssertTrue(scene.executeAction(name: "mainMenu", params: nil).success)
        XCTAssertTrue(view.scene is MainMenuScene)
    }

    func testSetupActionsAndState() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let scene = GameScene.newGameScene(levelConfig: .survival)
        view.presentScene(scene)
        defer { view.presentScene(nil) }
        let hermes = try XCTUnwrap(scene.internalHermes)
        let player = try XCTUnwrap(scene.internalNathaniel)
        let enemies = try XCTUnwrap(scene.internalEnemyManager)
        let count = enemies.aliveCount
        XCTAssertTrue(scene.executeAction(name: "spawnEnemy", params: ["type": "grunt", "x": "100", "y": "100"])
            .success)
        XCTAssertEqual(enemies.aliveCount, count + 1)
        XCTAssertFalse(scene.executeAction(name: "spawnEnemy", params: ["type": "grunt", "x": "nan", "y": "100"])
            .success)
        XCTAssertEqual(enemies.aliveCount, count + 1)
        player.currentHP = 1
        hermes.currentHP = 1
        XCTAssertTrue(scene.executeAction(name: "healPlayer", params: nil).success)
        XCTAssertEqual(player.currentHP, player.maxHP)
        XCTAssertEqual(hermes.currentHP, hermes.maxHP)
        let resources = ResourceManager.shared.totalCollected
        XCTAssertTrue(scene.executeAction(name: "addResources", params: ["amount": "10"]).success)
        XCTAssertEqual(ResourceManager.shared.totalCollected, resources + 10)
        XCTAssertTrue(scene.executeAction(name: "setHermesMode", params: ["mode": "following"]).success)
        XCTAssertEqual(hermes.mode, .following)
        XCTAssertTrue(scene.executeAction(name: "pause", params: nil).success)
        XCTAssertEqual(scene.internalLevelManager?.state, .paused)
        let data = try JSONEncoder().encode(scene.getCurrentGameState())
        let state = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(state["playerHealth"] as? Int, player.maxHP)
        XCTAssertEqual(state["hermesMode"] as? String, "following")
        XCTAssertEqual(state["towerCount"] as? Int, 0)
        XCTAssertTrue(scene.executeAction(name: "resume", params: nil).success)
        XCTAssertEqual(scene.internalLevelManager?.state, .playing)
        XCTAssertTrue(scene.executeAction(name: "killAllEnemies", params: nil).success)
        XCTAssertEqual(enemies.aliveCount, 0)
        let unknown = scene.executeAction(name: "missingAction", params: nil)
        XCTAssertFalse(unknown.success)
        XCTAssertEqual(unknown.error, "Unknown action: missingAction")
    }
}
