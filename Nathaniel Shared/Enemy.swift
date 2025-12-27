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

    // MARK: - Resource Drop Properties

    /// Minimum resources dropped on death
    let resourceDropMin: Int

    /// Maximum resources dropped on death
    let resourceDropMax: Int

    /// Calculate a random resource drop amount within the configured range
    func calculateResourceDrop() -> Int {
        guard resourceDropMax >= resourceDropMin && resourceDropMin > 0 else {
            return 0
        }
        return Int.random(in: resourceDropMin...resourceDropMax)
    }

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

    /// Whether this enemy has projectiles still in flight
    var hasActiveProjectiles: Bool {
        return weapon?.hasActiveProjectiles ?? false
    }

    // MARK: - Initialization

    init(name: String, maxHP: Int, speed: CGFloat, killScore: Int,
         visibleRange: CGFloat, attackRange: CGFloat,
         meleeDamage: Int = 0, meleeAttackCooldown: TimeInterval = 1.0,
         resourceDropMin: Int = 1, resourceDropMax: Int = 3,
         spriteSheetCols: Int = 8, spriteSheetRows: Int = 4) {

        self.killScore = killScore
        self.visibleRange = visibleRange
        self.attackRange = attackRange
        self.meleeDamage = meleeDamage
        self.meleeAttackCooldown = meleeAttackCooldown
        self.resourceDropMin = resourceDropMin
        self.resourceDropMax = resourceDropMax

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
        // Always update weapon projectiles, even after death
        // This ensures projectiles complete their trajectory instead of freezing
        weapon?.update(deltaTime: deltaTime)

        guard isActive && isAlive else { return }

        #if DEBUG
        // Apply dev settings for live updates (speed set by subclasses)
        applyDevSettings()
        #endif

        // Update melee timer
        meleeAttackTimer += deltaTime

        // Run AI behavior
        updateAI(deltaTime: deltaTime)

        // Call parent update for movement
        super.update(deltaTime: deltaTime)
    }

    #if DEBUG
    /// Override in subclasses to apply dev settings
    func applyDevSettings() {
        // Subclasses override this to apply their specific settings
    }
    #endif

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

    /// Resource drop range (low - basic enemy)
    static let defaultResourceDropMin = 1
    static let defaultResourceDropMax = 3

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
            resourceDropMin: Grunt.defaultResourceDropMin,
            resourceDropMax: Grunt.defaultResourceDropMax,
            spriteSheetCols: 8,
            spriteSheetRows: 4
        )

        // Load sprite sheet
        loadSpriteSheet(named: "gruntspritesheet")

        // Initial facing
        facingDirection = .south
    }

    #if DEBUG
    override func applyDevSettings() {
        speed = DevSettings.shared.gruntSpeed
    }
    #endif
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

// MARK: - Bow Weapon (for Boss)

/// Bow weapon that shoots arrows - used by the Boss
class Bow: Gun {

    init(cooldownTime: TimeInterval = 1.5, damage: Int = 25, range: CGFloat = 300) {
        super.init(
            cooldownTime: cooldownTime,
            damage: damage,
            range: range,
            bulletSpeed: 400,  // Arrows are slower than bullets
            bulletTexture: "arrow",
            projectileType: .arrow
        )
    }
}

// MARK: - Boss Enemy

/// Boss enemy for Level One - high HP, ranged attacks, triggers victory when defeated
class Boss: Enemy {

    // MARK: - Constants (from legacy code)

    /// Maximum health points (very high for boss)
    static let defaultMaxHP = 800

    /// Movement speed (moderate)
    static let defaultSpeed: CGFloat = 60

    /// Points awarded for killing (high value)
    static let defaultKillScore = 100

    /// Detection range
    static let defaultVisibleRange: CGFloat = 600

    /// Attack range (bow range)
    static let defaultAttackRange: CGFloat = 500

    /// Distance ratio at which boss stops moving (30% of range)
    static let stopDistanceRatio: CGFloat = 0.3

    /// Resource drop range (high - boss enemy)
    static let defaultResourceDropMin = 10
    static let defaultResourceDropMax = 20

    // MARK: - Properties

    /// Whether this boss has been defeated (for win condition)
    private(set) var isDefeated: Bool = false

    // MARK: - Initialization

    init() {
        super.init(
            name: "Boss",
            maxHP: Boss.defaultMaxHP,
            speed: Boss.defaultSpeed,
            killScore: Boss.defaultKillScore,
            visibleRange: Boss.defaultVisibleRange,
            attackRange: Boss.defaultAttackRange,
            meleeDamage: 0,  // No melee - ranged only
            meleeAttackCooldown: 0,
            resourceDropMin: Boss.defaultResourceDropMin,
            resourceDropMax: Boss.defaultResourceDropMax,
            spriteSheetCols: 8,
            spriteSheetRows: 8  // Boss has 8 rows for more animation variety
        )

        // Configure ranged weapon (Bow)
        hasRangedWeapon = true
        weapon = Bow(cooldownTime: 1.5, damage: 25, range: Boss.defaultAttackRange)
        weapon?.owner = self

        // Load sprite sheet
        loadSpriteSheet(named: "boss1spritesheet")

        // Initial facing
        facingDirection = .south
    }

    // MARK: - AI Override

    /// Boss-specific AI: approach target but maintain comfortable attack distance
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

        // Stop distance (30% of attack range)
        let stopDistance = attackRange * Boss.stopDistanceRatio

        if distanceToTarget > stopDistance {
            // Move closer while attacking if in attack range
            if distanceToTarget <= attackRange {
                isAttacking = true
                destination = target.position
                performAttack()
            } else {
                // Just move closer
                isAttacking = false
                destination = target.position
            }
        } else {
            // Close enough - stop and attack
            isAttacking = true
            destination = nil
            performAttack()
        }
    }

    // MARK: - Texture Update Override

    /// Boss has different animation frame layout (8x8 sprite sheet)
    override func updateTexture() {
        guard !frameTextures.isEmpty else { return }

        // Boss sprite sheet layout (based on legacy code):
        // Rows 0-4: Movement animations by direction
        // Row 5: Idle poses
        // Rows 6-7: Attack animations (if any)

        // Column mapping for directions (same as others)
        let col = facingDirection.rawValue

        // For boss: row 5 has idle frames, rows 0-4 have movement
        // The legacy code uses frames[index, col] for movement where index = 0-3
        // and frames[5, col] for idle
        let row: Int
        if isMoving {
            // Use movement row (cycle through first 4 rows based on animation)
            row = min(1, frameTextures.count - 1)  // Simplified: just use row 1 for walking
        } else {
            // Use idle row (row 5 in legacy, but we may have fewer rows)
            row = min(5, frameTextures.count - 1)
        }

        guard row < frameTextures.count, col < frameTextures[row].count else { return }
        sprite.texture = frameTextures[row][col]
    }

    #if DEBUG
    override func applyDevSettings() {
        speed = DevSettings.shared.bossSpeed
    }
    #endif

    // MARK: - Death Override

    override func onDeath() {
        isDefeated = true
        super.onDeath()
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

    /// Resource drop range (medium - ranged enemy)
    static let defaultResourceDropMin = 3
    static let defaultResourceDropMax = 6

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
            resourceDropMin: Soldier.defaultResourceDropMin,
            resourceDropMax: Soldier.defaultResourceDropMax,
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

    #if DEBUG
    override func applyDevSettings() {
        speed = DevSettings.shared.soldierSpeed
    }
    #endif

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
