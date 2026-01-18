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
        guard self.resourceDropMax >= self.resourceDropMin, self.resourceDropMin > 0 else {
            return 0
        }
        return Int.random(in: self.resourceDropMin ... self.resourceDropMax)
    }

    /// Current target (player character or structure)
    weak var target: Damageable?

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
        self.weapon?.hasActiveProjectiles ?? false
    }

    // MARK: - Threat System

    /// Threat table tracking threat per player
    var threatTable = ThreatTable()

    /// Multiplier for threat generation (affects how easily this enemy changes targets)
    /// Higher values = more responsive to threat changes
    /// Lower values = more "sticky" to current target
    var threatMultiplier: Float = 1.0

    /// Whether this enemy has been aggro'd (seen a player)
    private var hasInitialAggro = false

    // MARK: - Initialization

    init(
        name: String,
        maxHP: Int,
        speed: CGFloat,
        killScore: Int,
        visibleRange: CGFloat,
        attackRange: CGFloat,
        meleeDamage: Int = 0,
        meleeAttackCooldown: TimeInterval = 1.0,
        resourceDropMin: Int = 1,
        resourceDropMax: Int = 3,
        spriteSheetCols: Int = 8,
        spriteSheetRows: Int = 4
    ) {
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

    // MARK: - Threat System Methods

    /// Add threat for a target (called when damage is dealt, etc.)
    /// - Parameters:
    ///   - target: The character generating threat
    ///   - amount: Amount of threat to add (will be scaled by threatMultiplier)
    func addThreat(from target: Damageable, amount: Float) {
        let scaledAmount = amount * self.threatMultiplier
        self.threatTable.addThreat(for: target, amount: scaledAmount)
    }

    /// Generate initial aggro threat when first spotting a player
    /// - Parameter target: The player that was spotted
    func generateInitialAggro(for target: Character) {
        guard !self.hasInitialAggro else { return }
        self.hasInitialAggro = true
        self.threatTable.addThreat(for: target, amount: ThreatConfig.initialAggroThreat)
    }

    /// Generate proximity threat for being near a target
    /// - Parameters:
    ///   - target: The player in range
    ///   - deltaTime: Time since last update
    func generateProximityThreat(for target: Character, deltaTime: TimeInterval) {
        let amount = ThreatConfig.proximityThreatPerSecond * Float(deltaTime)
        self.threatTable.addThreat(for: target, amount: amount)
    }

    /// Get the target with highest threat, or nil if no threats
    func getHighestThreatTarget() -> Damageable? {
        self.threatTable.getHighestThreatTarget()
    }

    /// Update threat decay
    func updateThreatDecay(deltaTime: TimeInterval) {
        self.threatTable.decayThreat(deltaTime: deltaTime)
    }

    // MARK: - Update

    override func update(deltaTime: TimeInterval) {
        // Always update weapon projectiles, even after death
        // This ensures projectiles complete their trajectory instead of freezing
        self.weapon?.update(deltaTime: deltaTime)

        guard isActive, isAlive else { return }

        #if DEBUG
            // Apply dev settings for live updates (speed set by subclasses)
            self.applyDevSettings()
        #endif

        // Update melee timer
        self.meleeAttackTimer += deltaTime

        // Run AI behavior
        self.updateAI(deltaTime: deltaTime)

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
        guard let target, target.isAlive else {
            // No target or target dead - stop
            stop()
            self.isAttacking = false
            return
        }

        let dx = target.position.x - position.x
        let dy = target.position.y - position.y
        let distanceToTarget = position.distance(to: target.position)

        // Check if target is in visible range
        if distanceToTarget > self.visibleRange {
            // Target too far - don't pursue
            stop()
            self.isAttacking = false
            return
        }

        // Check if in attack range
        if distanceToTarget <= self.attackRange {
            // In range - attack!
            self.isAttacking = true
            stop() // Stop moving when attacking

            // Face target
            let direction = CGVector(dx: dx, dy: dy)
            facingDirection = FacingDirection.from(direction: direction)

            // Perform attack
            self.performAttack()
        } else {
            // Not in range - move toward target using pathfinding
            self.isAttacking = false

            // Move toward target (pathfinding handles obstacles)
            moveTo(target.position)
        }
    }

    /// Perform an attack (melee or ranged)
    func performAttack() {
        guard let target, target.isAlive else { return }

        if self.hasRangedWeapon, let weapon {
            // Ranged attack
            _ = weapon.use(target: target.position)
        } else if self.meleeDamage > 0 {
            // Melee attack
            if self.meleeAttackTimer >= self.meleeAttackCooldown {
                self.meleeAttackTimer = 0
                target.takeDamage(self.meleeDamage)
            }
        }
    }

    // MARK: - Damage and Threat

    /// Take damage from an attacker and generate threat
    /// - Parameters:
    ///   - amount: Amount of damage to take
    ///   - attacker: The character dealing the damage (for threat tracking)
    func takeDamage(_ amount: Int, from attacker: Damageable?) {
        // First, take the damage
        self.takeDamage(amount)

        // Generate threat if we have an attacker
        if let attacker {
            // Apply tower multiplier if attacker is a structure (towers generate less threat)
            let multiplier = (attacker is Structure)
                ? ThreatConfig.towerDamageThreatMultiplier
                : ThreatConfig.damageThreatMultiplier
            let threatAmount = Float(amount) * multiplier
            self.addThreat(from: attacker, amount: threatAmount)
        }
    }

    // MARK: - Texture Update

    override func updateTexture() {
        guard !frameTextures.isEmpty else { return }

        let col = facingDirection.rawValue

        // Row 0 = idle/attack, Row 1 = moving
        // Note: The grunt has 4 rows - rows 2 and 3 might be attack frames
        let row = if self.isAttacking || !isMoving {
            0
        } else {
            1
        }

        guard row < frameTextures.count, col < frameTextures[row].count else { return }
        sprite.texture = frameTextures[row][col]
    }
}

