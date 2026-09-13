//
//  SaveCleanupTests.swift
//  NathanielTests
//
//  Checks save-slot persistence and scene serialization after removing reflection.
//

@testable import Nathaniel
import SpriteKit
import XCTest

@MainActor
final class SaveCleanupTests: XCTestCase {
    func testExistingSaveLoadsWithoutMetadataAndIgnoresStaleMetadata() throws {
        let suite = "Nathaniel.SaveCleanupTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = self.savedState(name: "Existing save", score: 420)
        let data = try JSONEncoder().encode(state)
        defaults.set(data, forKey: "save_slot_2")

        let withoutMetadata = SaveManager(defaults: defaults)
        XCTAssertEqual(withoutMetadata.getSaveSlots().map(\.id), [1, 2, 3])
        XCTAssertEqual(withoutMetadata.getSlot(2)?.displayName, "Existing save")
        XCTAssertEqual(withoutMetadata.getSlot(2)?.score, 420)
        XCTAssertTrue(withoutMetadata.hasSaves)

        try defaults.set(JSONEncoder().encode([SaveSlot(id: 1)]), forKey: "save_slot_metadata")
        let withStaleMetadata = SaveManager(defaults: defaults)
        XCTAssertEqual(withStaleMetadata.getSlot(2)?.displayName, "Existing save")
        XCTAssertEqual(withStaleMetadata.loadFromSlot(2)?.score, 420)
        XCTAssertEqual(defaults.data(forKey: "save_slot_2"), data)
    }

    func testOverwriteAndDeleteUpdateSlotsAcrossReloads() throws {
        let suite = "Nathaniel.SaveCleanupTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = SaveManager(defaults: defaults)
        XCTAssertFalse(manager.hasSaves)
        XCTAssertTrue(manager.saveToSlot(self.savedState(name: "First", score: 10), slotId: 1))
        XCTAssertTrue(manager.saveToSlot(self.savedState(name: "Keep", score: 20), slotId: 2))
        XCTAssertTrue(manager.saveToSlot(self.savedState(name: "Updated", score: 30), slotId: 1))
        XCTAssertEqual(manager.getSlot(1)?.score, 30)

        let reloaded = SaveManager(defaults: defaults)
        XCTAssertEqual(reloaded.loadFromSlot(1)?.displayName, "Updated")
        reloaded.deleteSlot(1)
        XCTAssertFalse(try XCTUnwrap(reloaded.getSlot(1)).hasSave)
        XCTAssertTrue(reloaded.hasSaves)
        XCTAssertEqual(reloaded.loadFromSlot(2)?.displayName, "Keep")
        reloaded.deleteAllSlots()
        XCTAssertFalse(SaveManager(defaults: defaults).hasSaves)
        XCTAssertNil(defaults.data(forKey: "save_slot_2"))
    }

    func testInvalidSlotsAndCorruptDataDoNotChangeValidSaves() throws {
        let suite = "Nathaniel.SaveCleanupTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("invalid save".utf8), forKey: "save_slot_3")
        let manager = SaveManager(defaults: defaults)
        XCTAssertFalse(try XCTUnwrap(manager.getSlot(3)).hasSave)
        XCTAssertNil(manager.loadFromSlot(3))
        XCTAssertTrue(manager.saveToSlot(self.savedState(name: "Valid", score: 42), slotId: 2))
        XCTAssertFalse(manager.saveToSlot(self.savedState(name: "Invalid", score: 0), slotId: 0))
        XCTAssertFalse(manager.saveToSlot(self.savedState(name: "Invalid", score: 0), slotId: 4))
        manager.deleteSlot(0)
        manager.deleteSlot(4)
        XCTAssertNil(manager.loadFromSlot(0))
        XCTAssertEqual(manager.loadFromSlot(2)?.score, 42)
    }

    func testSceneRoundTripPreservesTowerOwnershipTargetsAndCarriedResources() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let original = GameScene.newGameScene()
        view.presentScene(original)
        defer {
            view.presentScene(nil)
            ResourceManager.shared.delegate = nil
            ResourceManager.shared.reset()
        }
        let nathaniel = try XCTUnwrap(original.internalNathaniel)
        let hermes = try XCTUnwrap(original.internalHermes)
        let structures = try XCTUnwrap(original.internalStructureManager)
        let enemies = try XCTUnwrap(original.internalEnemyManager)
        enemies.removeAllEnemies()
        let enemy = enemies.addEnemy(name: "Soldier", at: CGPoint(x: 600, y: 200), target: hermes)
        XCTAssertNotNil(enemy)
        let owned = structures.addGunTower(at: CGPoint(x: 300, y: 200))
        owned.constructionCost = 19
        owned.currentHP = owned.maxHP - 1
        structures.markAsHermesOwned(owned)
        structures.addHealTower(at: CGPoint(x: 400, y: 200))
        ResourceManager.shared.spawnResource(amount: 10, at: nathaniel.position)
        ResourceManager.shared.update(deltaTime: 0)
        XCTAssertTrue(nathaniel.hasCorpse)

        let saved = try XCTUnwrap(original.createSaveState(displayName: "Round trip"))
        let encoded = try JSONEncoder().encode(saved)
        let restored = try GameScene.newGameScene(fromSave: JSONDecoder().decode(SavedGameState.self, from: encoded))
        view.presentScene(restored)
        let roundTrip = try XCTUnwrap(restored.createSaveState(displayName: "Round trip"))
        XCTAssertEqual(roundTrip.enemies.count, 1)
        XCTAssertEqual(roundTrip.enemies.first?.targetIndex, 1)
        XCTAssertEqual(roundTrip.towers.count, 2)
        XCTAssertEqual(roundTrip.towers.filter(\.isHermesOwned).count, 1)
        XCTAssertEqual(roundTrip.towers.first?.constructionCost, 19)
        XCTAssertEqual(roundTrip.towers.first?.currentHP, owned.currentHP)
        XCTAssertEqual(roundTrip.battlefieldResources?.first?.isCarried, true)
        XCTAssertEqual(roundTrip.resources, saved.resources)

        restored.setHermesMode(.following)
        XCTAssertEqual(restored.internalStructureManager?.structures.count, 1)
        XCTAssertEqual(ResourceManager.shared.totalCollected, saved.resources + 4)
    }

    private func savedState(name: String, score: Int) -> SavedGameState {
        let character = SavedCharacterState(
            position: SavedPoint(.zero),
            currentHP: 10,
            maxHP: 20,
            facingDirection: .south,
            destination: nil
        )
        return SavedGameState(
            displayName: name,
            levelNumber: 2,
            elapsedTime: 45,
            score: score,
            lives: 3,
            resources: 30,
            nathaniel: character,
            hermes: SavedHermesState(characterState: character, mode: .independent),
            enemies: [],
            towers: []
        )
    }
}
