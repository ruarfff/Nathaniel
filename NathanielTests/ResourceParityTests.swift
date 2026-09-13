//
//  ResourceParityTests.swift
//  Nathaniel Shared
//
//  Checks corpse delivery, expiration, and save compatibility.
//

@testable import Nathaniel
import SpriteKit
import XCTest

final class ResourceParityTests: XCTestCase {
    override func tearDown() {
        ResourceManager.shared.delegate = nil
        ResourceManager.shared.reset()
        super.tearDown()
    }

    func testOnlySoldiersDropCorpsesWorthTenResources() {
        let manager = ResourceManager.shared
        manager.reset()
        manager.spawnFromEnemy(Grunt())
        manager.spawnFromEnemy(Boss())
        manager.spawnFromEnemy(Spawner())
        XCTAssertEqual(manager.activeCount, 0)
        manager.spawnFromEnemy(Soldier())
        XCTAssertEqual(manager.resources.map(\.amount), [10])
    }

    func testNathanielCarriesCorpsesUntilTheyReachHermes() {
        let manager = ResourceManager.shared
        manager.reset()
        manager.restore(total: 30)
        let nathaniel = Nathaniel()
        let hermes = Hermes()
        hermes.position = CGPoint(x: 400, y: 0)
        manager.collectors = [nathaniel, hermes]
        let corpse = manager.spawnResource(amount: 10, at: .zero)
        manager.update(deltaTime: 1.0 / 60)
        XCTAssertTrue(nathaniel.hasCorpse)
        XCTAssertEqual(manager.totalCollected, 30)

        nathaniel.position = CGPoint(x: 150, y: 0)
        manager.update(deltaTime: 20)
        XCTAssertEqual(corpse.position, nathaniel.position)
        XCTAssertEqual(manager.activeCount, 1, "Carried corpses do not expire")
        XCTAssertEqual(manager.totalCollected, 30)

        nathaniel.position = hermes.position
        manager.update(deltaTime: 1.0 / 60)
        XCTAssertEqual(manager.totalCollected, 40)
        XCTAssertEqual(manager.activeCount, 0)
        XCTAssertFalse(nathaniel.hasCorpse)
        manager.update(deltaTime: 1)
        XCTAssertEqual(manager.totalCollected, 40, "Delivery must only credit the wallet once")
    }

    func testCorpseExpiresAfterTenSecondsWithoutContact() {
        let manager = ResourceManager.shared
        manager.reset()
        manager.spawnResource(amount: 10, at: .zero)
        manager.update(deltaTime: 9.9)
        XCTAssertEqual(manager.activeCount, 1)
        manager.update(deltaTime: 0.2)
        XCTAssertEqual(manager.activeCount, 0)
        XCTAssertEqual(manager.totalCollected, 0)
    }

    func testFreshLevelClearsWalletAndCarriedCorpses() {
        let manager = ResourceManager.shared
        manager.reset()
        let nathaniel = Nathaniel()
        manager.collectors = [nathaniel]
        manager.spawnResource(amount: 10, at: .zero)
        manager.update(deltaTime: 0)
        manager.addResources(80)
        manager.reset()
        manager.restore(total: LevelConfig.levelOne.startingResources)
        XCTAssertEqual(manager.activeCount, 0)
        XCTAssertFalse(nathaniel.hasCorpse)
        XCTAssertEqual(manager.totalCollected, 30)
    }

    func testSavedCorpseRemainsCarriedWithoutDoubleCredit() throws {
        let manager = ResourceManager.shared
        manager.reset()
        let nathaniel = Nathaniel()
        let state = SavedResourceState(
            position: SavedPoint(.zero),
            amount: 10,
            timeToExpiration: 5,
            isCarried: true
        )
        let decoded = try JSONDecoder().decode(SavedResourceState.self, from: JSONEncoder().encode(state))
        manager.restore(total: 30)
        manager.restoreBattlefield([decoded], carrier: nathaniel)
        XCTAssertTrue(nathaniel.hasCorpse)
        XCTAssertEqual(manager.resources.first?.collectionState, .collecting)
        XCTAssertEqual(manager.totalCollected, 30)
    }

    func testOldHermesLockLoadsAsStationaryBuildMode() throws {
        let saved = try JSONDecoder().decode(SavedHermesMode.self, from: Data("\"locked\"".utf8))
        XCTAssertEqual(saved.hermesMode, .independent)
    }

    func testSpawnerSavePreservesProductionCountdown() throws {
        let spawner = Spawner()
        spawner.update(deltaTime: 12)
        let state = try XCTUnwrap(spawner.toSavedEnemyState(targetIndex: nil))
        let decoded = try JSONDecoder().decode(SavedEnemyState.self, from: JSONEncoder().encode(state))
        let restored = try XCTUnwrap(decoded.type.createEnemy() as? Spawner)
        restored.restore(from: decoded)
        XCTAssertEqual(restored.timeUntilNextSpawn, spawner.timeUntilNextSpawn, accuracy: 0.001)
        XCTAssertEqual(restored.initialSpawnsRemaining, spawner.initialSpawnsRemaining)
    }

    @MainActor
    func testTappingHermesWithACorpseCommandsDelivery() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let scene = GameScene.newGameScene()
        view.presentScene(scene)
        defer { view.presentScene(nil) }
        let nathaniel = try XCTUnwrap(scene.findNathanielPublic())
        let hermes = try XCTUnwrap(scene.findHermesPublic())
        nathaniel.movementComponent.pathfinding = nil
        ResourceManager.shared.spawnResource(amount: 10, at: nathaniel.position)
        ResourceManager.shared.update(deltaTime: 0)
        XCTAssertTrue(nathaniel.hasCorpse)

        scene.handleTap(at: hermes.position)

        XCTAssertEqual(nathaniel.destination, hermes.position)
        XCTAssertNil(scene.internalHUD?.childNode(withName: "buildButton"))
        XCTAssertEqual(ResourceManager.shared.totalCollected, 30)
    }

    @MainActor
    func testLoadingAnOldPendingRespawnDoesNotSpendAnotherLife() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let original = GameScene.newGameScene()
        view.presentScene(original)
        defer { view.presentScene(nil) }
        let spawn = try XCTUnwrap(original.findNathanielPublic()).position
        let save = original.createSaveState(displayName: "Pending respawn")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(save)) as? [String: Any])
        json["saveVersion"] = 1
        json["lives"] = 2
        var player = try XCTUnwrap(json["nathaniel"] as? [String: Any])
        player["currentHP"] = 0
        player["position"] = ["x": 400, "y": 100]
        json["nathaniel"] = player
        let state = try JSONDecoder().decode(SavedGameState.self, from: JSONSerialization.data(withJSONObject: json))

        let restored = GameScene.newGameScene(fromSave: state)
        view.presentScene(restored)
        let nathaniel = try XCTUnwrap(restored.findNathanielPublic())
        XCTAssertEqual(restored.findLevelManagerPublic()?.lives, 1)
        XCTAssertEqual(nathaniel.currentHP, nathaniel.maxHP)
        XCTAssertEqual(nathaniel.position, spawn)
    }

    func testRespawnClearsThePreviousMovementCommand() {
        let nathaniel = Nathaniel()
        nathaniel.moveTo(CGPoint(x: 400, y: 100))
        nathaniel.respawn(at: CGPoint(x: 84, y: 242))
        XCTAssertNil(nathaniel.destination)
        XCTAssertFalse(nathaniel.isMoving)
    }
}
