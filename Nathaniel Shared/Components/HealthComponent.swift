import SpriteKit

/// Component handling health, damage, and death for game entities
class HealthComponent {
    // MARK: - Properties

    /// The sprite node (for visual effects)
    weak var sprite: SKSpriteNode?

    /// Current health points
    private(set) var currentHP: Int {
        didSet {
            if self.currentHP <= 0 {
                self.currentHP = 0
                self.onDeath?()
            }
            self.onHealthChanged?(self.currentHP, self.maxHP)
        }
    }

    /// Maximum health points
    let maxHP: Int

    /// Whether the entity is alive
    var isAlive: Bool { self.currentHP > 0 }

    /// Health bar display
    private(set) var healthBar: HealthBar?

    // MARK: - Callbacks

    /// Called when health changes
    var onHealthChanged: ((_ current: Int, _ max: Int) -> Void)?

    /// Called when the entity dies
    var onDeath: (() -> Void)?

    /// Called when damage is taken (for visual feedback)
    var onDamageTaken: ((_ amount: Int) -> Void)?

    // MARK: - Initialization

    init(maxHP: Int, sprite: SKSpriteNode? = nil) {
        self.maxHP = maxHP
        self.currentHP = maxHP
        self.sprite = sprite
    }

    // MARK: - Damage

    /// Take damage from a source
    /// - Parameter amount: The amount of damage to take
    func takeDamage(_ amount: Int) {
        guard self.isAlive else { return }
        self.currentHP -= amount
        self.updateHealthBar()
        self.showDamageFlash()
        self.onDamageTaken?(amount)
    }

    /// Heal the entity
    /// - Parameter amount: The amount to heal
    func heal(_ amount: Int) {
        guard self.isAlive else { return }
        self.currentHP = min(self.currentHP + amount, self.maxHP)
        self.updateHealthBar()
    }

    /// Set health directly (for respawn, etc.)
    /// - Parameter value: The new health value
    func setHealth(_ value: Int) {
        self.currentHP = min(max(0, value), self.maxHP)
        self.updateHealthBar()
    }

    /// Restore to full health
    func restoreFullHealth() {
        self.currentHP = self.maxHP
        self.updateHealthBar()
    }

    // MARK: - Visual Feedback

    /// Flash the sprite red briefly to indicate damage
    func showDamageFlash() {
        guard let sprite else { return }

        // Enable color blending
        sprite.colorBlendFactor = 0.0

        // Flash sequence: tint red, then back to normal
        let flashRed = SKAction.colorize(with: .red, colorBlendFactor: 0.7, duration: 0.05)
        let flashBack = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.15)
        let flashSequence = SKAction.sequence([flashRed, flashBack])

        sprite.run(flashSequence)
    }

    // MARK: - Health Bar

    /// Set up a health bar for this entity
    /// - Parameters:
    ///   - width: Width of the health bar (defaults to sprite width)
    ///   - yOffset: Vertical offset above sprite
    ///   - compact: Use compact style (smaller height, rounded corners)
    func setupHealthBar(width: CGFloat? = nil, yOffset: CGFloat = 4, compact: Bool = false) {
        guard let sprite else { return }

        let barWidth = width ?? sprite.size.width
        let height = compact ? HealthBar.compactHeight : HealthBar.standardHeight
        let cornerRadius = compact ? HealthBar.compactCornerRadius : HealthBar.standardCornerRadius

        self.healthBar = HealthBar(width: barWidth, yOffset: yOffset, height: height, cornerRadius: cornerRadius)

        if let healthBar {
            healthBar.positionAbove(spriteHeight: sprite.size.height)
            sprite.addChild(healthBar.node)
            healthBar.update(currentHP: self.currentHP, maxHP: self.maxHP)
        }
    }

    /// Update the health bar display
    func updateHealthBar() {
        self.healthBar?.update(currentHP: self.currentHP, maxHP: self.maxHP)
    }

    // MARK: - Death Animation

    /// Play the default death animation (fade out and remove)
    /// - Parameter completion: Called when animation completes
    func playDeathAnimation(completion: (() -> Void)? = nil) {
        guard let sprite else {
            completion?()
            return
        }

        // Play explosion sound
        if let scene = sprite.scene {
            AudioManager.shared.playSoundEffect(.explosion, on: scene)
        }

        // Fade out and remove
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let remove = SKAction.removeFromParent()
        let deathSequence = SKAction.sequence([fadeOut, remove])

        if let completion {
            sprite.run(SKAction.sequence([deathSequence, SKAction.run(completion)]))
        } else {
            sprite.run(deathSequence)
        }
    }
}
