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

// MARK: - Damageable Protocol

/// Protocol for entities that have health and can be damaged/killed.
/// Used by threat assessment and targeting systems.
protocol Damageable: AnyObject {
    /// Display name
    var name: String { get }

    /// The sprite node (for visual effects like damage flash)
    var sprite: SKSpriteNode { get }

    /// World position
    var position: CGPoint { get }

    /// Current health points
    var currentHP: Int { get set }

    /// Maximum health points
    var maxHP: Int { get }

    /// Whether this entity is alive (currentHP > 0)
    var isAlive: Bool { get }

    /// Whether this entity is still active
    var isActive: Bool { get }

    /// Take damage from a source
    func takeDamage(_ amount: Int)

    /// Update health bar display
    func updateHealthBar()
}

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
    static var standardHeight: CGFloat { GameBalance.UI.HealthBar.standardHeight }

    /// Compact height for enemy health bars
    static var compactHeight: CGFloat { GameBalance.UI.HealthBar.compactHeight }

    /// Standard corner radius
    static var standardCornerRadius: CGFloat { GameBalance.UI.HealthBar.standardCornerRadius }

    /// Compact corner radius
    static var compactCornerRadius: CGFloat { GameBalance.UI.HealthBar.compactCornerRadius }

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
        self.node = SKNode()
        self.node.name = "healthBar"
        self.node.zPosition = 200 // Above character sprites

        let barRect = CGRect(x: -width / 2, y: 0, width: width, height: height)

        // Background (red - shows when health is missing)
        let bgPath = CGMutablePath()
        if cornerRadius > 0 {
            bgPath.addRoundedRect(in: barRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
        } else {
            bgPath.addRect(barRect)
        }
        self.backgroundNode = SKShapeNode(path: bgPath)
        self.backgroundNode.fillColor = SKColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 0.85)
        self.backgroundNode.strokeColor = .clear
        self.backgroundNode.lineWidth = 0

        // Health bar (green - shows current health)
        let healthPath = CGMutablePath()
        if cornerRadius > 0 {
            healthPath.addRoundedRect(in: barRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
        } else {
            healthPath.addRect(barRect)
        }
        self.healthNode = SKShapeNode(path: healthPath)
        self.healthNode.fillColor = SKColor(red: 0.2, green: 0.7, blue: 0.2, alpha: 1.0)
        self.healthNode.strokeColor = .clear
        self.healthNode.lineWidth = 0

        // Border (white outline)
        let borderPath = CGMutablePath()
        if cornerRadius > 0 {
            borderPath.addRoundedRect(in: barRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
        } else {
            borderPath.addRect(barRect)
        }
        self.borderNode = SKShapeNode(path: borderPath)
        self.borderNode.fillColor = .clear
        self.borderNode.strokeColor = SKColor.white.withAlphaComponent(0.8)
        self.borderNode.lineWidth = 1

        // Add in order: background, health, border
        self.node.addChild(self.backgroundNode)
        self.node.addChild(self.healthNode)
        self.node.addChild(self.borderNode)
    }

    /// Update the health bar to reflect current health
    func update(currentHP: Int, maxHP: Int) {
        guard maxHP > 0 else { return }

        let healthPercent = CGFloat(currentHP) / CGFloat(maxHP)
        let healthWidth = self.width * healthPercent

        // Update green health bar width
        let healthPath = CGMutablePath()
        let healthRect = CGRect(x: -self.width / 2, y: 0, width: healthWidth, height: self.height)
        if self.cornerRadius > 0, healthWidth > self.cornerRadius * 2 {
            healthPath.addRoundedRect(in: healthRect, cornerWidth: self.cornerRadius, cornerHeight: self.cornerRadius)
        } else {
            healthPath.addRect(healthRect)
        }
        self.healthNode.path = healthPath

        // Hide when full (optional)
        if self.hideWhenFull {
            self.node.isHidden = currentHP >= maxHP
        }
    }

    /// Position the health bar above a sprite
    func positionAbove(spriteHeight: CGFloat) {
        self.node.position = CGPoint(x: 0, y: spriteHeight / 2 + self.yOffset)
    }
}

