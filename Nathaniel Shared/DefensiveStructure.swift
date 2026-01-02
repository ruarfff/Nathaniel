import SpriteKit

// MARK: - Build Configuration

/// Configuration for Hermes's build system
enum BuildConfig {
    /// Radius around Hermes within which towers can be placed
    static let buildRadius: CGFloat = 250.0

    /// Tower costs (in resources)
    enum TowerCosts {
        static let gunTower: Int = 5
        static let laserTower: Int = 10
        static let healTower: Int = 15
    }

    /// Tower placement collision radius (for overlap checks)
    /// Adjusted to match 1.25x scale (50% smaller than original 2.5x)
    static let towerCollisionRadius: CGFloat = 15.0
}

// MARK: - Placement Validation

/// Result of placement validation with reason for failure
enum PlacementResult {
    case valid
    case outOfBuildRadius
    case blockedByTerrain
    case overlapsStructure
    case overlapsCharacter
    case overlapsEnemy
}

/// Validates tower placement positions
class PlacementValidator {
    // MARK: - Properties

    /// Reference to Hermes for build radius check
    weak var hermes: Character?

    /// Reference to TMX renderer for terrain collision check
    weak var tmxRenderer: TMXRenderer?

    /// Reference to structure manager for tower overlap check
    weak var structureManager: StructureManager?

    /// Reference to enemy manager for enemy overlap check
    weak var enemyManager: EnemyManager?

    /// Player characters to check for overlap
    var playerCharacters: [Character] = []

    // MARK: - Validation

    /// Validate if a position is valid for tower placement
    /// - Parameter position: The world position to check
    /// - Returns: PlacementResult indicating if valid or why invalid
    func validate(position: CGPoint) -> PlacementResult {
        // Check 1: Within build radius of Hermes
        if !self.isWithinBuildRadius(position) {
            return .outOfBuildRadius
        }

        // Check 2: Not on collision tiles
        if !self.isTerrainClear(position) {
            return .blockedByTerrain
        }

        // Check 3: Not overlapping existing structures
        if self.overlapsStructure(position) {
            return .overlapsStructure
        }

        // Check 4: Not overlapping player characters
        if self.overlapsPlayerCharacter(position) {
            return .overlapsCharacter
        }

        // Check 5: Not overlapping enemies
        if self.overlapsEnemy(position) {
            return .overlapsEnemy
        }

        return .valid
    }

    /// Convenience method for boolean check
    func isValidPlacement(at position: CGPoint) -> Bool {
        self.validate(position: position) == .valid
    }

    // MARK: - Individual Checks

    /// Check if position is within build radius of Hermes
    private func isWithinBuildRadius(_ position: CGPoint) -> Bool {
        guard let hermes else { return false }

        let dx = position.x - hermes.position.x
        let dy = position.y - hermes.position.y
        let distance = hypot(dx, dy)

        return distance <= BuildConfig.buildRadius
    }

    /// Check if terrain at position is walkable (no collision)
    private func isTerrainClear(_ position: CGPoint) -> Bool {
        guard let renderer = tmxRenderer else { return true }
        return renderer.isWalkable(at: position)
    }

    /// Check if position overlaps any existing structure
    private func overlapsStructure(_ position: CGPoint) -> Bool {
        guard let manager = structureManager else { return false }

        for structure in manager.activeStructures {
            let dx = position.x - structure.position.x
            let dy = position.y - structure.position.y
            let distance = hypot(dx, dy)

            // Use tower collision radius for overlap check
            if distance < BuildConfig.towerCollisionRadius * 2 {
                return true
            }
        }
        return false
    }

    /// Check if position overlaps any player character
    private func overlapsPlayerCharacter(_ position: CGPoint) -> Bool {
        for character in self.playerCharacters where character.isAlive {
            let dx = position.x - character.position.x
            let dy = position.y - character.position.y
            let distance = hypot(dx, dy)

            // Use character's collision radius plus tower radius
            if distance < character.collisionRadius + BuildConfig.towerCollisionRadius {
                return true
            }
        }
        return false
    }

