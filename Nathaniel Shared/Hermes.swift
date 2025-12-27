//
//  Hermes.swift
//  Nathaniel Shared
//
//  The robot companion character - Hermes.
//

import SpriteKit

/// Hermes operational modes - determines movement and ability behavior
enum HermesMode {
    /// Automatically follows Nathaniel
    case following
    /// Player controls Hermes directly (can place towers)
    case independent
    /// Towers deployed, cannot move
    case locked
}

/// The robot companion character class
class Hermes: Character {

    // MARK: - Constants (from legacy code)

    /// Starting/maximum health points
    static let defaultMaxHP = 2000

    /// Movement speed in points per second
    static let defaultSpeed: CGFloat = 40

    /// Weapon range in points
    static let weaponRange: CGFloat = 450

    /// Visible range (for targeting) in points
    static let visibleRange: CGFloat = 500

    // MARK: - Follow Behavior Constants

    /// Distance at which Hermes stops following (arrival zone)
    static let followStopDistance: CGFloat = 80

    /// Distance at which Hermes slows down (deceleration zone)
    static let followSlowDistance: CGFloat = 150

    /// Distance at which Hermes starts following
    static let followStartDistance: CGFloat = 200

    /// Distance at which Hermes teleports to catch up
    static let teleportDistance: CGFloat = 600

    /// Base speed when following at normal distance
    static let baseFollowSpeed: CGFloat = 45

    /// Speed when catching up from far behind
    static let catchUpSpeed: CGFloat = 100