/// Base class for all game characters (players, enemies)
class Character: GameEntity, Damageable {
    // MARK: - GameEntity Properties

    let sprite: SKSpriteNode

    var position: CGPoint {
        get { self.sprite.position }
        set { self.sprite.position = newValue }
    }

    var isActive: Bool = true

    // MARK: - Components

    /// Animation component for sprite sheet handling
    let animationComponent: AnimationComponent

    /// Movement component for pathfinding and movement
    let movementComponent: MovementComponent

    /// Health component for damage and health management
    let healthComponent: HealthComponent

    // MARK: - Character Properties

    /// Display name
    let name: String

    /// Current health points (delegates to healthComponent)
    var currentHP: Int {
        get { self.healthComponent.currentHP }
        set { self.healthComponent.setHealth(newValue) }
    }

    /// Maximum health points
    var maxHP: Int { self.healthComponent.maxHP }

    /// Whether the character is alive
    var isAlive: Bool { self.healthComponent.isAlive }

    /// Health bar display (delegates to healthComponent)
    var healthBar: HealthBar? {
        get { self.healthComponent.healthBar }
    }

    /// Movement speed in points per second (delegates to movementComponent)
    var speed: CGFloat {
        get { self.movementComponent.speed }
        set { self.movementComponent.speed = newValue }
    }

    /// Maximum speed (for resetting after effects)
    var maxSpeed: CGFloat { self.movementComponent.maxSpeed }

    /// Current movement destination (delegates to movementComponent)
    var destination: CGPoint? {
        get { self.movementComponent.destination }
        set { self.movementComponent.destination = newValue }
    }

    /// Whether the character is currently moving
    var isMoving: Bool { self.movementComponent.isMoving }

    /// Current facing direction (delegates to animationComponent)
    var facingDirection: FacingDirection {
        get { self.animationComponent.facingDirection }
        set { self.animationComponent.facingDirection = newValue }
    }

    /// Current animation state (delegates to animationComponent)
    var animationState: AnimationState {
        get { self.animationComponent.state }
        set { self.animationComponent.state = newValue }
    }

    /// Vision range for fog of war (how far the character can see)
    var visionRange: CGFloat = 200.0

    /// Collision radius for circle collision detection
    var collisionRadius: CGFloat {
        self.sprite.size.width * 0.4
    }

    // MARK: - Animation (backward compatibility)

    /// Sprite sheet columns
    let spriteSheetCols: Int

    /// Sprite sheet rows
    let spriteSheetRows: Int

    /// Individual frame textures organized by [row][col] (delegates to animationComponent)
    var frameTextures: [[SKTexture]] {
        get { self.animationComponent.frameTextures }
    }

    /// Base texture (sprite sheet) (delegates to animationComponent)
    var baseTexture: SKTexture? {
        get { self.animationComponent.baseTexture }
    }

    // MARK: - Pathfinding (backward compatibility)

    /// Pathfinding component for A* navigation (delegates to movementComponent)
    var pathfinding: PathfindingMovement? {
        get { self.movementComponent.pathfinding }
        set { self.movementComponent.pathfinding = newValue }
    }

    // MARK: - Targeting

    /// Callback to find enemies within targeting range
    var findEnemiesInRange: (() -> [Enemy])?

    /// Callback to get allied characters for group targeting
    var getAllies: (() -> [Character])?

    // MARK: - Initialization

    init(name: String, maxHP: Int, speed: CGFloat, spriteSheetCols: Int = 8, spriteSheetRows: Int = 2) {
        self.name = name
        self.spriteSheetCols = spriteSheetCols
        self.spriteSheetRows = spriteSheetRows

        // Create sprite node (will be configured by subclasses)
        self.sprite = SKSpriteNode()
        self.sprite.name = name

        // Initialize components
        self.animationComponent = AnimationComponent(
            sprite: self.sprite,
            columns: spriteSheetCols,
            rows: spriteSheetRows
        )
        self.movementComponent = MovementComponent(speed: speed)
        self.healthComponent = HealthComponent(maxHP: maxHP, sprite: self.sprite)

        // Wire up component callbacks
        self.setupComponentCallbacks()
    }