    /// Check if position overlaps any enemy
    private func overlapsEnemy(_ position: CGPoint) -> Bool {
        guard let manager = enemyManager else { return false }

        for enemy in manager.aliveEnemies {
            let dx = position.x - enemy.position.x
            let dy = position.y - enemy.position.y
            let distance = hypot(dx, dy)

            // Use enemy's collision radius plus tower radius
            if distance < enemy.collisionRadius + BuildConfig.towerCollisionRadius {
                return true
            }
        }
        return false
    }
}

// MARK: - Defensive Structure Base Class

/// Base class for all defensive structures (towers)
/// Structures are stationary, cannot move, and perform automated actions
class DefensiveStructure: Character {
    // MARK: - Properties

    /// Structures cannot move
    override var destination: CGPoint? {
        get { nil }
        set { /* Structures don't move */ }
    }

    /// Original resource cost paid to build this structure (for recoup calculation)
    var buildCost: Int = 0

    /// Attack range for finding targets
    var attackRange: CGFloat = 300

    /// Current target enemy
    weak var currentTarget: Enemy?

    /// Callback for checking nearby enemies
    var findNearestEnemy: (() -> Enemy?)?

    /// Callback when structure is destroyed
    var onDestroyed: (() -> Void)?

    // MARK: - Initialization

    init(name: String, maxHP: Int, attackRange: CGFloat) {
        self.attackRange = attackRange
        super.init(name: name, maxHP: maxHP, speed: 0, spriteSheetCols: 1, spriteSheetRows: 1)

        // Structures are always "idle" since they don't move
        animationState = .idle
    }

    // MARK: - GameEntity Methods

    override func update(deltaTime: TimeInterval) {
        guard isActive, isAlive else { return }

        // Find target if we don't have one or current target is dead
        if self.currentTarget?.isAlive != true {
            self.currentTarget = self.findTargetInRange()
        }

        // Attack current target if we have one
        if let target = currentTarget, target.isAlive {
            self.attackTarget(target, deltaTime: deltaTime)
        }
    }

    /// Find the nearest enemy within attack range
    func findTargetInRange() -> Enemy? {
        self.findNearestEnemy?()
    }

    /// Attack the current target (override in subclasses)
    func attackTarget(_ target: Enemy, deltaTime: TimeInterval) {
        // Override in subclasses
    }

    // MARK: - Death

    override func onDeath() {
        animationState = .dead
        isActive = false

        // Play explosion sound
        if let scene = sprite.scene {
            AudioManager.shared.playSoundEffect(.explosion, on: scene)
        }

        // Notify callback
        self.onDestroyed?()

        // Fade out and remove
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let remove = SKAction.removeFromParent()
        sprite.run(SKAction.sequence([fadeOut, remove]))
    }

    /// Destroy with enhanced visual effect (used by staggered destruction)
    /// This handles only the sprite animation, not the explosion effect
    func destroyWithEffect() {
        animationState = .dead
        isActive = false

        // Notify callback
        self.onDestroyed?()

        // Enhanced destruction animation: flash, expand slightly, then collapse
        let flashWhite = SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: 0.05)
        let flashBack = SKAction.colorize(withColorBlendFactor: 0, duration: 0.05)
        let scaleUp = SKAction.scale(by: 1.3, duration: 0.1)
        let scaleDown = SKAction.scale(to: 0.1, duration: 0.2)
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let remove = SKAction.removeFromParent()

        let flashSequence = SKAction.sequence([flashWhite, flashBack])
        let collapseGroup = SKAction.group([scaleDown, fadeOut])
        let fullSequence = SKAction.sequence([flashSequence, scaleUp, collapseGroup, remove])

        sprite.run(fullSequence)
    }

    // MARK: - Texture Setup (Single Frame)

    /// Load a single texture for the structure
    func loadTexture(named textureName: String, size: CGSize? = nil) {
        let texture = SKTexture(imageNamed: textureName)
        texture.filteringMode = .nearest
        sprite.texture = texture

        let textureSize = texture.size()
        print("DefensiveStructure: Loading texture '\(textureName)', size: \(textureSize)")

        if let size {
            sprite.size = size
        } else if textureSize.width > 0, textureSize.height > 0 {
            sprite.size = textureSize
        } else {
            // Fallback size if texture failed to load
            sprite.size = CGSize(width: 48, height: 64)
            sprite.color = .cyan
            sprite.colorBlendFactor = 1.0
            print("DefensiveStructure: WARNING - Texture '\(textureName)' failed to load, using fallback")
        }
    }
}

