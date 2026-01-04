import SpriteKit

// MARK: - Collection State

/// State of a resource's collection lifecycle
enum ResourceCollectionState {
    case idle // Sitting on ground, pulsing
    case collecting // Flying toward a collector
    case collected // Has been collected (will be removed)
}

// MARK: - Resource

/// A collectible resource dropped by enemies when destroyed
class Resource: GameEntity {
    // MARK: - Constants

    /// How long resources last before expiring (seconds)
    static var defaultExpirationTime: TimeInterval { GameBalance.Resources.expirationTime }

    /// Time before expiration when the resource starts warning (flashing)
    static var expirationWarningTime: TimeInterval { GameBalance.Resources.warningTime }

    /// Radius within which resources auto-collect to players
    static var autoCollectRadius: CGFloat { GameBalance.Resources.autoCollectRadius }

    /// Speed at which resources fly toward collector
    static var collectSpeed: CGFloat { GameBalance.Resources.collectSpeed }

    /// Pulse animation duration
    static var pulseDuration: TimeInterval { GameBalance.Resources.pulseDuration }

    /// Float animation height
    static var floatHeight: CGFloat { GameBalance.Resources.floatHeight }

    // MARK: - GameEntity Properties

    let sprite: SKSpriteNode

    var position: CGPoint {
        get { self.sprite.position }
        set { self.sprite.position = newValue }
    }

    var isActive: Bool = true

    // MARK: - Resource Properties

    /// The amount of resource value this drop contains
    let amount: Int

    /// Current collection state
    private(set) var collectionState: ResourceCollectionState = .idle

    /// Time remaining before this resource expires
    private(set) var timeToExpiration: TimeInterval

    /// The target this resource is flying toward (when collecting)
    private weak var collectTarget: Character?

    /// Whether the expiration warning animation is playing
    private var isWarningActive: Bool = false

    // MARK: - Initialization

    /// Create a new resource drop
    /// - Parameters:
    ///   - amount: The value of this resource
    ///   - position: Where to spawn the resource
    ///   - expirationTime: How long until expiration (default 20s)
    init(amount: Int, position: CGPoint, expirationTime: TimeInterval = Resource.defaultExpirationTime) {
        self.amount = amount
        self.timeToExpiration = expirationTime

        // Create the sprite using the factory (scrap metal chunk)
        self.sprite = ResourceSprite.createForAmount(amount)
        self.sprite.name = "resource"
        self.sprite.position = position
        self.sprite.zPosition = 50 // Below characters but above ground
        self.sprite.setScale(2.0)

        // Start idle animations
        self.startIdleAnimations()
    }

    // MARK: - Animations

    /// Start the idle floating/pulsing animation
    private func startIdleAnimations() {
        // Pulse scale animation
        let scaleUp = SKAction.scale(to: 2.2, duration: Resource.pulseDuration / 2)
        let scaleDown = SKAction.scale(to: 2.0, duration: Resource.pulseDuration / 2)
        scaleUp.timingMode = .easeInEaseOut
        scaleDown.timingMode = .easeInEaseOut
        let pulseSequence = SKAction.sequence([scaleUp, scaleDown])
        let pulseForever = SKAction.repeatForever(pulseSequence)
        self.sprite.run(pulseForever, withKey: "pulse")

        // Subtle floating animation
        let floatUp = SKAction.moveBy(x: 0, y: Resource.floatHeight, duration: Resource.pulseDuration)
        let floatDown = SKAction.moveBy(x: 0, y: -Resource.floatHeight, duration: Resource.pulseDuration)
        floatUp.timingMode = .easeInEaseOut
        floatDown.timingMode = .easeInEaseOut
        let floatSequence = SKAction.sequence([floatUp, floatDown])
        let floatForever = SKAction.repeatForever(floatSequence)
        self.sprite.run(floatForever, withKey: "float")
    }

    /// Start warning animation when about to expire
    private func startExpirationWarning() {
        guard !self.isWarningActive else { return }
        self.isWarningActive = true

        // Flash between normal and dim
        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: 0.2)
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.2)
        let flashSequence = SKAction.sequence([fadeOut, fadeIn])
        let flashForever = SKAction.repeatForever(flashSequence)
        self.sprite.run(flashForever, withKey: "warning")
    }

    /// Stop all animations
    private func stopAnimations() {
        self.sprite.removeAction(forKey: "pulse")
        self.sprite.removeAction(forKey: "float")
        self.sprite.removeAction(forKey: "warning")
    }

    // MARK: - GameEntity Update

    func update(deltaTime: TimeInterval) {
        guard self.isActive else { return }

        switch self.collectionState {
        case .idle:
            self.updateIdle(deltaTime: deltaTime)

        case .collecting:
            self.updateCollecting(deltaTime: deltaTime)

        case .collected:
            // Will be removed by ResourceManager
            self.isActive = false
        }
    }

    /// Update when in idle state
    private func updateIdle(deltaTime: TimeInterval) {
        // Update expiration timer
        self.timeToExpiration -= deltaTime

        // Check for expiration warning
        if self.timeToExpiration <= Resource.expirationWarningTime, !self.isWarningActive {
            self.startExpirationWarning()
        }

        // Check for full expiration
        if self.timeToExpiration <= 0 {
            self.expire()
        }
    }

    /// Update when flying toward collector
    private func updateCollecting(deltaTime: TimeInterval) {
        guard let target = collectTarget else {
            // Target gone, become idle again
            self.collectionState = .idle
            self.startIdleAnimations()
            return
        }

        let dx = target.position.x - self.position.x
        let dy = target.position.y - self.position.y
        let distance = hypot(dx, dy)

        // Check if we've reached the target
        if distance < 10 {
            self.collectionState = .collected
            return
        }

        // Move toward target
        let normalizedDx = dx / distance
        let normalizedDy = dy / distance
        let moveDistance = Resource.collectSpeed * CGFloat(deltaTime)

        self.position = CGPoint(
            x: self.position.x + normalizedDx * moveDistance,
            y: self.position.y + normalizedDy * moveDistance
        )
    }

    // MARK: - Collection

    /// Check if a character is within auto-collect range
    func isInCollectRange(of character: Character) -> Bool {
        guard self.collectionState == .idle else { return false }

        let dx = character.position.x - self.position.x
        let dy = character.position.y - self.position.y
        let distance = hypot(dx, dy)

        return distance <= Resource.autoCollectRadius
    }

    /// Start collecting toward a target
    func startCollecting(toward target: Character) {
        guard self.collectionState == .idle else { return }

        self.collectionState = .collecting
        self.collectTarget = target

        // Stop idle animations and speed up
        self.stopAnimations()

        // Play collection sound
        if let scene = sprite.scene {
            AudioManager.shared.playSoundEffect(.collect, on: scene)
        }
    }

    /// Force immediate collection (for manual pickup)
    func collect() {
        self.collectionState = .collected
        self.stopAnimations()
    }

    // MARK: - Expiration

    /// Called when the resource expires without being collected
    private func expire() {
        self.isActive = false
        self.stopAnimations()

        // Fade out and remove
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        self.sprite.run(SKAction.sequence([fadeOut, remove]))
    }
}
