//
//  GunTowerTests.swift
//  NathanielTests
//
//  Verifies tower shots use the shared gun damage and cleanup behavior.
//

@testable import Nathaniel
import SpriteKit
import XCTest

final class GunTowerTests: XCTestCase {
    @MainActor
    func testTowerShotDamagesOnceTriggersRetaliationAndCleansUpOnDeath() throws {
        let scene = SKScene(size: CGSize(width: 800, height: 480))
        let enemies = EnemyManager(scene: scene)
        let structures = StructureManager(scene: scene)
        structures.enemyManager = enemies
        let tower = structures.addGunTower(at: .zero)
        let enemy = Soldier()
        enemy.position = CGPoint(x: 100, y: 0)
        enemies.addEnemy(enemy)

        tower.update(deltaTime: tower.gun.cooldownTime)
        let bullet = try XCTUnwrap(tower.gun.activeBullets.first)
        XCTAssertTrue(tower.gun.owner === tower)
        XCTAssertTrue(bullet.sprite.parent === scene)
        XCTAssertNil(enemy.target)

        bullet.position = enemy.position
        tower.update(deltaTime: 0)

        XCTAssertEqual(enemy.currentHP, enemy.maxHP - tower.gun.damage)
        XCTAssertTrue(enemy.target === tower)
        XCTAssertFalse(bullet.isActive)
        XCTAssertNil(bullet.sprite.parent)
        tower.update(deltaTime: 0)
        XCTAssertEqual(enemy.currentHP, enemy.maxHP - tower.gun.damage)

        tower.update(deltaTime: tower.gun.cooldownTime)
        let nextBullet = try XCTUnwrap(tower.gun.activeBullets.first)
        XCTAssertTrue(nextBullet.sprite.parent === scene)
        tower.takeDamage(tower.maxHP)

        XCTAssertEqual(structures.count, 0)
        XCTAssertTrue(tower.gun.activeBullets.isEmpty)
        XCTAssertFalse(nextBullet.isActive)
        XCTAssertNil(nextBullet.sprite.parent)
    }
}