// MARK: - Gun Tower

/// Armed tower that fires bullets at enemies
class GunTower: DefensiveStructure {
    // MARK: - Constants

    /// Resource cost to build this tower
    static let cost: Int = BuildConfig.TowerCosts.gunTower

    // MARK: - Properties

    /// The gun weapon
    let gun: Gun

    /// Callback when a bullet is fired (for adding to scene)
    var onFire: ((Projectile) -> Void)?

    /// Callback for bullet collision checking
    var onCheckCollision: ((Projectile) -> Character?)?

    // MARK: - Initialization

    init() {
        // Create gun with tower-specific settings
        self.gun = Gun(
            cooldownTime: 1.2,
            damage: 20,
            range: 500,
            bulletSpeed: 400,
            bulletTexture: "bullet"
        )

        super.init(name: "GunTower", maxHP: 600, attackRange: 500)

        // Track build cost for recoup calculation
        buildCost = GunTower.cost

        // Load tower texture
        loadTexture(named: "guntower", size: CGSize(width: 48, height: 64))

        // Set up weapon callbacks
        self.gun.onFire = { [weak self] projectile in
            self?.onFire?(projectile)
        }
    }

    // MARK: - Update

    override func update(deltaTime: TimeInterval) {
        // Update gun cooldown and projectiles
        self.gun.update(deltaTime: deltaTime)

        // Check bullet collisions
        for projectile in self.gun.activeBullets {
            if let hit = onCheckCollision?(projectile) {
                // Towers generate threat so enemies will retaliate
                if let enemy = hit as? Enemy {
                    enemy.takeDamage(projectile.damage, from: self)
                } else {
                    hit.takeDamage(projectile.damage)
                }
                projectile.hasCollision = true
                projectile.deactivate()
            }
        }

        super.update(deltaTime: deltaTime)
    }

    override func attackTarget(_ target: Enemy, deltaTime: TimeInterval) {
        // Try to fire at target
        self.gun.owner = self
        _ = self.gun.use(target: target.position)
    }
}

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

            // Check distance
            let dx = target.position.x - position.x
            let dy = target.position.y - position.y
            let distance = sqrt(dx * dx + dy * dy)

            // Heal if in range and not at full health
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

// MARK: - Laser Beam

/// Visual representation of a laser beam
class LaserBeam {
    /// The line node representing the beam
    let node: SKShapeNode

    /// Beam color
    var color: SKColor {
        didSet {
            self.node.strokeColor = self.color
        }
    }

    /// Beam thickness
    var thickness: CGFloat {
        didSet {
            self.node.lineWidth = self.thickness
        }
    }

    /// Whether the beam is currently active
    var isActive: Bool = false {
        didSet {
            self.node.isHidden = !self.isActive
        }
    }

    init(color: SKColor = .red, thickness: CGFloat = 3) {
        self.color = color
        self.thickness = thickness

        self.node = SKShapeNode()
        self.node.strokeColor = color
        self.node.lineWidth = thickness
        self.node.lineCap = .round
        self.node.zPosition = 50
        self.node.isHidden = true
    }

    /// Update the beam to fire from origin to target
    func fire(from origin: CGPoint, to target: CGPoint) {
        let path = CGMutablePath()
        path.move(to: origin)
        path.addLine(to: target)
        self.node.path = path
        self.isActive = true
    }

    /// Deactivate the beam
    func deactivate() {
        self.isActive = false
        self.node.path = nil
    }
}

// MARK: - Laser Tower

/// Armed tower that fires continuous laser beams at enemies
class LaserTower: DefensiveStructure {
    // MARK: - Constants

    /// Resource cost to build this tower
    static let cost: Int = BuildConfig.TowerCosts.laserTower

    // MARK: - Properties

    /// Damage per second while beam is active
    let damagePerSecond: Int = 20

