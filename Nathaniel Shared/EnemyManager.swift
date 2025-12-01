//
//  EnemyManager.swift
//  Nathaniel Shared
//
//  Manages enemy spawning, tracking, and lifecycle.
//

import SpriteKit

// MARK: - Enemy Manager Delegate

/// Protocol for enemy manager events
protocol EnemyManagerDelegate: AnyObject {
    /// Called when a boss is defeated
    func enemyManagerDidDefeatBoss(_ manager: EnemyManager)

    /// Called when an enemy dies
    func enemyManager(_ manager: EnemyManager, enemyDidDie enemy: Enemy, score: Int)
}

// MARK: - Enemy Manager

/// Manages all enemies in the game, including spawning, updates, and cleanup
class EnemyManager {

    // MARK: - Properties

    /// All active enemies
    private(set) var enemies: [Enemy] = []

    /// Reference to the scene for adding sprites
    weak var scene: SKScene?

    /// Delegate for events
    weak var delegate: EnemyManagerDelegate?

    /// Z-position for enemy sprites
    var enemyZPosition: CGFloat = 100

    /// Scale for enemy sprites
    var enemyScale: CGFloat = 3.0

    /// Player characters that enemies can target
    var playerCharacters: [Character] = []

    // MARK: - Statistics

    /// Count of spawners
    private(set) var numSpawners: Int = 0

    /// Count of soldiers
    private(set) var numSoldiers: Int = 0

    /// Count of bosses
    private(set) var numBosses: Int = 0

    /// Total enemies spawned
    private(set) var totalSpawned: Int = 0

    /// Total enemies killed
    private(set) var totalKilled: Int = 0

    // MARK: - Initialization

    init(scene: SKScene? = nil) {
        self.scene = scene
    }

    /// Reset all state (for level restart)
    func reset() {
        // Remove all enemy sprites
        for enemy in enemies {
            enemy.sprite.removeFromParent()
        }
        enemies.removeAll()

        // Reset counts
        numSpawners = 0
        numSoldiers = 0
        numBosses = 0
        totalSpawned = 0
        totalKilled = 0
    }

    // MARK: - Enemy Factory

    /// Create and add an enemy based on name prefix
    /// - Parameters:
    ///   - name: Object name from map (e.g., "Grunt1", "Soldier2", "Boss")
    ///   - position: World position to spawn at
    ///   - target: Optional initial target
    /// - Returns: The created enemy, or nil if name not recognized
    @discardableResult
    func addEnemy(name: String, at position: CGPoint, target: Character? = nil) -> Enemy? {
        let enemy: Enemy

        if name.hasPrefix("Gr") {
            enemy = Grunt()
        } else if name.hasPrefix("So") {
            enemy = Soldier()
            numSoldiers += 1
            setupRangedWeapon(for: enemy)
        } else if name.hasPrefix("Sp") {
            // TODO: Implement Spawner enemy
            print("EnemyManager: Spawner not yet implemented")
            return nil
        } else if name.hasPrefix("Bo") {
            enemy = Boss()
            numBosses += 1
            setupRangedWeapon(for: enemy)
        } else {
            print("EnemyManager: Unknown enemy type '\(name)'")
            return nil
        }

        // Configure common properties
        enemy.position = position
        enemy.sprite.zPosition = enemyZPosition
        enemy.sprite.setScale(enemyScale)
        enemy.target = target

        // Set up health bar
        enemy.setupHealthBar(width: 40, yOffset: 8)

        // Add to scene
        scene?.addChild(enemy.sprite)

        // Track
        enemies.append(enemy)
        totalSpawned += 1

        print("EnemyManager: Spawned \(enemy.name) at (\(Int(position.x)), \(Int(position.y)))")

        return enemy
    }

    /// Spawn enemies from map object layer
    /// - Parameters:
    ///   - objects: Array of map objects with spawn info
    ///   - renderer: TMX renderer for coordinate conversion
    func spawnFromMapObjects(_ objects: [TMXObject], renderer: TMXRenderer) {
        for obj in objects {
            // Only process enemy spawns (by type or name prefix)
            let name = obj.name
            if name.hasPrefix("Gr") || name.hasPrefix("So") ||
               name.hasPrefix("Sp") || name.hasPrefix("Bo") {

                let position = renderer.convertToSpriteKit(point: obj.center)

                // Find nearest player to set as initial target
                let target = findNearestPlayer(to: position)

                addEnemy(name: name, at: position, target: target)
            }
        }
    }

