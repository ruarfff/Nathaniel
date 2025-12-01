//
//  Weapon.swift
//  Nathaniel Shared
//
//  Weapon protocol and implementations for combat.
//

import SpriteKit

// MARK: - Weapon Protocol

/// Protocol for all weapons (guns, lasers, melee, etc.)
protocol Weapon: AnyObject {
    /// The character that owns this weapon
    var owner: Character? { get set }

    /// Cooldown time between attacks in seconds
    var cooldownTime: TimeInterval { get }

    /// Time elapsed since last attack
    var cooldownElapsed: TimeInterval { get set }

    /// Damage dealt per hit
    var damage: Int { get }

    /// Range in points (0 for melee weapons)
    var range: CGFloat { get }

    /// Whether the weapon is currently being used (for animation purposes)
    var isBeingUsed: Bool { get }

    /// Update the weapon each frame
    func update(deltaTime: TimeInterval)

    /// Attempt to use the weapon (attack)
    /// - Parameter target: The target to attack (position or character)
    /// - Returns: True if the weapon was successfully used
    func use(target: CGPoint) -> Bool
}

// MARK: - Weapon Default Implementation

extension Weapon {
    /// Check if the weapon is ready to fire (cooldown has elapsed)
    var isReady: Bool {
        return cooldownElapsed >= cooldownTime
    }

    /// Reset the cooldown timer
    func resetCooldown() {
        cooldownElapsed = 0
    }
}

// MARK: - Projectile

/// A projectile fired by a ranged weapon
class Projectile: GameEntity {

    // MARK: - GameEntity Properties

    let sprite: SKSpriteNode

    var position: CGPoint {
        get { sprite.position }
        set { sprite.position = newValue }
    }

    var isActive: Bool = false

    // MARK: - Projectile Properties

    /// Damage dealt on hit
    let damage: Int

    /// Speed in points per second
    let speed: CGFloat

    /// Maximum travel distance
    let maxDistance: CGFloat

    /// Starting position (for distance calculation)
    private var startPosition: CGPoint = .zero

    /// Direction of travel (normalized)
    private var direction: CGVector = .zero

    /// Destination point (for visibility calculation)
    private var destination: CGPoint = .zero

    /// Whether the projectile has hit something
    var hasCollision: Bool = false

    /// Collision radius for hit detection
    var collisionRadius: CGFloat {
        return sprite.size.width * 0.5
    }

    /// Whether the projectile is still visible/active
    var isVisible: Bool {
        guard isActive && !hasCollision else { return false }
        let travelDistance = hypot(position.x - startPosition.x, position.y - startPosition.y)
        return travelDistance < maxDistance
    }

    // MARK: - Initialization

    init(textureName: String, damage: Int, speed: CGFloat, maxDistance: CGFloat) {
        self.damage = damage
        self.speed = speed
        self.maxDistance = maxDistance

        // Create sprite
        let texture = SKTexture(imageNamed: textureName)
        texture.filteringMode = .nearest
        self.sprite = SKSpriteNode(texture: texture)
        self.sprite.name = "projectile"
        self.sprite.zPosition = 50  // Below characters but above ground
    }

    // MARK: - Fire

    /// Fire the projectile from a position toward a target
    func fire(from start: CGPoint, toward target: CGPoint) {
        hasCollision = false
        isActive = true
        startPosition = start
        destination = target
        position = start

        // Calculate normalized direction
        let dx = target.x - start.x
        let dy = target.y - start.y
        let length = hypot(dx, dy)

        if length > 0 {
            direction = CGVector(dx: dx / length, dy: dy / length)
        } else {
            direction = CGVector(dx: 0, dy: -1)  // Default: fire down
        }

        // Rotate sprite to face direction
        sprite.zRotation = atan2(direction.dy, direction.dx)
    }

    // MARK: - GameEntity Methods

    func update(deltaTime: TimeInterval) {
        guard isActive && !hasCollision else { return }

        // Move in direction
        let moveDistance = speed * CGFloat(deltaTime)
        position = CGPoint(
            x: position.x + direction.dx * moveDistance,
            y: position.y + direction.dy * moveDistance
        )

        // Check if we've traveled max distance
        if !isVisible {
            deactivate()
        }
    }

    /// Deactivate the projectile (hit something or traveled too far)
    func deactivate() {
        isActive = false
        sprite.removeFromParent()
    }

    /// Check collision with a character
    func checkCollision(with character: Character) -> Bool {
        guard isActive && !hasCollision && character.isAlive else { return false }

        let dx = position.x - character.position.x
        let dy = position.y - character.position.y
        let distance = hypot(dx, dy)

        return distance < collisionRadius + character.collisionRadius
    }
}

