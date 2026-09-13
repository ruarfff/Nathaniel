//
//  EnemyDeathTests.swift
//  NathanielTests
//
//  Checks that enemy death rewards do not wait for projectile cleanup.
//

@testable import Nathaniel
import SpriteKit
import XCTest

final class EnemyDeathTests: XCTestCase {
    @MainActor
    func testBossDeathWinsBeforeItsArrowHitsHermes() throws {
        let wasInvincible = DevSettings.shared.playerInvincible
        DevSettings.shared.playerInvincible = false
        defer { DevSettings.shared.playerInvincible = wasInvincible }
        let scene = SKScene()
        let level = LevelManager(config: .levelOne)
        let manager = EnemyManager(scene: scene)
        manager.delegate = level
        let hermes = Hermes()
        hermes.position = CGPoint(x: 200, y: 0)
        hermes.currentHP = 25
        hermes.onDeathCallback = { [weak level] in level?.triggerGameOver() }
        manager.playerCharacters = [hermes]
        let boss = Boss()
        manager.addEnemy(boss)
        let bow = try XCTUnwrap(boss.weapon)
        bow.update(deltaTime: bow.cooldownTime)
        XCTAssertTrue(bow.use(target: hermes.position))
        let arrow = try XCTUnwrap(bow.activeBullets.first)

        boss.takeDamage(boss.maxHP)

        XCTAssertEqual(level.state, .victory)
        XCTAssertEqual(level.score, boss.killScore)
        XCTAssertTrue(arrow.isActive)
        arrow.position = hermes.position
        manager.update(deltaTime: 0)
        XCTAssertFalse(hermes.isAlive)
        XCTAssertEqual(level.state, .victory)
        XCTAssertEqual(level.score, boss.killScore)
        XCTAssertTrue(manager.enemies.isEmpty)
    }

    @MainActor
    func testSoldierDeathPaysOnceWhileItsShotContinues() throws {
        let resources = ResourceManager.shared
        resources.reset()
        defer { resources.reset() }
        let scene = SKScene()
        let level = LevelManager(config: .levelOne)
        let manager = EnemyManager(scene: scene)
        manager.delegate = level
        let soldier = Soldier()
        soldier.position = CGPoint(x: 100, y: 100)
        manager.addEnemy(soldier)
        let gun = try XCTUnwrap(soldier.weapon)
        gun.update(deltaTime: gun.cooldownTime)
        XCTAssertTrue(gun.use(target: CGPoint(x: 200, y: 100)))
        let bullet = try XCTUnwrap(gun.activeBullets.first)

        soldier.takeDamage(soldier.maxHP)

        XCTAssertEqual(level.score, soldier.killScore)
        XCTAssertEqual(resources.resources.map(\.position), [soldier.position])
        XCTAssertTrue(bullet.isActive)
        soldier.currentHP = 0
        manager.update(deltaTime: 0)
        XCTAssertEqual(level.score, soldier.killScore)
        XCTAssertEqual(resources.activeCount, 1)
        XCTAssertEqual(manager.enemies.count, 1)

        bullet.deactivate()
        manager.update(deltaTime: 0)
        XCTAssertTrue(manager.enemies.isEmpty)
        XCTAssertEqual(level.score, soldier.killScore)
        XCTAssertEqual(resources.activeCount, 1)
    }

    @MainActor
    func testRemovedEnemyCannotRewardTheCurrentLevel() {
        let scene = SKScene()
        let level = LevelManager(config: .levelOne)
        let manager = EnemyManager(scene: scene)
        manager.delegate = level
        let boss = Boss()
        manager.addEnemy(boss)
        manager.removeAllEnemies()

        boss.takeDamage(boss.maxHP)

        XCTAssertEqual(level.score, 0)
        XCTAssertEqual(level.state, .playing)
    }

    @MainActor
    func testSaveIncludesSoldierRewardBeforeItsShotFinishes() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 800, height: 480))
        let scene = GameScene.newGameScene()
        view.presentScene(scene)
        defer {
            view.presentScene(nil)
            ResourceManager.shared.reset()
        }
        let manager = try XCTUnwrap(scene.internalEnemyManager)
        let soldier = Soldier()
        soldier.position = CGPoint(x: 700, y: 300)
        manager.addEnemy(soldier)
        let gun = try XCTUnwrap(soldier.weapon)
        gun.update(deltaTime: gun.cooldownTime)
        XCTAssertTrue(gun.use(target: CGPoint(x: 650, y: 300)))
        let score = try XCTUnwrap(scene.createSaveState(displayName: "Before death")).score

        soldier.takeDamage(soldier.maxHP)
        let save = try XCTUnwrap(scene.createSaveState(displayName: "After death"))

        XCTAssertTrue(gun.hasActiveProjectiles)
        XCTAssertEqual(save.score, score + soldier.killScore)
        XCTAssertTrue(save.battlefieldResources?.contains { $0.position.cgPoint == soldier.position } == true)
        XCTAssertFalse(save.enemies.contains { $0.position.cgPoint == soldier.position })
    }
}
