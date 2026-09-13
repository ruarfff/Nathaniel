//
//  EnemyManager.swift
//  Nathaniel Shared
//
//  Creates enemies and manages their targets, projectiles, and lifetime.
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

    /// Reference to the map renderer for pathfinding configuration
    weak var renderer: TMXRenderer?

    /// Z-position for enemy sprites
    var enemyZPosition: CGFloat = 100

    /// Scale for enemy sprites
    var enemyScale: CGFloat = 1.0

    /// Player characters that enemies can target
    var playerCharacters: [Character] = []

    /// Callback to check structure collision (for pathfinding around towers)
    var structureCollisionCheck: ((CGPoint, CGFloat) -> Bool)?

    /// Reference to structures that enemies can target
    weak var structureManager: StructureManager?

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
        for enemy in self.enemies {
            enemy.removeFromScene()
        }
        self.enemies.removeAll()

        // Reset counts
        self.numSpawners = 0
        self.numSoldiers = 0
        self.numBosses = 0
        self.totalSpawned = 0
        self.totalKilled = 0
    }

    /// Remove all enemies from the scene (for loading saved game)
    func removeAllEnemies() {
        for enemy in self.enemies {
            enemy.removeFromScene()
        }
        self.enemies.removeAll()
        self.numSpawners = 0
        self.numSoldiers = 0
        self.numBosses = 0
    }

    /// Add a pre-created enemy to the manager
    /// - Parameter enemy: The enemy to add
    func addEnemy(_ enemy: Enemy) {
        // Configure display properties
        enemy.sprite.zPosition = self.enemyZPosition
        enemy.sprite.setScale(self.enemyScale)

        // Set up compact health bar (smaller, closer to sprite, rounded)
        enemy.setupHealthBar(width: 32, yOffset: 3, compact: true)
        enemy.healthBar?.hideWhenFull = true

        // Set up ranged weapon if applicable
        self.setupRangedWeapon(for: enemy)
        if let spawner = enemy as? Spawner {
            self.scene?.addChild(spawner.beam.node)
            spawner.onSpawn = { [weak self] position in
                self?.addEnemy(name: "Grunt", at: position)
            }
        }

        // Track type counts
        if enemy is Soldier {
            self.numSoldiers += 1
        }
        if enemy is Boss {
            self.numBosses += 1
        }
        if enemy is Spawner {
            self.numSpawners += 1
        }

        // Configure pathfinding if renderer is available
        if let renderer {
            enemy.configurePathfinding(with: renderer)
            enemy.pathfinding?.structureCollisionCheck = self.structureCollisionCheck
        }

        // Add to scene
        self.scene?.addChild(enemy.sprite)

        // Track
        self.enemies.append(enemy)
        self.totalSpawned += 1
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
        } else if name.hasPrefix("Sp") {
            enemy = Spawner()
        } else if name.hasPrefix("Bo") {
            enemy = Boss()
        } else {
            print("EnemyManager: Unknown enemy type '\(name)'")
            return nil
        }

        enemy.position = position
        // Grunts attack Nathaniel by default. Other map enemies acquire a target
        // when one enters sight or attacks them.
        enemy.target = target ?? (enemy is Grunt ? self.playerCharacters.first(where: { $0 is Nathaniel }) : nil)
        self.addEnemy(enemy)

        print("EnemyManager: Spawned \(enemy.name) at (\(Int(position.x)), \(Int(position.y)))")

        return enemy
    }

    /// Spawn enemies from map object layer
    /// - Parameters:
    ///   - objects: Array of map objects with spawn info
    ///   - renderer: TMX renderer for coordinate conversion
    func spawnFromMapObjects(_ objects: [TMXObject], renderer: TMXRenderer) {
        // Store renderer for pathfinding configuration
        self.renderer = renderer

        for obj in objects {
            // Only process enemy spawns (by type or name prefix)
            let name = obj.name
            if name.hasPrefix("Gr") || name.hasPrefix("So") ||
                name.hasPrefix("Sp") || name.hasPrefix("Bo")
            {
                let position = renderer.convertToSpriteKit(point: CGPoint(x: obj.x, y: obj.y))
                self.addEnemy(name: name, at: position)
            }
        }
    }

    /// Set up ranged weapon callbacks for an enemy
    private func setupRangedWeapon(for enemy: Enemy) {
        guard let weapon = enemy.weapon else { return }

        // Projectile spawn callback
        weapon.onFire = { [weak self] projectile in
            guard let self else { return }
            projectile.sprite.setScale(2.0)
            self.scene?.addChild(projectile.sprite)
        }

        // Projectile collision callback
        weapon.onCheckCollision = { [weak self] projectile in
            guard let self else { return nil }
            for player in self.playerCharacters where player.isAlive {
                if projectile.checkCollision(with: player) {
                    return player
                }
            }
            for structure in self.structureManager?.structures ?? [] where structure.isAlive && structure.isActive {
                if projectile.checkCollision(with: structure) {
                    return structure
                }
            }
            return nil
        }
    }

    // MARK: - Update

    /// Update all enemies
    func update(deltaTime: TimeInterval) {
        var indicesToRemove: [Int] = []

        for (index, enemy) in self.enemies.enumerated() {
            self.selectTarget(for: enemy)

            // Update the enemy
            enemy.update(deltaTime: deltaTime)

            // Check if dead and inactive (death animation finished)
            // Also wait for any projectiles to complete their trajectory
            if !enemy.isAlive, !enemy.isActive, !enemy.hasActiveProjectiles {
                indicesToRemove.append(index)
            }
        }

        // Remove dead enemies (in reverse order to maintain indices)
        for index in indicesToRemove.reversed() {
            let enemy = self.enemies[index]
            self.totalKilled += 1

            // Notify delegate
            self.delegate?.enemyManager(self, enemyDidDie: enemy, score: enemy.killScore)

            // Check if this was a boss
            if enemy is Boss {
                self.numBosses -= 1
                self.delegate?.enemyManagerDidDefeatBoss(self)
            }

            if enemy is Soldier {
                self.numSoldiers -= 1
            }
            if enemy is Spawner {
                self.numSpawners -= 1
            }
            self.enemies.remove(at: index)
        }
    }

    /// Keep a live target. Otherwise acquire visible allies or an ally targeting
    /// this enemy, in the original player/tower order.
    private func selectTarget(for enemy: Enemy) {
        guard enemy.isAlive, enemy.target?.isAlive != true else { return }
        enemy.target = nil
        for player in self.playerCharacters where player.isAlive {
            let isTargetingEnemy = (player as? Nathaniel)?.currentTarget === enemy ||
                (player as? Hermes)?.currentTarget === enemy
            if enemy.position.distance(to: player.position) < enemy.visibleRange || isTargetingEnemy {
                enemy.target = player
            }
        }
        for structure in self.structureManager?.structures ?? [] where structure.isAlive && structure.isActive {
            if enemy.position.distance(to: structure.position) < enemy.visibleRange || structure
                .currentTarget === enemy
            {
                enemy.target = structure
            }
        }
    }

    // MARK: - Targeting

    /// Find the nearest player character to a position
    func findNearestPlayer(to position: CGPoint, withinRange range: CGFloat? = nil) -> Character? {
        var nearestPlayer: Character?
        var nearestDistance: CGFloat = .infinity

        for player in self.playerCharacters where player.isAlive {
            let distance = position.distance(to: player.position)

            // Check range if specified
            if let range, distance > range {
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
        for enemy in self.enemies where enemy.isAlive {
            if enemy.contains(point: point) {
                return enemy
            }
        }
        return nil
    }

    // MARK: - Collision Callbacks

    /// Create a collision check callback for a player's weapon
    func createCollisionCallback() -> (Projectile) -> Character? {
        { [weak self] projectile in
            guard let self else { return nil }
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
        for enemy in self.enemies where enemy.isAlive {
            if projectile.checkCollision(with: enemy) {
                return enemy
            }
        }
        return nil
    }

    // MARK: - Queries

    /// Get all alive enemies
    var aliveEnemies: [Enemy] {
        self.enemies.filter(\.isAlive)
    }

    /// Count of alive enemies
    var aliveCount: Int {
        self.aliveEnemies.count
    }

    /// Whether any boss is alive
    var isBossAlive: Bool {
        self.enemies.contains { $0 is Boss && $0.isAlive }
    }
}
