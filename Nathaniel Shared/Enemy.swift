//
//  Enemy.swift
//  Nathaniel Shared
//
//  Base class for enemy characters and specific enemy implementations.
//

import SpriteKit

// MARK: - Enemy Base Class

/// Base class for all enemy characters
class Enemy: Character {

    // MARK: - Properties

    /// Score awarded when this enemy is killed
    let killScore: Int

    /// Range at which enemy can detect targets
    let visibleRange: CGFloat

    /// Range at which enemy can attack
    let attackRange: CGFloat

    /// Current target (usually a player character)
    weak var target: Character?

    /// Whether this enemy has a ranged weapon
    var hasRangedWeapon: Bool = false

    /// Weapon (for ranged enemies)
    var weapon: Gun?

    /// Melee damage (for melee enemies)
    let meleeDamage: Int

    /// Melee attack cooldown
    let meleeAttackCooldown: TimeInterval

    /// Time since last melee attack
    var meleeAttackTimer: TimeInterval = 0

    /// Whether the enemy is currently attacking
    var isAttacking: Bool = false

    // MARK: - Initialization

    init(name: String, maxHP: Int, speed: CGFloat, killScore: Int,
         visibleRange: CGFloat, attackRange: CGFloat,
         meleeDamage: Int = 0, meleeAttackCooldown: TimeInterval = 1.0,
         spriteSheetCols: Int = 8, spriteSheetRows: Int = 4) {

        self.killScore = killScore
        self.visibleRange = visibleRange
        self.attackRange = attackRange
        self.meleeDamage = meleeDamage
        self.meleeAttackCooldown = meleeAttackCooldown

        super.init(
            name: name,
            maxHP: maxHP,
            speed: speed,
            spriteSheetCols: spriteSheetCols,
            spriteSheetRows: spriteSheetRows
        )
    }

    // MARK: - Update

    override func update(deltaTime: TimeInterval) {
        guard isActive && isAlive else { return }

        // Update melee timer
        meleeAttackTimer += deltaTime

        // Update weapon if ranged
        weapon?.update(deltaTime: deltaTime)

        // Run AI behavior
        updateAI(deltaTime: deltaTime)

        // Call parent update for movement
        super.update(deltaTime: deltaTime)
    }

    /// AI behavior - subclasses can override for custom behavior
    func updateAI(deltaTime: TimeInterval) {
        guard let target = target, target.isAlive else {
            // No target or target dead - stop
            destination = nil
            isAttacking = false
            return
        }

        let dx = target.position.x - position.x
        let dy = target.position.y - position.y
        let distanceToTarget = hypot(dx, dy)

        // Check if target is in visible range
        if distanceToTarget > visibleRange {
            // Target too far - don't pursue
            destination = nil
            isAttacking = false
            return
        }

        // Check if in attack range
        if distanceToTarget <= attackRange {
            // In range - attack!
            isAttacking = true
            destination = nil  // Stop moving when attacking

            // Face target
            let direction = CGVector(dx: dx, dy: dy)
            facingDirection = FacingDirection.from(direction: direction)

            // Perform attack
            performAttack()
        } else {
            // Not in range - move toward target
            isAttacking = false

            // Move toward target (stop slightly before attack range)
            destination = target.position
        }
    }

    /// Perform an attack (melee or ranged)
    func performAttack() {
        guard let target = target, target.isAlive else { return }

        if hasRangedWeapon, let weapon = weapon {
            // Ranged attack
            _ = weapon.use(target: target.position)
        } else if meleeDamage > 0 {
            // Melee attack
            if meleeAttackTimer >= meleeAttackCooldown {
                meleeAttackTimer = 0
                target.takeDamage(meleeDamage)
            }
        }
    }

    // MARK: - Texture Update

    override func updateTexture() {
        guard !frameTextures.isEmpty else { return }

        let col = facingDirection.rawValue

        // Row 0 = idle/attack, Row 1 = moving
        // Note: The grunt has 4 rows - rows 2 and 3 might be attack frames
        let row: Int
        if isAttacking || !isMoving {
            row = 0
        } else {
            row = 1
        }

        guard row < frameTextures.count, col < frameTextures[row].count else { return }
        sprite.texture = frameTextures[row][col]
    }
}

// MARK: - Grunt Enemy

