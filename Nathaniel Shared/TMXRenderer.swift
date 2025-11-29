import SpriteKit

/// Renders a TMXMap to SpriteKit nodes
class TMXRenderer {
    let map: TMXMap
    private var tilesetTextures: [String: SKTexture] = [:]

    init(map: TMXMap) {
        self.map = map
    }

    /// Load tileset textures from the bundle
    func loadTilesets(from directory: String = "Assets/Maps") {
        for tileset in map.tilesets {
            // Remove .png extension if present for texture loading
            var textureName = tileset.imageSource
            if textureName.hasSuffix(".png") {
                textureName = String(textureName.dropLast(4))
            }

            // Try loading from the specified directory
            let fullPath = "\(directory)/\(textureName)"
            let texture = SKTexture(imageNamed: fullPath)

            // Disable texture filtering for pixel-perfect rendering
            texture.filteringMode = .nearest

            tileset.texture = texture
            tilesetTextures[tileset.imageSource] = texture
            print("TMXRenderer: Loaded tileset \(tileset.name) from \(fullPath)")
        }
    }

    /// Create a node containing all visible map layers
    func createMapNode() -> SKNode {
        let mapNode = SKNode()
        mapNode.name = "map"

        // Render each tile layer
        for layer in map.layers {
            let layerNode = createLayerNode(layer: layer)
            layerNode.name = layer.name
            mapNode.addChild(layerNode)
        }

        return mapNode
    }

    /// Create a node for a single tile layer
    private func createLayerNode(layer: TMXLayer) -> SKNode {
        let layerNode = SKNode()

        for y in 0..<layer.height {
            for x in 0..<layer.width {
                let gid = layer.tile(at: x, y: y)
                guard gid > 0 else { continue } // Skip empty tiles

                if let tileNode = createTileNode(gid: gid, x: x, y: y) {
                    layerNode.addChild(tileNode)
                }
            }
        }

        return layerNode
    }

    /// Create a sprite node for a single tile
    private func createTileNode(gid: Int, x: Int, y: Int) -> SKSpriteNode? {
        // Find the tileset containing this GID
        guard let tileset = findTileset(for: gid),
              let texture = tileset.texture,
              let rect = tileset.textureRect(for: gid) else {
            return nil
        }

        // Create texture from tileset atlas
        let tileTexture = SKTexture(rect: rect, in: texture)
        tileTexture.filteringMode = .nearest

        let node = SKSpriteNode(texture: tileTexture)
        node.anchorPoint = CGPoint(x: 0, y: 1) // Top-left anchor for Tiled compatibility

        // Position in SpriteKit coordinates (y inverted from Tiled)
        // Tiled: origin at top-left, y increases downward
        // SpriteKit: origin at bottom-left, y increases upward
        let posX = CGFloat(x * map.tileWidth)
        let posY = CGFloat(map.pixelHeight - y * map.tileHeight)
        node.position = CGPoint(x: posX, y: posY)

        return node
    }

    /// Find the tileset that contains a given global tile ID
    private func findTileset(for gid: Int) -> TMXTileset? {
        // Tilesets are ordered by firstGid, find the one with the highest firstGid <= gid
        var result: TMXTileset?
        for tileset in map.tilesets {
            if tileset.firstGid <= gid {
                result = tileset
            } else {
                break
            }
        }
        return result
    }

    /// Get the collision layer for pathfinding
    func getCollisionLayer() -> TMXLayer? {
        return map.layers.first { $0.name == "Collision" }
    }

    /// Get spawn objects from the Objects layer
    func getSpawnObjects() -> [TMXObject] {
        guard let objectGroup = map.objectGroups.first(where: { $0.name == "Objects" }) else {
            return []
        }
        return objectGroup.objects
    }

    /// Convert Tiled coordinates to SpriteKit coordinates
    func convertToSpriteKit(point: CGPoint) -> CGPoint {
        return CGPoint(x: point.x, y: CGFloat(map.pixelHeight) - point.y)
    }

    /// Convert SpriteKit coordinates to Tiled coordinates
    func convertToTiled(point: CGPoint) -> CGPoint {
        return CGPoint(x: point.x, y: CGFloat(map.pixelHeight) - point.y)
    }

    /// Convert world position to tile grid coordinates
    func worldToTile(point: CGPoint) -> (x: Int, y: Int) {
        let tiledPoint = convertToTiled(point: point)
        let tileX = Int(tiledPoint.x) / map.tileWidth
        let tileY = Int(tiledPoint.y) / map.tileHeight
        return (tileX, tileY)
    }

    /// Convert tile grid coordinates to world position (center of tile)
    func tileToWorld(x: Int, y: Int) -> CGPoint {
        let tiledX = CGFloat(x * map.tileWidth + map.tileWidth / 2)
        let tiledY = CGFloat(y * map.tileHeight + map.tileHeight / 2)
        return convertToSpriteKit(point: CGPoint(x: tiledX, y: tiledY))
    }

    /// Check if a tile position is walkable (not blocked by collision layer)
    func isWalkable(tileX: Int, tileY: Int) -> Bool {
        guard let collisionLayer = getCollisionLayer() else {
            return true // No collision layer = everything walkable
        }
        return !collisionLayer.isSolid(at: tileX, y: tileY)
    }

    /// Check if a world position is walkable
    func isWalkable(at point: CGPoint) -> Bool {
        let tile = worldToTile(point: point)
        return isWalkable(tileX: tile.x, tileY: tile.y)
    }
}
