//
//  TowerConfig.swift
//  Nathaniel Shared
//
//  Defines available tower types and their costs.
//

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
}

// MARK: - Tower Configuration

/// Central configuration for tower building system
/// Delegates to GameBalance.Towers for centralized game balance
enum TowerConfig {
    // MARK: - Tower Costs (in resources)

    /// Cost to build a Gun Tower
    static var gunTowerCost: Int {
        #if DEBUG
            return DevSettings.shared.towerCostGun
        #else
            return GameBalance.Towers.gunTowerCost
        #endif
    }

    /// Cost to build a Laser Tower
    static var laserTowerCost: Int {
        #if DEBUG
            return DevSettings.shared.towerCostLaser
        #else
            return GameBalance.Towers.laserTowerCost
        #endif
    }

    /// Cost to build a Heal Tower
    static var healTowerCost: Int {
        #if DEBUG
            return DevSettings.shared.towerCostHeal
        #else
            return GameBalance.Towers.healTowerCost
        #endif
    }

    // MARK: - Helper Methods

    /// Check if the player can afford a tower type
    static func canAfford(_ type: TowerType, currentResources: Int) -> Bool {
        currentResources >= type.cost
    }
}
