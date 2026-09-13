//
//  Hermes.swift
//  Nathaniel Shared
//
//  Controls the stationary builder and following robot companion.
//

import SpriteKit

/// Hermes operational modes - determines movement and ability behavior
enum HermesMode {
    /// Automatically follows Nathaniel
    case following
    /// Hermes stays in place and can build towers
    case independent
}

/// The robot companion character class
class Hermes: Character {
    // MARK: - Constants

    /// Starting/maximum health points
    static var defaultMaxHP: Int {
        GameBalance.Hermes.maxHP
    }

    /// Movement speed in points per second
    static var defaultSpeed: CGFloat {
        GameBalance.Hermes.speed
    }

    /// Weapon range in points.
    static var weaponRange: CGFloat {
        GameBalance.Hermes.weaponRange
    }

    /// Visible range for targeting in points.
    static var visibleRange: CGFloat {
        GameBalance.Hermes.visionRange
    }

    // MARK: - Laser Weapon Constants

    /// Damage per second while the laser is active.
    static var laserDPS: Int {
        GameBalance.Hermes.laserDPS
    }

    /// Duration of each laser burst
    static var laserBurstDuration: TimeInterval {
        GameBalance.Hermes.laserBurstDuration
    }

    /// Cooldown between laser bursts
    static var laserCooldownTime: TimeInterval {
        GameBalance.Hermes.laserCooldown
    }

    // MARK: - Follow Behavior Constants

    /// Distance at which Hermes stops following (arrival zone)
    static var followStopDistance: CGFloat {
        GameBalance.Hermes.followStopDistance
    }

    // MARK: - Sprite Sheet Configuration

    /// Idle sprite sheet has 8 columns (directions) x 1 row
    private static let idleSheetCols = 8
    private static let idleSheetRows = 1

    /// Moving sprite sheet has 5 columns x 1 row
    private static let movingSheetCols = 5
    private static let movingSheetRows = 1

    // MARK: - Properties

    /// Textures for idle state (8 directions)
    private var idleTextures: [SKTexture] = []

    /// Textures for moving state (5 frames, mapped to directions)
    private var movingTextures: [SKTexture] = []

    /// Current operational mode
    var mode: HermesMode = .independent {
        didSet {
            if oldValue != self.mode {
                stop()
                self.followDestination = nil
                self.updateModeVisual()
            }
        }
    }

    /// Whether Hermes is in build mode (placing structures) - computed for backward compatibility
    var isInBuildMode: Bool {
        get { self.mode == .independent }
        set { self.mode = newValue ? .independent : .following }
    }

    private var followIndicator: SKSpriteNode?
    private var selectionIndicator: SKShapeNode?
    private var followDestination: CGPoint?

    /// The character Hermes should follow when not in build mode
    weak var followTarget: Character?

    /// Callback for when Hermes dies (for game over handling)
    var onDeathCallback: (() -> Void)?

    // MARK: - Combat Properties

    /// The laser beam visual
    let laser: LaserBeam

    /// Whether currently firing the laser
    private(set) var isFiring: Bool = false {
        didSet {
            if oldValue != self.isFiring {
                self.updateCombatGlow()
            }
        }
    }

    /// Time elapsed in current laser burst
    private var burstElapsed: TimeInterval = 0

    /// Time elapsed in current cooldown
    private var cooldownElapsed: TimeInterval = 0

    /// Fractional damage carried between frames while the laser is firing.
    private var pendingLaserDamage: Double = 0

    /// Whether laser sound has been played this burst
    private var hasPlayedLaserSound: Bool = false

    /// Unified targeting component
    let targeting: TargetingComponent

    /// Current target for combat (delegates to targeting component)
    var currentTarget: Character? {
        self.targeting.currentTarget
    }

    // MARK: - Combat Visual Properties

    /// Visual indicator showing Hermes's current target (cyan ring)
    private var targetIndicator: TargetIndicator?

    /// Glow effect shown when Hermes is actively firing
    private var combatGlow: SKShapeNode?

    // MARK: - Initialization