    /// Set up ranged weapon callbacks for an enemy
    private func setupRangedWeapon(for enemy: Enemy) {
        guard let weapon = enemy.weapon else { return }

        // Projectile spawn callback
        weapon.onFire = { [weak self] projectile in
            guard let self = self else { return }
            projectile.sprite.setScale(2.0)
            self.scene?.addChild(projectile.sprite)
        }

        // Projectile collision callback
        weapon.onCheckCollision = { [weak self] projectile in
            guard let self = self else { return nil }
            for player in self.playerCharacters where player.isAlive {
                if projectile.checkCollision(with: player) {
                    return player
                }
            }
            return nil
        }
    }

    // MARK: - Update

    /// Update all enemies
    func update(deltaTime: TimeInterval) {
        var indicesToRemove: [Int] = []

        for (index, enemy) in enemies.enumerated() {
            // Auto-assign targets
            if enemy.target == nil || !enemy.target!.isAlive {
                enemy.target = findNearestPlayer(to: enemy.position, withinRange: enemy.visibleRange)
            }

            // Check if player is attacking this enemy (aggro response)
            if enemy.target == nil {
                for player in playerCharacters where player.isAlive {
                    // If player is targeting an enemy, that enemy should respond
                    if let playerTarget = (player as? Nathaniel)?.target, playerTarget === enemy {
                        enemy.target = player
                        break
                    }
                }
            }

            // Update the enemy
            enemy.update(deltaTime: deltaTime)

            // Check if dead and inactive (death animation finished)
            if !enemy.isAlive && !enemy.isActive {
                indicesToRemove.append(index)
            }
        }

        // Remove dead enemies (in reverse order to maintain indices)
        for index in indicesToRemove.reversed() {
            let enemy = enemies[index]
            totalKilled += 1

            // Notify delegate
            delegate?.enemyManager(self, enemyDidDie: enemy, score: enemy.killScore)

            // Check if this was a boss
            if enemy is Boss {
                numBosses -= 1
                delegate?.enemyManagerDidDefeatBoss(self)
            }

            enemies.remove(at: index)
        }
    }

    // MARK: - Targeting

    /// Find the nearest player character to a position
    func findNearestPlayer(to position: CGPoint, withinRange range: CGFloat? = nil) -> Character? {
        var nearestPlayer: Character?
        var nearestDistance: CGFloat = .infinity

        for player in playerCharacters where player.isAlive {
            let dx = player.position.x - position.x
            let dy = player.position.y - position.y
            let distance = hypot(dx, dy)

            // Check range if specified
            if let range = range, distance > range {
                continue
            }

            if distance < nearestDistance {
                nearestDistance = distance
                nearestPlayer = player
            }
        }

        return nearestPlayer
    }

    /// Find an enemy at the given position (for tap-to-target)
    func enemy(at point: CGPoint) -> Enemy? {
        for enemy in enemies where enemy.isAlive {
            if enemy.contains(point: point) {
                return enemy
            }
        }
        return nil
    }

    // MARK: - Collision Callbacks

    /// Create a collision check callback for a player's weapon
    func createCollisionCallback() -> (Projectile) -> Character? {
        return { [weak self] projectile in
            guard let self = self else { return nil }
            for enemy in self.enemies where enemy.isAlive {
                if projectile.checkCollision(with: enemy) {
                    return enemy
                }
            }
            return nil
        }
    }

    /// Check if a projectile collides with any enemy (for tower weapons)
    func checkProjectileCollision(_ projectile: Projectile) -> Character? {
        for enemy in enemies where enemy.isAlive {
            if projectile.checkCollision(with: enemy) {
                return enemy
            }
        }
        return nil
    }

    // MARK: - Queries

    /// Get all alive enemies
    var aliveEnemies: [Enemy] {
        return enemies.filter { $0.isAlive }
    }

    /// Count of alive enemies
    var aliveCount: Int {
        return aliveEnemies.count
    }

    /// Whether any boss is alive
    var isBossAlive: Bool {
        return enemies.contains { $0 is Boss && $0.isAlive }
    }
}
