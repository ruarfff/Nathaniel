//
//  GameEntity.swift
//  Nathaniel Shared
//
//  Game entity protocol and base classes for the entity system.
//

import SpriteKit

// MARK: - Direction

/// Represents the 8 cardinal/ordinal directions a character can face
enum FacingDirection: Int, CaseIterable {
    case south = 0
    case southWest = 1
    case north = 2
    case west = 3
    case southEast = 4
    case northEast = 5
    case east = 6
    case northWest = 7

    /// Get facing direction from a movement vector
    static func from(direction: CGVector) -> FacingDirection {
        guard direction.dx != 0 || direction.dy != 0 else {
            return .south
        }

        // Calculate angle and convert to 8 regions
        // SpriteKit: +y is up, +x is right
        let angle = atan2(-direction.dy, -direction.dx)
        let normalizedAngle = (angle + .pi * 2).truncatingRemainder(dividingBy: .pi * 2)
        let region = Int(round(normalizedAngle * 8 / (.pi * 2))) % 8

        // Map regions to facing directions (matches legacy code)
        switch region {
        case 0: return .west
        case 1: return .northWest
        case 2: return .north
        case 3: return .northEast
        case 4: return .east
        case 5: return .southEast
        case 6: return .south
        case 7: return .southWest
        default: return .south
        }
    }
}

// MARK: - Animation State

/// Animation states for characters
enum AnimationState {
    case idle
    case moving
    case attacking
    case dead
}

// MARK: - GameEntity Protocol

/// Protocol for all game entities (characters, projectiles, structures, etc.)
protocol GameEntity: AnyObject {
    /// The sprite node representing this entity
    var sprite: SKSpriteNode { get }

    /// World position (center of the entity)
    var position: CGPoint { get set }

    /// Whether this entity is still active (should be updated/drawn)
    var isActive: Bool { get set }

    /// Update the entity each frame
    func update(deltaTime: TimeInterval)
}

// MARK: - Character Base Class

/// Base class for all game characters (players, enemies)
class Character: GameEntity {

    // MARK: - GameEntity Properties

    let sprite: SKSpriteNode

    var position: CGPoint {
        get { sprite.position }
        set { sprite.position = newValue }
    }

    var isActive: Bool = true

    // MARK: - Character Properties

    /// Display name
    let name: String

    /// Current health points
    var currentHP: Int {
        didSet {
            if currentHP <= 0 {
                currentHP = 0
                onDeath()
            }
        }
    }

    /// Maximum health points
    let maxHP: Int

    /// Whether the character is alive
    var isAlive: Bool { currentHP > 0 }

    /// Movement speed in points per second
    var speed: CGFloat

    /// Maximum speed (for resetting after effects)
    let maxSpeed: CGFloat

    /// Current movement destination (nil if not moving)
    var destination: CGPoint?

    /// Whether the character is currently moving
    var isMoving: Bool { destination != nil }

    /// Current facing direction
    var facingDirection: FacingDirection = .south

    /// Current animation state
    var animationState: AnimationState = .idle

    /// Collision radius for circle collision detection
    var collisionRadius: CGFloat {
        return sprite.size.width * 0.4
    }

    // MARK: - Animation

    /// Sprite sheet columns
    let spriteSheetCols: Int

    /// Sprite sheet rows
    let spriteSheetRows: Int

    /// Individual frame textures organized by [row][col]
    var frameTextures: [[SKTexture]] = []

    /// Base texture (sprite sheet)
    var baseTexture: SKTexture?

    // MARK: - Initialization

    init(name: String, maxHP: Int, speed: CGFloat, spriteSheetCols: Int = 8, spriteSheetRows: Int = 2) {
        self.name = name
        self.maxHP = maxHP
        self.currentHP = maxHP
        self.speed = speed
        self.maxSpeed = speed
        self.spriteSheetCols = spriteSheetCols
        self.spriteSheetRows = spriteSheetRows

        // Create sprite node (will be configured by subclasses)
        self.sprite = SKSpriteNode()
        self.sprite.name = name
    }

    // MARK: - Texture Setup