    /// Formation offset - position relative to Nathaniel (behind and to the left)
    static let formationOffset = CGPoint(x: -50, y: -35)

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
            // Update visuals when mode changes
            if oldValue != mode {
                updateModeVisual()
            }
        }
    }

    /// Whether Hermes is in build mode (placing structures) - computed for backward compatibility
    var isInBuildMode: Bool {
        get { mode == .independent }
        set { mode = newValue ? .independent : .following }
    }

    /// Whether Hermes is locked (has deployed towers and cannot move) - computed for backward compatibility
    var isLocked: Bool {
        mode == .locked
    }

    /// Visual indicator node for locked state
    private var lockedIndicator: SKSpriteNode?

    /// Visual indicator node for follow state
    private var followIndicator: SKSpriteNode?

    /// Mode to restore after unlocking (nil if not locked)
    private var preLockMode: HermesMode?

    /// Build radius indicator circle
    private var buildRadiusIndicator: SKShapeNode?

    /// Whether to show build radius (when selected in build mode)
    var showBuildRadius: Bool = false {
        didSet {
            updateBuildRadiusVisual()
        }
    }

    /// The character Hermes should follow when not in build mode
    weak var followTarget: Character?

    /// Callback for when Hermes dies (for game over handling)
    var onDeathCallback: (() -> Void)?

    // MARK: - Initialization

    init() {
        super.init(
            name: "Hermes",
            maxHP: Hermes.defaultMaxHP,
            speed: Hermes.defaultSpeed,
            spriteSheetCols: Hermes.idleSheetCols,
            spriteSheetRows: Hermes.idleSheetRows
        )

        print("Hermes: Initializing...")

        // Load both sprite sheets
        loadIdleSpriteSheet()
        loadMovingSpriteSheet()

        print("Hermes: Sprite size after loading: \(sprite.size)")
        print("Hermes: Idle textures count: \(idleTextures.count)")
        print("Hermes: Moving textures count: \(movingTextures.count)")

        // Set initial facing direction
        facingDirection = .south

        // Start in independent mode (legacy build mode behavior)
        mode = .independent
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

        let frameWidth = textureSize.width / CGFloat(Hermes.idleSheetCols)
        let frameHeight = textureSize.height / CGFloat(Hermes.idleSheetRows)
        print("Hermes: Idle frame size: \(frameWidth) x \(frameHeight)")

        // Configure sprite size based on a single frame
        sprite.size = CGSize(width: frameWidth, height: frameHeight)

        // Slice the idle sprite sheet into individual textures
        idleTextures = []
        for col in 0..<Hermes.idleSheetCols {
            let x = CGFloat(col) / CGFloat(Hermes.idleSheetCols)
            let w = 1.0 / CGFloat(Hermes.idleSheetCols)

            let rect = CGRect(x: x, y: 0, width: w, height: 1.0)
            let frameTexture = SKTexture(rect: rect, in: texture)
            frameTexture.filteringMode = .nearest
            idleTextures.append(frameTexture)
        }

        // Set initial texture
        if !idleTextures.isEmpty {
            sprite.texture = idleTextures[0]
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
        movingTextures = []
        for col in 0..<Hermes.movingSheetCols {
            let x = CGFloat(col) / CGFloat(Hermes.movingSheetCols)
            let w = 1.0 / CGFloat(Hermes.movingSheetCols)

            let rect = CGRect(x: x, y: 0, width: w, height: 1.0)
            let frameTexture = SKTexture(rect: rect, in: texture)
            frameTexture.filteringMode = .nearest
            movingTextures.append(frameTexture)
        }
    }

    // MARK: - Texture Updates

    /// Override to use Hermes-specific sprite sheets
    override func updateTexture() {
        if isMoving && !movingTextures.isEmpty {
            // Use moving sprite based on direction
            // Legacy mapping: direction -> moving frame index
            let movingIndex = movingTextureIndex(for: facingDirection)
            sprite.texture = movingTextures[movingIndex]
        } else if !idleTextures.isEmpty {
            // Use idle sprite based on direction
            let idleIndex = idleTextureIndex(for: facingDirection)
            sprite.texture = idleTextures[idleIndex]
        }
    }

    /// Map facing direction to idle texture index
    /// Legacy mapping from UpdateState():
    /// South=0, SouthWest=1, North=2, West=3, SouthEast=4, NorthEast=5, East=6, NorthWest=7
    private func idleTextureIndex(for direction: FacingDirection) -> Int {
        return direction.rawValue
    }

    /// Map facing direction to moving texture index
    /// Legacy mapping:
    /// North/South -> 1, SouthEast -> 2, NorthEast/East -> 3, NorthWest/West -> 4, SouthWest -> 0
    private func movingTextureIndex(for direction: FacingDirection) -> Int {
        switch direction {
        case .north, .south:
            return 1
        case .southEast:
            return 2
        case .northEast, .east:
            return 3
        case .northWest, .west:
            return 4
        case .southWest:
            return 0
        }
    }

    // MARK: - Update

    override func update(deltaTime: TimeInterval) {
        #if DEBUG
        // Apply dev settings for live updates
        speed = DevSettings.shared.hermesSpeed
        #endif

        // Handle follow behavior only in following mode
        if mode == .following, let target = followTarget {
            updateFollowBehavior(target: target)
        }

        super.update(deltaTime: deltaTime)
    }

    /// Override takeDamage to support invincibility setting
    override func takeDamage(_ amount: Int) {
        #if DEBUG
        if DevSettings.shared.playerInvincible {
            return  // Ignore damage when invincible
        }
        #endif
        super.takeDamage(amount)
    }

    /// Update follow behavior with formation offset, speed zones, and smooth movement
    private func updateFollowBehavior(target: Character) {
        // Calculate target position with formation offset
        // Offset is relative to target's facing direction
        let targetPos = calculateFormationPosition(for: target)

        let dx = targetPos.x - position.x
        let dy = targetPos.y - position.y
        let distance = sqrt(dx * dx + dy * dy)

        // Teleport if too far behind
        if distance > Hermes.teleportDistance {
            teleportToFormation(target: target)
            return
        }

        // Determine behavior based on distance zones
        if distance <= Hermes.followStopDistance {
            // Arrival zone - stop and match target's facing direction
            destination = nil
            speed = Hermes.defaultSpeed

            // Face the same direction as the target when idle
            if !target.isMoving {
                facingDirection = target.facingDirection
            }
        } else if distance <= Hermes.followSlowDistance {
            // Deceleration zone - slow approach
            destination = targetPos
            // Smoothly reduce speed as we get closer
            let t = (distance - Hermes.followStopDistance) / (Hermes.followSlowDistance - Hermes.followStopDistance)
            speed = Hermes.defaultSpeed + (Hermes.baseFollowSpeed - Hermes.defaultSpeed) * t
        } else if distance <= Hermes.followStartDistance {
            // Normal follow zone
            destination = targetPos
            speed = Hermes.baseFollowSpeed
        } else {
            // Catch-up zone - move faster to close the gap
            destination = targetPos
            // Interpolate speed based on distance (faster when further)
            let catchUpT = min(1.0, (distance - Hermes.followStartDistance) / (Hermes.teleportDistance - Hermes.followStartDistance))
            speed = Hermes.baseFollowSpeed + (Hermes.catchUpSpeed - Hermes.baseFollowSpeed) * catchUpT
        }
    }

    /// Calculate the formation position relative to the target
    private func calculateFormationPosition(for target: Character) -> CGPoint {
        // Rotate the formation offset based on target's facing direction
        let offset = Hermes.formationOffset
        let angle = facingAngle(for: target.facingDirection)

        // Rotate offset by the facing angle
        let cos_a = cos(angle)
        let sin_a = sin(angle)
        let rotatedX = offset.x * cos_a - offset.y * sin_a
        let rotatedY = offset.x * sin_a + offset.y * cos_a

        return CGPoint(
            x: target.position.x + rotatedX,
            y: target.position.y + rotatedY
        )
    }

    /// Convert facing direction to angle in radians
    private func facingAngle(for direction: FacingDirection) -> CGFloat {
        switch direction {
        case .south: return 0
        case .southWest: return .pi * 0.25
        case .west: return .pi * 0.5
        case .northWest: return .pi * 0.75
        case .north: return .pi
        case .northEast: return .pi * 1.25
        case .east: return .pi * 1.5
        case .southEast: return .pi * 1.75
        }
    }

    /// Teleport Hermes to formation position when too far behind
    private func teleportToFormation(target: Character) {
        let targetPos = calculateFormationPosition(for: target)
        position = targetPos
        destination = nil
        facingDirection = target.facingDirection
        speed = Hermes.defaultSpeed
        print("Hermes: Teleported to formation (was too far behind)")
    }

    // MARK: - Overrides

    override func onDeath() {
        super.onDeath()
        onDeathCallback?()
    }

    // MARK: - Respawn

    /// Respawn Hermes at a given position with full health
    func respawn(at position: CGPoint) {
        self.position = position
        self.currentHP = maxHP
        self.destination = nil
        self.facingDirection = .south
        self.animationState = .idle
        self.isActive = true
        updateTexture()
    }

    // MARK: - Mode Control

    /// Toggle between following and independent modes
    func toggleMode() {
        guard mode != .locked else { return }  // Can't toggle while locked
        mode = (mode == .following) ? .independent : .following
    }

    /// Toggle build mode on/off (backward compatible alias for toggleMode)
    func toggleBuildMode() {
        toggleMode()
    }

    /// Enter independent mode (stop following, allow tower placement)
    func enterBuildMode() {
        guard mode != .locked else { return }
        mode = .independent
        stop()
    }

    /// Exit build mode (resume following)
    func exitBuildMode() {
        guard mode != .locked else { return }
        mode = .following
    }

    /// Enter following mode
    func enterFollowMode() {
        guard mode != .locked else { return }
        mode = .following
    }

    /// Enter independent mode (player controls directly)
    func enterIndependentMode() {
        guard mode != .locked else { return }
        mode = .independent
    }

    // MARK: - Locked State (Tower Deployment)

    /// Lock Hermes when towers are deployed
    /// Prevents all movement until towers are released
    func lock() {
        guard mode != .locked else { return }
        preLockMode = mode  // Remember current mode
        mode = .locked
        destination = nil  // Stop any current movement
        print("Hermes: Locked - towers deployed")
    }

    /// Unlock Hermes when towers are destroyed/released
    /// Allows movement again, restoring previous mode
    func unlock() {
        guard mode == .locked else { return }
        mode = preLockMode ?? .independent  // Restore previous mode
        preLockMode = nil
        print("Hermes: Unlocked - can move again")
    }

    /// Override destination to prevent movement when locked
    override var destination: CGPoint? {
        get { super.destination }
        set {
            if mode == .locked {
                // Reject movement commands when locked
                return
            }
            super.destination = newValue
        }
    }

    /// Update visual indicators based on current mode
    private func updateModeVisual() {
        switch mode {
        case .locked:
            // Show locked indicator (anchor-like symbol)
            showLockedIndicator()
            hideFollowIndicator()
            sprite.color = .yellow
            sprite.colorBlendFactor = 0.15

        case .following:
            // Show follow indicator (chain link)
            hideLockedIndicator()
            showFollowIndicator()
            sprite.color = .cyan
            sprite.colorBlendFactor = 0.12

        case .independent:
            // No indicators, no tint
            hideLockedIndicator()
            hideFollowIndicator()
            sprite.colorBlendFactor = 0
        }
    }

    /// Show the locked state indicator
    private func showLockedIndicator() {
        if lockedIndicator == nil {
            let indicator = SKSpriteNode(color: .clear, size: CGSize(width: 24, height: 24))

            // Create an anchor shape using a shape node
            let anchorShape = SKShapeNode()
            let path = CGMutablePath()
            // Simple anchor shape: circle with line down
            path.addEllipse(in: CGRect(x: -6, y: 2, width: 12, height: 12))
            path.move(to: CGPoint(x: 0, y: 2))
            path.addLine(to: CGPoint(x: 0, y: -10))
            path.move(to: CGPoint(x: -6, y: -6))
            path.addLine(to: CGPoint(x: 6, y: -6))
            anchorShape.path = path
            anchorShape.strokeColor = .yellow
            anchorShape.lineWidth = 2
            anchorShape.zPosition = 1

            indicator.addChild(anchorShape)
            indicator.position = CGPoint(x: 0, y: sprite.size.height / 2 + 16)
            indicator.zPosition = 200
            sprite.addChild(indicator)
            lockedIndicator = indicator

            // Pulse animation
            let scaleUp = SKAction.scale(to: 1.2, duration: 0.5)
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.5)
            let pulse = SKAction.sequence([scaleUp, scaleDown])
            indicator.run(SKAction.repeatForever(pulse))
        }
        lockedIndicator?.isHidden = false
    }

    /// Hide the locked state indicator
    private func hideLockedIndicator() {
        lockedIndicator?.isHidden = true
    }

    /// Show the follow state indicator (chain link above head)
    private func showFollowIndicator() {
        if followIndicator == nil {
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
            followIndicator = indicator

            // Gentle bob animation
            let moveUp = SKAction.moveBy(x: 0, y: 3, duration: 0.6)
            let moveDown = SKAction.moveBy(x: 0, y: -3, duration: 0.6)
            moveUp.timingMode = .easeInEaseOut
            moveDown.timingMode = .easeInEaseOut
            let bob = SKAction.sequence([moveUp, moveDown])
            indicator.run(SKAction.repeatForever(bob))
        }
        followIndicator?.isHidden = false
    }

    /// Hide the follow state indicator
    private func hideFollowIndicator() {
        followIndicator?.isHidden = true
    }

    // MARK: - Build Radius Visual

    /// Update the build radius indicator
    private func updateBuildRadiusVisual() {
        if showBuildRadius {
            // Create build radius circle if needed
            if buildRadiusIndicator == nil {
                let radius = TowerConfig.buildRadius
                let circle = SKShapeNode(circleOfRadius: radius)
                circle.strokeColor = SKColor.cyan.withAlphaComponent(0.5)
                circle.fillColor = SKColor.cyan.withAlphaComponent(0.05)
                circle.lineWidth = 2
                circle.glowWidth = 1
                circle.zPosition = -1  // Below Hermes sprite

                // Add dashed line effect
                let pattern: [CGFloat] = [10, 5]
                let path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)
                circle.path = path.copy(dashingWithPhase: 0, lengths: pattern)

                sprite.addChild(circle)
                buildRadiusIndicator = circle

                // Subtle rotation animation
                let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 20)
                circle.run(SKAction.repeatForever(rotate))
            }
            buildRadiusIndicator?.isHidden = false
        } else {
            // Hide build radius
            buildRadiusIndicator?.isHidden = true
        }
        // Note: Color tint is now handled by updateModeVisual()
    }

    /// Add a selection highlight ring (called externally when Hermes is selected)
    func showSelectionHighlight() {
        // The build radius indicator serves as the selection highlight in build mode
        if isInBuildMode {
            showBuildRadius = true
        }
    }

    /// Remove selection highlight
    func hideSelectionHighlight() {
        showBuildRadius = false
    }
}
