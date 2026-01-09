import SpriteKit

// MARK: - Defensive Structure Base Class

/// Base class for all defensive structures (towers)
/// Structures are stationary, cannot move, and perform automated actions
class DefensiveStructure: Structure {
    // MARK: - Properties

    /// Original resource cost paid to build this structure (for recoup calculation)
    var buildCost: Int = 0

    /// Attack range for finding targets
    var attackRange: CGFloat = 300

    /// Current target enemy
    weak var currentTarget: Enemy?

    /// Callback for checking nearby enemies
    var findNearestEnemy: (() -> Enemy?)?

    /// Callback when structure is destroyed
    var onDestroyed: (() -> Void)?

    // MARK: - Initialization

    init(name: String, maxHP: Int, attackRange: CGFloat) {
        self.attackRange = attackRange
        super.init(name: name, maxHP: maxHP)
    }

    // MARK: - GameEntity Methods

    override func update(deltaTime: TimeInterval) {
        guard isActive, isAlive else { return }

        // Find target if we don't have one or current target is dead
        if self.currentTarget?.isAlive != true {
            self.currentTarget = self.findTargetInRange()
        }

        // Attack current target if we have one
        if let target = currentTarget, target.isAlive {
            self.attackTarget(target, deltaTime: deltaTime)
        }
    }

    /// Find the nearest enemy within attack range
    func findTargetInRange() -> Enemy? {
        self.findNearestEnemy?()
    }

    /// Attack the current target (override in subclasses)
    func attackTarget(_ target: Enemy, deltaTime: TimeInterval) {
        // Override in subclasses
    }

    // MARK: - Death

    override func onDeath() {
        isActive = false

        // Play explosion sound
        if let scene = sprite.scene {
            AudioManager.shared.playSoundEffect(.explosion, on: scene)
        }

        // Notify callback
        self.onDestroyed?()

        // Fade out and remove
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let remove = SKAction.removeFromParent()
        sprite.run(SKAction.sequence([fadeOut, remove]))
    }

    /// Destroy with enhanced visual effect (used by staggered destruction)
    /// This handles only the sprite animation, not the explosion effect
    func destroyWithEffect() {
        isActive = false

        // Notify callback
        self.onDestroyed?()

        // Enhanced destruction animation: flash, expand slightly, then collapse
        let flashWhite = SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: 0.05)
        let flashBack = SKAction.colorize(withColorBlendFactor: 0, duration: 0.05)
        let scaleUp = SKAction.scale(by: 1.3, duration: 0.1)
        let scaleDown = SKAction.scale(to: 0.1, duration: 0.2)
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let remove = SKAction.removeFromParent()

        let flashSequence = SKAction.sequence([flashWhite, flashBack])
        let collapseGroup = SKAction.group([scaleDown, fadeOut])
        let fullSequence = SKAction.sequence([flashSequence, scaleUp, collapseGroup, remove])

        sprite.run(fullSequence)
    }

    // MARK: - Texture Setup (Single Frame)

    /// Load a single texture for the structure
    func loadTexture(named textureName: String, size: CGSize? = nil) {
        let texture = SKTexture(imageNamed: textureName)
        texture.filteringMode = .nearest
        sprite.texture = texture

        let textureSize = texture.size()
        print("DefensiveStructure: Loading texture '\(textureName)', size: \(textureSize)")

        if let size {
            sprite.size = size
        } else if textureSize.width > 0, textureSize.height > 0 {
            sprite.size = textureSize
        } else {
            // Fallback size if texture failed to load
            sprite.size = CGSize(width: 48, height: 64)
            sprite.color = .cyan
            sprite.colorBlendFactor = 1.0
            print("DefensiveStructure: WARNING - Texture '\(textureName)' failed to load, using fallback")
        }
    }
}