    /// Load and slice a sprite sheet into individual frame textures
    func loadSpriteSheet(named textureName: String) {
        print("Character: Loading sprite sheet '\(textureName)'...")

        let texture = SKTexture(imageNamed: textureName)
        texture.filteringMode = .nearest
        baseTexture = texture

        let textureSize = texture.size()
        print("Character: Texture size: \(textureSize)")

        guard textureSize.width > 0, textureSize.height > 0 else {
            print("Character: ERROR - Failed to load sprite sheet '\(textureName)' - size is zero")
            // Try setting a placeholder color so we can at least see something
            sprite.color = .blue
            sprite.size = CGSize(width: 32, height: 48)
            return
        }

        let frameWidth = textureSize.width / CGFloat(spriteSheetCols)
        let frameHeight = textureSize.height / CGFloat(spriteSheetRows)
        print("Character: Frame size: \(frameWidth) x \(frameHeight)")

        // Configure sprite size based on a single frame
        sprite.size = CGSize(width: frameWidth, height: frameHeight)
        print("Character: Sprite size set to: \(sprite.size)")

        // Slice the sprite sheet into individual textures
        frameTextures = []
        for row in 0..<spriteSheetRows {
            var rowTextures: [SKTexture] = []
            for col in 0..<spriteSheetCols {
                // Calculate normalized rect (SpriteKit textures have origin at bottom-left)
                let x = CGFloat(col) / CGFloat(spriteSheetCols)
                let y = 1.0 - CGFloat(row + 1) / CGFloat(spriteSheetRows)
                let w = 1.0 / CGFloat(spriteSheetCols)
                let h = 1.0 / CGFloat(spriteSheetRows)

                let rect = CGRect(x: x, y: y, width: w, height: h)
                let frameTexture = SKTexture(rect: rect, in: texture)
                frameTexture.filteringMode = .nearest
                rowTextures.append(frameTexture)
            }
            frameTextures.append(rowTextures)
        }

        // Set initial texture
        updateTexture()
        print("Character: Sprite sheet loading complete. Frame textures: \(frameTextures.count) rows")
    }

    /// Update the sprite texture based on current state
    func updateTexture() {
        guard !frameTextures.isEmpty else {
            print("Character: updateTexture - no frame textures loaded!")
            return
        }

        let col = facingDirection.rawValue
        let row = isMoving ? 1 : 0

        guard row < frameTextures.count, col < frameTextures[row].count else {
            print("Character: updateTexture - invalid row/col: \(row)/\(col)")
            return
        }

        sprite.texture = frameTextures[row][col]
    }

    // MARK: - GameEntity Methods

    func update(deltaTime: TimeInterval) {
        guard isActive && isAlive else { return }

        updateMovement(deltaTime: deltaTime)
        updateAnimation()
    }

    // MARK: - Movement

    /// Update movement toward destination
    private func updateMovement(deltaTime: TimeInterval) {
        guard let dest = destination else {
            animationState = .idle
            return
        }

        let direction = CGVector(dx: dest.x - position.x, dy: dest.y - position.y)
        let distance = sqrt(direction.dx * direction.dx + direction.dy * direction.dy)

        // Check if we've arrived (within 5 points, matching legacy)
        if distance <= 5 {
            destination = nil
            animationState = .idle
            return
        }

        // Normalize and move
        let normalizedDir = CGVector(dx: direction.dx / distance, dy: direction.dy / distance)
        let moveDistance = speed * CGFloat(deltaTime)

        // Don't overshoot
        let actualMove = min(moveDistance, distance)

        position = CGPoint(
            x: position.x + normalizedDir.dx * actualMove,
            y: position.y + normalizedDir.dy * actualMove
        )

        // Update facing direction
        facingDirection = FacingDirection.from(direction: direction)
        animationState = .moving
    }

    /// Update animation state and texture
    private func updateAnimation() {
        updateTexture()
    }

    // MARK: - Combat

    /// Take damage from a source
    func takeDamage(_ amount: Int) {
        guard isAlive else { return }
        currentHP -= amount
    }

    /// Called when the character dies
    func onDeath() {
        animationState = .dead
        // Subclasses can override for specific death behavior
    }

    // MARK: - Collision

    /// Check circle collision with another character
    func isColliding(with other: Character) -> Bool {
        let dx = position.x - other.position.x
        let dy = position.y - other.position.y
        let distance = sqrt(dx * dx + dy * dy)
        return distance < collisionRadius + other.collisionRadius
    }

    /// Check if a point is within collision radius
    func contains(point: CGPoint) -> Bool {
        let dx = position.x - point.x
        let dy = position.y - point.y
        let distance = sqrt(dx * dx + dy * dy)
        return distance < collisionRadius
    }

    // MARK: - Movement Commands

    /// Move toward a destination point
    func moveTo(_ point: CGPoint) {
        destination = point
    }

    /// Stop movement immediately
    func stop() {
        destination = nil
    }
}