// MARK: - Grunt Enemy

/// Basic melee enemy that chases and attacks players
class Grunt: Enemy {
    // MARK: - Constants

    /// Maximum health points
    static var defaultMaxHP: Int { GameBalance.Grunt.maxHP }

    /// Movement speed
    static var defaultSpeed: CGFloat { GameBalance.Grunt.speed }

    /// Points awarded for killing
    static var defaultKillScore: Int { GameBalance.Grunt.killScore }

    /// Detection range
    static var defaultVisibleRange: CGFloat { GameBalance.Grunt.visionRange }

    /// Attack range (melee)
    static var defaultAttackRange: CGFloat { GameBalance.Grunt.attackRange }

    /// Melee damage per hit
    static var defaultMeleeDamage: Int { GameBalance.Grunt.meleeDamage }

    /// Time between melee attacks
    static var defaultMeleeAttackCooldown: TimeInterval { GameBalance.Grunt.meleeAttackCooldown }

    /// Resource drop range (low - basic enemy)
    static var defaultResourceDropMin: Int { GameBalance.Grunt.resourceDropMin }
    static var defaultResourceDropMax: Int { GameBalance.Grunt.resourceDropMax }

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

        // Grunts are easily provoked and quickly switch targets
        threatMultiplier = GameBalance.Grunt.threatMultiplier
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
            bulletSpeed: 400, // Arrows are slower than bullets
            bulletTexture: "arrow",
            projectileType: .arrow
        )
    }
}

// MARK: - Boss Enemy

/// Boss enemy for Level One - high HP, ranged attacks, triggers victory when defeated
class Boss: Enemy {
    // MARK: - Constants

    /// Maximum health points (very high for boss)
    static var defaultMaxHP: Int { GameBalance.Boss.maxHP }

    /// Movement speed (moderate)
    static var defaultSpeed: CGFloat { GameBalance.Boss.speed }

    /// Points awarded for killing (high value)
    static var defaultKillScore: Int { GameBalance.Boss.killScore }

    /// Detection range
    static var defaultVisibleRange: CGFloat { GameBalance.Boss.visionRange }

    /// Attack range (bow range)
    static var defaultAttackRange: CGFloat { GameBalance.Boss.attackRange }

    /// Distance ratio at which boss stops moving (30% of range)
    static var stopDistanceRatio: CGFloat { GameBalance.Boss.stopDistanceRatio }

