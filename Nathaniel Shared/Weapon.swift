import SpriteKit

// MARK: - Weapon Protocol

/// Protocol for all weapons (guns, lasers, melee, etc.)
protocol Weapon: AnyObject {
    /// The entity that owns this weapon (Character or Structure)
    var owner: Damageable? { get set }

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
        cooldownElapsed >= cooldownTime
    }

    /// Reset the cooldown timer
    func resetCooldown() {
        cooldownElapsed = 0
    }
}

// MARK: - Projectile

/// Type of projectile for applying dev settings
enum ProjectileType {
    case bullet // Player bullets, gun tower bullets, blaster bullets
    case arrow // Boss arrows
}

/// A projectile fired by a ranged weapon
class Projectile: GameEntity {
    // MARK: - GameEntity Properties

    let sprite: SKSpriteNode

    var position: CGPoint {
        get { self.sprite.position }
        set { self.sprite.position = newValue }
    }

    var isActive: Bool = false

    // MARK: - Projectile Properties

    /// Damage dealt on hit
    let damage: Int

    /// Base speed in points per second
    let baseSpeed: CGFloat

    /// Type of projectile (for dev settings)
    let projectileType: ProjectileType

    /// Effective speed (reads from DevSettings in DEBUG)
    var speed: CGFloat {
        #if DEBUG
            switch self.projectileType {
            case .bullet:
                return DevSettings.shared.bulletSpeed
            case .arrow:
                return DevSettings.shared.arrowSpeed
            }
        #else
            return self.baseSpeed
        #endif
    }

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
        self.sprite.size.width * 0.5
    }

    /// Whether the projectile is still visible/active
    var isVisible: Bool {
        guard self.isActive, !self.hasCollision else { return false }
        let travelDistance = hypot(position.x - self.startPosition.x, self.position.y - self.startPosition.y)
        return travelDistance < self.maxDistance
    }

    // MARK: - Initialization

    init(
        textureName: String,
        damage: Int,
        speed: CGFloat,
        maxDistance: CGFloat,
        projectileType: ProjectileType = .bullet
    ) {
        self.damage = damage
        self.baseSpeed = speed
        self.maxDistance = maxDistance
        self.projectileType = projectileType

        // Create sprite
        let texture = SKTexture(imageNamed: textureName)
        texture.filteringMode = .nearest
        self.sprite = SKSpriteNode(texture: texture)
        self.sprite.name = "projectile"
        self.sprite.zPosition = 50 // Below characters but above ground
    }

    // MARK: - Fire

    /// Fire the projectile from a position toward a target
    func fire(from start: CGPoint, toward target: CGPoint) {
        self.hasCollision = false
        self.isActive = true
        self.startPosition = start
        self.destination = target
        self.position = start

        // Calculate normalized direction
        let dx = target.x - start.x
        let dy = target.y - start.y
        let length = hypot(dx, dy)

        if length > 0 {
            self.direction = CGVector(dx: dx / length, dy: dy / length)
        } else {
            self.direction = CGVector(dx: 0, dy: -1) // Default: fire down
        }

        // Rotate sprite to face direction
        self.sprite.zRotation = atan2(self.direction.dy, self.direction.dx)
    }

    // MARK: - GameEntity Methods

    func update(deltaTime: TimeInterval) {
        guard self.isActive, !self.hasCollision else { return }

        // Move in direction
        let moveDistance = self.speed * CGFloat(deltaTime)
        self.position = CGPoint(
            x: self.position.x + self.direction.dx * moveDistance,
            y: self.position.y + self.direction.dy * moveDistance
        )

        // Check if we've traveled max distance
        if !self.isVisible {
            self.deactivate()
        }
    }

    /// Deactivate the projectile (hit something or traveled too far)
    func deactivate() {
        self.isActive = false
        self.sprite.removeFromParent()
    }

    /// Check collision with a character
    func checkCollision(with character: Character) -> Bool {
        guard self.isActive, !self.hasCollision, character.isAlive else { return false }

        let dx = self.position.x - character.position.x
        let dy = self.position.y - character.position.y
        let distance = hypot(dx, dy)

        return distance < self.collisionRadius + character.collisionRadius
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
        if self.projectiles.count < self.maxSize {
            let newProjectile = self.factory()
            self.projectiles.append(newProjectile)
            return newProjectile
        }

        // Reuse oldest if at limit (force deactivate)
        let oldest = self.projectiles[0]
        oldest.deactivate()
        return oldest
    }

    /// Update all active projectiles
    func update(deltaTime: TimeInterval) {
        for projectile in self.projectiles where projectile.isActive {
            projectile.update(deltaTime: deltaTime)
        }
    }

    /// Get all active projectiles (for collision checking)
    var activeProjectiles: [Projectile] {
        self.projectiles.filter(\.isActive)
    }

    /// Remove all projectiles
    func clear() {
        for projectile in self.projectiles {
            projectile.deactivate()
        }
        self.projectiles.removeAll()
    }
}