    /// Cooldown between beam bursts
    let cooldownTime: TimeInterval = 3.5

    /// Duration of each beam burst
    let burstDuration: TimeInterval = 1.5

    /// Time elapsed in current cooldown
    private var cooldownElapsed: TimeInterval = 0

    /// Time elapsed in current burst
    private var burstElapsed: TimeInterval = 0

    /// Whether currently firing
    private(set) var isFiring: Bool = false

    /// The laser beam visual
    let beam: LaserBeam

    /// Sound played flag (to avoid repeating)
    private var hasPlayedSound: Bool = false

    // MARK: - Initialization

    init() {
        self.beam = LaserBeam(color: .red, thickness: 3)

        super.init(name: "LaserTower", maxHP: 600, attackRange: 350)

        // Track build cost for recoup calculation
        buildCost = LaserTower.cost

        // Load tower texture
        loadTexture(named: "lasertower", size: CGSize(width: 48, height: 64))
    }

    /// Called when adding to scene - adds beam node to scene
    func setupBeamNode(in scene: SKScene) {
        scene.addChild(self.beam.node)
    }

    // MARK: - Update

    override func update(deltaTime: TimeInterval) {
        guard isActive, isAlive else {
            self.beam.deactivate()
            return
        }

        // Update cooldown
        if !self.isFiring {
            self.cooldownElapsed += deltaTime
        }

        super.update(deltaTime: deltaTime)
    }

    override func attackTarget(_ target: Enemy, deltaTime: TimeInterval) {
        // Check if ready to fire
        if !self.isFiring, self.cooldownElapsed >= self.cooldownTime {
            // Start firing
            self.isFiring = true
            self.burstElapsed = 0
            self.cooldownElapsed = 0
            self.hasPlayedSound = false
        }

        if self.isFiring {
            self.burstElapsed += deltaTime

            // Play sound during burst (once)
            if !self.hasPlayedSound, self.burstElapsed > 0.1 {
                if let scene = sprite.scene {
                    AudioManager.shared.playSoundEffect(.laser, on: scene)
                }
                self.hasPlayedSound = true
            }

            // Update beam visual
            self.beam.fire(from: position, to: target.position)

            // Deal damage over time - towers generate threat so enemies retaliate
            let damage = Int(CGFloat(damagePerSecond) * CGFloat(deltaTime))
            if damage > 0 {
                // target is already Enemy, use threat-aware damage
                target.takeDamage(damage, from: self)
            }

            // Check if burst is over
            if self.burstElapsed >= self.burstDuration {
                self.isFiring = false
                self.beam.deactivate()
            }
        }
    }

    // MARK: - Death

    override func onDeath() {
        self.beam.deactivate()
        self.beam.node.removeFromParent()
        super.onDeath()
    }
}

// MARK: - Structure Manager Delegate

/// Delegate for structure manager events
protocol StructureManagerDelegate: AnyObject {
    /// Called when a Hermes-owned tower is destroyed by enemies
    /// - Parameters:
    ///   - manager: The structure manager
    ///   - remainingCount: Number of Hermes towers still standing
    ///   - potentialRecoup: New potential recoup amount
    func structureManager(
        _ manager: StructureManager,
        hermesTowerDestroyed remainingCount: Int,
        potentialRecoup: Int
    )
}

// MARK: - Structure Manager

/// Manages all defensive structures in the game
class StructureManager {
    // MARK: - Properties

    /// Delegate for tower destruction events
    weak var delegate: StructureManagerDelegate?

    /// All structures
    private(set) var structures: [DefensiveStructure] = []

    /// Towers owned by Hermes's current deployment
    private var hermesTowers: [DefensiveStructure] = []

    /// Reference to the scene
    weak var scene: SKScene?

    /// Enemy manager for finding targets
    weak var enemyManager: EnemyManager?

    /// Player characters for heal tower targeting
    var playerCharacters: [Character] = []

    /// Z position for structure sprites
    var structureZPosition: CGFloat = 100

    /// Scale for structure sprites
    var structureScale: CGFloat = 2.0

    /// Whether Hermes has any deployed towers
    var hasHermesTowers: Bool {
        !self.hermesTowers.isEmpty
    }

