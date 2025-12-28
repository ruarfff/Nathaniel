//
//  Nathaniel.swift
//  Nathaniel Shared
//
//  The main player character - Nathaniel.
//

import SpriteKit

/// The main player character class
class Nathaniel: Character {

    // MARK: - Constants (from legacy code)

    /// Starting/maximum health points
    static let defaultMaxHP = 8000

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

    /// Current target for auto-attack (if any)
    weak var target: Character?

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
        weapon.owner = self

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
        weapon.update(deltaTime: deltaTime)

        // Auto-attack target if we have one and weapon is ready
        if let target = target, target.isAlive {
            let dx = target.position.x - position.x
            let dy = target.position.y - position.y
            let distance = hypot(dx, dy)

            // Attack if in range
            if distance <= Nathaniel.weaponRange {
                _ = weapon.use(target: target.position)
            }
        }
    }

    // MARK: - Combat

    /// Fire weapon at a specific position
    func fireAt(_ target: CGPoint) -> Bool {
        return weapon.use(target: target)
    }

    /// Override takeDamage to support invincibility setting
    override func takeDamage(_ amount: Int) {
        #if DEBUG
        if DevSettings.shared.playerInvincible {
            return  // Ignore damage when invincible
        }
        #endif
        super.takeDamage(amount)
    }

    // MARK: - Overrides

    override func onDeath() {
        // Don't call super - we want custom death handling for player
        animationState = .dead
        isActive = false

        // Fade out but don't remove (we may respawn)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        sprite.run(fadeOut)

        // Notify callback
        onDeathCallback?()
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
        self.target = nil

        // Reset sprite visuals
        sprite.alpha = 1.0
        sprite.removeAllActions()
        sprite.colorBlendFactor = 0.0

        updateTexture()
        updateHealthBar()
    }
}
