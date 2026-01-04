import SpriteKit

/// The main player character class
class Nathaniel: Character {
    // MARK: - Constants (from legacy code)

    /// Starting/maximum health points
    static let defaultMaxHP = 8_000

    /// Movement speed in points per second
    static let defaultSpeed: CGFloat = 70

    /// Weapon range in points (slightly less than vision range so players see enemies before attacking)
    static let weaponRange: CGFloat = 700

    /// Visible range (for targeting) in points - covers most of the visible screen from camera center
    static let visibleRange: CGFloat = 800

    // MARK: - Properties

    /// Whether Nathaniel has collected a corpse (for certain levels)
    var hasCorpse: Bool = false

    /// Callback for when Nathaniel dies (for game over handling)
    var onDeathCallback: (() -> Void)?

    /// Primary weapon (Gun)
    let weapon: Gun

    // MARK: - Combat Properties

    /// Unified targeting component
    let targeting: TargetingComponent

    /// Current target for combat (delegates to targeting component)
    var currentTarget: Character? {
        self.targeting.currentTarget
    }

    /// Visual indicator showing Nathaniel's current target (red ring)
    private var targetIndicator: TargetIndicator?

    /// Legacy alias for backward compatibility
    var target: Character? {
        get { self.currentTarget }
        set {
            if let enemy = newValue as? Enemy {
                self.targeting.setManualTarget(enemy)
            } else {
                self.targeting.clearAll()
            }
        }
    }

    // MARK: - Initialization

    init() {
        // Initialize weapon first (before super.init)
        self.weapon = Gun()

        // Initialize targeting component
        self.targeting = TargetingComponent(
            behavior: .aggressive,
            attackRange: Nathaniel.weaponRange,
            visionRange: Nathaniel.visibleRange
        )

        super.init(
            name: "Nathaniel",
            maxHP: Nathaniel.defaultMaxHP,
            speed: Nathaniel.defaultSpeed,
            spriteSheetCols: 8,
            spriteSheetRows: 2
        )

        // Set weapon owner
        self.weapon.owner = self

        // Set vision range to match static constant
        visionRange = Nathaniel.visibleRange

        // Wire up targeting callbacks
        self.targeting.onTargetChanged = { [weak self] _ in
            self?.updateTargetIndicator()
        }

        print("Nathaniel: Initializing...")

        // Load the sprite sheet
        loadSpriteSheet(named: "nathanielspritesheet")

        print("Nathaniel: Sprite size after loading: \(sprite.size)")
        print("Nathaniel: Frame textures count: \(frameTextures.count)")

        // Set initial facing direction
        facingDirection = .south
    }

    // MARK: - Update

    override func update(deltaTime: TimeInterval) {
        #if DEBUG
            // Apply dev settings for live updates
            speed = DevSettings.shared.nathanielSpeed
        #endif

        super.update(deltaTime: deltaTime)

        // Update weapon (handles cooldown and projectiles)
        self.weapon.update(deltaTime: deltaTime)

        // Update targeting via component
        self.targeting.update(position: position, isActive: isActive && isAlive)

        // Update target indicator position to follow target
        self.targetIndicator?.updatePosition()

        // Auto-attack target if we have one and in range
        if self.targeting.isTargetInAttackRange(from: position),
           let target = currentTarget, target.isAlive
        {
            _ = self.weapon.use(target: target.position)
        }
    }

    // MARK: - Targeting

    /// Set a manual target (called when player taps an enemy)
    func setManualTarget(_ target: Enemy?) {
        self.targeting.setManualTarget(target)
    }

    /// Clear manual target (called when player taps ground or deselects)
    func clearManualTarget() {
        self.targeting.clearManualTarget()
    }

    /// Get current attack range
    var attackRange: CGFloat {
        Nathaniel.weaponRange
    }

    // MARK: - Combat Visual Feedback

    /// Update the target indicator when current target changes
    private func updateTargetIndicator() {
        // Remove existing indicator
        self.targetIndicator?.remove()
        self.targetIndicator = nil

        // Create new indicator for current target
        guard let target = self.currentTarget,
              let scene = sprite.scene
        else {
            return
        }

        // Create red indicator for Nathaniel's target
        self.targetIndicator = TargetIndicator.create(for: target.sprite, in: scene)
    }

    // MARK: - Combat

    /// Fire weapon at a specific position
    func fireAt(_ target: CGPoint) -> Bool {
        self.weapon.use(target: target)
    }

    /// Override takeDamage to support invincibility setting
    override func takeDamage(_ amount: Int) {
        #if DEBUG
            if DevSettings.shared.playerInvincible {
                return // Ignore damage when invincible
            }
        #endif
        super.takeDamage(amount)
    }

    // MARK: - Overrides

    override func onDeath() {
        // Clear combat state
        self.targeting.clearAll()

        // Don't call super - we want custom death handling for player
        animationState = .dead
        isActive = false

        // Fade out but don't remove (we may respawn)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        sprite.run(fadeOut)

        // Notify callback
        self.onDeathCallback?()
    }

    // MARK: - Respawn

    /// Respawn Nathaniel at a given position with full health
    func respawn(at position: CGPoint) {
        self.position = position
        self.currentHP = maxHP
        self.destination = nil
        self.facingDirection = .south
        self.animationState = .idle
        self.isActive = true

        // Reset combat state
        self.targeting.clearAll()

        // Reset sprite visuals
        sprite.alpha = 1.0
        sprite.removeAllActions()
        sprite.colorBlendFactor = 0.0

        updateTexture()
        updateHealthBar()
    }
}
