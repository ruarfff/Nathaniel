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

    /// Difficulty level (affects spawn rates and enemy types)
    enum Difficulty {
        case normal     // Level 4 / Standard survival
        case hard       // Final level
    }

    var difficulty: Difficulty = .normal

    /// Random number generator
    private var random = SystemRandomNumberGenerator()

    // MARK: - Initialization

    init() {}

    /// Reset for new level
    func reset() {
        timeSinceLastSpawn = 0
        spawnInterval = 5.0
        elapsedTime = 0
        maxEnemyTypeIndex = 2
        isActive = true
    }

    // MARK: - Update

    /// Update the spawner each frame
    func update(deltaTime: TimeInterval) {
        guard isActive, let enemyManager = enemyManager else { return }

        elapsedTime += deltaTime
        timeSinceLastSpawn += deltaTime

        // Update difficulty scaling based on elapsed time (in minutes)
        let minutes = elapsedTime / 60.0
        updateDifficulty(minutes: minutes)

        // Spawn enemy if interval has passed
        if timeSinceLastSpawn >= spawnInterval {
            spawnEnemy(using: enemyManager)
            timeSinceLastSpawn = 0
        }
    }

    /// Update difficulty scaling based on elapsed time
    private func updateDifficulty(minutes: TimeInterval) {
        switch difficulty {
        case .normal:
            // Standard progression (like legacy LevelFour/FinalLevel)
            if minutes > 5 {
                maxEnemyTypeIndex = 7
            } else if minutes > 4 {
                maxEnemyTypeIndex = 6
                spawnInterval = max(1.0, spawnInterval - 0.1)
            } else if minutes > 3 {
                maxEnemyTypeIndex = 5
                spawnInterval = max(2.0, spawnInterval - 0.1)
            } else if minutes > 2 {
                maxEnemyTypeIndex = 4
                spawnInterval = max(3.0, spawnInterval - 0.1)
            } else if minutes > 1 {
                maxEnemyTypeIndex = 3
                spawnInterval = max(4.0, spawnInterval - 0.1)
            }

        case .hard:
            // Harder progression for final level
            if minutes > 3 {
                maxEnemyTypeIndex = 7
                spawnInterval = max(1.0, spawnInterval - 0.1)
            } else if minutes > 2 {
                maxEnemyTypeIndex = 6
                spawnInterval = max(1.5, spawnInterval - 0.1)
            } else if minutes > 1 {
                maxEnemyTypeIndex = 5
                spawnInterval = max(2.0, spawnInterval - 0.1)
            } else if minutes > 0.5 {
                maxEnemyTypeIndex = 4
                spawnInterval = max(3.0, spawnInterval - 0.1)
            }
        }
    }

    /// Spawn a random enemy at a random edge position
    private func spawnEnemy(using enemyManager: EnemyManager) {
        guard mapWidth > 0 && mapHeight > 0 else { return }

        // Pick a random enemy type
        let typeIndex = Int.random(in: 0..<maxEnemyTypeIndex, using: &random)
        let enemyName: String

        // Enemy type distribution based on index (matches legacy logic)
        switch typeIndex {
        case 0:
            enemyName = "Grunt"
        case 1:
            enemyName = "Soldier"
        case 2:
            enemyName = "Spawner"  // Will be skipped if not implemented
        case 3:
            enemyName = "Boss"
        default:
            enemyName = "Soldier"  // Default to soldiers for higher indices
        }

        // Spawn position at bottom edge of map (like legacy code)
        let spawnX = CGFloat.random(in: 50...(mapWidth - 50), using: &random)
        let spawnY: CGFloat

        // Vary spawn position slightly
        if typeIndex == 2 {
            // Spawners spawn further from edge
            spawnY = mapHeight - 200
        } else {
            spawnY = mapHeight - 50
        }

        let position = CGPoint(x: spawnX, y: spawnY)

        // Find a target for the enemy
        let target = enemyManager.findNearestPlayer(to: position)

        // Spawn the enemy
        enemyManager.addEnemy(name: enemyName, at: position, target: target)
    }
}
