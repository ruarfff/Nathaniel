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

    /// Weapon range in points
    static let weaponRange: CGFloat = 450

    /// Visible range (for targeting) in points
    static let visibleRange: CGFloat = 500

    // MARK: - Properties

    /// Whether Nathaniel has collected a corpse (for certain levels)
    var hasCorpse: Bool = false

    /// Callback for when Nathaniel dies (for game over handling)
    var onDeathCallback: (() -> Void)?

    // MARK: - Initialization

    init() {
        super.init(
            name: "Nathaniel",
            maxHP: Nathaniel.defaultMaxHP,
            speed: Nathaniel.defaultSpeed,
            spriteSheetCols: 8,
            spriteSheetRows: 2
        )

        print("Nathaniel: Initializing...")

        // Load the sprite sheet
        loadSpriteSheet(named: "nathanielspritesheet")

        print("Nathaniel: Sprite size after loading: \(sprite.size)")
        print("Nathaniel: Frame textures count: \(frameTextures.count)")

        // Set initial facing direction
        facingDirection = .south
    }

    // MARK: - Overrides

    override func onDeath() {
        super.onDeath()
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
        updateTexture()
    }
}
