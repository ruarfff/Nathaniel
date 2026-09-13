//
//  EnemyParityTests.swift
//  NathanielTests
//
//  Checks the original enemy combat rules and SpriteKit coordinate conversion.
//

@testable import Nathaniel
import SpriteKit
import XCTest

final class EnemyParityTests: XCTestCase {
    func testFacingMatchesAllSpriteKitDirections() {
        let directions: [(CGVector, FacingDirection)] = [
            (CGVector(dx: 0, dy: 1), .north),
            (CGVector(dx: 1, dy: 1), .northEast),
            (CGVector(dx: 1, dy: 0), .east),
            (CGVector(dx: 1, dy: -1), .southEast),
            (CGVector(dx: 0, dy: -1), .south),
            (CGVector(dx: -1, dy: -1), .southWest),
            (CGVector(dx: -1, dy: 0), .west),
            (CGVector(dx: -1, dy: 1), .northWest),
        ]
        for (vector, expected) in directions {
            XCTAssertEqual(FacingDirection.from(direction: vector), expected)
        }
    }

    func testGruntShootsAtRangeWithoutMoving() {
        let manager = EnemyManager()
        let player = Character(name: "Target", maxHP: 100, speed: 0)
        player.sprite.size = CGSize(width: 32, height: 48)
        player.position = CGPoint(x: 200, y: 0)
        manager.playerCharacters = [player]
        let grunt = Grunt()
        grunt.target = player
        manager.addEnemy(grunt)

        for _ in 0 ..< 90 {
            manager.update(deltaTime: 1.0 / 60)
        }

        XCTAssertTrue(grunt.weapon is Blaster)
        XCTAssertEqual(grunt.position, .zero)
        XCTAssertEqual(player.currentHP, 75)
        XCTAssertEqual(grunt.sprite.size, CGSize(width: 72, height: 33))
    }

    func testSoldierUsesGunAndCanDamageTower() {
        let scene = SKScene()
        let structures = StructureManager(scene: scene)
        let tower = structures.addGunTower(at: CGPoint(x: 200, y: 0))
        let manager = EnemyManager(scene: scene)
        manager.structureManager = structures
        let soldier = Soldier()
        manager.addEnemy(soldier)

        for _ in 0 ..< 90 {
            manager.update(deltaTime: 1.0 / 60)
        }

        XCTAssertTrue(soldier.target === tower)
        XCTAssertFalse(soldier.weapon is Blaster)
        XCTAssertEqual(soldier.weapon?.soundEffect, .gunShot)
        XCTAssertEqual(tower.currentHP, tower.maxHP - 25)
        XCTAssertEqual(soldier.position, .zero)
        XCTAssertTrue(soldier.sprite.texture === soldier.animationComponent.texture(at: 1, col: 6))
    }

    func testEnemyKeepsItsLiveTargetOutsideSight() {
        let manager = EnemyManager()
        let original = Character(name: "Original", maxHP: 100, speed: 0)
        original.position = CGPoint(x: 1_000, y: 0)
        let nearby = Character(name: "Nearby", maxHP: 100, speed: 0)
        nearby.position = CGPoint(x: 10, y: 0)
        manager.playerCharacters = [original, nearby]
        let soldier = Soldier()
        soldier.target = original
        manager.addEnemy(soldier)

        soldier.takeDamage(1, from: nearby)
        manager.update(deltaTime: 0.1)

        XCTAssertTrue(soldier.target === original)
        XCTAssertGreaterThan(soldier.position.x, 0)
    }

    func testBossUsesOriginalAnimationAndArrowSpeed() {
        let boss = Boss()
        boss.facingDirection = .north
        boss.updateTexture()
        XCTAssertTrue(boss.sprite.texture === boss.animationComponent.texture(at: 5, col: 4))
        let target = Character(name: "Target", maxHP: 100, speed: 0)
        target.position = CGPoint(x: 400, y: 0)
        boss.target = target

        boss.update(deltaTime: 0.5)

        XCTAssertTrue(boss.isMoving)
        XCTAssertTrue(boss.isAttacking)
        XCTAssertTrue(boss.sprite.texture === boss.animationComponent.texture(at: 2, col: 6))
        XCTAssertEqual(boss.weapon?.bulletSpeed, 240)
        XCTAssertEqual(boss.weapon?.soundEffect, .arrowShot)
    }

    func testSpawnerPreservesLegacyCadenceAndStopsAfterDeath() {
        let spawner = Spawner()
        var positions: [CGPoint] = []
        spawner.onSpawn = { positions.append($0) }

        spawner.update(deltaTime: 29)
        XCTAssertTrue(positions.isEmpty)
        spawner.update(deltaTime: 1)
        spawner.update(deltaTime: 30)
        spawner.update(deltaTime: 30)
        XCTAssertEqual(positions.count, 3)
        XCTAssertEqual(positions.first, CGPoint(x: 240, y: -168))
        XCTAssertEqual(spawner.timeUntilNextSpawn, 120)
        XCTAssertEqual(spawner.initialSpawnsRemaining, 0)
        spawner.update(deltaTime: 119)
        XCTAssertEqual(positions.count, 3)
        spawner.update(deltaTime: 1)
        XCTAssertEqual(positions.count, 4)

        spawner.takeDamage(spawner.maxHP)
        spawner.update(deltaTime: 120)
        XCTAssertEqual(positions.count, 4)
    }

    func testSpawnerStateRestoresAndLaserDamagesAtSixtyFPS() {
        let spawner = Spawner()
        spawner.restoreSpawnState(timeUntilNextSpawn: 4, initialSpawnsRemaining: 1)
        var count = 0
        spawner.onSpawn = { _ in count += 1 }
        let target = Character(name: "Target", maxHP: 100, speed: 0)
        target.position = CGPoint(x: 200, y: 0)
        spawner.target = target

        for _ in 0 ..< 300 {
            spawner.update(deltaTime: 1.0 / 60)
        }

        XCTAssertEqual(count, 1)
        XCTAssertEqual(spawner.initialSpawnsRemaining, 0)
        XCTAssertEqual(target.currentHP, 70)
        XCTAssertEqual(spawner.position, .zero)
    }
}
