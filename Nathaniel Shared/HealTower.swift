import SpriteKit

// MARK: - Heal Tower

/// Support tower that heals nearby player characters
class HealTower: DefensiveStructure {
    // MARK: - Constants

    /// Resource cost to build this tower
    static let cost: Int = BuildConfig.TowerCosts.healTower

    // MARK: - Properties

    /// Heal amount per tick
    let healAmount: Int = 5

    /// Delay between heal ticks
    let healDelay: TimeInterval = 1.0

    /// Time since last heal
    private var healTimer: TimeInterval = 0

    /// Characters to heal (set by GameScene)
    var healTargets: [Character] = []

    /// Visual effect node
    private var healEffectNode: SKShapeNode?

    // MARK: - Initialization

    init() {
        super.init(name: "HealTower", maxHP: 600, attackRange: 400)

        // Track build cost for recoup calculation
        buildCost = HealTower.cost

        // Load tower texture
        loadTexture(named: "healtower", size: CGSize(width: 48, height: 64))

        // Create heal range indicator (hidden by default)
        self.setupHealEffect()
    }

    private func setupHealEffect() {
        let circle = SKShapeNode(circleOfRadius: attackRange)
        circle.strokeColor = SKColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 0.3)
        circle.fillColor = SKColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 0.1)
        circle.lineWidth = 2
        circle.zPosition = -1
        circle.isHidden = true
        sprite.addChild(circle)
        self.healEffectNode = circle
    }

    // MARK: - Update

    override func update(deltaTime: TimeInterval) {
        guard isActive, isAlive else { return }

        self.healTimer += deltaTime

        if self.healTimer >= self.healDelay {
            self.healNearbyAllies()
            self.healTimer = 0
        }
    }

    /// Heal nearby allied characters
    private func healNearbyAllies() {
        for target in self.healTargets {
            guard target.isAlive else { continue }

            // Heal if in range and not at full health
            let distance = position.distance(to: target.position)
            if distance < attackRange, target.currentHP < target.maxHP - self.healAmount {
                target.currentHP = min(target.maxHP, target.currentHP + self.healAmount)
                target.updateHealthBar()

                // Show heal effect
                self.showHealEffect(on: target)
            }
        }
    }

    /// Show visual heal effect on target
    private func showHealEffect(on target: Character) {
        // Brief green tint on healed character
        let flashGreen = SKAction.colorize(with: .green, colorBlendFactor: 0.5, duration: 0.1)
        let flashBack = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.2)
        target.sprite.run(SKAction.sequence([flashGreen, flashBack]))
    }

    /// Show/hide heal range indicator
    func showHealRange(_ show: Bool) {
        self.healEffectNode?.isHidden = !show
    }

    // Override attack methods - heal tower doesn't attack
    override func findTargetInRange() -> Enemy? { nil }
    override func attackTarget(_ target: Enemy, deltaTime: TimeInterval) {}
}
