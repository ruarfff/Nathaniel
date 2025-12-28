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

/// Spawn mode for levels - determines how enemies appear
enum SpawnMode {
    case mapBased       // Enemies spawn from map object points
    case waveBased      // Enemies spawn in waves at regular intervals
}

/// Configuration for a level
struct LevelConfig {
    let levelNumber: Int
    let mapName: String
    let startingLives: Int
    let startingResources: Int
    let hasBoss: Bool
    let spawnMode: SpawnMode
    let nextLevelNumber: Int?  // nil = game complete or survival mode

    /// Get the next level configuration
    var nextLevel: LevelConfig? {
        guard let next = nextLevelNumber else { return nil }
        return LevelConfig.level(next)
    }

    /// Level One configuration
    static let levelOne = LevelConfig(
        levelNumber: 1,
        mapName: "levelone",
        startingLives: 3,
        startingResources: 30,
        hasBoss: true,
        spawnMode: .mapBased,
        nextLevelNumber: 2
    )

    /// Level Two configuration
    static let levelTwo = LevelConfig(
        levelNumber: 2,
        mapName: "leveltwo",
        startingLives: 3,
        startingResources: 30,
        hasBoss: true,
        spawnMode: .mapBased,
        nextLevelNumber: 3
    )

    /// Level Three configuration
    static let levelThree = LevelConfig(
        levelNumber: 3,
        mapName: "levelthree",
        startingLives: 3,
        startingResources: 30,
        hasBoss: true,
        spawnMode: .mapBased,
        nextLevelNumber: 4
    )

    /// Level Four configuration (wave-based survival-style)
    static let levelFour = LevelConfig(
        levelNumber: 4,
        mapName: "survivalmap",
        startingLives: 3,
        startingResources: 0,
        hasBoss: true,
        spawnMode: .waveBased,
        nextLevelNumber: 5
    )

    /// Final Level configuration (wave-based, harder enemies)
    static let finalLevel = LevelConfig(
        levelNumber: 5,
        mapName: "survivalmap",
        startingLives: 3,
        startingResources: 0,
        hasBoss: true,
        spawnMode: .waveBased,
        nextLevelNumber: nil  // Game complete after final level
    )

    /// Survival mode configuration (endless waves, no victory)
    static let survival = LevelConfig(
        levelNumber: 0,
        mapName: "survivalmap",
        startingLives: 1,
        startingResources: 50,
        hasBoss: false,
        spawnMode: .waveBased,
        nextLevelNumber: nil
    )

    /// Get level config by number (for level select)
    static func level(_ number: Int) -> LevelConfig? {
        switch number {
        case 0: return .survival
        case 1: return .levelOne
        case 2: return .levelTwo
        case 3: return .levelThree
        case 4: return .levelFour
        case 5: return .finalLevel
        default: return nil
        }
    }

    /// All playable campaign levels in order
    static let campaignLevels: [LevelConfig] = [
        .levelOne, .levelTwo, .levelThree, .levelFour, .finalLevel
    ]
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

    /// Restore state from saved game
    func restore(elapsedTime: TimeInterval, score: Int, lives: Int) {
        self.elapsedTime = elapsedTime
        self.score = score
        self.lives = lives
        self.state = .playing
    }

    // MARK: - Pause/Resume

    /// Pause the game
    func pause() {
        guard state == .playing else { return }
        state = .paused
    }

    /// Resume from pause
    func resume() {
        guard state == .paused else { return }
        state = .playing
    }

    /// Whether the game is currently paused
    var isPaused: Bool {
        return state == .paused
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

        // Spawn resource drop from the dead enemy
        ResourceManager.shared.spawnFromEnemy(enemy)
    }
}
