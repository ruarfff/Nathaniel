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

    /// Current target for combat (may be auto-acquired or manual)
    weak var currentTarget: Character? {
        didSet {
            if oldValue !== self.currentTarget {
                self.updateTargetIndicator()
            }
        }
    }

    /// Manual target override set by player (takes priority over auto-targeting)
    weak var manualTargetOverride: Character?

    /// Current targeting behavior mode
    var targetingBehavior: TargetingBehavior = .aggressive

    /// Visual indicator showing Nathaniel's current target (red ring)
    private var targetIndicator: TargetIndicator?

    /// Legacy alias for backward compatibility
    var target: Character? {
        get { self.currentTarget }
        set { self.currentTarget = newValue }
    }

    // MARK: - Initialization

    init() {
        // Initialize weapon first (before super.init)
        self.weapon = Gun()

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

        // Update targeting (auto-acquire if no manual target)
        self.updateTargeting()

        // Update target indicator position to follow target
        self.targetIndicator?.updatePosition()

        // Auto-attack target if we have one and weapon is ready
        if let target = currentTarget, target.isAlive {
            let dx = target.position.x - position.x
            let dy = target.position.y - position.y
            let distance = hypot(dx, dy)

            // Attack if in range
            if distance <= Nathaniel.weaponRange {
                _ = self.weapon.use(target: target.position)
            }
        }
    }

    // MARK: - Targeting

    /// Update targeting based on manual override or auto-acquisition
    private func updateTargeting() {
        guard isActive, isAlive else {
            self.currentTarget = nil
            return
        }

        // Manual override always takes priority
        if let manual = manualTargetOverride, manual.isAlive {
            self.currentTarget = manual
            return
        }

        // Clear manual override if target is dead
        if self.manualTargetOverride != nil, self.manualTargetOverride?.isAlive != true {
            self.manualTargetOverride = nil
        }

        // Check if current target is still valid (sticky targeting)
        if let current = currentTarget {
            if !current.isAlive {
                // Target died - clear it
                self.currentTarget = nil
            } else {
                // Check if target is still in vision range
                let dx = current.position.x - position.x
                let dy = current.position.y - position.y
                let distance = hypot(dx, dy)

                if distance > Nathaniel.visibleRange {
                    // Target left vision range - clear it
                    self.currentTarget = nil
                } else {
                    // Keep current target (sticky targeting)
                    return
                }
            }
        }

        // No valid target - find a new one using threat assessment
        guard let enemies = findEnemiesInRange?() else { return }
        let allies = self.getAllies?() ?? []

        // Find best target using aggressive behavior (Nathaniel is main combat character)
        if let bestTarget = ThreatAssessment.findBestTarget(
            from: position,
            enemies: enemies,
            allies: allies,
            behavior: self.targetingBehavior,
            maxRange: Nathaniel.visibleRange
        ) {
            self.currentTarget = bestTarget
        }
    }

    /// Set a manual target (called when player taps an enemy)
    func setManualTarget(_ target: Enemy?) {
        self.manualTargetOverride = target
        self.currentTarget = target
    }

    /// Clear manual target (called when player taps ground or deselects)
    func clearManualTarget() {
        self.manualTargetOverride = nil
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
        self.currentTarget = nil
        self.manualTargetOverride = nil

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
        self.currentTarget = nil
        self.manualTargetOverride = nil

        // Reset sprite visuals
        sprite.alpha = 1.0
        sprite.removeAllActions()
        sprite.colorBlendFactor = 0.0

        updateTexture()
        updateHealthBar()
    }
}