    init() {
        // Initialize laser before super.init (required for let property)
        self.laser = LaserBeam(color: .purple, thickness: 4)

        // Initialize targeting component with default supportive behavior
        self.targeting = TargetingComponent(
            behavior: .supportive,
            attackRange: Hermes.weaponRange,
            visionRange: Hermes.visibleRange
        )

        super.init(
            name: "Hermes",
            maxHP: Hermes.defaultMaxHP,
            speed: Hermes.defaultSpeed,
            spriteSheetCols: Hermes.idleSheetCols,
            spriteSheetRows: Hermes.idleSheetRows
        )

        // Set vision range to match static constant
        visionRange = Hermes.visibleRange

        // Wire up targeting callbacks
        self.targeting.onTargetChanged = { [weak self] _ in
            self?.updateTargetIndicator()
        }

        print("Hermes: Initializing...")

        // Load both sprite sheets
        self.loadIdleSpriteSheet()
        self.loadMovingSpriteSheet()

        print("Hermes: Sprite size after loading: \(sprite.size)")
        print("Hermes: Idle textures count: \(self.idleTextures.count)")
        print("Hermes: Moving textures count: \(self.movingTextures.count)")

        // Set initial facing direction
        facingDirection = .south

        // Start in independent mode (legacy build mode behavior)
        self.mode = .independent
    }

    /// Set up the laser beam node in a scene (call after adding Hermes to scene)
    func setupLaserNode(in scene: SKScene) {
        scene.addChild(self.laser.node)
    }

    // MARK: - Texture Loading

    /// Load the idle sprite sheet (8 directions)
    private func loadIdleSpriteSheet() {
        print("Hermes: Loading idle sprite sheet...")

        let texture = SKTexture(imageNamed: "hermesidlespritesheet")
        texture.filteringMode = .nearest

        let textureSize = texture.size()
        print("Hermes: Idle texture size: \(textureSize)")

        guard textureSize.width > 0, textureSize.height > 0 else {
            print("Hermes: ERROR - Failed to load idle sprite sheet - size is zero")
            sprite.color = .purple
            sprite.size = CGSize(width: 32, height: 48)
            return
        }

        // Original body dimensions on the 800 × 480 playfield.
        sprite.size = CGSize(width: 80, height: 72)

        // Slice the idle sprite sheet into individual textures
        self.idleTextures = []
        for col in 0 ..< Hermes.idleSheetCols {
            let x = CGFloat(col) / CGFloat(Hermes.idleSheetCols)
            let w = 1.0 / CGFloat(Hermes.idleSheetCols)

            let rect = CGRect(x: x, y: 0, width: w, height: 1.0)
            let frameTexture = SKTexture(rect: rect, in: texture)
            frameTexture.filteringMode = .nearest
            self.idleTextures.append(frameTexture)
        }

        // Set initial texture
        if !self.idleTextures.isEmpty {
            sprite.texture = self.idleTextures[0]
        }
    }

    /// Load the moving sprite sheet (5 frames for animation)
    private func loadMovingSpriteSheet() {
        print("Hermes: Loading moving sprite sheet...")

        let texture = SKTexture(imageNamed: "hermesmovingspritesheet")
        texture.filteringMode = .nearest

        let textureSize = texture.size()
        print("Hermes: Moving texture size: \(textureSize)")

        guard textureSize.width > 0, textureSize.height > 0 else {
            print("Hermes: ERROR - Failed to load moving sprite sheet")
            return
        }

        // Slice the moving sprite sheet into individual textures
        self.movingTextures = []
        for col in 0 ..< Hermes.movingSheetCols {
            let x = CGFloat(col) / CGFloat(Hermes.movingSheetCols)
            let w = 1.0 / CGFloat(Hermes.movingSheetCols)

            let rect = CGRect(x: x, y: 0, width: w, height: 1.0)
            let frameTexture = SKTexture(rect: rect, in: texture)
            frameTexture.filteringMode = .nearest
            self.movingTextures.append(frameTexture)
        }
    }

    // MARK: - Texture Updates

