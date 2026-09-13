//
//  Enemy.swift
//  Nathaniel Shared
//
//  Enemy combat, animation, and spawning from the original game.
//

import SpriteKit

/// Shared enemy movement, targeting, and projectile combat.
class Enemy: Character {
    // MARK: - Properties

    let killScore: Int
    let visibleRange: CGFloat
    let attackRange: CGFloat
    weak var target: Damageable?
    var weapon: Gun?
    var isAttacking = false

    var hasActiveProjectiles: Bool {
        self.weapon?.hasActiveProjectiles ?? false
    }

    var stoppingDistance: CGFloat {
        self.attackRange
    }

    // MARK: - Initialization

    init(
        name: String,
        maxHP: Int,
        speed: CGFloat,
        killScore: Int,
        visibleRange: CGFloat,
        attackRange: CGFloat,
        spriteSheetCols: Int = 8,
        spriteSheetRows: Int = 4
    ) {
        self.killScore = killScore
        self.visibleRange = visibleRange
        self.attackRange = attackRange
        super.init(
            name: name,
            maxHP: maxHP,
            speed: speed,
            spriteSheetCols: spriteSheetCols,
            spriteSheetRows: spriteSheetRows
        )
    }

    // MARK: - Public Methods

    override func update(deltaTime: TimeInterval) {
        // Shots already in flight continue after the shooter dies.
        self.weapon?.update(deltaTime: deltaTime)
        guard isActive, isAlive else { return }
        #if DEBUG
            self.applyDevSettings()
        #endif
        self.updateAI(deltaTime: deltaTime)
        super.update(deltaTime: deltaTime)
    }

    func updateAI(deltaTime: TimeInterval) {
        guard let target, target.isAlive else {
            stop()
            self.isAttacking = false
            return
        }

        // Visibility controls acquisition. An acquired target is still pursued
        // after it leaves sight, as in the original game.
        let distance = position.distance(to: target.position)
        if distance > self.stoppingDistance {
            moveTo(target.position)
        } else {
            stop()
        }
        self.isAttacking = distance <= self.attackRange
        if self.isAttacking {
            facingDirection = FacingDirection.from(direction: CGVector(
                dx: target.position.x - position.x,
                dy: target.position.y - position.y
            ))
            _ = self.weapon?.use(target: target.position)
        }
    }

    /// Retain a live target; an idle enemy retaliates against its attacker.
    func takeDamage(_ amount: Int, from attacker: Damageable?) {
        self.takeDamage(amount)
        if isAlive, self.target?.isAlive != true, attacker?.isAlive == true {
            self.target = attacker
        }
    }

    override func updateTexture() {
        let row = self.isAttacking || !isMoving ? 0 : 1
        if let texture = animationComponent.texture(at: row, col: facingDirection.rawValue) {
            sprite.texture = texture
        }
    }

    /// Remove all visual state when a level is unloaded or a save is restored.
    func removeFromScene() {
        self.weapon?.projectilePool.clear()
        sprite.removeFromParent()
    }

    #if DEBUG
        func applyDevSettings() {}
    #endif
}

/// Red-bullet weapon used by Grunts.
class Blaster: Gun {
    init() {
        super.init(
            cooldownTime: GameBalance.Grunt.blasterCooldown,
            damage: GameBalance.Grunt.blasterDamage,
            range: GameBalance.Grunt.attackRange,
            bulletSpeed: 450,
            bulletTexture: "redbullet",
            soundEffect: .laser
        )
    }
}

/// Bow used by the boss. Arrows use time-based movement at the original 30 FPS speed.
class Bow: Gun {
    init() {
        super.init(
            cooldownTime: GameBalance.Boss.bowCooldown,
            damage: GameBalance.Boss.bowDamage,
            range: GameBalance.Boss.attackRange,
            bulletSpeed: GameBalance.Boss.arrowSpeed,
            bulletTexture: "arrow",
            projectileType: .arrow,
            soundEffect: .arrowShot
        )
    }
}

/// A fast ranged enemy armed with a Blaster.
class Grunt: Enemy {
    init() {
        super.init(
            name: "Grunt",
            maxHP: GameBalance.Grunt.maxHP,
            speed: GameBalance.Grunt.speed,
            killScore: GameBalance.Grunt.killScore,
            visibleRange: GameBalance.Grunt.visionRange,
            attackRange: GameBalance.Grunt.attackRange
        )
        weapon = Blaster()
        weapon?.owner = self
        loadSpriteSheet(named: "gruntspritesheet")
        sprite.size = CGSize(width: 72, height: 33)
    }

    #if DEBUG
        override func applyDevSettings() {
            speed = DevSettings.shared.gruntSpeed
        }
    #endif
}

/// A Soldier stops within gun range and fires ordinary bullets.
class Soldier: Enemy {
    init() {
        super.init(
            name: "Soldier",
            maxHP: GameBalance.Soldier.maxHP,
            speed: GameBalance.Soldier.speed,
            killScore: GameBalance.Soldier.killScore,
            visibleRange: GameBalance.Soldier.range,
            attackRange: GameBalance.Soldier.range,
            spriteSheetRows: 2
        )
        weapon = Gun(
            cooldownTime: GameBalance.Soldier.gunCooldown,
            damage: GameBalance.Soldier.gunDamage,
            range: GameBalance.Soldier.range,
            bulletSpeed: 450,
            bulletTexture: "bullet"
        )
        weapon?.owner = self
        loadSpriteSheet(named: "greenenemyspritesheet")
        sprite.size = CGSize(width: 60, height: 72)
    }

