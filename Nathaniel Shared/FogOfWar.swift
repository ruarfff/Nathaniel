import SpriteKit

/// Represents the visibility state of a tile
enum FogState: Int {
    case unexplored = 0 // Never seen - fully obscured
    case explored = 1 // Previously seen - dimmed
    case visible = 2 // Currently visible - clear
}

/// Manages fog of war rendering and visibility calculations
class FogOfWar {
    // MARK: - Properties

    /// Map dimensions in tiles
    private let mapWidth: Int
    private let mapHeight: Int

    /// Size of each tile in pixels
    private let tileSize: CGFloat

    /// Fog state for each tile [y][x]
    private var fogState: [[FogState]]

    /// The parent node containing all fog tiles
    let fogNode: SKNode

    /// Individual fog tile sprites [y][x]
    private var fogTiles: [[SKSpriteNode]]

    /// Alpha value for unexplored tiles
    private let unexploredAlpha: CGFloat = GameBalance.FogOfWar.unexploredAlpha

    /// Alpha value for explored (previously seen) tiles
    private let exploredAlpha: CGFloat = GameBalance.FogOfWar.exploredAlpha

    /// Alpha value for visible tiles (fully transparent)
    private let visibleAlpha: CGFloat = GameBalance.FogOfWar.visibleAlpha

    /// Dirty tiles that need visual update
    private var dirtyTiles: Set<TileCoord> = []

    /// Simple struct for tile coordinates (Hashable)
    private struct TileCoord: Hashable {
        let x: Int
        let y: Int
    }

    /// Throttle fog updates for performance
    private var lastUpdateTime: TimeInterval = 0
    private let updateInterval: TimeInterval = GameBalance.FogOfWar.updateInterval

    // MARK: - Initialization

    /// Create a fog of war system for a map
    /// - Parameters:
    ///   - mapWidth: Map width in tiles
    ///   - mapHeight: Map height in tiles
    ///   - tileSize: Size of each tile in pixels
    init(mapWidth: Int, mapHeight: Int, tileSize: CGFloat) {
        self.mapWidth = mapWidth
        self.mapHeight = mapHeight
        self.tileSize = tileSize

        // Initialize fog state - all unexplored
        self.fogState = Array(repeating: Array(repeating: .unexplored, count: mapWidth), count: mapHeight)

        // Create fog node container
        self.fogNode = SKNode()
        self.fogNode.name = "fogOfWar"

        // Initialize fog tiles array
        self.fogTiles = []

        // Create fog tile sprites
        self.createFogTiles()
    }

    /// Create fog tile sprites covering the entire map
    private func createFogTiles() {
        for y in 0 ..< self.mapHeight {
            var rowTiles: [SKSpriteNode] = []
            for x in 0 ..< self.mapWidth {
                let tile = SKSpriteNode(color: .black, size: CGSize(width: tileSize, height: tileSize))
                // Position tile center (SpriteKit origin is bottom-left)
                tile.position = CGPoint(
                    x: CGFloat(x) * self.tileSize + self.tileSize / 2,
                    y: CGFloat(y) * self.tileSize + self.tileSize / 2
                )
                tile.alpha = self.unexploredAlpha
                tile.zPosition = 50 // Above map tiles, below characters
                self.fogNode.addChild(tile)
                rowTiles.append(tile)
            }
            self.fogTiles.append(rowTiles)
        }
    }

    // MARK: - Coordinate Conversion

    /// Convert world position to tile coordinates
    private func worldToTile(_ position: CGPoint) -> (x: Int, y: Int) {
        let x = Int(position.x / self.tileSize)
        let y = Int(position.y / self.tileSize)
        return (x: max(0, min(self.mapWidth - 1, x)), y: max(0, min(self.mapHeight - 1, y)))
    }

    /// Convert tile coordinates to world position (center of tile)
    private func tileToWorld(x: Int, y: Int) -> CGPoint {
        CGPoint(
            x: CGFloat(x) * self.tileSize + self.tileSize / 2,
            y: CGFloat(y) * self.tileSize + self.tileSize / 2
        )
    }

    /// Check if tile coordinates are valid
    private func isValidTile(x: Int, y: Int) -> Bool {
        x >= 0 && x < self.mapWidth && y >= 0 && y < self.mapHeight
    }

    // MARK: - Visibility Update

