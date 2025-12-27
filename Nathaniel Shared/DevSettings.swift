//
//  DevSettings.swift
//  Nathaniel Shared
//
//  Development settings for testing and debugging.
//  Only compiled in DEBUG builds.
//

#if DEBUG

import Foundation
import CoreGraphics

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
    public var nathanielMaxHealth: Int = 8000

    /// Hermes maximum health
    public var hermesMaxHealth: Int = 2000

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
    public var arrowSpeed: CGFloat = 400

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

    // MARK: - Initialization

    private init() {
        // Private init ensures singleton usage
    }

    // MARK: - Reset

    /// Reset all settings to their default values
    public func reset() {
        // Player settings
        nathanielSpeed = 70
        hermesSpeed = 40
        nathanielMaxHealth = 8000
        hermesMaxHealth = 2000
        playerInvincible = false
        respawnDelay = 2.0

        // Enemy settings
        gruntSpeed = 70
        soldierSpeed = 40
        bossSpeed = 60
        enemyVisibleRange = 500
        enemyAttackRange = 300
        enemyDamage = 25

        // Projectile settings
        bulletSpeed = 450
        arrowSpeed = 400
        projectileDamage = 25

        // Spawn settings
        spawnInterval = 5.0

        // Camera settings
        cameraZoom = 1.0
        cameraMinZoom = 0.5
        cameraMaxZoom = 2.0
        cameraFollowSmoothing = 0.1
        cameraFreeMode = false

        // Tower settings
        towerDamage = 25
        towerRange = 350
        towerCostGun = 5
        towerCostLaser = 10
        towerCostHeal = 15
        instantBuild = false

        // Debug toggles
        infiniteResources = false
        showDebugInfo = false
        showCollisionBounds = false
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
        case infiniteResources, showDebugInfo, showCollisionBounds
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Player settings (with defaults)
        nathanielSpeed = try container.decodeIfPresent(CGFloat.self, forKey: .nathanielSpeed) ?? 70
        hermesSpeed = try container.decodeIfPresent(CGFloat.self, forKey: .hermesSpeed) ?? 40
        nathanielMaxHealth = try container.decodeIfPresent(Int.self, forKey: .nathanielMaxHealth) ?? 8000
        hermesMaxHealth = try container.decodeIfPresent(Int.self, forKey: .hermesMaxHealth) ?? 2000
        playerInvincible = try container.decodeIfPresent(Bool.self, forKey: .playerInvincible) ?? false
        respawnDelay = try container.decodeIfPresent(TimeInterval.self, forKey: .respawnDelay) ?? 2.0

        // Enemy settings
        gruntSpeed = try container.decodeIfPresent(CGFloat.self, forKey: .gruntSpeed) ?? 70
        soldierSpeed = try container.decodeIfPresent(CGFloat.self, forKey: .soldierSpeed) ?? 40
        bossSpeed = try container.decodeIfPresent(CGFloat.self, forKey: .bossSpeed) ?? 60
        enemyVisibleRange = try container.decodeIfPresent(CGFloat.self, forKey: .enemyVisibleRange) ?? 500
        enemyAttackRange = try container.decodeIfPresent(CGFloat.self, forKey: .enemyAttackRange) ?? 300
        enemyDamage = try container.decodeIfPresent(Int.self, forKey: .enemyDamage) ?? 25

        // Projectile settings
        bulletSpeed = try container.decodeIfPresent(CGFloat.self, forKey: .bulletSpeed) ?? 450
        arrowSpeed = try container.decodeIfPresent(CGFloat.self, forKey: .arrowSpeed) ?? 400
        projectileDamage = try container.decodeIfPresent(Int.self, forKey: .projectileDamage) ?? 25

        // Spawn settings
        spawnInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .spawnInterval) ?? 5.0

        // Camera settings
        cameraZoom = try container.decodeIfPresent(CGFloat.self, forKey: .cameraZoom) ?? 1.0
        cameraMinZoom = try container.decodeIfPresent(CGFloat.self, forKey: .cameraMinZoom) ?? 0.5
        cameraMaxZoom = try container.decodeIfPresent(CGFloat.self, forKey: .cameraMaxZoom) ?? 2.0
        cameraFollowSmoothing = try container.decodeIfPresent(CGFloat.self, forKey: .cameraFollowSmoothing) ?? 0.1
        cameraFreeMode = try container.decodeIfPresent(Bool.self, forKey: .cameraFreeMode) ?? false

        // Tower settings
        towerDamage = try container.decodeIfPresent(Int.self, forKey: .towerDamage) ?? 25
        towerRange = try container.decodeIfPresent(CGFloat.self, forKey: .towerRange) ?? 350
        towerCostGun = try container.decodeIfPresent(Int.self, forKey: .towerCostGun) ?? 5
        towerCostLaser = try container.decodeIfPresent(Int.self, forKey: .towerCostLaser) ?? 10
        towerCostHeal = try container.decodeIfPresent(Int.self, forKey: .towerCostHeal) ?? 15
        instantBuild = try container.decodeIfPresent(Bool.self, forKey: .instantBuild) ?? false

        // Debug toggles
        infiniteResources = try container.decodeIfPresent(Bool.self, forKey: .infiniteResources) ?? false
        showDebugInfo = try container.decodeIfPresent(Bool.self, forKey: .showDebugInfo) ?? false
        showCollisionBounds = try container.decodeIfPresent(Bool.self, forKey: .showCollisionBounds) ?? false
    }

    // MARK: - Apply Partial Updates

    /// Apply a partial update from a dictionary of key-value pairs.
    /// Returns the number of settings that were updated.
    @discardableResult
    public func apply(updates: [String: Any]) -> Int {
        var updatedCount = 0

        for (key, value) in updates {
            if applySetting(key: key, value: value) {
                updatedCount += 1
            }
        }

        return updatedCount
    }

    /// Apply a single setting update
    private func applySetting(key: String, value: Any) -> Bool {
        switch key {
        // Player settings
        case "nathanielSpeed":
            if let v = asCGFloat(value) { nathanielSpeed = v; return true }
        case "hermesSpeed":
            if let v = asCGFloat(value) { hermesSpeed = v; return true }
        case "nathanielMaxHealth":
            if let v = asInt(value) { nathanielMaxHealth = v; return true }
        case "hermesMaxHealth":
            if let v = asInt(value) { hermesMaxHealth = v; return true }
        case "playerInvincible":
            if let v = asBool(value) { playerInvincible = v; return true }
        case "respawnDelay":
            if let v = asTimeInterval(value) { respawnDelay = v; return true }

        // Enemy settings
        case "gruntSpeed":
            if let v = asCGFloat(value) { gruntSpeed = v; return true }
        case "soldierSpeed":
            if let v = asCGFloat(value) { soldierSpeed = v; return true }
        case "bossSpeed":
            if let v = asCGFloat(value) { bossSpeed = v; return true }
        case "enemyVisibleRange":
            if let v = asCGFloat(value) { enemyVisibleRange = v; return true }
        case "enemyAttackRange":
            if let v = asCGFloat(value) { enemyAttackRange = v; return true }
        case "enemyDamage":
            if let v = asInt(value) { enemyDamage = v; return true }

        // Projectile settings
        case "bulletSpeed":
            if let v = asCGFloat(value) { bulletSpeed = v; return true }
        case "arrowSpeed":
            if let v = asCGFloat(value) { arrowSpeed = v; return true }
        case "projectileDamage":
            if let v = asInt(value) { projectileDamage = v; return true }

        // Spawn settings
        case "spawnInterval":
            if let v = asTimeInterval(value) { spawnInterval = v; return true }

        // Camera settings
        case "cameraZoom":
            if let v = asCGFloat(value) { cameraZoom = v; return true }
        case "cameraMinZoom":
            if let v = asCGFloat(value) { cameraMinZoom = v; return true }
        case "cameraMaxZoom":
            if let v = asCGFloat(value) { cameraMaxZoom = v; return true }
        case "cameraFollowSmoothing":
            if let v = asCGFloat(value) { cameraFollowSmoothing = v; return true }
        case "cameraFreeMode":
            if let v = asBool(value) { cameraFreeMode = v; return true }

        // Tower settings
        case "towerDamage":
            if let v = asInt(value) { towerDamage = v; return true }
        case "towerRange":
            if let v = asCGFloat(value) { towerRange = v; return true }
        case "towerCostGun":
            if let v = asInt(value) { towerCostGun = v; return true }
        case "towerCostLaser":
            if let v = asInt(value) { towerCostLaser = v; return true }
        case "towerCostHeal":
            if let v = asInt(value) { towerCostHeal = v; return true }
        case "instantBuild":
            if let v = asBool(value) { instantBuild = v; return true }

        // Debug toggles
        case "infiniteResources":
            if let v = asBool(value) { infiniteResources = v; return true }
        case "showDebugInfo":
            if let v = asBool(value) { showDebugInfo = v; return true }
        case "showCollisionBounds":
            if let v = asBool(value) { showCollisionBounds = v; return true }

        default:
            print("[DevSettings] Unknown setting key: \(key)")
            return false
        }
        return false
    }

    // MARK: - Type Conversion Helpers

    private func asCGFloat(_ value: Any) -> CGFloat? {
        if let v = value as? CGFloat { return v }
        if let v = value as? Double { return CGFloat(v) }
        if let v = value as? Int { return CGFloat(v) }
        if let v = value as? NSNumber { return CGFloat(v.doubleValue) }
        return nil
    }

    private func asInt(_ value: Any) -> Int? {
        if let v = value as? Int { return v }
        if let v = value as? Double { return Int(v) }
        if let v = value as? NSNumber { return v.intValue }
        return nil
    }

    private func asBool(_ value: Any) -> Bool? {
        if let v = value as? Bool { return v }
        if let v = value as? Int { return v != 0 }
        if let v = value as? NSNumber { return v.boolValue }
        return nil
    }

    private func asTimeInterval(_ value: Any) -> TimeInterval? {
        if let v = value as? TimeInterval { return v }
        if let v = value as? Double { return v }
        if let v = value as? Int { return TimeInterval(v) }
        if let v = value as? NSNumber { return v.doubleValue }
        return nil
    }
}

#endif