    /// Wire up callbacks between components
    private func setupComponentCallbacks() {
        // Movement -> Animation: update facing direction
        self.movementComponent.onFacingDirectionChanged = { [weak self] direction in
            self?.animationComponent.facingDirection = direction
        }

        // Movement -> Animation: update moving state
        self.movementComponent.onMovementStateChanged = { [weak self] isMoving in
            self?.animationComponent.isMoving = isMoving
            self?.animationComponent.state = isMoving ? .moving : .idle
        }

        // Health -> Character: handle death
        self.healthComponent.onDeath = { [weak self] in
            self?.onDeath()
        }
    }

    // MARK: - Texture Setup

    /// Load and slice a sprite sheet into individual frame textures
    func loadSpriteSheet(named textureName: String) {
        print("Character: Loading sprite sheet '\(textureName)'...")
        if self.animationComponent.loadSpriteSheet(named: textureName) {
            print("Character: Sprite sheet loading complete. Frame textures: \(self.frameTextures.count) rows")
        } else {
            print("Character: ERROR - Failed to load sprite sheet '\(textureName)'")
        }
    }

    /// Update the sprite texture based on current state
    func updateTexture() {
        self.animationComponent.updateTexture()
    }

    // MARK: - GameEntity Methods

    func update(deltaTime: TimeInterval) {
        guard self.isActive, self.isAlive else { return }

        self.updateMovement(deltaTime: deltaTime)
        self.updateAnimation()
    }

    // MARK: - Movement

    /// Update movement toward destination
    private func updateMovement(deltaTime: TimeInterval) {
        let newPosition = self.movementComponent.update(
            currentPosition: self.position,
            deltaTime: deltaTime,
            collisionRadius: self.collisionRadius
        )
        self.position = newPosition
    }

    /// Update animation state and texture
    private func updateAnimation() {
        self.updateTexture()
    }

    // MARK: - Health Bar

    /// Set up a health bar for this character
    /// - Parameters:
    ///   - width: Width of the health bar (defaults to sprite width)
    ///   - yOffset: Vertical offset above sprite
    ///   - compact: Use compact style (smaller height, rounded corners)
    func setupHealthBar(width: CGFloat? = nil, yOffset: CGFloat = 4, compact: Bool = false) {
        self.healthComponent.setupHealthBar(width: width, yOffset: yOffset, compact: compact)
    }

    /// Update the health bar display
    func updateHealthBar() {
        self.healthComponent.updateHealthBar()
    }

    // MARK: - Combat

    /// Take damage from a source
    func takeDamage(_ amount: Int) {
        self.healthComponent.takeDamage(amount)
    }

    /// Flash the sprite red briefly to indicate damage
    func showDamageFlash() {
        self.healthComponent.showDamageFlash()
    }

    /// Called when the character dies
    func onDeath() {
        self.animationState = .dead
        self.isActive = false

        // Play explosion sound
        if let scene = sprite.scene {
            AudioManager.shared.playSoundEffect(.explosion, on: scene)
        }

        // Fade out and remove
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let remove = SKAction.removeFromParent()
        let deathSequence = SKAction.sequence([fadeOut, remove])

        self.sprite.run(deathSequence)
    }

    // MARK: - Collision

    /// Check circle collision with another character
    func isColliding(with other: Character) -> Bool {
        self.position.distance(to: other.position) < self.collisionRadius + other.collisionRadius
    }

    /// Check if a point is within collision radius
    func contains(point: CGPoint) -> Bool {
        self.position.distance(to: point) < self.collisionRadius
    }

    // MARK: - Movement Commands

    /// Move toward a destination point
    /// If pathfinding is configured, calculates an A* path around obstacles.
    /// Otherwise, moves in a direct line.
    func moveTo(_ point: CGPoint) {
        self.movementComponent.moveTo(point, from: self.position)
    }

    /// Stop movement immediately
    func stop() {
        self.movementComponent.stop()
    }

    /// Configure pathfinding for this character
    /// - Parameter renderer: The TMXRenderer providing collision data
    func configurePathfinding(with renderer: TMXRenderer) {
        self.movementComponent.configurePathfinding(with: renderer)
    }
}