/// Basic melee enemy that chases and attacks players
class Grunt: Enemy {

    // MARK: - Constants (from legacy code)

    /// Maximum health points
    static let defaultMaxHP = 150

    /// Movement speed
    static let defaultSpeed: CGFloat = 70

    /// Points awarded for killing
    static let defaultKillScore = 20

    /// Detection range
    static let defaultVisibleRange: CGFloat = 800

    /// Attack range (melee)
    static let defaultAttackRange: CGFloat = 60

    /// Melee damage per hit
    static let defaultMeleeDamage = 20

    /// Time between melee attacks
    static let defaultMeleeAttackCooldown: TimeInterval = 0.8

    // MARK: - Initialization

    init() {
        super.init(
            name: "Grunt",
            maxHP: Grunt.defaultMaxHP,
            speed: Grunt.defaultSpeed,
            killScore: Grunt.defaultKillScore,
            visibleRange: Grunt.defaultVisibleRange,
            attackRange: Grunt.defaultAttackRange,
            meleeDamage: Grunt.defaultMeleeDamage,
            meleeAttackCooldown: Grunt.defaultMeleeAttackCooldown,
            spriteSheetCols: 8,
            spriteSheetRows: 4
        )

        // Load sprite sheet
        loadSpriteSheet(named: "gruntspritesheet")

        // Initial facing
        facingDirection = .south
    }
}

// MARK: - Blaster Weapon (for ranged enemies)

/// Ranged weapon used by enemies that shoots red bullets
class Blaster: Gun {

    init(cooldownTime: TimeInterval = 0.8, damage: Int = 25, range: CGFloat = 600) {
        super.init(
            cooldownTime: cooldownTime,
            damage: damage,
            range: range,
            bulletSpeed: 450,
            bulletTexture: "redbullet"
        )
    }
}

// MARK: - Soldier Enemy

/// Ranged enemy that keeps distance and shoots at players
class Soldier: Enemy {

    // MARK: - Constants (from legacy code)

    /// Maximum health points
    static let defaultMaxHP = 200

    /// Movement speed (slower than Grunt)
    static let defaultSpeed: CGFloat = 40

    /// Points awarded for killing
    static let defaultKillScore = 30

    /// Detection and attack range (same for ranged)
    static let defaultRange: CGFloat = 300

    /// Preferred distance to maintain from target (60% of range)
    static let preferredDistanceRatio: CGFloat = 0.6

    // MARK: - Initialization

    init() {
        super.init(
            name: "Soldier",
            maxHP: Soldier.defaultMaxHP,
            speed: Soldier.defaultSpeed,
            killScore: Soldier.defaultKillScore,
            visibleRange: Soldier.defaultRange,
            attackRange: Soldier.defaultRange,
            meleeDamage: 0,  // No melee - ranged only
            meleeAttackCooldown: 0,
            spriteSheetCols: 8,
            spriteSheetRows: 2  // Soldier has only 2 rows
        )

        // Configure ranged weapon
        hasRangedWeapon = true
        weapon = Blaster(cooldownTime: 0.8, damage: 25, range: Soldier.defaultRange)
        weapon?.owner = self

        // Load sprite sheet
        loadSpriteSheet(named: "greenenemyspritesheet")

        // Initial facing
        facingDirection = .south
    }

    // MARK: - AI Override

    /// Soldier-specific AI: maintain distance while shooting
    override func updateAI(deltaTime: TimeInterval) {
        guard let target = target, target.isAlive else {
            destination = nil
            isAttacking = false
            return
        }

        let dx = target.position.x - position.x
        let dy = target.position.y - position.y
        let distanceToTarget = hypot(dx, dy)

        // Check if target is in visible range
        if distanceToTarget > visibleRange {
            destination = nil
            isAttacking = false
            return
        }

        // Face the target
        let direction = CGVector(dx: dx, dy: dy)
        facingDirection = FacingDirection.from(direction: direction)

        // Preferred distance to maintain
        let preferredDistance = attackRange * Soldier.preferredDistanceRatio

        if distanceToTarget > preferredDistance {
            // Too far - move closer while attacking
            isAttacking = true
            destination = target.position
            performAttack()
        } else {
            // In preferred range - stop and attack
            isAttacking = true
            destination = nil
            performAttack()
        }
    }
}