    override func updateTexture() {
        let row = isAttacking || isMoving ? 1 : 0
        if let texture = animationComponent.texture(at: row, col: facingDirection.rawValue) {
            sprite.texture = texture
        }
    }

    #if DEBUG
        override func applyDevSettings() {
            speed = DevSettings.shared.soldierSpeed
        }
    #endif
}

/// A boss advances while firing until it reaches 30 percent of its bow range.
class Boss: Enemy {
    private static let idleColumns = [0, 1, 4, 2, 7, 5, 6, 3]
    private var animationElapsed: TimeInterval = 0
    private(set) var isDefeated = false

    override var stoppingDistance: CGFloat {
        attackRange * GameBalance.Boss.stopDistanceRatio
    }

    init() {
        super.init(
            name: "Boss",
            maxHP: GameBalance.Boss.maxHP,
            speed: GameBalance.Boss.speed,
            killScore: GameBalance.Boss.killScore,
            visibleRange: GameBalance.Boss.visionRange,
            attackRange: GameBalance.Boss.attackRange,
            spriteSheetRows: 8
        )
        weapon = Bow()
        weapon?.owner = self
        loadSpriteSheet(named: "boss1spritesheet")
        sprite.size = CGSize(width: 80, height: 72)
        self.updateTexture()
    }

    override func update(deltaTime: TimeInterval) {
        self.animationElapsed += deltaTime
        super.update(deltaTime: deltaTime)
    }

    override func updateTexture() {
        let row = isMoving ? Int(self.animationElapsed * 4) % 4 : 5
        // The idle poses use a different direction order from the walking rows.
        let col = isMoving ? facingDirection.rawValue : Self.idleColumns[facingDirection.rawValue]
        if let texture = animationComponent.texture(at: row, col: col) {
            sprite.texture = texture
        }
    }

    override func onDeath() {
        self.isDefeated = true
        super.onDeath()
    }

    #if DEBUG
        override func applyDevSettings() {
            speed = DevSettings.shared.bossSpeed
        }
    #endif
}

/// A stationary laser emplacement that periodically produces Grunts.
class Spawner: Enemy {
    // MARK: - Properties

    let beam = LaserBeam(color: SKColor(red: 0, green: 1, blue: 0.5, alpha: 1), thickness: 6)
    var onSpawn: ((CGPoint) -> Void)?
    private(set) var timeUntilNextSpawn: TimeInterval = 30
    private(set) var initialSpawnsRemaining = 3
    private var cooldownElapsed: TimeInterval = 0
    private var burstElapsed: TimeInterval = 0
    private var damageElapsed: TimeInterval = 0

    // MARK: - Initialization

    init() {
        super.init(
            name: "Spawner",
            maxHP: GameBalance.Spawner.maxHP,
            speed: 0,
            killScore: GameBalance.Spawner.killScore,
            visibleRange: GameBalance.Spawner.visionRange,
            attackRange: GameBalance.Spawner.attackRange,
            spriteSheetCols: 1,
            spriteSheetRows: 1
        )
        loadSpriteSheet(named: "spawner")
        sprite.size = CGSize(width: 240, height: 168)
    }

    // MARK: - Public Methods

    override func updateAI(deltaTime: TimeInterval) {
        stop()
        self.timeUntilNextSpawn -= deltaTime
        if self.timeUntilNextSpawn <= 0 {
            self.initialSpawnsRemaining = max(0, self.initialSpawnsRemaining - 1)
            // Preserve the shipped XNA cadence: 30, 60, 90, then every 120 seconds.
            self.timeUntilNextSpawn = self.initialSpawnsRemaining > 0 ? 30 : 120
            self.onSpawn?(CGPoint(x: position.x + sprite.size.width, y: position.y - sprite.size.height))
        }

        guard let target, target.isAlive, position.distance(to: target.position) <= attackRange else {
            isAttacking = false
            self.burstElapsed = 0
            self.beam.deactivate()
            return
        }

        if !isAttacking {
            self.cooldownElapsed += deltaTime
            guard self.cooldownElapsed >= GameBalance.Spawner.laserCooldown else { return }
            self.cooldownElapsed = 0
            self.burstElapsed = 0
            isAttacking = true
            if let scene = sprite.scene {
                AudioManager.shared.playSoundEffect(.laserCannon, on: scene)
            }
        }
        let activeTime = min(deltaTime, GameBalance.Spawner.laserBurstDuration - self.burstElapsed)
        self.burstElapsed += activeTime
        self.damageElapsed += activeTime
        self.beam.fire(from: position, to: target.position)
        // The original laser applies one second of damage per tick. Carry the
        // remainder across bursts so damage does not depend on the frame rate.
        let ticks = Int(self.damageElapsed)
        if ticks > 0 {
            self.damageElapsed -= Double(ticks)
            target.takeDamage(ticks * GameBalance.Spawner.laserDPS)
        }
        if self.burstElapsed >= GameBalance.Spawner.laserBurstDuration {
            isAttacking = false
            self.beam.deactivate()
        }
    }

    func restoreSpawnState(timeUntilNextSpawn: TimeInterval, initialSpawnsRemaining: Int) {
        self.timeUntilNextSpawn = max(0, timeUntilNextSpawn)
        self.initialSpawnsRemaining = min(3, max(0, initialSpawnsRemaining))
    }

    override func onDeath() {
        self.beam.node.removeFromParent()
        self.beam.deactivate()
        super.onDeath()
    }

    override func removeFromScene() {
        self.beam.node.removeFromParent()
        self.beam.deactivate()
        super.removeFromScene()
    }
}
