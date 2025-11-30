//
//  Hermes.swift
//  Nathaniel Shared
//
//  The robot companion character - Hermes.
//

import SpriteKit

/// The robot companion character class
class Hermes: Character {

    // MARK: - Constants (from legacy code)

    /// Starting/maximum health points
    static let defaultMaxHP = 2000

    /// Movement speed in points per second
    static let defaultSpeed: CGFloat = 40

    /// Weapon range in points
    static let weaponRange: CGFloat = 450

    /// Visible range (for targeting) in points
    static let visibleRange: CGFloat = 500

    /// Distance at which Hermes stops following (to avoid clustering)
    static let followStopDistance: CGFloat = 100

    // MARK: - Sprite Sheet Configuration

    /// Idle sprite sheet has 8 columns (directions) x 1 row
    private static let idleSheetCols = 8
    private static let idleSheetRows = 1

    /// Moving sprite sheet has 5 columns x 1 row
    private static let movingSheetCols = 5
    private static let movingSheetRows = 1

    // MARK: - Properties

    /// Textures for idle state (8 directions)
    private var idleTextures: [SKTexture] = []

    /// Textures for moving state (5 frames, mapped to directions)
    private var movingTextures: [SKTexture] = []

    /// Whether Hermes is in build mode (placing structures)
    var isInBuildMode: Bool = false {
        didSet {
            // When in build mode, Hermes doesn't follow automatically
        }
    }

    /// The character Hermes should follow when not in build mode
    weak var followTarget: Character?

    /// Callback for when Hermes dies (for game over handling)
    var onDeathCallback: (() -> Void)?

    // MARK: - Initialization

    init() {
        super.init(
            name: "Hermes",
            maxHP: Hermes.defaultMaxHP,
            speed: Hermes.defaultSpeed,
            spriteSheetCols: Hermes.idleSheetCols,
            spriteSheetRows: Hermes.idleSheetRows
        )

        print("Hermes: Initializing...")

        // Load both sprite sheets
        loadIdleSpriteSheet()
        loadMovingSpriteSheet()

        print("Hermes: Sprite size after loading: \(sprite.size)")
        print("Hermes: Idle textures count: \(idleTextures.count)")
        print("Hermes: Moving textures count: \(movingTextures.count)")

        // Set initial facing direction
        facingDirection = .south

        // Start in build mode (legacy behavior)
        isInBuildMode = true
    }

    // MARK: - Texture Loading

    /// Load the idle sprite sheet (8 directions)
    private func loadIdleSpriteSheet() {
        print("Hermes: Loading idle sprite sheet...")

        let texture = SKTexture(imageNamed: "hermesidlespritesheet")
        texture.filteringMode = .nearest

        let textureSize = texture.size()
        print("Hermes: Idle texture size: \(textureSize)")

        guard textureSize.width > 0, textureSize.height > 0 else {
            print("Hermes: ERROR - Failed to load idle sprite sheet - size is zero")
            sprite.color = .purple
            sprite.size = CGSize(width: 32, height: 48)
            return
        }

        let frameWidth = textureSize.width / CGFloat(Hermes.idleSheetCols)
        let frameHeight = textureSize.height / CGFloat(Hermes.idleSheetRows)
        print("Hermes: Idle frame size: \(frameWidth) x \(frameHeight)")

        // Configure sprite size based on a single frame
        sprite.size = CGSize(width: frameWidth, height: frameHeight)

        // Slice the idle sprite sheet into individual textures
        idleTextures = []
        for col in 0..<Hermes.idleSheetCols {
            let x = CGFloat(col) / CGFloat(Hermes.idleSheetCols)
            let w = 1.0 / CGFloat(Hermes.idleSheetCols)

            let rect = CGRect(x: x, y: 0, width: w, height: 1.0)
            let frameTexture = SKTexture(rect: rect, in: texture)
            frameTexture.filteringMode = .nearest
            idleTextures.append(frameTexture)
        }

        // Set initial texture
        if !idleTextures.isEmpty {
            sprite.texture = idleTextures[0]
        }
    }