// MARK: - Gun (Nathaniel's Primary Weapon)

/// Standard gun weapon that fires bullets
class Gun: Weapon {
    // MARK: - Weapon Properties

    weak var owner: Damageable?

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
    init(
        cooldownTime: TimeInterval,
        damage: Int,
        range: CGFloat,
        bulletSpeed: CGFloat,
        bulletTexture: String,
        projectileType: ProjectileType = .bullet
    ) {
        self.cooldownTime = cooldownTime
        self.damage = damage
        self.range = range
        self.bulletSpeed = bulletSpeed

        self.projectilePool = ProjectilePool(maxSize: 20) {
            Projectile(
                textureName: bulletTexture,
                damage: damage,
                speed: bulletSpeed,
                maxDistance: range,
                projectileType: projectileType
            )
        }
    }

    // MARK: - Weapon Methods

    func update(deltaTime: TimeInterval) {
        // Update cooldown
        self.cooldownElapsed += deltaTime

        // Update all projectiles
        self.projectilePool.update(deltaTime: deltaTime)

        // Check collisions for active projectiles
        for projectile in self.projectilePool.activeProjectiles {
            if let hitCharacter = onCheckCollision?(projectile) {
                // If hitting an enemy, use threat-aware damage
                if let enemy = hitCharacter as? Enemy {
                    enemy.takeDamage(projectile.damage, from: self.owner)
                } else {
                    hitCharacter.takeDamage(projectile.damage)
                }
                projectile.hasCollision = true
                projectile.deactivate()
            }
        }

        // Reset isBeingUsed after a short time
        if self.isBeingUsed, self.cooldownElapsed > 0.1 {
            self.isBeingUsed = false
        }
    }

    func use(target: CGPoint) -> Bool {
        guard let owner else { return false }

        // Check cooldown
        guard self.cooldownElapsed >= self.cooldownTime else {
            return false
        }

        // Check range
        let dx = target.x - owner.position.x
        let dy = target.y - owner.position.y
        let distance = hypot(dx, dy)

        if distance > self.range {
            return false
        }

        // Reset cooldown and fire
        self.cooldownElapsed = 0
        self.isBeingUsed = true

        // Get a projectile and fire it
        let bullet = self.projectilePool.acquire()
        bullet.fire(from: owner.position, toward: target)

        // Notify scene to add the bullet sprite
        self.onFire?(bullet)

        // Play gunshot sound
        if let sprite = owner.sprite.scene {
            AudioManager.shared.playSoundEffect(.gunShot, on: sprite)
        }

        return true
    }

    /// Get all active bullets (for external collision handling if needed)
    var activeBullets: [Projectile] {
        self.projectilePool.activeProjectiles
    }

    /// Whether any projectiles are still in flight
    var hasActiveProjectiles: Bool {
        !self.projectilePool.activeProjectiles.isEmpty
    }
}
