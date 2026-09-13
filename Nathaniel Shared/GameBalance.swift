//
//  GameBalance.swift
//  Nathaniel Shared
//
//  Defines the original game balance values.
//

import SpriteKit

// MARK: - GameBalance

/// Central location for game balance constants.
/// Adjust values here to tune gameplay without hunting through multiple files.
enum GameBalance {
    // MARK: - Player Characters

    /// Nathaniel's stats (main player character)
    enum Nathaniel {
        static let maxHP = 8_000
        static let speed: CGFloat = 70
        static let weaponRange: CGFloat = 450
        static let visionRange: CGFloat = 500

        // Weapon stats
        static let gunCooldown: TimeInterval = 0.8
        static let gunDamage = 25
        static let bulletSpeed: CGFloat = 450
    }

    /// Hermes's stats (robot companion)
    enum Hermes {
        static let maxHP = 2_000
        static let speed: CGFloat = 40
        static let weaponRange: CGFloat = 450
        static let visionRange: CGFloat = 500
        static let laserDPS = 25
        static let laserBurstDuration: TimeInterval = 1.5
        static let laserCooldown: TimeInterval = 3.5
        static let followStopDistance: CGFloat = 100
    }

    // MARK: - Enemies

    /// Grunt enemy stats (ranged blaster enemy)
    enum Grunt {
        static let maxHP = 150
        static let speed: CGFloat = 70
        static let killScore = 20
        static let visionRange: CGFloat = 800
        static let attackRange: CGFloat = 250
        static let blasterDamage = 25
        static let blasterCooldown: TimeInterval = 0.8
    }

    /// Soldier enemy stats (ranged enemy)
    enum Soldier {
        static let maxHP = 200
        static let speed: CGFloat = 40
        static let killScore = 30
        static let range: CGFloat = 300

        // Gun weapon
        static let gunCooldown: TimeInterval = 0.8
        static let gunDamage = 25
    }

    /// Boss enemy stats
    enum Boss {
        static let maxHP = 800
        static let speed: CGFloat = 60
        static let killScore = 100
        static let visionRange: CGFloat = 600
        static let attackRange: CGFloat = 500
        static let stopDistanceRatio: CGFloat = 0.3

        // Bow weapon
        static let bowCooldown: TimeInterval = 1.5
        static let bowDamage = 25
        static let arrowSpeed: CGFloat = 240
    }

    /// Stationary enemy that fires a laser and produces Grunts.
    enum Spawner {
        static let maxHP = 1_500
        static let killScore = 100
        static let visionRange: CGFloat = 400
        static let attackRange: CGFloat = 350
        static let laserDPS = 30
        static let laserCooldown: TimeInterval = 3.5
        static let laserBurstDuration: TimeInterval = 1.5
    }

    // MARK: - Towers

    /// Tower stats (defensive structures)
    enum Towers {
        /// Build system
        static let collisionRadius: CGFloat = 24

        // Costs
        static let gunTowerCost = 5
        static let laserTowerCost = 10
        static let healTowerCost = 15

        /// Gun Tower
        enum GunTower {
            static let maxHP = 600
            static let attackRange: CGFloat = 500
            static let gunCooldown: TimeInterval = 0.8
            static let gunDamage = 25
            static let bulletSpeed: CGFloat = 450
        }

        /// Laser Tower
        enum LaserTower {
            static let maxHP = 600
            static let attackRange: CGFloat = 350
            static let damagePerSecond = 20
            static let cooldown: TimeInterval = 3.5
            static let burstDuration: TimeInterval = 1.5
        }

        /// Heal Tower
        enum HealTower {
            static let maxHP = 600
            static let attackRange: CGFloat = 400
            static let healAmount = 5
            static let healDelay: TimeInterval = 1.0
        }

        /// Shared tower visual constants
        enum Visual {
            static let textureSize = CGSize(width: 48, height: 48)
            static let laserBeamThickness: CGFloat = 3
            static let healEffectStrokeColor = SKColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 0.3)
            static let healEffectFillColor = SKColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 0.1)
        }
    }

    // MARK: - UI

    /// UI layout and sizing constants
    enum UI {
        /// Health bars
        enum HealthBar {
            static let standardHeight: CGFloat = 6
            static let compactHeight: CGFloat = 4
            static let standardCornerRadius: CGFloat = 0
            static let compactCornerRadius: CGFloat = 2
        }

        /// HUD
        enum HUD {
            static let padding: CGFloat = 16
            static let spacing: CGFloat = 8
            static let playerHealthBarWidth: CGFloat = 90
            static let playerHealthBarHeight: CGFloat = 8
        }

        /// Build menu
        enum BuildMenu {
            static let itemWidth: CGFloat = 100
            static let itemHeight: CGFloat = 90
            static let menuHeightRatio: CGFloat = 0.25
            static let menuWidthRatio: CGFloat = 0.8
            static let itemSpacing: CGFloat = 20
            static let bottomOffset: CGFloat = 60
        }
    }

    // MARK: - Combat

    /// General combat constants
    enum Combat {
        /// Default melee attack cooldown for enemies
        static let defaultMeleeAttackCooldown: TimeInterval = 1.0

        /// Stuck detection frame threshold for pathfinding
        static let stuckDetectionFrames = 30

        /// Minimum distance to consider "arrived" at destination
        static let arrivalThreshold: CGFloat = 5.0
    }

    // MARK: - Fog of War

    /// Fog of war visibility constants
    enum FogOfWar {
        /// Alpha value for unexplored (never seen) tiles
        static let unexploredAlpha: CGFloat = 0.95

        /// Alpha value for explored (previously seen) tiles
        static let exploredAlpha: CGFloat = 0.6

        /// Alpha value for visible (currently seen) tiles
        static let visibleAlpha: CGFloat = 0.0

        /// Update interval for fog calculations (seconds)
        static let updateInterval: TimeInterval = 0.1

        /// Duration for fog fade transitions
        static let fadeTransitionDuration: TimeInterval = 0.15
    }
}
