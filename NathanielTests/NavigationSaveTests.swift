//
//  NavigationSaveTests.swift
//  NathanielTests
//
//  Checks that saved movement resumes toward its goal around obstacles.
//

@testable import Nathaniel
import SpriteKit
import XCTest

@MainActor
final class NavigationSaveTests: XCTestCase {
    private let start = CGPoint(x: 272, y: 176)
    private let goal = CGPoint(x: 400, y: 176)
    private let towerPosition = CGPoint(x: 320, y: 200)
    private let towerRadius: CGFloat = 24

    func testMidRouteSaveRestoresGoalAndAvoidsTower() throws {
        let renderer = TMXRenderer(map: TMXMap(width: 20, height: 12, tileWidth: 32, tileHeight: 32))
        let original = self.makeNathaniel(renderer: renderer)
        original.position = self.start
        original.moveTo(self.goal)
        original.update(deltaTime: 0.1)
        XCTAssertTrue(original.isMoving)
        XCTAssertNotEqual(original.destination, self.goal)

        let data = try JSONEncoder().encode(original.toSavedCharacterState())
        let saved = try JSONDecoder().decode(SavedCharacterState.self, from: data)
        XCTAssertEqual(saved.destination?.cgPoint, self.goal)
        let restored = self.makeNathaniel(renderer: renderer)
        restored.restoreFromSavedState(saved)

        self.assertReachesGoalWithoutHittingTower(restored)
    }

    func testExistingDestinationFieldReplansAroundTower() {
        let renderer = TMXRenderer(map: TMXMap(width: 20, height: 12, tileWidth: 32, tileHeight: 32))
        let restored = self.makeNathaniel(renderer: renderer)
        let saved = SavedCharacterState(
            position: SavedPoint(self.start),
            currentHP: restored.maxHP,
            maxHP: restored.maxHP,
            facingDirection: .east,
            destination: SavedPoint(self.goal)
        )

        restored.restoreFromSavedState(saved)

        self.assertReachesGoalWithoutHittingTower(restored)
    }

    func testOlderIdleSaveStopsExistingRoute() throws {
        let renderer = TMXRenderer(map: TMXMap(width: 20, height: 12, tileWidth: 32, tileHeight: 32))
        let restored = self.makeNathaniel(renderer: renderer)
        restored.position = self.start
        let idleSave = restored.toSavedCharacterState()
        let data = try JSONEncoder().encode(idleSave)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(json["destination"])
        let saved = try JSONDecoder().decode(SavedCharacterState.self, from: data)
        restored.moveTo(self.goal)

        restored.restoreFromSavedState(saved)
        restored.update(deltaTime: 1)

        XCTAssertFalse(restored.isMoving)
        XCTAssertEqual(restored.position, self.start)
        XCTAssertNil(restored.toSavedCharacterState().destination)
    }

    func testEnemySaveKeepsRequestedDestination() throws {
        let renderer = TMXRenderer(map: TMXMap(width: 20, height: 12, tileWidth: 32, tileHeight: 32))
        let original = Soldier()
        original.position = self.start
        original.configurePathfinding(with: renderer)
        original.moveTo(self.goal)
        XCTAssertNotEqual(original.destination, self.goal)

        let saved = try XCTUnwrap(original.toSavedEnemyState(targetIndex: nil))

        XCTAssertEqual(saved.destination?.cgPoint, self.goal)
        let restored = Soldier()
        restored.configurePathfinding(with: renderer)
        restored.restore(from: saved)
        XCTAssertEqual(restored.pathfinding?.pathWorldCoordinates.last, self.goal)
    }

    func testSceneLoadPlansRoutesAfterRestoringTowerAndMap() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let original = GameScene.newGameScene(levelConfig: .survival)
        view.presentScene(original)
        defer {
            view.presentScene(nil)
            ResourceManager.shared.reset()
        }
        let originalNathaniel = try XCTUnwrap(original.internalNathaniel)
        let originalStructures = try XCTUnwrap(original.internalStructureManager)
        let originalEnemies = try XCTUnwrap(original.internalEnemyManager)
        // This rectangle is clear terrain in the survival map.
        let start = CGPoint(x: 432, y: 784)
        let goal = CGPoint(x: 592, y: 784)
        let towerPosition = CGPoint(x: 528, y: 784)
        originalStructures.addGunTower(at: towerPosition)
        originalNathaniel.position = start
        originalNathaniel.moveTo(goal)
        originalNathaniel.update(deltaTime: 0.1)
        let enemy = Soldier()
        enemy.position = CGPoint(x: 432, y: 816)
        originalEnemies.addEnemy(enemy)
        enemy.moveTo(goal)
        let saved = try XCTUnwrap(original.createSaveState(displayName: "Moving around tower"))

        let restored = GameScene.newGameScene(fromSave: saved)
        view.presentScene(restored)
        let nathaniel = try XCTUnwrap(restored.internalNathaniel)
        let structures = try XCTUnwrap(restored.internalStructureManager)
        let restoredEnemy = try XCTUnwrap(restored.internalEnemyManager?.enemies.first)
        let route = try XCTUnwrap(nathaniel.pathfinding).pathWorldCoordinates

        XCTAssertFalse(route.isEmpty)
        XCTAssertFalse(route.contains { structures.collidesWithStructure(at: $0) })
        XCTAssertEqual(restoredEnemy.pathfinding?.pathWorldCoordinates.last, goal)
        var minimumClearance = nathaniel.position.distance(to: towerPosition)
        for _ in 0 ..< 600 {
            nathaniel.update(deltaTime: 1.0 / 60)
            minimumClearance = min(minimumClearance, nathaniel.position.distance(to: towerPosition))
        }
        XCTAssertGreaterThanOrEqual(minimumClearance, GameBalance.Towers.collisionRadius + nathaniel.collisionRadius)
        XCTAssertLessThanOrEqual(nathaniel.position.distance(to: goal), 16)
        XCTAssertFalse(nathaniel.isMoving)
    }

    private func makeNathaniel(renderer: TMXRenderer) -> Nathaniel {
        let character = Nathaniel()
        character.configurePathfinding(with: renderer)
        let position = self.towerPosition
        let radius = self.towerRadius
        character.pathfinding?.structureCollisionCheck = { point, characterRadius in
            point.distance(to: position) < radius + characterRadius
        }
        return character
    }

    private func assertReachesGoalWithoutHittingTower(
        _ character: Nathaniel,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var minimumClearance = character.position.distance(to: self.towerPosition)
        for _ in 0 ..< 600 {
            character.update(deltaTime: 1.0 / 60)
            minimumClearance = min(minimumClearance, character.position.distance(to: self.towerPosition))
        }
        XCTAssertGreaterThanOrEqual(
            minimumClearance,
            self.towerRadius + character.collisionRadius,
            file: file,
            line: line
        )
        XCTAssertLessThanOrEqual(character.position.distance(to: self.goal), 16, file: file, line: line)
        XCTAssertFalse(character.isMoving, file: file, line: line)
    }
}
