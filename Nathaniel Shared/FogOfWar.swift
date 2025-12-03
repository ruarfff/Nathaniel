//
//  FogOfWar.swift
//  Nathaniel Shared
//
//  Manages fog of war visibility system for the game map.
//

import SpriteKit

/// Represents the visibility state of a tile
enum FogState: Int {
    case unexplored = 0  // Never seen - fully obscured
    case explored = 1    // Previously seen - dimmed
    case visible = 2     // Currently visible - clear
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
    private let unexploredAlpha: CGFloat = 0.95

    /// Alpha value for explored (previously seen) tiles
    private let exploredAlpha: CGFloat = 0.6

    /// Alpha value for visible tiles (fully transparent)
    private let visibleAlpha: CGFloat = 0.0

    /// Dirty tiles that need visual update
    private var dirtyTiles: Set<TileCoord> = []

    /// Simple struct for tile coordinates (Hashable)
    private struct TileCoord: Hashable {
        let x: Int
        let y: Int
    }

    /// Throttle fog updates for performance
    private var lastUpdateTime: TimeInterval = 0
    private let updateInterval: TimeInterval = 0.1  // 10 FPS for fog updates

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
        createFogTiles()
    }

    /// Create fog tile sprites covering the entire map
    private func createFogTiles() {
        for y in 0..<mapHeight {
            var rowTiles: [SKSpriteNode] = []
            for x in 0..<mapWidth {
                let tile = SKSpriteNode(color: .black, size: CGSize(width: tileSize, height: tileSize))
                // Position tile center (SpriteKit origin is bottom-left)
                tile.position = CGPoint(
                    x: CGFloat(x) * tileSize + tileSize / 2,
                    y: CGFloat(y) * tileSize + tileSize / 2
                )
                tile.alpha = unexploredAlpha
                tile.zPosition = 50  // Above map tiles, below characters
                fogNode.addChild(tile)
                rowTiles.append(tile)
            }
            fogTiles.append(rowTiles)
        }
    }

    // MARK: - Coordinate Conversion

    /// Convert world position to tile coordinates
    private func worldToTile(_ position: CGPoint) -> (x: Int, y: Int) {
        let x = Int(position.x / tileSize)
        let y = Int(position.y / tileSize)
        return (x: max(0, min(mapWidth - 1, x)), y: max(0, min(mapHeight - 1, y)))
    }

    /// Convert tile coordinates to world position (center of tile)
    private func tileToWorld(x: Int, y: Int) -> CGPoint {
        return CGPoint(
            x: CGFloat(x) * tileSize + tileSize / 2,
            y: CGFloat(y) * tileSize + tileSize / 2
        )
    }

    /// Check if tile coordinates are valid
    private func isValidTile(x: Int, y: Int) -> Bool {
        return x >= 0 && x < mapWidth && y >= 0 && y < mapHeight
    }

    // MARK: - Visibility Update

    /// Update fog of war based on character positions and vision ranges
    /// - Parameter positions: Array of (position, visionRange) tuples for each character
    func update(visibleFrom positions: [(CGPoint, CGFloat)]) {
        // Reset all currently visible tiles to explored
        for y in 0..<mapHeight {
            for x in 0..<mapWidth {
                if fogState[y][x] == .visible {
                    fogState[y][x] = .explored
                    dirtyTiles.insert(TileCoord(x: x, y: y))
                }
            }
        }

        // Mark tiles in vision range as visible
        for (position, visionRange) in positions {
            updateVisibilityFrom(position: position, visionRange: visionRange)
        }

        // Commit visual updates
        commitVisualUpdates()
    }

    /// Update fog of war with throttling (for use in game loop)
    /// - Parameters:
    ///   - positions: Array of (position, visionRange) tuples
    ///   - currentTime: Current game time
    /// - Returns: Whether an update was performed
    @discardableResult
    func updateThrottled(visibleFrom positions: [(CGPoint, CGFloat)], currentTime: TimeInterval) -> Bool {
        guard currentTime - lastUpdateTime >= updateInterval else {
            return false
        }
        lastUpdateTime = currentTime
        update(visibleFrom: positions)
        return true
    }

    /// Calculate and update visibility from a single position
    private func updateVisibilityFrom(position: CGPoint, visionRange: CGFloat) {
        let centerTile = worldToTile(position)
        let tileRange = Int(ceil(visionRange / tileSize)) + 1

        // Check tiles within the vision range bounding box
        for dy in -tileRange...tileRange {
            for dx in -tileRange...tileRange {
                let tx = centerTile.x + dx
                let ty = centerTile.y + dy

                guard isValidTile(x: tx, y: ty) else { continue }

                // Calculate distance from position to tile center
                let tileCenter = tileToWorld(x: tx, y: ty)
                let distance = hypot(tileCenter.x - position.x, tileCenter.y - position.y)

                if distance <= visionRange {
                    if fogState[ty][tx] != .visible {
                        fogState[ty][tx] = .visible
                        dirtyTiles.insert(TileCoord(x: tx, y: ty))
                    }
                }
            }
        }
    }

    /// Apply visual updates to dirty tiles
    private func commitVisualUpdates() {
        for coord in dirtyTiles {
            updateTileVisual(x: coord.x, y: coord.y)
        }
        dirtyTiles.removeAll()
    }

    /// Update a single tile's visual appearance based on its fog state
    private func updateTileVisual(x: Int, y: Int) {
        guard isValidTile(x: x, y: y) else { return }

        let tile = fogTiles[y][x]
        let targetAlpha: CGFloat

        switch fogState[y][x] {
        case .unexplored:
            targetAlpha = unexploredAlpha
        case .explored:
            targetAlpha = exploredAlpha
        case .visible:
            targetAlpha = visibleAlpha
        }

        // Smooth transition with animation
        tile.removeAllActions()
        tile.run(SKAction.fadeAlpha(to: targetAlpha, duration: 0.15))
    }

    // MARK: - Visibility Queries

    /// Check if a position is currently visible
    /// - Parameter position: World position to check
    /// - Returns: True if the tile at this position is visible
    func isVisible(at position: CGPoint) -> Bool {
        let tile = worldToTile(position)
        guard isValidTile(x: tile.x, y: tile.y) else { return false }
        return fogState[tile.y][tile.x] == .visible
    }

    /// Check if a position has been explored (seen at least once)
    /// - Parameter position: World position to check
    /// - Returns: True if the tile has been explored or is visible
    func isExplored(at position: CGPoint) -> Bool {
        let tile = worldToTile(position)
        guard isValidTile(x: tile.x, y: tile.y) else { return false }
        return fogState[tile.y][tile.x] != .unexplored
    }

    /// Get the fog state at a position
    /// - Parameter position: World position to check
    /// - Returns: The fog state of the tile
    func getFogState(at position: CGPoint) -> FogState {
        let tile = worldToTile(position)
        guard isValidTile(x: tile.x, y: tile.y) else { return .unexplored }
        return fogState[tile.y][tile.x]
    }

    // MARK: - Reset

    /// Reset all fog to unexplored state
    func reset() {
        for y in 0..<mapHeight {
            for x in 0..<mapWidth {
                fogState[y][x] = .unexplored
                fogTiles[y][x].alpha = unexploredAlpha
            }
        }
        dirtyTiles.removeAll()
    }

    /// Reveal the entire map (for debugging or end-game)
    func revealAll() {
        for y in 0..<mapHeight {
            for x in 0..<mapWidth {
                fogState[y][x] = .visible
                fogTiles[y][x].alpha = visibleAlpha
            }
        }
        dirtyTiles.removeAll()
    }
}
