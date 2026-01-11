import SpriteKit

/// Component handling sprite sheet animation for game entities
class AnimationComponent {
    // MARK: - Properties

    /// The sprite node to animate
    weak var sprite: SKSpriteNode?

    /// Sprite sheet columns
    let columns: Int

    /// Sprite sheet rows
    let rows: Int

    /// Individual frame textures organized by [row][col]
    private(set) var frameTextures: [[SKTexture]] = []

    /// Base texture (sprite sheet)
    private(set) var baseTexture: SKTexture?

    /// Current animation state
    var state: AnimationState = .idle

    /// Current facing direction
    var facingDirection: FacingDirection = .south

    /// Whether the entity is currently moving (affects texture selection)
    var isMoving: Bool = false

    // MARK: - Initialization

    init(sprite: SKSpriteNode, columns: Int = 8, rows: Int = 2) {
        self.sprite = sprite
        self.columns = columns
        self.rows = rows
    }

    // MARK: - Sprite Sheet Loading

    /// Load and slice a sprite sheet into individual frame textures
    /// - Parameter textureName: The name of the sprite sheet texture asset
    /// - Returns: True if loading succeeded, false otherwise
    @discardableResult
    func loadSpriteSheet(named textureName: String) -> Bool {
        guard let sprite else { return false }

        let texture = SKTexture(imageNamed: textureName)
        texture.filteringMode = .nearest
        self.baseTexture = texture

        let textureSize = texture.size()
        guard textureSize.width > 0, textureSize.height > 0 else {
            // Failed to load - set placeholder
            sprite.color = .blue
            sprite.size = CGSize(width: 32, height: 48)
            return false
        }

        let frameWidth = textureSize.width / CGFloat(self.columns)
        let frameHeight = textureSize.height / CGFloat(self.rows)

        // Configure sprite size based on a single frame
        sprite.size = CGSize(width: frameWidth, height: frameHeight)

        // Slice the sprite sheet into individual textures
        self.frameTextures = []
        for row in 0 ..< self.rows {
            var rowTextures: [SKTexture] = []
            for col in 0 ..< self.columns {
                // Calculate normalized rect (SpriteKit textures have origin at bottom-left)
                let x = CGFloat(col) / CGFloat(self.columns)
                let y = 1.0 - CGFloat(row + 1) / CGFloat(self.rows)
                let w = 1.0 / CGFloat(self.columns)
                let h = 1.0 / CGFloat(self.rows)

                let rect = CGRect(x: x, y: y, width: w, height: h)
                let frameTexture = SKTexture(rect: rect, in: texture)
                frameTexture.filteringMode = .nearest
                rowTextures.append(frameTexture)
            }
            self.frameTextures.append(rowTextures)
        }

        // Set initial texture
        self.updateTexture()
        return true
    }

    // MARK: - Texture Updates

    /// Update the sprite texture based on current state
    /// Uses standard row layout: row 0 = idle, row 1 = moving
    func updateTexture() {
        guard let sprite, !self.frameTextures.isEmpty else { return }

        let col = self.facingDirection.rawValue
        let row = self.isMoving ? 1 : 0

        guard row < self.frameTextures.count, col < self.frameTextures[row].count else { return }

        sprite.texture = self.frameTextures[row][col]
    }

    /// Get a specific texture frame
    /// - Parameters:
    ///   - row: The row index
    ///   - col: The column index
    /// - Returns: The texture at the specified position, or nil if out of bounds
    func texture(at row: Int, col: Int) -> SKTexture? {
        guard row < self.frameTextures.count, col < self.frameTextures[row].count else {
            return nil
        }
        return self.frameTextures[row][col]
    }

    /// Check if textures have been loaded
    var hasTextures: Bool {
        !self.frameTextures.isEmpty
    }
}
