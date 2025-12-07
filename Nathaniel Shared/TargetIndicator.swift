//
//  TargetIndicator.swift
//  Nathaniel Shared
//
//  Visual indicator for targeted enemies - a red pulsing ring.
//

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

    /// Default ring radius
    static let defaultRadius: CGFloat = 45

    /// Ring stroke color
    static let ringColor = SKColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0)

    /// Ring stroke width
    static let strokeWidth: CGFloat = 2.5

    /// Pulse animation duration
    static let pulseDuration: TimeInterval = 0.8

    /// Pulse scale range
    static let pulseMinScale: CGFloat = 1.0
    static let pulseMaxScale: CGFloat = 1.15

    // MARK: - Initialization

    init(radius: CGFloat = TargetIndicator.defaultRadius) {
        self.radius = radius

        // Create the ring shape
        ringNode = SKShapeNode(circleOfRadius: radius)
        ringNode.strokeColor = TargetIndicator.ringColor
        ringNode.fillColor = .clear
        ringNode.lineWidth = TargetIndicator.strokeWidth
        ringNode.glowWidth = 1.0  // Subtle glow effect

        super.init()

        addChild(ringNode)

        // Start the pulse animation
        startPulseAnimation()
    }

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

        ringNode.run(repeatPulse, withKey: "pulse")
    }

    // MARK: - Target Tracking

    /// Attach the indicator to a target node
    func attach(to target: SKNode) {
        trackedTarget = target

        // Position at target
        position = target.position

        // Set z-position above enemies but below UI
        zPosition = target.zPosition + 1

        // Fade in
        alpha = 0
        run(SKAction.fadeIn(withDuration: 0.15))
    }

    /// Update position to follow tracked target
    func updatePosition() {
        guard let target = trackedTarget else { return }
        position = target.position
    }

    /// Remove the indicator with animation
    func remove() {
        let fadeOut = SKAction.fadeOut(withDuration: 0.15)
        let remove = SKAction.removeFromParent()
        run(SKAction.sequence([fadeOut, remove]))
    }

    // MARK: - Static Factory

    /// Create and attach a target indicator to an enemy
    static func create(for target: SKNode, in scene: SKScene) -> TargetIndicator {
        let indicator = TargetIndicator()
        indicator.attach(to: target)
        scene.addChild(indicator)
        return indicator
    }
}