    /// Override to use Hermes-specific sprite sheets
    override func updateTexture() {
        if isMoving, !self.movingTextures.isEmpty {
            // Use moving sprite based on direction
            // Legacy mapping: direction -> moving frame index
            let movingIndex = self.movingTextureIndex(for: facingDirection)
            sprite.texture = self.movingTextures[movingIndex]
        } else if !self.idleTextures.isEmpty {
            // Use idle sprite based on direction
            let idleIndex = self.idleTextureIndex(for: facingDirection)
            sprite.texture = self.idleTextures[idleIndex]
        }
    }

    /// Map facing direction to idle texture index
    /// Legacy mapping from UpdateState():
    /// South=0, SouthWest=1, North=2, West=3, SouthEast=4, NorthEast=5, East=6, NorthWest=7
    private func idleTextureIndex(for direction: FacingDirection) -> Int {
        direction.rawValue
    }

    /// Map facing direction to moving texture index
    /// Legacy mapping:
    /// North/South -> 1, SouthEast -> 2, NorthEast/East -> 3, NorthWest/West -> 4, SouthWest -> 0
    private func movingTextureIndex(for direction: FacingDirection) -> Int {
        switch direction {
        case .north, .south:
            1
        case .southEast:
            2
        case .northEast, .east:
            3
        case .northWest, .west:
            4
        case .southWest:
            0
        }
    }

    // MARK: - Update

    override func update(deltaTime: TimeInterval) {
        #if DEBUG
            // Apply dev settings for live updates
            speed = DevSettings.shared.hermesSpeed
        #endif

        // Handle follow behavior only in following mode
        if self.mode == .following, let target = followTarget, target.isAlive {
            self.updateFollowBehavior(target: target)
        } else {
            stop()
        }

        // Update combat (targeting and laser)
        self.updateCombat(deltaTime: deltaTime)

        // Update target indicator position to follow target
        self.targetIndicator?.updatePosition()

        super.update(deltaTime: deltaTime)
    }

    /// Override takeDamage to support invincibility setting
    override func takeDamage(_ amount: Int) {
        #if DEBUG
            if DevSettings.shared.playerInvincible {
                return // Ignore damage when invincible
            }
        #endif
        super.takeDamage(amount)
    }

    // MARK: - Combat

    /// Update combat state including targeting and laser firing
    func updateCombat(deltaTime: TimeInterval) {
        guard isActive, isAlive else {
            // Deactivate laser if not able to fight
            self.laser.deactivate()
            self.isFiring = false
            return
        }

        // Update cooldown
        if !self.isFiring {
            self.cooldownElapsed += deltaTime
        }

        // Set targeting behavior based on mode
        self.targeting.behavior = switch self.mode {
        case .following:
            .supportive // Prioritize enemies attacking Nathaniel
        case .independent:
            .aggressive // Attack anything in range
        }

        // Update targeting via component
        self.targeting.update(position: position, isActive: isActive && isAlive)

        // Attack current target if we have one
        if let target = currentTarget, target.isAlive {
            self.attackTarget(target, deltaTime: deltaTime)
        } else {
            // No valid target - deactivate laser
            if self.isFiring {
                self.isFiring = false
                self.laser.deactivate()
            }
        }
    }