    /// Load the moving sprite sheet (5 frames for animation)
    private func loadMovingSpriteSheet() {
        print("Hermes: Loading moving sprite sheet...")

        let texture = SKTexture(imageNamed: "hermesmovingspritesheet")
        texture.filteringMode = .nearest

        let textureSize = texture.size()
        print("Hermes: Moving texture size: \(textureSize)")

        guard textureSize.width > 0, textureSize.height > 0 else {
            print("Hermes: ERROR - Failed to load moving sprite sheet")
            return
        }

        // Slice the moving sprite sheet into individual textures
        movingTextures = []
        for col in 0..<Hermes.movingSheetCols {
            let x = CGFloat(col) / CGFloat(Hermes.movingSheetCols)
            let w = 1.0 / CGFloat(Hermes.movingSheetCols)

            let rect = CGRect(x: x, y: 0, width: w, height: 1.0)
            let frameTexture = SKTexture(rect: rect, in: texture)
            frameTexture.filteringMode = .nearest
            movingTextures.append(frameTexture)
        }
    }

    // MARK: - Texture Updates

    /// Override to use Hermes-specific sprite sheets
    override func updateTexture() {
        if isMoving && !movingTextures.isEmpty {
            // Use moving sprite based on direction
            // Legacy mapping: direction -> moving frame index
            let movingIndex = movingTextureIndex(for: facingDirection)
            sprite.texture = movingTextures[movingIndex]
        } else if !idleTextures.isEmpty {
            // Use idle sprite based on direction
            let idleIndex = idleTextureIndex(for: facingDirection)
            sprite.texture = idleTextures[idleIndex]
        }
    }

    /// Map facing direction to idle texture index
    /// Legacy mapping from UpdateState():
    /// South=0, SouthWest=1, North=2, West=3, SouthEast=4, NorthEast=5, East=6, NorthWest=7
    private func idleTextureIndex(for direction: FacingDirection) -> Int {
        return direction.rawValue
    }

    /// Map facing direction to moving texture index
    /// Legacy mapping:
    /// North/South -> 1, SouthEast -> 2, NorthEast/East -> 3, NorthWest/West -> 4, SouthWest -> 0
    private func movingTextureIndex(for direction: FacingDirection) -> Int {
        switch direction {
        case .north, .south:
            return 1
        case .southEast:
            return 2
        case .northEast, .east:
            return 3
        case .northWest, .west:
            return 4
        case .southWest:
            return 0
        }
    }

    // MARK: - Update

    override func update(deltaTime: TimeInterval) {
        // Handle follow behavior when not in build mode
        if !isInBuildMode, let target = followTarget {
            updateFollowBehavior(target: target)
        }

        super.update(deltaTime: deltaTime)
    }

    /// Update follow behavior - follow target unless within stop distance
    private func updateFollowBehavior(target: Character) {
        let dx = target.position.x - position.x
        let dy = target.position.y - position.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance > Hermes.followStopDistance {
            // Follow the target
            destination = target.position
        } else {
            // Close enough, stop moving
            destination = nil
        }
    }

    // MARK: - Overrides

    override func onDeath() {
        super.onDeath()
        onDeathCallback?()
    }

    // MARK: - Respawn

    /// Respawn Hermes at a given position with full health
    func respawn(at position: CGPoint) {
        self.position = position
        self.currentHP = maxHP
        self.destination = nil
        self.facingDirection = .south
        self.animationState = .idle
        self.isActive = true
        updateTexture()
    }

    // MARK: - Build Mode

    /// Toggle build mode on/off
    func toggleBuildMode() {
        isInBuildMode = !isInBuildMode
    }

    /// Enter build mode (stop following)
    func enterBuildMode() {
        isInBuildMode = true
        stop()
    }

    /// Exit build mode (resume following)
    func exitBuildMode() {
        isInBuildMode = false
    }
}