    /// Resource drop range (high - boss enemy)
    static var defaultResourceDropMin: Int { GameBalance.Boss.resourceDropMin }
    static var defaultResourceDropMax: Int { GameBalance.Boss.resourceDropMax }

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
            meleeDamage: 0, // No melee - ranged only
            meleeAttackCooldown: 0,
            resourceDropMin: Boss.defaultResourceDropMin,
            resourceDropMax: Boss.defaultResourceDropMax,
            spriteSheetCols: 8,
            spriteSheetRows: 8 // Boss has 8 rows for more animation variety
        )

        // Configure ranged weapon (Bow)
        hasRangedWeapon = true
        weapon = Bow(cooldownTime: 1.5, damage: 25, range: Boss.defaultAttackRange)
        weapon?.owner = self

        // Load sprite sheet
        loadSpriteSheet(named: "boss1spritesheet")

        // Initial facing
        facingDirection = .south

        // Bosses are more deliberate and harder to pull aggro from their target
        threatMultiplier = GameBalance.Boss.threatMultiplier
    }

    // MARK: - AI Override

    /// Boss-specific AI: approach target but maintain comfortable attack distance
    override func updateAI(deltaTime: TimeInterval) {
        guard let target, target.isAlive else {
            stop()
            isAttacking = false
            return
        }

        let dx = target.position.x - position.x
        let dy = target.position.y - position.y
        let distanceToTarget = position.distance(to: target.position)

        // Check if target is in visible range
        if distanceToTarget > visibleRange {
            stop()
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
                moveTo(target.position)
                performAttack()
            } else {
                // Just move closer using pathfinding
                isAttacking = false
                moveTo(target.position)
            }
        } else {
            // Close enough - stop and attack
            isAttacking = true
            stop()
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
        let row: Int = if isMoving {
            // Use movement row (cycle through first 4 rows based on animation)
            min(1, frameTextures.count - 1) // Simplified: just use row 1 for walking
        } else {
            // Use idle row (row 5 in legacy, but we may have fewer rows)
            min(5, frameTextures.count - 1)
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
        self.isDefeated = true
        super.onDeath()
    }
}

// MARK: - Soldier Enemy

/// Ranged enemy that keeps distance and shoots at players
class Soldier: Enemy {
    // MARK: - Constants

    /// Maximum health points
    static var defaultMaxHP: Int { GameBalance.Soldier.maxHP }

    /// Movement speed (slower than Grunt)
    static var defaultSpeed: CGFloat { GameBalance.Soldier.speed }

    /// Points awarded for killing
    static var defaultKillScore: Int { GameBalance.Soldier.killScore }

    /// Detection and attack range (same for ranged)
    static var defaultRange: CGFloat { GameBalance.Soldier.range }

    /// Preferred distance to maintain from target (60% of range)
    static var preferredDistanceRatio: CGFloat { GameBalance.Soldier.preferredDistanceRatio }

    /// Resource drop range (medium - ranged enemy)
    static var defaultResourceDropMin: Int { GameBalance.Soldier.resourceDropMin }
    static var defaultResourceDropMax: Int { GameBalance.Soldier.resourceDropMax }

    // MARK: - Initialization

    init() {
        super.init(
            name: "Soldier",
            maxHP: Soldier.defaultMaxHP,
            speed: Soldier.defaultSpeed,
            killScore: Soldier.defaultKillScore,
            visibleRange: Soldier.defaultRange,
            attackRange: Soldier.defaultRange,
            meleeDamage: 0, // No melee - ranged only
            meleeAttackCooldown: 0,
            resourceDropMin: Soldier.defaultResourceDropMin,
            resourceDropMax: Soldier.defaultResourceDropMax,
            spriteSheetCols: 8,
            spriteSheetRows: 2 // Soldier has only 2 rows
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
        guard let target, target.isAlive else {
            stop()
            isAttacking = false
            return
        }

        let dx = target.position.x - position.x
        let dy = target.position.y - position.y
        let distanceToTarget = position.distance(to: target.position)

        // Check if target is in visible range
        if distanceToTarget > visibleRange {
            stop()
            isAttacking = false
            return
        }

        // Face the target
        let direction = CGVector(dx: dx, dy: dy)
        facingDirection = FacingDirection.from(direction: direction)

        // Preferred distance to maintain
        let preferredDistance = attackRange * Soldier.preferredDistanceRatio

        if distanceToTarget > preferredDistance {
            // Too far - move closer while attacking using pathfinding
            isAttacking = true
            moveTo(target.position)
            performAttack()
        } else {
            // In preferred range - stop and attack
            isAttacking = true
            stop()
            performAttack()
        }
    }
}