    /// Attack the current target with laser
    private func attackTarget(_ target: Character, deltaTime: TimeInterval) {
        // Check distance - must be in weapon range to fire
        let dx = target.position.x - position.x
        let dy = target.position.y - position.y
        let distance = position.distance(to: target.position)

        guard distance <= Hermes.weaponRange else {
            // Target out of weapon range - stop firing (but keep targeting)
            if self.isFiring {
                self.isFiring = false
                self.laser.deactivate()
            }
            return
        }

        // Face the target
        let direction = CGVector(dx: dx, dy: dy)
        facingDirection = FacingDirection.from(direction: direction)

        // Check if ready to fire
        if !self.isFiring, self.cooldownElapsed >= Hermes.laserCooldownTime {
            // Start firing
            self.isFiring = true
            self.burstElapsed = 0
            self.cooldownElapsed = 0
            self.hasPlayedLaserSound = false
        }

        if self.isFiring {
            let activeDuration = min(deltaTime, max(0, Hermes.laserBurstDuration - self.burstElapsed))
            self.burstElapsed += activeDuration

            // Play sound during burst (once)
            if !self.hasPlayedLaserSound, self.burstElapsed > 0.1 {
                if let scene = sprite.scene {
                    AudioManager.shared.playSoundEffect(.laser, on: scene)
                }
                self.hasPlayedLaserSound = true
            }

            // Update beam visual - fire from Hermes position to target
            self.laser.fire(from: position, to: target.position)

            // Deal damage over time
            self.pendingLaserDamage += Double(Hermes.laserDPS) * activeDuration
            let damage = Int(self.pendingLaserDamage)
            self.pendingLaserDamage -= Double(damage)
            if damage > 0 {
                // Use threat-aware damage if target is an enemy
                if let enemy = target as? Enemy {
                    enemy.takeDamage(damage, from: self)
                } else {
                    target.takeDamage(damage)
                }
            }

            // Check if burst is over
            if self.burstElapsed >= Hermes.laserBurstDuration {
                self.isFiring = false
                self.laser.deactivate()
            }
        }
    }

    /// Set a manual target (called when player taps an enemy while Hermes is selected)
    func setManualTarget(_ target: Enemy?) {
        self.targeting.setManualTarget(target)
    }

    /// Clear manual target (called when player taps ground or deselects Hermes)
    func clearManualTarget() {
        self.targeting.clearManualTarget()
    }

    /// Get current attack range (for CombatCapable)
    var attackRange: CGFloat {
        Hermes.weaponRange
    }

    /// Follow Nathaniel at the original speed and stop within 100 points.
    private func updateFollowBehavior(target: Character) {
        guard position.distance(to: target.position) > Hermes.followStopDistance else {
            stop()
            return
        }

        // Keep the current path until Nathaniel has moved beyond the arrival distance.
        let targetMoved = self.followDestination.map {
            $0.distance(to: target.position) > Hermes.followStopDistance
        } ?? true
        if !isMoving || targetMoved {
            self.followDestination = target.position
            super.moveTo(target.position)
        }
    }

    // MARK: - Overrides

    override func onDeath() {
        // Deactivate laser and clear combat state
        self.laser.deactivate()
        self.isFiring = false
        self.targeting.clearAll()

        super.onDeath()
        self.onDeathCallback?()
    }

    // MARK: - Respawn

    /// Respawn Hermes at a given position with full health
    func respawn(at position: CGPoint) {
        self.position = position
        self.currentHP = maxHP
        self.destination = nil
        self.facingDirection = .south

        // Reset combat state
        self.targeting.clearAll()
        self.isFiring = false
        self.laser.deactivate()
        self.cooldownElapsed = 0
        self.pendingLaserDamage = 0
        self.animationState = .idle
        self.isActive = true
        self.updateTexture()
    }

    // MARK: - Mode Control

    func toggleMode() {
        self.mode = self.mode == .following ? .independent : .following
    }

    func toggleBuildMode() {
        self.toggleMode()
    }

    /// Stop Hermes so the player can place towers.
    func enterBuildMode() {
        self.mode = .independent
        stop()
    }

    func exitBuildMode() {
        self.mode = .following
    }

    func enterFollowMode() {
        self.mode = .following
    }

    /// Retained for saved games and command clients: independent means stationary building.
    func enterIndependentMode() {
        self.enterBuildMode()
    }

    /// Hermes moves only by following Nathaniel, never by a direct move command.
    override var destination: CGPoint? {
        get { super.destination }
        set {
            if newValue == nil {
                stop()
            }
        }
    }

    override func moveTo(_ point: CGPoint) {}

    private func updateModeVisual() {
        if self.mode == .following {
            self.showFollowIndicator()
            sprite.color = .cyan
            sprite.colorBlendFactor = 0.12
        } else {
            self.hideFollowIndicator()
            sprite.colorBlendFactor = 0
        }
    }

