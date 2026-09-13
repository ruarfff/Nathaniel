#if DEBUG

    import CoreGraphics
    import Foundation

    /// Singleton class providing development settings that can be modified at runtime.
    /// All settings have defaults matching the production values.
    /// Use the GameCommandServer /settings endpoint to modify these values.
    public class DevSettings: Codable {
        // MARK: - Singleton

        public static let shared = DevSettings()

        // MARK: - Player Settings

        /// Nathaniel movement speed (pts/sec)
        public var nathanielSpeed: CGFloat = 70

        /// Hermes movement speed (pts/sec)
        public var hermesSpeed: CGFloat = 40

        /// Nathaniel maximum health
        public var nathanielMaxHealth: Int = 8_000

        /// Hermes maximum health
        public var hermesMaxHealth: Int = 2_000

        /// Players take no damage when true
        public var playerInvincible: Bool = false

        /// Seconds before player respawns after death
        public var respawnDelay: TimeInterval = 2.0

        // MARK: - Enemy Settings

        /// Grunt movement speed (pts/sec)
        public var gruntSpeed: CGFloat = 70

        /// Soldier movement speed (pts/sec)
        public var soldierSpeed: CGFloat = 40

        /// Boss movement speed (pts/sec)
        public var bossSpeed: CGFloat = 60

        /// Enemy visible range (detection distance)
        public var enemyVisibleRange: CGFloat = 500

        /// Enemy attack range
        public var enemyAttackRange: CGFloat = 300

        /// Base enemy damage
        public var enemyDamage: Int = 25

        // MARK: - Projectile Settings

        /// Player/Gun tower bullet speed (pts/sec)
        public var bulletSpeed: CGFloat = 450

        /// Boss arrow speed (pts/sec)
        public var arrowSpeed: CGFloat = 240

        /// Base projectile damage
        public var projectileDamage: Int = 25

        // MARK: - Spawn/Wave Settings

        /// Seconds between enemy spawns (wave-based levels)
        public var spawnInterval: TimeInterval = 5.0

        // MARK: - Camera Settings

        /// Current camera zoom level
        public var cameraZoom: CGFloat = 1.0

        /// Minimum zoom (zoomed out)
        public var cameraMinZoom: CGFloat = 0.5

        /// Maximum zoom (zoomed in)
        public var cameraMaxZoom: CGFloat = 2.0

        /// Camera follow smoothing factor (0-1)
        public var cameraFollowSmoothing: CGFloat = 0.1

        /// Disable auto-follow when true
        public var cameraFreeMode: Bool = false

        // MARK: - Tower Settings

        /// Gun tower damage per shot
        public var towerDamage: Int = 25

        /// Tower attack range
        public var towerRange: CGFloat = 350

        /// Gun tower resource cost
        public var towerCostGun: Int = 5

        /// Laser tower resource cost
        public var towerCostLaser: Int = 10

        /// Heal tower resource cost
        public var towerCostHeal: Int = 15

        /// Towers build instantly when true
        public var instantBuild: Bool = false

        // MARK: - Debug Toggles

        /// Resources never decrease when true
        public var infiniteResources: Bool = false

        /// Show debug overlay when true
        public var showDebugInfo: Bool = false

        /// Visualize collision bounds when true
        public var showCollisionBounds: Bool = false

        /// Visualize pathfinding (paths, waypoints) when true
        public var showPathfindingDebug: Bool = false

        // MARK: - Initialization

        private init() {
            // Private init ensures singleton usage
        }

        // MARK: - Reset

        /// Reset all settings to their default values
        public func reset() {
            // Player settings
            self.nathanielSpeed = 70
            self.hermesSpeed = 40
            self.nathanielMaxHealth = 8_000
            self.hermesMaxHealth = 2_000
            self.playerInvincible = false
            self.respawnDelay = 2.0

            // Enemy settings
            self.gruntSpeed = 70
            self.soldierSpeed = 40
            self.bossSpeed = 60
            self.enemyVisibleRange = 500
            self.enemyAttackRange = 300
            self.enemyDamage = 25

            // Projectile settings
            self.bulletSpeed = 450
            self.arrowSpeed = 240
            self.projectileDamage = 25

            // Spawn settings
            self.spawnInterval = 5.0

            // Camera settings
            self.cameraZoom = 1.0
            self.cameraMinZoom = 0.5
            self.cameraMaxZoom = 2.0
            self.cameraFollowSmoothing = 0.1
            self.cameraFreeMode = false

            // Tower settings
            self.towerDamage = 25
            self.towerRange = 350
            self.towerCostGun = 5
            self.towerCostLaser = 10
            self.towerCostHeal = 15
            self.instantBuild = false

            // Debug toggles
            self.infiniteResources = false
            self.showDebugInfo = false
            self.showCollisionBounds = false
            self.showPathfindingDebug = false
        }

        // MARK: - Codable

        enum CodingKeys: String, CodingKey {
            // Player
            case nathanielSpeed, hermesSpeed
            case nathanielMaxHealth, hermesMaxHealth
            case playerInvincible, respawnDelay
            // Enemy
            case gruntSpeed, soldierSpeed, bossSpeed
            case enemyVisibleRange, enemyAttackRange, enemyDamage
            // Projectile
            case bulletSpeed, arrowSpeed, projectileDamage
            // Spawn
            case spawnInterval
            // Camera
            case cameraZoom, cameraMinZoom, cameraMaxZoom
            case cameraFollowSmoothing, cameraFreeMode
            // Tower
            case towerDamage, towerRange
            case towerCostGun, towerCostLaser, towerCostHeal
            case instantBuild
            // Debug
            case infiniteResources, showDebugInfo, showCollisionBounds, showPathfindingDebug
        }

        public required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            // Player settings (with defaults)
            self.nathanielSpeed = try container.decodeIfPresent(CGFloat.self, forKey: .nathanielSpeed) ?? 70
            self.hermesSpeed = try container.decodeIfPresent(CGFloat.self, forKey: .hermesSpeed) ?? 40
            self.nathanielMaxHealth = try container.decodeIfPresent(Int.self, forKey: .nathanielMaxHealth) ?? 8_000
            self.hermesMaxHealth = try container.decodeIfPresent(Int.self, forKey: .hermesMaxHealth) ?? 2_000
            self.playerInvincible = try container.decodeIfPresent(Bool.self, forKey: .playerInvincible) ?? false
            self.respawnDelay = try container.decodeIfPresent(TimeInterval.self, forKey: .respawnDelay) ?? 2.0

            // Enemy settings
            self.gruntSpeed = try container.decodeIfPresent(CGFloat.self, forKey: .gruntSpeed) ?? 70
            self.soldierSpeed = try container.decodeIfPresent(CGFloat.self, forKey: .soldierSpeed) ?? 40
            self.bossSpeed = try container.decodeIfPresent(CGFloat.self, forKey: .bossSpeed) ?? 60
            self.enemyVisibleRange = try container.decodeIfPresent(CGFloat.self, forKey: .enemyVisibleRange) ?? 500
            self.enemyAttackRange = try container.decodeIfPresent(CGFloat.self, forKey: .enemyAttackRange) ?? 300
            self.enemyDamage = try container.decodeIfPresent(Int.self, forKey: .enemyDamage) ?? 25

            // Projectile settings
            self.bulletSpeed = try container.decodeIfPresent(CGFloat.self, forKey: .bulletSpeed) ?? 450
            self.arrowSpeed = try container.decodeIfPresent(CGFloat.self, forKey: .arrowSpeed) ?? 240
            self.projectileDamage = try container.decodeIfPresent(Int.self, forKey: .projectileDamage) ?? 25

            // Spawn settings
            self.spawnInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .spawnInterval) ?? 5.0

            // Camera settings
            self.cameraZoom = try container.decodeIfPresent(CGFloat.self, forKey: .cameraZoom) ?? 1.0
            self.cameraMinZoom = try container.decodeIfPresent(CGFloat.self, forKey: .cameraMinZoom) ?? 0.5
            self.cameraMaxZoom = try container.decodeIfPresent(CGFloat.self, forKey: .cameraMaxZoom) ?? 2.0
            self.cameraFollowSmoothing = try container
                .decodeIfPresent(CGFloat.self, forKey: .cameraFollowSmoothing) ?? 0.1
            self.cameraFreeMode = try container.decodeIfPresent(Bool.self, forKey: .cameraFreeMode) ?? false

            // Tower settings
            self.towerDamage = try container.decodeIfPresent(Int.self, forKey: .towerDamage) ?? 25
            self.towerRange = try container.decodeIfPresent(CGFloat.self, forKey: .towerRange) ?? 350
            self.towerCostGun = try container.decodeIfPresent(Int.self, forKey: .towerCostGun) ?? 5
            self.towerCostLaser = try container.decodeIfPresent(Int.self, forKey: .towerCostLaser) ?? 10
            self.towerCostHeal = try container.decodeIfPresent(Int.self, forKey: .towerCostHeal) ?? 15
            self.instantBuild = try container.decodeIfPresent(Bool.self, forKey: .instantBuild) ?? false

            // Debug toggles
            self.infiniteResources = try container.decodeIfPresent(Bool.self, forKey: .infiniteResources) ?? false
            self.showDebugInfo = try container.decodeIfPresent(Bool.self, forKey: .showDebugInfo) ?? false
            self.showCollisionBounds = try container.decodeIfPresent(Bool.self, forKey: .showCollisionBounds) ?? false
            self.showPathfindingDebug = try container.decodeIfPresent(Bool.self, forKey: .showPathfindingDebug) ?? false
        }
    }

#endif