    /// Count of Hermes's deployed towers
    var hermesTowerCount: Int {
        self.hermesTowers.count
    }

    /// Calculate potential recoup if all surviving towers are released now
    /// Used by HUD to show preview on release button
    var potentialRecoupAmount: Int {
        self.hermesTowers.reduce(0) { total, tower in
            total + TowerConfig.calculateRecoup(for: tower.buildCost)
        }
    }

    // MARK: - Initialization

    init(scene: SKScene) {
        self.scene = scene
    }

    // MARK: - Structure Management

    /// Add a gun tower at the specified position
    func addGunTower(at position: CGPoint) -> GunTower {
        let tower = GunTower()
        self.setupStructure(tower, at: position)

        // Set up gun tower callbacks
        tower.onFire = { [weak self] projectile in
            guard let scene = self?.scene else { return }
            projectile.sprite.setScale(2.0)
            scene.addChild(projectile.sprite)
        }

        tower.onCheckCollision = { [weak self] projectile in
            return self?.enemyManager?.checkProjectileCollision(projectile)
        }

        tower.findNearestEnemy = { [weak self, weak tower] in
            guard let self, let tower else { return nil }
            // Use threat-based targeting: prioritize enemies attacking tower, then allies
            return self.findBestTarget(for: tower, range: tower.attackRange)
        }

        return tower
    }

    /// Add a heal tower at the specified position
    func addHealTower(at position: CGPoint) -> HealTower {
        let tower = HealTower()
        self.setupStructure(tower, at: position)

        // Set heal targets
        tower.healTargets = self.playerCharacters

        return tower
    }

    /// Add a laser tower at the specified position
    func addLaserTower(at position: CGPoint) -> LaserTower {
        let tower = LaserTower()
        self.setupStructure(tower, at: position)

        // Add beam node to scene
        if let scene {
            tower.setupBeamNode(in: scene)
        }

        tower.findNearestEnemy = { [weak self, weak tower] in
            guard let self, let tower else { return nil }
            // Use threat-based targeting: prioritize enemies attacking tower, then allies
            return self.findBestTarget(for: tower, range: tower.attackRange)
        }

        return tower
    }

    // MARK: - Hermes Tower Management

    /// Add a tower for Hermes at the specified position
    /// - Parameters:
    ///   - type: The type of tower to build
    ///   - position: Where to place the tower
    /// - Returns: The created tower
    @discardableResult
    func addHermesTower(type: TowerType, at position: CGPoint) -> DefensiveStructure {
        let tower: DefensiveStructure = switch type {
        case .gunTower:
            self.addGunTower(at: position)
        case .laserTower:
            self.addLaserTower(at: position)
        case .healTower:
            self.addHealTower(at: position)
        }

        // Track as Hermes tower
        self.hermesTowers.append(tower)

        print(
            "StructureManager: Added Hermes tower (\(type.displayName)), total Hermes towers: \(self.hermesTowerCount)"
        )

        return tower
    }

    /// Mark an existing tower as Hermes-owned (for restoring saved game)
    func markAsHermesOwned(_ tower: DefensiveStructure) {
        guard !self.hermesTowers.contains(where: { $0 === tower }) else { return }
        self.hermesTowers.append(tower)
    }

    /// Destroy all towers owned by Hermes and return 20% of their costs
    /// Called when releasing Hermes to move again
    /// - Parameters:
    ///   - camera: Camera for screen shake effects (optional)
    ///   - completion: Called when all towers are destroyed
    /// - Returns: Total resources recovered from surviving towers
    @discardableResult
    func destroyAllHermesTowers(camera: SKCameraNode? = nil, completion: (() -> Void)? = nil) -> Int {
        print("StructureManager: Destroying \(self.hermesTowerCount) Hermes towers with effects")

        guard let scene, !hermesTowers.isEmpty else {
            self.hermesTowers.removeAll()
            completion?()
            return 0
        }

        // Calculate recoup BEFORE destroying - only surviving towers count
        let recoupAmount = self.hermesTowers.reduce(0) { total, tower in
            total + TowerConfig.calculateRecoup(for: tower.buildCost)
        }

        // Add recoup to resources
        if recoupAmount > 0 {
            ResourceManager.shared.addResources(recoupAmount)
            print("StructureManager: Recouped \(recoupAmount) resources from \(self.hermesTowerCount) towers")

            // Show visual feedback at first tower's position
            if let firstTower = hermesTowers.first {
                self.showRecoupEffect(amount: recoupAmount, at: firstTower.position, in: scene)
            }
        }

        // Capture towers to destroy
        let towersToDestroy = self.hermesTowers

        // Clear the array immediately to prevent issues
        self.hermesTowers.removeAll()

        // Use staggered destruction for dramatic effect
        StaggeredDestruction.destroy(
            towers: towersToDestroy,
            in: scene,
            camera: camera,
            delayBetween: 0.12,
            completion: completion
        )

        return recoupAmount
    }