    /// Show the follow state indicator (chain link above head)
    private func showFollowIndicator() {
        if self.followIndicator == nil {
            let indicator = SKSpriteNode(color: .clear, size: CGSize(width: 24, height: 24))

            // Create a chain link shape
            let linkShape = SKShapeNode()
            let path = CGMutablePath()
            // Two interlocking ovals for chain link
            path.addEllipse(in: CGRect(x: -8, y: -2, width: 10, height: 8))
            path.addEllipse(in: CGRect(x: -2, y: -2, width: 10, height: 8))
            linkShape.path = path
            linkShape.strokeColor = .cyan
            linkShape.lineWidth = 2
            linkShape.zPosition = 1

            indicator.addChild(linkShape)
            indicator.position = CGPoint(x: 0, y: sprite.size.height / 2 + 16)
            indicator.zPosition = 200
            sprite.addChild(indicator)
            self.followIndicator = indicator

            // Gentle bob animation
            let moveUp = SKAction.moveBy(x: 0, y: 3, duration: 0.6)
            let moveDown = SKAction.moveBy(x: 0, y: -3, duration: 0.6)
            moveUp.timingMode = .easeInEaseOut
            moveDown.timingMode = .easeInEaseOut
            let bob = SKAction.sequence([moveUp, moveDown])
            indicator.run(SKAction.repeatForever(bob))
        }
        self.followIndicator?.isHidden = false
    }

    /// Hide the follow state indicator
    private func hideFollowIndicator() {
        self.followIndicator?.isHidden = true
    }

    // MARK: - Combat Visual Feedback

    /// Update the target indicator when current target changes
    private func updateTargetIndicator() {
        // Remove existing indicator
        self.targetIndicator?.remove()
        self.targetIndicator = nil

        // Create new indicator for current target
        guard let target = self.currentTarget,
              let scene = sprite.scene
        else {
            return
        }

        // Create cyan indicator for Hermes's target
        self.targetIndicator = TargetIndicator.createCyan(for: target.sprite, in: scene)
    }

    /// Update combat glow effect based on firing state
    private func updateCombatGlow() {
        if self.isFiring {
            self.showCombatGlow()
        } else {
            self.hideCombatGlow()
        }
    }

    /// Show the combat glow effect (cyan glow around Hermes when firing)
    private func showCombatGlow() {
        if self.combatGlow == nil {
            // Create a subtle glow circle around Hermes
            let glowRadius: CGFloat = 35
            let glow = SKShapeNode(circleOfRadius: glowRadius)
            glow.strokeColor = .clear
            glow.fillColor = SKColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.2)
            glow.glowWidth = 8
            glow.zPosition = -1 // Behind sprite

            sprite.addChild(glow)
            self.combatGlow = glow
        }

        // Fade in the glow
        self.combatGlow?.alpha = 0
        self.combatGlow?.isHidden = false
        self.combatGlow?.run(SKAction.fadeAlpha(to: 1.0, duration: 0.1))

        // Add pulsing effect while firing
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.15),
            SKAction.scale(to: 1.0, duration: 0.15),
        ])
        self.combatGlow?.run(SKAction.repeatForever(pulse), withKey: "combatPulse")
    }

    /// Hide the combat glow effect
    private func hideCombatGlow() {
        self.combatGlow?.removeAction(forKey: "combatPulse")
        self.combatGlow?.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.run { [weak self] in
                self?.combatGlow?.isHidden = true
            },
        ]))
    }

    // MARK: - Selection

    func showSelectionHighlight() {
        if self.selectionIndicator == nil {
            let circle = SKShapeNode(circleOfRadius: sprite.size.width * 0.6)
            circle.strokeColor = .cyan
            circle.fillColor = .clear
            circle.lineWidth = 2
            circle.zPosition = -1
            sprite.addChild(circle)
            self.selectionIndicator = circle
        }
        self.selectionIndicator?.isHidden = false
    }

    func hideSelectionHighlight() {
        self.selectionIndicator?.isHidden = true
    }
}
