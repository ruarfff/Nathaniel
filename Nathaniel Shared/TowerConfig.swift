import Foundation
import SpriteKit

// MARK: - Tower Type

/// Represents the types of towers Hermes can build
enum TowerType: String, CaseIterable {
    case gunTower
    case laserTower
    case healTower

    /// Display name for the tower type
    var displayName: String {
        switch self {
        case .gunTower: "Gun Tower"
        case .laserTower: "Laser Tower"
        case .healTower: "Heal Tower"
        }
    }

    /// Resource cost to build this tower type
    var cost: Int {
        switch self {
        case .gunTower: TowerConfig.gunTowerCost
        case .laserTower: TowerConfig.laserTowerCost
        case .healTower: TowerConfig.healTowerCost
        }
    }

    /// Texture name for the tower icon in build menu
    var iconTextureName: String {
        switch self {
        case .gunTower: "guntower"
        case .laserTower: "lasertower"
        case .healTower: "healtower"
        }
    }

    /// Factory method to create a tower of this type
    func createTower() -> DefensiveStructure {
        switch self {
        case .gunTower:
            GunTower()
        case .laserTower:
            LaserTower()
        case .healTower:
            HealTower()
        }
    }
}

// MARK: - Tower Configuration

/// Central configuration for tower building system
/// Adjust these values for game balance
enum TowerConfig {
    // MARK: - Tower Costs (in resources)

    /// Cost to build a Gun Tower
    static var gunTowerCost: Int {
        #if DEBUG
            return DevSettings.shared.towerCostGun
        #else
            return 5
        #endif
    }

    /// Cost to build a Laser Tower
    static var laserTowerCost: Int {
        #if DEBUG
            return DevSettings.shared.towerCostLaser
        #else
            return 10
        #endif
    }

    /// Cost to build a Heal Tower
    static var healTowerCost: Int {
        #if DEBUG
            return DevSettings.shared.towerCostHeal
        #else
            return 15
        #endif
    }

    // MARK: - Build Radius

    /// Maximum distance from Hermes where towers can be placed
    static let buildRadius: CGFloat = 250

    /// Minimum distance from Hermes where towers can be placed (to avoid overlap)
    static let minBuildDistance: CGFloat = 50

    // MARK: - Validation

    /// Minimum distance between towers to prevent overlap
    static let towerSpacing: CGFloat = 60

    // MARK: - Recoup System

    /// Percentage of tower cost returned when Hermes releases towers (0.0 to 1.0)
    /// Only towers still standing are eligible - towers destroyed by enemies give nothing
    static let recoupPercentage: Double = 0.20

    // MARK: - Helper Methods

    /// Check if the player can afford a tower type
    static func canAfford(_ type: TowerType, currentResources: Int) -> Bool {
        currentResources >= type.cost
    }

    /// Check if a position is within valid build range of Hermes
    static func isWithinBuildRange(towerPosition: CGPoint, hermesPosition: CGPoint) -> Bool {
        let dx = towerPosition.x - hermesPosition.x
        let dy = towerPosition.y - hermesPosition.y
        let distance = sqrt(dx * dx + dy * dy)

        return distance >= minBuildDistance && distance <= buildRadius
    }

    /// Calculate recoup amount for a tower cost
    /// - Parameter cost: Original build cost of the tower
    /// - Returns: Amount of resources to return (rounded down)
    static func calculateRecoup(for cost: Int) -> Int {
        Int(Double(cost) * recoupPercentage)
    }
}