    /// Update fog of war based on character positions and vision ranges
    /// - Parameter positions: Array of (position, visionRange) tuples for each character
    func update(visibleFrom positions: [(CGPoint, CGFloat)]) {
        // Reset all currently visible tiles to explored
        for y in 0 ..< self.mapHeight {
            for x in 0 ..< self.mapWidth {
                if self.fogState[y][x] == .visible {
                    self.fogState[y][x] = .explored
                    self.dirtyTiles.insert(TileCoord(x: x, y: y))
                }
            }
        }

        // Mark tiles in vision range as visible
        for (position, visionRange) in positions {
            self.updateVisibilityFrom(position: position, visionRange: visionRange)
        }

        // Commit visual updates
        self.commitVisualUpdates()
    }

    /// Update fog of war with throttling (for use in game loop)
    /// - Parameters:
    ///   - positions: Array of (position, visionRange) tuples
    ///   - currentTime: Current game time
    /// - Returns: Whether an update was performed
    @discardableResult
    func updateThrottled(visibleFrom positions: [(CGPoint, CGFloat)], currentTime: TimeInterval) -> Bool {
        guard currentTime - self.lastUpdateTime >= self.updateInterval else {
            return false
        }
        self.lastUpdateTime = currentTime
        self.update(visibleFrom: positions)
        return true
    }

    /// Calculate and update visibility from a single position
    private func updateVisibilityFrom(position: CGPoint, visionRange: CGFloat) {
        let centerTile = self.worldToTile(position)
        let tileRange = Int(ceil(visionRange / self.tileSize)) + 1

        // Check tiles within the vision range bounding box
        for dy in -tileRange ... tileRange {
            for dx in -tileRange ... tileRange {
                let tx = centerTile.x + dx
                let ty = centerTile.y + dy

                guard self.isValidTile(x: tx, y: ty) else { continue }

                // Calculate distance from position to tile center
                let tileCenter = self.tileToWorld(x: tx, y: ty)
                if position.distance(to: tileCenter) <= visionRange {
                    if self.fogState[ty][tx] != .visible {
                        self.fogState[ty][tx] = .visible
                        self.dirtyTiles.insert(TileCoord(x: tx, y: ty))
                    }
                }
            }
        }
    }

    /// Apply visual updates to dirty tiles
    private func commitVisualUpdates() {
        for coord in self.dirtyTiles {
            self.updateTileVisual(x: coord.x, y: coord.y)
        }
        self.dirtyTiles.removeAll()
    }

    /// Update a single tile's visual appearance based on its fog state
    private func updateTileVisual(x: Int, y: Int) {
        guard self.isValidTile(x: x, y: y) else { return }

        let tile = self.fogTiles[y][x]
        let targetAlpha: CGFloat = switch self.fogState[y][x] {
        case .unexplored:
            self.unexploredAlpha
        case .explored:
            self.exploredAlpha
        case .visible:
            self.visibleAlpha
        }

        // Smooth transition with animation
        tile.removeAllActions()
        tile.run(SKAction.fadeAlpha(to: targetAlpha, duration: GameBalance.FogOfWar.fadeTransitionDuration))
    }

    // MARK: - Visibility Queries

    /// Check if a position is currently visible
    /// - Parameter position: World position to check
    /// - Returns: True if the tile at this position is visible
    func isVisible(at position: CGPoint) -> Bool {
        let tile = self.worldToTile(position)
        guard self.isValidTile(x: tile.x, y: tile.y) else { return false }
        return self.fogState[tile.y][tile.x] == .visible
    }

    /// Check if a position has been explored (seen at least once)
    /// - Parameter position: World position to check
    /// - Returns: True if the tile has been explored or is visible
    func isExplored(at position: CGPoint) -> Bool {
        let tile = self.worldToTile(position)
        guard self.isValidTile(x: tile.x, y: tile.y) else { return false }
        return self.fogState[tile.y][tile.x] != .unexplored
    }

    /// Get the fog state at a position
    /// - Parameter position: World position to check
    /// - Returns: The fog state of the tile
    func getFogState(at position: CGPoint) -> FogState {
        let tile = self.worldToTile(position)
        guard self.isValidTile(x: tile.x, y: tile.y) else { return .unexplored }
        return self.fogState[tile.y][tile.x]
    }

    // MARK: - Reset

    /// Reset all fog to unexplored state
    func reset() {
        for y in 0 ..< self.mapHeight {
            for x in 0 ..< self.mapWidth {
                self.fogState[y][x] = .unexplored
                self.fogTiles[y][x].alpha = self.unexploredAlpha
            }
        }
        self.dirtyTiles.removeAll()
    }

    /// Reveal the entire map (for debugging or end-game)
    func revealAll() {
        for y in 0 ..< self.mapHeight {
            for x in 0 ..< self.mapWidth {
                self.fogState[y][x] = .visible
                self.fogTiles[y][x].alpha = self.visibleAlpha
            }
        }
        self.dirtyTiles.removeAll()
    }
}