    /// Show floating text effect for resource recoup
    private func showRecoupEffect(amount: Int, at position: CGPoint, in scene: SKScene) {
        let label = SKLabelNode(text: "+\(amount)")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 24
        label.fontColor = SKColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 1.0) // Light green
        label.position = CGPoint(x: position.x, y: position.y + 40)
        label.zPosition = 500
        scene.addChild(label)

        // Float up and fade out
        let moveUp = SKAction.moveBy(x: 0, y: 60, duration: 1.2)
        moveUp.timingMode = .easeOut
        let fadeIn = SKAction.fadeIn(withDuration: 0.1)
        let wait = SKAction.wait(forDuration: 0.6)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let remove = SKAction.removeFromParent()

        let sequence = SKAction.sequence([
            fadeIn,
            SKAction.group([moveUp, SKAction.sequence([wait, fadeOut])]),
            remove,
        ])
        label.run(sequence)

        // Play collect sound
        AudioManager.shared.playSoundEffect(.collect, on: scene)
    }

    /// Destroy all towers immediately without effects (for cleanup/reset)
    func destroyAllHermesTowersImmediate() {
        print("StructureManager: Immediately destroying \(self.hermesTowerCount) Hermes towers")

        for tower in self.hermesTowers {
            tower.onDeath()
        }

        self.hermesTowers.removeAll()
    }

    /// Common setup for all structures
    private func setupStructure(_ structure: DefensiveStructure, at position: CGPoint) {
        structure.position = position
        structure.sprite.zPosition = self.structureZPosition

        // Start with zero scale for placement animation
        structure.sprite.setScale(0)

        // Set up health bar (scaled for smaller tower size)
        structure.setupHealthBar(width: 25, yOffset: 5)
        structure.healthBar?.hideWhenFull = false
        structure.healthBar?.node.alpha = 0 // Hide health bar during animation

        // Add destruction callback
        structure.onDestroyed = { [weak self, weak structure] in
            guard let structure else { return }
            self?.removeStructure(structure)
        }

        // Add to scene
        self.scene?.addChild(structure.sprite)
        self.structures.append(structure)

        // Play placement animation and sound
        self.playPlacementFeedback(for: structure)

        let pos = "(\(Int(position.x)), \(Int(position.y)))"
        print("StructureManager: Added \(structure.name) at \(pos), scale: \(self.structureScale)")
    }

    /// Play visual and audio feedback when a tower is placed
    private func playPlacementFeedback(for structure: DefensiveStructure) {
        guard let scene else { return }

        // Play placement sound
        AudioManager.shared.playSoundEffect(.collect, on: scene)

        // Scale-in animation with slight overshoot for "pop" effect
        let targetScale = self.structureScale
        let scaleUp = SKAction.scale(to: targetScale * 1.15, duration: 0.15)
        scaleUp.timingMode = .easeOut
        let scaleDown = SKAction.scale(to: targetScale, duration: 0.1)
        scaleDown.timingMode = .easeIn
        let scaleSequence = SKAction.sequence([scaleUp, scaleDown])

        // Brief white flash effect
        let flashWhite = SKAction.colorize(with: .white, colorBlendFactor: 0.6, duration: 0.1)
        let flashBack = SKAction.colorize(withColorBlendFactor: 0, duration: 0.15)
        let flashSequence = SKAction.sequence([flashWhite, flashBack])

        // Run animations together
        let animationGroup = SKAction.group([scaleSequence, flashSequence])

        // Fade in health bar after animation completes
        let showHealthBar = SKAction.run { [weak structure] in
            structure?.healthBar?.node.alpha = 1.0
        }

        structure.sprite.run(SKAction.sequence([animationGroup, showHealthBar]))
    }

    /// Remove a structure from the manager
    private func removeStructure(_ structure: DefensiveStructure) {
        if let index = structures.firstIndex(where: { $0 === structure }) {
            self.structures.remove(at: index)
        }
        // Also remove from Hermes towers if applicable
        if let hermesIndex = hermesTowers.firstIndex(where: { $0 === structure }) {
            self.hermesTowers.remove(at: hermesIndex)
            print("StructureManager: Hermes tower destroyed, remaining: \(self.hermesTowerCount)")

            // Notify delegate of tower destruction (for HUD updates)
            self.delegate?.structureManager(
                self,
                hermesTowerDestroyed: self.hermesTowerCount,
                potentialRecoup: self.potentialRecoupAmount
            )
        }
    }

    // MARK: - Update

    /// Update all structures
    func update(deltaTime: TimeInterval) {
        for structure in self.structures where structure.isActive {
            structure.update(deltaTime: deltaTime)
        }
    }

    // MARK: - Helpers

    /// Find the nearest enemy to a position within range (legacy - prefer findBestTarget)
    func findNearestEnemy(to position: CGPoint, range: CGFloat) -> Enemy? {
        guard let enemyManager else { return nil }

        var nearestEnemy: Enemy?
        var nearestDistance: CGFloat = range

        for enemy in enemyManager.enemies where enemy.isAlive {
            let dx = enemy.position.x - position.x
            let dy = enemy.position.y - position.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance < nearestDistance {
                nearestDistance = distance
                nearestEnemy = enemy
            }
        }

        return nearestEnemy
    }

    /// Find the best target for a tower using threat assessment
    /// Priority: 1) Enemies attacking this tower, 2) Enemies attacking allies, 3) Nearest enemy
    /// - Parameters:
    ///   - tower: The tower looking for a target
    ///   - range: Maximum range to search
    /// - Returns: The best enemy target, or nil if none in range
    func findBestTarget(for tower: DefensiveStructure, range: CGFloat) -> Enemy? {
        guard let enemyManager else { return nil }

        let enemies = enemyManager.aliveEnemies

        // Build allies list: tower itself (highest priority) + player characters
        // The tower is first so ThreatAssessment gives enemies attacking it the protectedAllyBonus
        var allies: [Character] = [tower]
        allies.append(contentsOf: self.playerCharacters)

        // Use supportive behavior so:
        // - Enemies attacking this tower (first ally) get protectedAllyBonus (+5.0)
        // - Enemies attacking Nathaniel/Hermes get aggroWeight (+3.0)
        // - Distance and low HP factors still apply
        return ThreatAssessment.findBestTarget(
            from: tower.position,
            enemies: enemies,
            allies: allies,
            behavior: .supportive,
            maxRange: range
        )
    }

    /// Get all active structures
    var activeStructures: [DefensiveStructure] {
        self.structures.filter(\.isActive)
    }

    /// Get count of active structures
    var count: Int {
        self.structures.count
    }

    /// Check if a position collides with any active structure
    /// - Parameters:
    ///   - position: World position to check
    ///   - radius: Collision radius of the entity checking (default 0)
    /// - Returns: true if position overlaps any structure
    func collidesWithStructure(at position: CGPoint, entityRadius: CGFloat = 0) -> Bool {
        for structure in self.structures where structure.isActive {
            let dx = position.x - structure.position.x
            let dy = position.y - structure.position.y
            let distance = hypot(dx, dy)

            // Use tower collision radius plus entity radius
            if distance < BuildConfig.towerCollisionRadius + entityRadius {
                return true
            }
        }
        return false
    }

    /// Clear all structures
    func clear() {
        for structure in self.structures {
            structure.sprite.removeFromParent()
        }
        self.structures.removeAll()
        self.hermesTowers.removeAll()
    }
}
