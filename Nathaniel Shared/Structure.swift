import SpriteKit

// MARK: - Structure Base Class

/// Base class for stationary structures with health.
/// Unlike Character, structures cannot move, have no animation, and no pathfinding.
/// Implements GameEntity and Damageable protocols.
class Structure: GameEntity, Damageable {
    // MARK: - GameEntity Properties

    let sprite: SKSpriteNode

    var position: CGPoint {
        get { self.sprite.position }
        set { self.sprite.position = newValue }
    }

    var isActive: Bool = true

    // MARK: - Damageable Properties

    let name: String

    var currentHP: Int {
        didSet {
            if self.currentHP <= 0 {
                self.currentHP = 0
                self.onDeath()
            }
        }
    }

    let maxHP: Int

    var isAlive: Bool { self.currentHP > 0 }

    /// Health bar display
    var healthBar: HealthBar?

    // MARK: - Structure Properties

    /// Collision radius for overlap detection
    var collisionRadius: CGFloat {
        self.sprite.size.width * 0.4
    }

    // MARK: - Initialization

    init(name: String, maxHP: Int) {
        self.name = name
        self.maxHP = maxHP
        self.currentHP = maxHP

        self.sprite = SKSpriteNode()
        self.sprite.name = name
    }

    // MARK: - GameEntity Methods

    func update(deltaTime: TimeInterval) {
        // Override in subclasses
    }

    // MARK: - Damageable Methods

    func takeDamage(_ amount: Int) {
        guard self.isAlive else { return }
        self.currentHP -= amount
        self.updateHealthBar()
        self.showDamageFlash()
    }

    func updateHealthBar() {
        self.healthBar?.update(currentHP: self.currentHP, maxHP: self.maxHP)
    }

    /// Flash the sprite red briefly to indicate damage
    func showDamageFlash() {
        self.sprite.colorBlendFactor = 0.0
        let flashRed = SKAction.colorize(with: .red, colorBlendFactor: 0.7, duration: 0.05)
        let flashBack = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.15)
        self.sprite.run(SKAction.sequence([flashRed, flashBack]))
    }

    // MARK: - Health Bar Setup

    /// Set up a health bar for this structure
    func setupHealthBar(width: CGFloat? = nil, yOffset: CGFloat = 4) {
        let barWidth = width ?? self.sprite.size.width
        self.healthBar = HealthBar(width: barWidth, yOffset: yOffset)

        if let healthBar {
            healthBar.positionAbove(spriteHeight: self.sprite.size.height)
            self.sprite.addChild(healthBar.node)
            healthBar.update(currentHP: self.currentHP, maxHP: self.maxHP)
        }
    }

    // MARK: - Death

    /// Called when the structure is destroyed
    func onDeath() {
        self.isActive = false

        // Play explosion sound
        if let scene = sprite.scene {
            AudioManager.shared.playSoundEffect(.explosion, on: scene)
        }

        // Fade out and remove
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let remove = SKAction.removeFromParent()
        self.sprite.run(SKAction.sequence([fadeOut, remove]))
    }

    // MARK: - Collision

    /// Check if a point is within collision radius
    func contains(point: CGPoint) -> Bool {
        self.position.distance(to: point) < self.collisionRadius
    }
}
