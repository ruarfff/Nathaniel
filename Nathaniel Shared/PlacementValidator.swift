import SpriteKit

// MARK: - Placement Validation

/// Result of placement validation with reason for failure
enum PlacementResult {
    case valid
    case outOfBuildRadius
    case blockedByTerrain
    case overlapsStructure
    case overlapsCharacter
    case overlapsEnemy
}

/// Validates tower placement positions
class PlacementValidator {
    // MARK: - Properties

    /// Reference to Hermes for build radius check
    weak var hermes: Character?

    /// Reference to TMX renderer for terrain collision check
    weak var tmxRenderer: TMXRenderer?

    /// Reference to structure manager for tower overlap check
    weak var structureManager: StructureManager?

    /// Reference to enemy manager for enemy overlap check
    weak var enemyManager: EnemyManager?

    /// Player characters to check for overlap
    var playerCharacters: [Character] = []

    // MARK: - Validation

    /// Validate if a position is valid for tower placement
    /// - Parameter position: The world position to check
    /// - Returns: PlacementResult indicating if valid or why invalid
    func validate(position: CGPoint) -> PlacementResult {
        // Check 1: Within build radius of Hermes
        if !self.isWithinBuildRadius(position) {
            return .outOfBuildRadius
        }

        // Check 2: Not on collision tiles
        if !self.isTerrainClear(position) {
            return .blockedByTerrain
        }

        // Check 3: Not overlapping existing structures
        if self.overlapsStructure(position) {
            return .overlapsStructure
        }

        // Check 4: Not overlapping player characters
        if self.overlapsPlayerCharacter(position) {
            return .overlapsCharacter
        }

        // Check 5: Not overlapping enemies
        if self.overlapsEnemy(position) {
            return .overlapsEnemy
        }

        return .valid
    }

    /// Convenience method for boolean check
    func isValidPlacement(at position: CGPoint) -> Bool {
        self.validate(position: position) == .valid
    }

    // MARK: - Individual Checks

    /// Check if position is within build radius of Hermes
    private func isWithinBuildRadius(_ position: CGPoint) -> Bool {
        guard let hermes else { return false }
        return position.distance(to: hermes.position) <= BuildConfig.buildRadius
    }

    /// Check if terrain at position is walkable (no collision)
    private func isTerrainClear(_ position: CGPoint) -> Bool {
        guard let renderer = tmxRenderer else { return true }
        return renderer.isWalkable(at: position)
    }

    /// Check if position overlaps any existing structure
    private func overlapsStructure(_ position: CGPoint) -> Bool {
        guard let manager = structureManager else { return false }

        for structure in manager.activeStructures {
            // Use tower collision radius for overlap check
            if position.distance(to: structure.position) < BuildConfig.towerCollisionRadius * 2 {
                return true
            }
        }
        return false
    }

    /// Check if position overlaps any player character
    private func overlapsPlayerCharacter(_ position: CGPoint) -> Bool {
        for character in self.playerCharacters where character.isAlive {
            // Use character's collision radius plus tower radius
            if position.distance(to: character.position) < character.collisionRadius + BuildConfig
                .towerCollisionRadius
            {
                return true
            }
        }
        return false
    }

    /// Check if position overlaps any enemy
    private func overlapsEnemy(_ position: CGPoint) -> Bool {
        guard let manager = enemyManager else { return false }

        for enemy in manager.aliveEnemies {
            // Use enemy's collision radius plus tower radius
            if position.distance(to: enemy.position) < enemy.collisionRadius + BuildConfig.towerCollisionRadius {
                return true
            }
        }
        return false
    }
}