// MARK: - Projectile Pool

/// Manages a pool of projectiles for efficient reuse
class ProjectilePool {

    private var projectiles: [Projectile] = []
    private let maxSize: Int
    private let factory: () -> Projectile

    init(maxSize: Int = 50, factory: @escaping () -> Projectile) {
        self.maxSize = maxSize
        self.factory = factory
    }

    /// Get an available projectile (inactive one or create new)
    func acquire() -> Projectile {
        // Try to find an inactive projectile
        if let available = projectiles.first(where: { !$0.isActive }) {
            return available
        }

        // Create new if under limit
        if projectiles.count < maxSize {
            let newProjectile = factory()
            projectiles.append(newProjectile)
            return newProjectile
        }

        // Reuse oldest if at limit (force deactivate)
        let oldest = projectiles[0]
        oldest.deactivate()
        return oldest
    }

    /// Update all active projectiles
    func update(deltaTime: TimeInterval) {
        for projectile in projectiles where projectile.isActive {
            projectile.update(deltaTime: deltaTime)
        }
    }

    /// Get all active projectiles (for collision checking)
    var activeProjectiles: [Projectile] {
        return projectiles.filter { $0.isActive }
    }

    /// Remove all projectiles
    func clear() {
        for projectile in projectiles {
            projectile.deactivate()
        }
        projectiles.removeAll()
    }
}

// MARK: - Gun (Nathaniel's Primary Weapon)

/// Standard gun weapon that fires bullets
class Gun: Weapon {

    // MARK: - Weapon Properties

    weak var owner: Character?

    let cooldownTime: TimeInterval
    var cooldownElapsed: TimeInterval = 0

    let damage: Int
    let range: CGFloat

    private(set) var isBeingUsed: Bool = false

    // MARK: - Gun-specific Properties

    /// Bullet speed in points per second
    let bulletSpeed: CGFloat

    /// Projectile pool for bullets
    let projectilePool: ProjectilePool

    /// Callback when a bullet is fired (for adding to scene)
    var onFire: ((Projectile) -> Void)?

    /// Callback for collision checking (returns true if hit something)
    var onCheckCollision: ((Projectile) -> Character?)?

    // MARK: - Initialization

    /// Create a gun with default bullet parameters
    convenience init() {
        self.init(
            cooldownTime: 0.8,
            damage: 25,
            range: 600,
            bulletSpeed: 450,
            bulletTexture: "bullet"
        )
    }

    /// Create a gun with custom parameters
    init(cooldownTime: TimeInterval, damage: Int, range: CGFloat,
         bulletSpeed: CGFloat, bulletTexture: String) {
        self.cooldownTime = cooldownTime
        self.damage = damage
        self.range = range
        self.bulletSpeed = bulletSpeed

        self.projectilePool = ProjectilePool(maxSize: 20) {
            Projectile(
                textureName: bulletTexture,
                damage: damage,
                speed: bulletSpeed,
                maxDistance: range
            )
        }
    }

    // MARK: - Weapon Methods

    func update(deltaTime: TimeInterval) {
        // Update cooldown
        cooldownElapsed += deltaTime

        // Update all projectiles
        projectilePool.update(deltaTime: deltaTime)

        // Check collisions for active projectiles
        for projectile in projectilePool.activeProjectiles {
            if let hitCharacter = onCheckCollision?(projectile) {
                hitCharacter.takeDamage(projectile.damage)
                projectile.hasCollision = true
                projectile.deactivate()
            }
        }

        // Reset isBeingUsed after a short time
        if isBeingUsed && cooldownElapsed > 0.1 {
            isBeingUsed = false
        }
    }

    func use(target: CGPoint) -> Bool {
        guard let owner = owner else { return false }

        // Check cooldown
        guard cooldownElapsed >= cooldownTime else {
            return false
        }

        // Check range
        let dx = target.x - owner.position.x
        let dy = target.y - owner.position.y
        let distance = hypot(dx, dy)

        if distance > range {
            return false
        }

        // Reset cooldown and fire
        cooldownElapsed = 0
        isBeingUsed = true

        // Get a projectile and fire it
        let bullet = projectilePool.acquire()
        bullet.fire(from: owner.position, toward: target)

        // Notify scene to add the bullet sprite
        onFire?(bullet)

        // Play gunshot sound
        if let sprite = owner.sprite.scene {
            AudioManager.shared.playSoundEffect(.gunShot, on: sprite)
        }

        return true
    }

    /// Get all active bullets (for external collision handling if needed)
    var activeBullets: [Projectile] {
        return projectilePool.activeProjectiles
    }
}
