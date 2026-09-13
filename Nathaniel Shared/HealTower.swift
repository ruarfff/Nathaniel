//
//  HealTower.swift
//  Nathaniel Shared
//
//  Heals Nathaniel first, then Hermes, once per healing tick.
//

import SpriteKit

// MARK: - Heal Tower

/// Support tower that heals nearby player characters
class HealTower: DefensiveStructure {
    // MARK: - Properties

    /// Heal amount per tick
    let healAmount: Int = GameBalance.Towers.HealTower.healAmount

    /// Delay between heal ticks
    let healDelay: TimeInterval = GameBalance.Towers.HealTower.healDelay

    /// Time since last heal
    private var healTimer: TimeInterval = 0

    /// Characters to heal (set by GameScene)
    var healTargets: [Character] = []

    // MARK: - Initialization

    init() {
        super.init(
            name: "HealTower",
            maxHP: GameBalance.Towers.HealTower.maxHP,
            attackRange: GameBalance.Towers.HealTower.attackRange
        )

        // Load tower texture
        loadTexture(named: "healtower", size: GameBalance.Towers.Visual.textureSize)
    }

    // MARK: - Update

    override func update(deltaTime: TimeInterval) {
        guard isActive, isAlive else { return }

        self.healTimer += deltaTime

        if self.healTimer >= self.healDelay, self.healNearbyAllies() {
            self.healTimer = 0
        }
    }

    /// Heal Nathaniel first, then Hermes, once per tick.
    private func healNearbyAllies() -> Bool {
        let target = self.healTargets.first { $0 is Nathaniel && self.canHeal($0) }
            ?? self.healTargets.first { $0 is Hermes && self.canHeal($0) }
        guard let target else { return false }

        target.currentHP = min(target.maxHP, target.currentHP + self.healAmount)
        target.updateHealthBar()
        self.showHealEffect(on: target)
        return true
    }

    private func canHeal(_ target: Character) -> Bool {
        target.isAlive && target.currentHP < target.maxHP &&
            position.distance(to: target.position) < attackRange
    }

    /// Show visual heal effect on target
    private func showHealEffect(on target: Character) {
        // Brief green tint on healed character
        let flashGreen = SKAction.colorize(with: .green, colorBlendFactor: 0.5, duration: 0.1)
        let flashBack = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.2)
        target.sprite.run(SKAction.sequence([flashGreen, flashBack]))
    }

    /// Override attack methods - heal tower doesn't attack
    override func findTargetInRange() -> Enemy? {
        nil
    }

    override func attackTarget(_ target: Enemy, deltaTime: TimeInterval) {}
}
