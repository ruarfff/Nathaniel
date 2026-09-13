//
//  WaveSpawner.swift
//  Nathaniel Shared
//
//  Handles wave-based enemy spawning for survival-style levels.
//  Enemies spawn at regular intervals, with difficulty scaling over time.
//

import SpriteKit

// MARK: - Wave Spawner

/// Handles wave-based enemy spawning for survival-style levels
class WaveSpawner {
    // MARK: - Properties

    /// Reference to enemy manager for spawning
    weak var enemyManager: EnemyManager?

    /// Map dimensions for spawn positioning
    var mapWidth: CGFloat = 0
    var mapHeight: CGFloat = 0

    /// Time accumulator since last spawn
    private var timeSinceLastSpawn: TimeInterval = 0

    /// Current spawn interval (decreases over time)
    private var spawnInterval: TimeInterval = 5.0

    /// Total elapsed time (for difficulty scaling)
    private var elapsedTime: TimeInterval = 0

    /// Maximum enemy types available (increases over time)
    private var maxEnemyTypeIndex: Int = 2

    /// Whether the spawner is active
    var isActive: Bool = true

    /// Completed minutes, retained for the saved wave display.
    var currentWave: Int {
        Int(self.elapsedTime / 60)
    }

    /// Seconds remaining before the next enemy spawns.
    var timeUntilNextWave: TimeInterval {
        max(0, self.spawnInterval - self.timeSinceLastSpawn)
    }

    /// Random number generator
    private var random = SystemRandomNumberGenerator()

    // MARK: - Initialization

    init() {}

    /// Reset for new level
    func reset() {
        self.timeSinceLastSpawn = 0
        self.spawnInterval = 5.0
        self.elapsedTime = 0
        self.maxEnemyTypeIndex = 2
        self.isActive = true
    }

    /// Restore state from saved game
    func restore(elapsedTime: TimeInterval, timeUntilNext: TimeInterval) {
        self.elapsedTime = max(0, elapsedTime)
        self.updateDifficulty()
        self.timeSinceLastSpawn = self.spawnInterval - min(self.spawnInterval, max(0, timeUntilNext))
        self.isActive = true
    }

    // MARK: - Update

    /// Update the spawner each frame
    func update(deltaTime: TimeInterval) {
        guard self.isActive, let enemyManager else { return }

        self.elapsedTime += deltaTime
        self.timeSinceLastSpawn += deltaTime

        self.updateDifficulty()

        // Spawn enemy if interval has passed
        if self.timeSinceLastSpawn >= self.spawnInterval {
            self.spawnEnemy(using: enemyManager)
            self.timeSinceLastSpawn = 0
        }
    }

    /// Update difficulty scaling based on elapsed time
    private func updateDifficulty() {
        // Use fixed level-time thresholds so frame rate cannot change the schedule.
        if self.elapsedTime > 300 {
            self.maxEnemyTypeIndex = 7
            self.spawnInterval = 1
        } else if self.elapsedTime > 240 {
            self.maxEnemyTypeIndex = 6
            self.spawnInterval = 1
        } else if self.elapsedTime > 180 {
            self.maxEnemyTypeIndex = 5
            self.spawnInterval = 2
        } else if self.elapsedTime > 120 {
            self.maxEnemyTypeIndex = 4
            self.spawnInterval = 3
        } else if self.elapsedTime > 60 {
            self.maxEnemyTypeIndex = 3
            self.spawnInterval = 4
        } else {
            self.maxEnemyTypeIndex = 2
            self.spawnInterval = 5
        }
    }

    /// Spawn a random enemy at a random edge position
    private func spawnEnemy(using enemyManager: EnemyManager) {
        guard self.mapWidth > 0 && self.mapHeight > 0 else { return }

        // Pick a random enemy type
        let typeIndex = Int.random(in: 0 ..< self.maxEnemyTypeIndex, using: &self.random)
        let enemyName

            // Enemy type distribution based on index (matches legacy logic)
            = switch typeIndex
        {
        case 0:
            "Grunt"
        case 1:
            "Soldier"
        case 2:
            "Spawner"
        case 3:
            "Boss"
        default:
            "Soldier" // Default to soldiers for higher indices
        }

        let spawnX = typeIndex == 2 ? self.mapWidth / 4 : CGFloat.random(in: 0 ..< self.mapWidth, using: &self.random)
        // XNA uses top-left coordinates. These are its bottom-edge offsets after conversion.
        let spawnY: CGFloat = typeIndex == 2 ? 200 : (typeIndex == 0 ? 10 : 50)
        let position = CGPoint(x: spawnX, y: min(spawnY, mapHeight))

        // The original waves send Grunts, early Soldiers, and Spawners toward Nathaniel.
        let target = typeIndex <= 2 ? enemyManager.playerCharacters.first { $0 is Nathaniel } : nil

        // Spawn the enemy
        enemyManager.addEnemy(name: enemyName, at: position, target: target)
    }
}
