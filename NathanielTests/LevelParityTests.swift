//
//  LevelParityTests.swift
//  NathanielTests
//
//  Checks original level rules, wave timing, and wave spawn positions.
//

@testable import Nathaniel
import SpriteKit
import XCTest

final class LevelParityTests: XCTestCase {
    // MARK: - Level Rules

    func testCampaignAllowsThreeRespawnsBeforeGameOver() {
        let level = LevelManager(config: .levelOne)

        for remainingLives in [2, 1, 0] {
            XCTAssertTrue(level.handlePlayerDeath())
            XCTAssertEqual(level.lives, remainingLives)
            XCTAssertEqual(level.state, .playing)
        }

        XCTAssertFalse(level.handlePlayerDeath())
        XCTAssertEqual(level.state, .gameOver)
        XCTAssertEqual(level.lives, 0)
    }

    func testSurvivalEndsOnFirstDeath() {
        let level = LevelManager(config: .survival)

        XCTAssertEqual(level.lives, 0)
        XCTAssertFalse(level.handlePlayerDeath())
        XCTAssertEqual(level.state, .gameOver)
    }

    func testFreshLevelsUseOriginalStartingResources() {
        XCTAssertEqual(LevelConfig.campaignLevels.map(\.startingResources), [30, 30, 30, 0, 0])
        XCTAssertEqual(LevelConfig.survival.startingResources, 30)
    }

    func testBossDeathWinsCampaignButNotSurvival() {
        let enemies = EnemyManager()
        for config in LevelConfig.campaignLevels {
            let level = LevelManager(config: config)
            level.enemyManagerDidDefeatBoss(enemies)
            XCTAssertEqual(level.state, .victory)
        }

        let survival = LevelManager(config: .survival)
        survival.enemyManagerDidDefeatBoss(enemies)
        XCTAssertEqual(survival.state, .playing)
    }

    func testGameOverDoesNotReplaceVictory() {
        let level = LevelManager(config: .levelOne)
        level.triggerVictory()
        level.triggerGameOver()
        XCTAssertEqual(level.state, .victory)
    }

    func testPausedLevelDoesNotAdvanceTimeOrLoseLives() {
        let level = LevelManager(config: .levelOne)
        level.update(deltaTime: 10)
        level.pause()
        level.update(deltaTime: 20)

        XCTAssertEqual(level.elapsedTime, 10)
        XCTAssertFalse(level.handlePlayerDeath())
        XCTAssertEqual(level.lives, 3)

        level.resume()
        level.update(deltaTime: 2)
        XCTAssertEqual(level.elapsedTime, 12)
    }

    // MARK: - Waves

    func testWaveIntervalsChangeAtOriginalTimeThresholds() {
        let spawner = WaveSpawner()
        let cases: [(elapsedTime: TimeInterval, interval: TimeInterval)] = [
            (0, 5), (60, 5), (60.01, 4), (120, 4), (120.01, 3),
            (180, 3), (180.01, 2), (240, 2), (240.01, 1), (365, 1),
        ]

        for testCase in cases {
            spawner.restore(elapsedTime: testCase.elapsedTime, timeUntilNext: 5)
            XCTAssertEqual(spawner.timeUntilNextWave, testCase.interval, "At \(testCase.elapsedTime) seconds")
        }
    }

    func testRestoredWaveKeepsExactCountdownAndElapsedTime() {
        let enemies = WaveRecordingEnemyManager()
        let spawner = self.makeSpawner(enemies: enemies)
        spawner.restore(elapsedTime: 179.75, timeUntilNext: 0.5)

        spawner.update(deltaTime: 0.25)
        XCTAssertTrue(enemies.spawns.isEmpty)
        XCTAssertEqual(spawner.timeUntilNextWave, 0.25)

        spawner.update(deltaTime: 0.25)
        XCTAssertEqual(enemies.spawns.count, 1)
        XCTAssertEqual(spawner.timeUntilNextWave, 2)
        XCTAssertEqual(spawner.currentWave, 3)
    }

    func testWaveTimingDoesNotDependOnFrameCount() {
        let slowFrames = WaveRecordingEnemyManager()
        let fastFrames = WaveRecordingEnemyManager()
        let slowSpawner = self.makeSpawner(enemies: slowFrames)
        let fastSpawner = self.makeSpawner(enemies: fastFrames)
        slowSpawner.restore(elapsedTime: 61, timeUntilNext: 4)
        fastSpawner.restore(elapsedTime: 61, timeUntilNext: 4)

        for _ in 0 ..< 16 {
            slowSpawner.update(deltaTime: 1)
        }
        for _ in 0 ..< 64 {
            fastSpawner.update(deltaTime: 0.25)
        }

        XCTAssertEqual(slowFrames.spawns.count, 4)
        XCTAssertEqual(fastFrames.spawns.count, slowFrames.spawns.count)
        XCTAssertEqual(fastSpawner.timeUntilNextWave, slowSpawner.timeUntilNextWave)
    }

    func testWaveEnemiesUseConvertedBottomEdgePositions() {
        let enemies = WaveRecordingEnemyManager()
        let spawner = self.makeSpawner(enemies: enemies)
        spawner.restore(elapsedTime: 365, timeUntilNext: 1)

        for _ in 0 ..< 20 {
            spawner.update(deltaTime: 1)
        }

        XCTAssertEqual(enemies.spawns.count, 20)
        for spawn in enemies.spawns {
            XCTAssertGreaterThanOrEqual(spawn.position.x, 0)
            XCTAssertLessThan(spawn.position.x, 960)
            switch spawn.name {
            case "Grunt":
                XCTAssertEqual(spawn.position.y, 10)
            case "Spawner":
                XCTAssertEqual(spawn.position, CGPoint(x: 240, y: 200))
            default:
                XCTAssertEqual(spawn.position.y, 50)
            }
        }
    }

    func testInactiveSpawnerFreezesCountdown() {
        let enemies = WaveRecordingEnemyManager()
        let spawner = self.makeSpawner(enemies: enemies)
        spawner.isActive = false
        spawner.update(deltaTime: 100)

        XCTAssertTrue(enemies.spawns.isEmpty)
        XCTAssertEqual(spawner.timeUntilNextWave, 5)

        spawner.isActive = true
        spawner.update(deltaTime: 5)
        XCTAssertEqual(enemies.spawns.count, 1)
    }

    // MARK: - Private Methods

    private func makeSpawner(enemies: WaveRecordingEnemyManager) -> WaveSpawner {
        let spawner = WaveSpawner()
        spawner.enemyManager = enemies
        spawner.mapWidth = 960
        spawner.mapHeight = 960
        return spawner
    }
}

private final class WaveRecordingEnemyManager: EnemyManager {
    var spawns: [(name: String, position: CGPoint)] = []

    override func addEnemy(name: String, at position: CGPoint, target: Character? = nil) -> Enemy? {
        self.spawns.append((name, position))
        return nil
    }
}
