//
//  PlacementValidator.swift
//  Nathaniel Shared
//
//  Checks the original tower footprint against terrain and battlefield objects.
//

import SpriteKit

// MARK: - Placement Validation

enum PlacementResult {
    case valid
    case blockedByTerrain
    case overlapsStructure
    case overlapsCharacter
    case overlapsEnemy
    case overlapsResource
}

class PlacementValidator {
    // MARK: - Properties

    weak var tmxRenderer: TMXRenderer?
    weak var structureManager: StructureManager?
    weak var enemyManager: EnemyManager?
    weak var resourceManager: ResourceManager?
    var playerCharacters: [Character] = []

    // MARK: - Public Methods

    func validate(position: CGPoint) -> PlacementResult {
        let frame = self.towerFrame(at: position)
        if !self.isTerrainClear(frame) {
            return .blockedByTerrain
        }
        if self.structureManager?.activeStructures.contains(where: {
            frame.intersects(self.towerFrame(at: $0.position))
        }) == true {
            return .overlapsStructure
        }
        if self.playerCharacters.contains(where: { $0.isAlive && frame.intersects($0.sprite.frame) }) {
            return .overlapsCharacter
        }
        if self.enemyManager?.aliveEnemies.contains(where: { frame.intersects($0.sprite.frame) }) == true {
            return .overlapsEnemy
        }
        if self.resourceManager?.resources
            .contains(where: { $0.isActive && frame.intersects($0.sprite.frame) }) == true
        {
            return .overlapsResource
        }
        return .valid
    }

    func isValidPlacement(at position: CGPoint) -> Bool {
        self.validate(position: position) == .valid
    }

    // MARK: - Private Methods

    private func towerFrame(at position: CGPoint) -> CGRect {
        let size = GameBalance.Towers.Visual.textureSize
        return CGRect(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func isTerrainClear(_ frame: CGRect) -> Bool {
        guard let renderer = tmxRenderer else { return true }
        let map = renderer.map
        guard frame.minX >= 0, frame.minY >= 0,
              frame.maxX <= CGFloat(map.pixelWidth), frame.maxY <= CGFloat(map.pixelHeight)
        else { return false }

        let first = renderer.convertToTiled(point: CGPoint(x: frame.minX, y: frame.maxY))
        let last = renderer.convertToTiled(point: CGPoint(x: frame.maxX, y: frame.minY))
        let firstX = Int(floor(first.x / CGFloat(map.tileWidth)))
        let firstY = Int(floor(first.y / CGFloat(map.tileHeight)))
        // The far edges are exclusive, so touching a solid tile does not overlap it.
        let lastX = Int(ceil(last.x / CGFloat(map.tileWidth))) - 1
        let lastY = Int(ceil(last.y / CGFloat(map.tileHeight))) - 1
        for x in firstX ... lastX {
            for y in firstY ... lastY where !renderer.isWalkable(tileX: x, tileY: y) {
                return false
            }
        }
        return true
    }
}
