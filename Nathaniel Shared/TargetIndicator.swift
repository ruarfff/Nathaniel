import SpriteKit

/// A visual indicator that shows which enemy is currently targeted
class TargetIndicator: SKNode {
    // MARK: - Properties

    /// The ring shape node
    private let ringNode: SKShapeNode

    /// The target being tracked (weak to avoid retain cycles)
    private weak var trackedTarget: SKNode?

    /// Radius of the ring
    private let radius: CGFloat

    // MARK: - Constants

    /// Default ring radius (compact - positioned at enemy feet)
    static let defaultRadius: CGFloat = 25

    /// Ring stroke color (red for player targeting)
    static let ringColor = SKColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0)

    /// Ring fill color (subtle fill for visibility)
    static let fillColor = SKColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.1)

    /// Cyan color for Hermes targeting
    static let cyanRingColor = SKColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 1.0)
    static let cyanFillColor = SKColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.1)

    /// Ring stroke width (thinner for compact look)
    static let strokeWidth: CGFloat = 2.0

    /// Pulse animation duration
    static let pulseDuration: TimeInterval = 0.8

    /// Pulse scale range (reduced for subtler effect)
    static let pulseMinScale: CGFloat = 1.0
    static let pulseMaxScale: CGFloat = 1.08

    // MARK: - Initialization

    init(
        radius: CGFloat = TargetIndicator.defaultRadius,
        strokeColor: SKColor = TargetIndicator.ringColor,
        fillColor: SKColor = TargetIndicator.fillColor
    ) {
        self.radius = radius

        // Create the ring shape
        self.ringNode = SKShapeNode(circleOfRadius: radius)
        self.ringNode.strokeColor = strokeColor
        self.ringNode.fillColor = fillColor
        self.ringNode.lineWidth = TargetIndicator.strokeWidth
        self.ringNode.glowWidth = 0.5 // Subtle glow effect

        super.init()

        addChild(self.ringNode)

        // Start the pulse animation
        self.startPulseAnimation()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Animation

    /// Start the pulsing animation
    private func startPulseAnimation() {
        let scaleUp = SKAction.scale(
            to: TargetIndicator.pulseMaxScale,
            duration: TargetIndicator.pulseDuration / 2
        )
        scaleUp.timingMode = .easeInEaseOut

        let scaleDown = SKAction.scale(
            to: TargetIndicator.pulseMinScale,
            duration: TargetIndicator.pulseDuration / 2
        )
        scaleDown.timingMode = .easeInEaseOut

        let pulse = SKAction.sequence([scaleUp, scaleDown])
        let repeatPulse = SKAction.repeatForever(pulse)

        self.ringNode.run(repeatPulse, withKey: "pulse")
    }

    // MARK: - Target Tracking

    /// Offset to position indicator at enemy feet (negative Y)
    private static let feetOffset: CGFloat = -20

    /// Attach the indicator to a target node
    func attach(to target: SKNode) {
        self.trackedTarget = target

        // Position at target's feet (below center)
        position = CGPoint(
            x: target.position.x,
            y: target.position.y + TargetIndicator.feetOffset
        )

        // Set z-position below enemies (ground level)
        zPosition = target.zPosition - 1

        // Fade in
        alpha = 0
        run(SKAction.fadeIn(withDuration: 0.15))
    }

    /// Update position to follow tracked target
    func updatePosition() {
        guard let target = trackedTarget else { return }
        position = CGPoint(
            x: target.position.x,
            y: target.position.y + TargetIndicator.feetOffset
        )
    }

    /// Remove the indicator with animation
    func remove() {
        let fadeOut = SKAction.fadeOut(withDuration: 0.15)
        let remove = SKAction.removeFromParent()
        run(SKAction.sequence([fadeOut, remove]))
    }

    // MARK: - Static Factory

    /// Create and attach a target indicator to an enemy (red - player targeting)
    static func create(for target: SKNode, in scene: SKScene) -> TargetIndicator {
        let indicator = TargetIndicator()
        indicator.attach(to: target)
        scene.addChild(indicator)
        return indicator
    }

    /// Create and attach a cyan target indicator (for Hermes targeting)
    static func createCyan(for target: SKNode, in scene: SKScene) -> TargetIndicator {
        let indicator = TargetIndicator(
            strokeColor: cyanRingColor,
            fillColor: cyanFillColor
        )
        indicator.attach(to: target)
        scene.addChild(indicator)
        return indicator
    }
}
