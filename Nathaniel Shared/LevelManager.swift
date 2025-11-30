//
//  LevelManager.swift
//  Nathaniel Shared
//
//  Manages game state: lives, score, win/lose conditions, and level transitions.
//

import SpriteKit

// MARK: - Level State

/// Represents the current game state
enum LevelState {
    case playing
    case paused
    case victory
    case gameOver
}

// MARK: - Level Configuration

/// Configuration for a level
struct LevelConfig {
    let levelNumber: Int
    let mapName: String
    let startingLives: Int
    let startingResources: Int
    let hasBoss: Bool

    /// Level One configuration
    static let levelOne = LevelConfig(
        levelNumber: 1,
        mapName: "levelone",
        startingLives: 3,
        startingResources: 30,
        hasBoss: true
    )

    /// Survival mode configuration
    static let survival = LevelConfig(
        levelNumber: 0,
        mapName: "survivalmap",
        startingLives: 1,
        startingResources: 50,
        hasBoss: false
    )
}

// MARK: - Level Manager Delegate

/// Protocol for level manager events
protocol LevelManagerDelegate: AnyObject {
    /// Called when the game is over (all lives lost)
    func levelManagerDidGameOver(_ manager: LevelManager)

    /// Called when the level is won (boss defeated)
    func levelManagerDidWin(_ manager: LevelManager)

    /// Called when a life is lost (player respawn)
    func levelManager(_ manager: LevelManager, didLoseLife remainingLives: Int)

    /// Called when score changes
    func levelManager(_ manager: LevelManager, didUpdateScore newScore: Int)
}

// MARK: - Level Manager

/// Manages game state including lives, score, and win/lose conditions
class LevelManager: EnemyManagerDelegate {

    // MARK: - Properties

    /// The current level configuration
    private(set) var config: LevelConfig

    /// Current game state
    private(set) var state: LevelState = .playing

    /// Remaining player lives
    private(set) var lives: Int

    /// Current score
    private(set) var score: Int = 0

    /// Current resources (for building structures)
    private(set) var resources: Int

    /// Total elapsed time in seconds
    private(set) var elapsedTime: TimeInterval = 0

    /// Delegate for events
    weak var delegate: LevelManagerDelegate?

    /// Reference to the enemy manager
    weak var enemyManager: EnemyManager?

    /// Starting position for player respawn
    var startPosition: CGPoint = .zero

    // MARK: - Initialization

    init(config: LevelConfig) {
        self.config = config
        self.lives = config.startingLives
        self.resources = config.startingResources
    }

    /// Reset level state (for restart)
    func reset() {
        lives = config.startingLives
        resources = config.startingResources
        score = 0
        elapsedTime = 0
        state = .playing
    }

    // MARK: - Update

    /// Update the level manager each frame
    func update(deltaTime: TimeInterval) {
        guard state == .playing else { return }

        elapsedTime += deltaTime
    }

    // MARK: - Player Death Handling

    /// Called when a player character dies
    /// - Returns: true if player should respawn, false if game over
    func handlePlayerDeath() -> Bool {
        guard state == .playing else { return false }

        if lives > 0 {
            lives -= 1
            delegate?.levelManager(self, didLoseLife: lives)

            if lives == 0 {
                triggerGameOver()
                return false
            }

            return true // Should respawn
        } else {
            triggerGameOver()
            return false
        }
    }

    /// Trigger game over state
    private func triggerGameOver() {
        state = .gameOver
        delegate?.levelManagerDidGameOver(self)
    }

    // MARK: - Victory Handling

    /// Called when the boss is defeated (level complete)
    func triggerVictory() {
        guard state == .playing else { return }

        state = .victory
        delegate?.levelManagerDidWin(self)
    }

    // MARK: - Score

    /// Add to the current score
    func addScore(_ points: Int) {
        score += points
        delegate?.levelManager(self, didUpdateScore: score)
    }

    // MARK: - Resources

    /// Add resources
    func addResources(_ amount: Int) {
        resources += amount
    }

    /// Spend resources if available
    /// - Returns: true if resources were spent, false if insufficient
    func spendResources(_ amount: Int) -> Bool {
        if resources >= amount {
            resources -= amount
            return true
        }
        return false
    }

    // MARK: - EnemyManagerDelegate

    func enemyManagerDidDefeatBoss(_ manager: EnemyManager) {
        // Only trigger victory for non-survival levels
        if config.hasBoss && config.levelNumber > 0 {
            triggerVictory()
        }
    }

    func enemyManager(_ manager: EnemyManager, enemyDidDie enemy: Enemy, score: Int) {
        addScore(score)
    }
}
