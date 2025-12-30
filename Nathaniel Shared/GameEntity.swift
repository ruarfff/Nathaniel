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

// MARK: - Health Bar

/// Visual health bar displayed above characters
class HealthBar {
    /// The container node holding all health bar elements
    let node: SKNode

    /// The red background (showing damage taken)
    private let backgroundNode: SKShapeNode

    /// The green foreground (showing current health)
    private let healthNode: SKShapeNode

    /// The white border
    private let borderNode: SKShapeNode

    /// Width of the health bar
    let width: CGFloat

    /// Height of the health bar
    let height: CGFloat

    /// Corner radius for rounded bars
    let cornerRadius: CGFloat

    /// Offset above the character sprite
    let yOffset: CGFloat

    /// Whether to hide the bar when health is full
    var hideWhenFull: Bool = true

    /// Standard height for health bars
    static let standardHeight: CGFloat = 6

    /// Compact height for enemy health bars
    static let compactHeight: CGFloat = 4

    /// Standard corner radius
    static let standardCornerRadius: CGFloat = 0

    /// Compact corner radius
    static let compactCornerRadius: CGFloat = 2

    init(
        width: CGFloat,
        yOffset: CGFloat,
        height: CGFloat = HealthBar.standardHeight,
        cornerRadius: CGFloat = HealthBar.standardCornerRadius
    ) {
        self.width = width
        self.yOffset = yOffset
        self.height = height
        self.cornerRadius = cornerRadius

        // Create container node
        node = SKNode()
        node.name = "healthBar"
        node.zPosition = 200 // Above character sprites

        let barRect = CGRect(x: -width / 2, y: 0, width: width, height: height)

        // Background (red - shows when health is missing)
        let bgPath = CGMutablePath()
        if cornerRadius > 0 {
            bgPath.addRoundedRect(in: barRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
        } else {
            bgPath.addRect(barRect)
        }
        backgroundNode = SKShapeNode(path: bgPath)
        backgroundNode.fillColor = SKColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 0.85)
        backgroundNode.strokeColor = .clear
        backgroundNode.lineWidth = 0

        // Health bar (green - shows current health)
        let healthPath = CGMutablePath()
        if cornerRadius > 0 {
            healthPath.addRoundedRect(in: barRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
        } else {
            healthPath.addRect(barRect)
        }
        healthNode = SKShapeNode(path: healthPath)
        healthNode.fillColor = SKColor(red: 0.2, green: 0.7, blue: 0.2, alpha: 1.0)
        healthNode.strokeColor = .clear
        healthNode.lineWidth = 0

        // Border (white outline)
        let borderPath = CGMutablePath()
        if cornerRadius > 0 {
            borderPath.addRoundedRect(in: barRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
        } else {
            borderPath.addRect(barRect)
        }
        borderNode = SKShapeNode(path: borderPath)
        borderNode.fillColor = .clear
        borderNode.strokeColor = SKColor.white.withAlphaComponent(0.8)
        borderNode.lineWidth = 1

        // Add in order: background, health, border
        node.addChild(backgroundNode)
        node.addChild(healthNode)
        node.addChild(borderNode)
    }

    /// Update the health bar to reflect current health
    func update(currentHP: Int, maxHP: Int) {
        guard maxHP > 0 else { return }

        let healthPercent = CGFloat(currentHP) / CGFloat(maxHP)
        let healthWidth = width * healthPercent

        // Update green health bar width
        let healthPath = CGMutablePath()
        let healthRect = CGRect(x: -width / 2, y: 0, width: healthWidth, height: height)
        if cornerRadius > 0, healthWidth > cornerRadius * 2 {
            healthPath.addRoundedRect(in: healthRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
        } else {
            healthPath.addRect(healthRect)
        }
        healthNode.path = healthPath

        // Hide when full (optional)
        if hideWhenFull {
            node.isHidden = currentHP >= maxHP
        }
    }

    /// Position the health bar above a sprite
    func positionAbove(spriteHeight: CGFloat) {
        node.position = CGPoint(x: 0, y: spriteHeight / 2 + yOffset)
    }
}

/// Base class for all game characters (players, enemies)
class Character: GameEntity {
    // MARK: - GameEntity Properties

    let sprite: SKSpriteNode

    /// Health bar display
    var healthBar: HealthBar?

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

    /// Vision range for fog of war (how far the character can see)
    var visionRange: CGFloat = 200.0

    /// Collision radius for circle collision detection
    var collisionRadius: CGFloat {
        sprite.size.width * 0.4
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

    // MARK: - Pathfinding

    /// Pathfinding component for A* navigation (optional)
    var pathfinding: PathfindingMovement?

    /// Final destination when using pathfinding (may differ from current waypoint)
    private var finalDestination: CGPoint?

    // MARK: - Initialization

    init(name: String, maxHP: Int, speed: CGFloat, spriteSheetCols: Int = 8, spriteSheetRows: Int = 2) {
        self.name = name
        self.maxHP = maxHP
        currentHP = maxHP
        self.speed = speed
        maxSpeed = speed
        self.spriteSheetCols = spriteSheetCols
        self.spriteSheetRows = spriteSheetRows

        // Create sprite node (will be configured by subclasses)
        sprite = SKSpriteNode()
        sprite.name = name
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
        for row in 0 ..< spriteSheetRows {
            var rowTextures: [SKTexture] = []
            for col in 0 ..< spriteSheetCols {
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
        guard isActive, isAlive else { return }

        updateMovement(deltaTime: deltaTime)
        updateAnimation()
    }

    // MARK: - Movement

    /// Update movement toward destination
    private func updateMovement(deltaTime: TimeInterval) {
        // If using pathfinding, get next waypoint
        if let pathfinding = pathfinding, pathfinding.hasActivePath {
            updatePathfindingMovement(deltaTime: deltaTime, pathfinding: pathfinding)
            return
        }

        // Direct movement (no pathfinding)
        guard let dest = destination else {
            animationState = .idle
            return
        }

        moveTowardPoint(dest, deltaTime: deltaTime)

        // Check if we've arrived at final destination
        let direction = CGVector(dx: dest.x - position.x, dy: dest.y - position.y)
        let distance = sqrt(direction.dx * direction.dx + direction.dy * direction.dy)
        if distance <= 5 {
            destination = nil
            finalDestination = nil
            animationState = .idle
        }
    }

    /// Update movement using pathfinding waypoints
    private func updatePathfindingMovement(deltaTime: TimeInterval, pathfinding: PathfindingMovement) {
        // Get next waypoint from path follower
        guard let waypoint = pathfinding.update(currentPosition: position) else {
            // Path complete - clear destinations
            destination = nil
            finalDestination = nil
            animationState = .idle
            return
        }

        // Move toward current waypoint
        moveTowardPoint(waypoint, deltaTime: deltaTime)

        // Update destination to current waypoint for isMoving check
        destination = waypoint
    }

    /// Move toward a specific point (shared by direct and pathfinding movement)
    private func moveTowardPoint(_ target: CGPoint, deltaTime: TimeInterval) {
        let direction = CGVector(dx: target.x - position.x, dy: target.y - position.y)
        let distance = sqrt(direction.dx * direction.dx + direction.dy * direction.dy)

        guard distance > 0 else { return }

        // Normalize and move
        let normalizedDir = CGVector(dx: direction.dx / distance, dy: direction.dy / distance)
        let moveDistance = speed * CGFloat(deltaTime)

        // Don't overshoot
        let actualMove = min(moveDistance, distance)

        // Calculate new position
        let newPosition = CGPoint(
            x: position.x + normalizedDir.dx * actualMove,
            y: position.y + normalizedDir.dy * actualMove
        )

        // Check collision if pathfinding is configured
        if let pathfinding = pathfinding {
            if pathfinding.isWalkable(at: newPosition) {
                position = newPosition
            } else {
                // Try sliding along X axis
                let slideX = CGPoint(x: newPosition.x, y: position.y)
                if pathfinding.isWalkable(at: slideX) {
                    position = slideX
                } else {
                    // Try sliding along Y axis
                    let slideY = CGPoint(x: position.x, y: newPosition.y)
                    if pathfinding.isWalkable(at: slideY) {
                        position = slideY
                    }
                    // If both blocked, don't move (character is stuck)
                }
            }
        } else {
            // No pathfinding - direct movement without collision check
            position = newPosition
        }

        // Update facing direction
        facingDirection = FacingDirection.from(direction: direction)
        animationState = .moving
    }

    /// Update animation state and texture
    private func updateAnimation() {
        updateTexture()
    }

    // MARK: - Health Bar

    /// Set up a health bar for this character
    /// - Parameters:
    ///   - width: Width of the health bar (defaults to sprite width)
    ///   - yOffset: Vertical offset above sprite
    ///   - compact: Use compact style (smaller height, rounded corners)
    func setupHealthBar(width: CGFloat? = nil, yOffset: CGFloat = 4, compact: Bool = false) {
        let barWidth = width ?? sprite.size.width
        let height = compact ? HealthBar.compactHeight : HealthBar.standardHeight
        let cornerRadius = compact ? HealthBar.compactCornerRadius : HealthBar.standardCornerRadius

        healthBar = HealthBar(width: barWidth, yOffset: yOffset, height: height, cornerRadius: cornerRadius)

        if let healthBar {
            healthBar.positionAbove(spriteHeight: sprite.size.height)
            sprite.addChild(healthBar.node)
            healthBar.update(currentHP: currentHP, maxHP: maxHP)
        }
    }

    /// Update the health bar display
    func updateHealthBar() {
        healthBar?.update(currentHP: currentHP, maxHP: maxHP)
    }

    // MARK: - Combat

    /// Take damage from a source
    func takeDamage(_ amount: Int) {
        guard isAlive else { return }
        currentHP -= amount

        // Update health bar
        updateHealthBar()

        // Flash red to indicate damage
        showDamageFlash()
    }

    /// Flash the sprite red briefly to indicate damage
    func showDamageFlash() {
        // Enable color blending
        sprite.colorBlendFactor = 0.0

        // Flash sequence: tint red, then back to normal
        let flashRed = SKAction.colorize(with: .red, colorBlendFactor: 0.7, duration: 0.05)
        let flashBack = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.15)
        let flashSequence = SKAction.sequence([flashRed, flashBack])

        sprite.run(flashSequence)
    }

    /// Called when the character dies
    func onDeath() {
        animationState = .dead
        isActive = false

        // Play explosion sound
        if let scene = sprite.scene {
            AudioManager.shared.playSoundEffect(.explosion, on: scene)
        }

        // Fade out and remove
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let remove = SKAction.removeFromParent()
        let deathSequence = SKAction.sequence([fadeOut, remove])

        sprite.run(deathSequence)
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
    /// If pathfinding is configured, calculates an A* path around obstacles.
    /// Otherwise, moves in a direct line.
    func moveTo(_ point: CGPoint) {
        finalDestination = point

        // Try pathfinding if available
        if let pathfinding = pathfinding, pathfinding.isEnabled {
            if pathfinding.calculatePath(from: position, to: point) {
                // Path found - movement will follow waypoints
                destination = pathfinding.currentWaypoint ?? point
                return
            }
            // No path found - fall through to direct movement
        }

        // Direct movement (no pathfinding or path not found)
        destination = point
    }

    /// Stop movement immediately
    func stop() {
        destination = nil
        finalDestination = nil
        pathfinding?.clearPath()
    }

    /// Configure pathfinding for this character
    /// - Parameter renderer: The TMXRenderer providing collision data
    func configurePathfinding(with renderer: TMXRenderer) {
        let pathfinding = PathfindingMovement()
        pathfinding.configure(with: renderer)
        self.pathfinding = pathfinding
    }
}
