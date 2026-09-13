//
//  GunTower.swift
//  Nathaniel Shared
//
//  Fires the original gun from a stationary defensive tower.
//

import SpriteKit

// MARK: - Gun Tower

/// Armed tower that fires bullets at enemies
class GunTower: DefensiveStructure {
    // MARK: - Properties

    /// The gun weapon
    let gun: Gun

    // MARK: - Initialization

    init() {
        // Create gun with tower-specific settings from GameBalance
        self.gun = Gun(
            cooldownTime: GameBalance.Towers.GunTower.gunCooldown,
            damage: GameBalance.Towers.GunTower.gunDamage,
            range: GameBalance.Towers.GunTower.attackRange,
            bulletSpeed: GameBalance.Towers.GunTower.bulletSpeed,
            bulletTexture: "bullet"
        )

        super.init(
            name: "GunTower",
            maxHP: GameBalance.Towers.GunTower.maxHP,
            attackRange: GameBalance.Towers.GunTower.attackRange
        )

        // Load tower texture
        loadTexture(named: "guntower", size: GameBalance.Towers.Visual.textureSize)

        self.gun.owner = self
    }

    // MARK: - Update

    override func update(deltaTime: TimeInterval) {
        // Update gun cooldown and projectiles
        self.gun.update(deltaTime: deltaTime)

        super.update(deltaTime: deltaTime)
    }

    override func attackTarget(_ target: Enemy, deltaTime: TimeInterval) {
        // Try to fire at target
        _ = self.gun.use(target: target.position)
    }

    override func onDeath() {
        self.gun.projectilePool.clear()
        super.onDeath()
    }
}
