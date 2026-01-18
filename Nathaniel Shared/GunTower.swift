import SpriteKit

// MARK: - Gun Tower

/// Armed tower that fires bullets at enemies
class GunTower: DefensiveStructure {
    // MARK: - Constants

    /// Resource cost to build this tower
    static let cost: Int = BuildConfig.TowerCosts.gunTower

    // MARK: - Properties

    /// The gun weapon
    let gun: Gun

    /// Callback when a bullet is fired (for adding to scene)
    var onFire: ((Projectile) -> Void)?

    /// Callback for bullet collision checking
    var onCheckCollision: ((Projectile) -> Character?)?

    // MARK: - Initialization

    init() {
        // Create gun with tower-specific settings from GameBalance
        self.gun = Gun(
            cooldownTime: GameBalance.Towers.GunTower.gunCooldown,
            damage: GameBalance.Towers.GunTower.gunDamage,
            range: GameBalance.Towers.GunTower.attackRange,
            bulletSpeed: GameBalance.Towers.GunTower.bulletSpeed,
            bulletTexture: "bullet"
        )

        super.init(
            name: "GunTower",
            maxHP: GameBalance.Towers.GunTower.maxHP,
            attackRange: GameBalance.Towers.GunTower.attackRange
        )

        // Track build cost for recoup calculation
        buildCost = GunTower.cost

        // Load tower texture
        loadTexture(named: "guntower", size: GameBalance.Towers.Visual.textureSize)

        // Set up weapon callbacks
        self.gun.onFire = { [weak self] projectile in
            self?.onFire?(projectile)
        }
    }

    // MARK: - Update

    override func update(deltaTime: TimeInterval) {
        // Update gun cooldown and projectiles
        self.gun.update(deltaTime: deltaTime)

        // Check bullet collisions
        for projectile in self.gun.activeBullets {
            if let hit = onCheckCollision?(projectile) {
                // Towers generate threat so enemies will retaliate
                if let enemy = hit as? Enemy {
                    enemy.takeDamage(projectile.damage, from: self)
                } else {
                    hit.takeDamage(projectile.damage)
                }
                projectile.hasCollision = true
                projectile.deactivate()
            }
        }

        super.update(deltaTime: deltaTime)
    }

    override func attackTarget(_ target: Enemy, deltaTime: TimeInterval) {
        // Try to fire at target
        self.gun.owner = self
        _ = self.gun.use(target: target.position)
    }
}
