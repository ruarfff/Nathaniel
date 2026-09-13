//
//  BuildConfig.swift
//  Nathaniel Shared
//
//  Defines tower costs and collision dimensions.
//

import SpriteKit

// MARK: - Build Configuration

/// Configuration for Hermes's build system (delegates to GameBalance.Towers)
enum BuildConfig {
    /// Tower costs (in resources)
    enum TowerCosts {
        static var gunTower: Int {
            GameBalance.Towers.gunTowerCost
        }

        static var laserTower: Int {
            GameBalance.Towers.laserTowerCost
        }

        static var healTower: Int {
            GameBalance.Towers.healTowerCost
        }
    }

    /// Tower placement collision radius (for overlap checks)
    static var towerCollisionRadius: CGFloat {
        GameBalance.Towers.collisionRadius
    }
}
