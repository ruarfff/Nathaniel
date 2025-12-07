//
//  VisualEffects.swift
//  Nathaniel Shared
//
//  Visual effect utilities for explosions, particles, and screen effects.
//

import SpriteKit

// MARK: - Explosion Effect

/// Creates an explosion visual effect at a given position
class ExplosionEffect {

    // MARK: - Configuration

    /// Duration of the explosion animation
    static let explosionDuration: TimeInterval = 0.4

    /// Number of particle fragments
    static let fragmentCount: Int = 8

    /// Fragment spread radius
    static let spreadRadius: CGFloat = 60

    // MARK: - Create Explosion

    /// Create an explosion effect at the given position
    /// - Parameters:
    ///   - position: World position for the explosion
    ///   - scene: Scene to add the effect to
    ///   - color: Base color for the explosion (defaults to orange)
    ///   - scale: Scale multiplier for the effect size
    static func create(at position: CGPoint, in scene: SKScene, color: SKColor = .orange, scale: CGFloat = 1.0) {
        // Create central flash
        let flash = SKShapeNode(circleOfRadius: 30 * scale)
        flash.position = position
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.zPosition = 500
        flash.alpha = 1.0
        scene.addChild(flash)

        // Flash animation
        let expandFlash = SKAction.scale(to: 2.5, duration: 0.1)
        let fadeFlash = SKAction.fadeOut(withDuration: 0.2)
        let removeFlash = SKAction.removeFromParent()
        flash.run(SKAction.sequence([expandFlash, fadeFlash, removeFlash]))

        // Create expanding ring
        let ring = SKShapeNode(circleOfRadius: 20 * scale)
        ring.position = position
        ring.fillColor = .clear
        ring.strokeColor = color
        ring.lineWidth = 4
        ring.zPosition = 499
        scene.addChild(ring)

        // Ring expansion
        let expandRing = SKAction.scale(to: 4.0, duration: 0.3)
        let fadeRing = SKAction.fadeOut(withDuration: 0.3)
        let removeRing = SKAction.removeFromParent()
        ring.run(SKAction.sequence([SKAction.group([expandRing, fadeRing]), removeRing]))

        // Create fragments
        for i in 0..<fragmentCount {
            let angle = CGFloat(i) * (2 * .pi / CGFloat(fragmentCount)) + CGFloat.random(in: -0.3...0.3)
            let fragment = createFragment(color: color, scale: scale)
            fragment.position = position
            fragment.zPosition = 498
            scene.addChild(fragment)

            // Calculate end position
            let distance = spreadRadius * scale * CGFloat.random(in: 0.6...1.2)
            let endX = position.x + cos(angle) * distance
            let endY = position.y + sin(angle) * distance

            // Fragment animation
            let move = SKAction.move(to: CGPoint(x: endX, y: endY), duration: explosionDuration)
            move.timingMode = .easeOut
            let rotate = SKAction.rotate(byAngle: CGFloat.random(in: -4...4), duration: explosionDuration)
            let fade = SKAction.fadeOut(withDuration: explosionDuration * 0.8)
            let shrink = SKAction.scale(to: 0.2, duration: explosionDuration)
            let remove = SKAction.removeFromParent()

            let group = SKAction.group([move, rotate, fade, shrink])
            fragment.run(SKAction.sequence([group, remove]))
        }
    }

    /// Create a single fragment particle
    private static func createFragment(color: SKColor, scale: CGFloat) -> SKNode {
        let size = CGFloat.random(in: 4...10) * scale
        let fragment = SKShapeNode(rectOf: CGSize(width: size, height: size * 0.6))
        fragment.fillColor = color
        fragment.strokeColor = color.withAlphaComponent(0.5)
        fragment.lineWidth = 1

        // Random starting rotation
        fragment.zRotation = CGFloat.random(in: 0...(.pi * 2))

        return fragment
    }
}

// MARK: - Debris Effect

/// Creates debris particles that fly outward and fall
class DebrisEffect {

    // MARK: - Configuration

    static let debrisCount: Int = 6
    static let debrisDuration: TimeInterval = 0.6

    // MARK: - Create Debris

    /// Create debris effect at the given position
    /// - Parameters:
    ///   - position: World position for the debris
    ///   - scene: Scene to add the effect to
    ///   - colors: Array of colors to use for debris pieces
    static func create(at position: CGPoint, in scene: SKScene, colors: [SKColor] = [.gray, .darkGray, .brown]) {
        for _ in 0..<debrisCount {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let size = CGFloat.random(in: 3...8)

            let debris = SKShapeNode(rectOf: CGSize(width: size, height: size * 0.7))
            debris.fillColor = colors.randomElement() ?? .gray
            debris.strokeColor = .clear
            debris.position = position
            debris.zPosition = 450
            debris.zRotation = CGFloat.random(in: 0...(.pi * 2))
            scene.addChild(debris)

            // Calculate trajectory with arc (goes up then falls)
            let horizontalDistance = CGFloat.random(in: 30...80)
            let endX = position.x + cos(angle) * horizontalDistance
            let endY = position.y - CGFloat.random(in: 20...60)  // Falls below start

            // Create arc path using CGMutablePath (cross-platform)
            let controlY = position.y + CGFloat.random(in: 30...60)  // Goes up first

            let path = CGMutablePath()
            path.move(to: position)
            path.addQuadCurve(
                to: CGPoint(x: endX, y: endY),
                control: CGPoint(x: (position.x + endX) / 2, y: controlY)
            )

            let followPath = SKAction.follow(path, asOffset: false, orientToPath: false, duration: debrisDuration)
            followPath.timingMode = .easeIn

            let spin = SKAction.rotate(byAngle: CGFloat.random(in: -6...6), duration: debrisDuration)
            let fade = SKAction.sequence([
                SKAction.wait(forDuration: debrisDuration * 0.5),
                SKAction.fadeOut(withDuration: debrisDuration * 0.5)
            ])
            let remove = SKAction.removeFromParent()

            let group = SKAction.group([followPath, spin, fade])
            debris.run(SKAction.sequence([group, remove]))
        }
    }
}

// MARK: - Screen Shake

/// Provides screen shake functionality via camera manipulation
class ScreenShake {

    // MARK: - Shake Camera

    /// Shake the camera for dramatic effect
    /// - Parameters:
    ///   - camera: The camera node to shake
    ///   - intensity: Shake intensity in points (default 8)
    ///   - duration: Total shake duration (default 0.3)
    static func shake(camera: SKCameraNode, intensity: CGFloat = 8, duration: TimeInterval = 0.3) {
        let originalPosition = camera.position
        let shakeCount = 6
        let shakeDuration = duration / Double(shakeCount)

        var actions: [SKAction] = []

        for i in 0..<shakeCount {
            // Decrease intensity over time
            let factor = 1.0 - (CGFloat(i) / CGFloat(shakeCount))
            let currentIntensity = intensity * factor

            let offsetX = CGFloat.random(in: -currentIntensity...currentIntensity)
            let offsetY = CGFloat.random(in: -currentIntensity...currentIntensity)

            let shakePosition = CGPoint(
                x: originalPosition.x + offsetX,
                y: originalPosition.y + offsetY
            )

            let moveAction = SKAction.move(to: shakePosition, duration: shakeDuration)
            moveAction.timingMode = .easeOut
            actions.append(moveAction)
        }

        // Return to original position
        let returnAction = SKAction.move(to: originalPosition, duration: shakeDuration)
        returnAction.timingMode = .easeOut
        actions.append(returnAction)

        camera.run(SKAction.sequence(actions))
    }

    /// Shake with increasing intensity then decreasing (for chain explosions)
    /// - Parameters:
    ///   - camera: The camera node to shake
    ///   - burstCount: Number of explosion bursts
    ///   - baseIntensity: Starting intensity
    static func chainShake(camera: SKCameraNode, burstCount: Int, baseIntensity: CGFloat = 5) {
        // Build up shake intensity with each burst
        let maxIntensity = baseIntensity + CGFloat(burstCount) * 2
        shake(camera: camera, intensity: min(maxIntensity, 15), duration: 0.4)
    }
}

// MARK: - Staggered Destruction Helper

/// Helper for staggered tower destruction effects
class StaggeredDestruction {

    /// Destroy towers with staggered timing for dramatic effect
    /// - Parameters:
    ///   - towers: Array of towers to destroy
    ///   - scene: Scene for effects
    ///   - camera: Camera for screen shake (optional)
    ///   - delayBetween: Delay between each tower destruction
    ///   - completion: Called when all towers are destroyed
    static func destroy(
        towers: [DefensiveStructure],
        in scene: SKScene,
        camera: SKCameraNode?,
        delayBetween: TimeInterval = 0.15,
        completion: (() -> Void)? = nil
    ) {
        guard !towers.isEmpty else {
            completion?()
            return
        }

        // Sort towers for visual effect (e.g., by distance from center or random)
        let sortedTowers = towers.shuffled()

        // Create destruction sequence
        var delay: TimeInterval = 0

        for (index, tower) in sortedTowers.enumerated() {
            let capturedDelay = delay
            let isLast = index == sortedTowers.count - 1

            scene.run(SKAction.sequence([
                SKAction.wait(forDuration: capturedDelay),
                SKAction.run {
                    // Create visual effects at tower position
                    let position = tower.position

                    // Explosion effect
                    ExplosionEffect.create(at: position, in: scene, color: .orange, scale: 1.2)

                    // Debris effect
                    DebrisEffect.create(at: position, in: scene)

                    // Screen shake (intensity increases with each explosion)
                    if let camera = camera {
                        let intensity: CGFloat = 4 + CGFloat(index) * 1.5
                        ScreenShake.shake(camera: camera, intensity: min(intensity, 12), duration: 0.2)
                    }

                    // Play sound
                    AudioManager.shared.playSoundEffect(.explosion, on: scene)

                    // Trigger tower death (handles sprite removal)
                    tower.destroyWithEffect()
                },
                SKAction.run {
                    if isLast {
                        // Final shake after all destroyed
                        if let camera = camera {
                            scene.run(SKAction.sequence([
                                SKAction.wait(forDuration: 0.2),
                                SKAction.run {
                                    ScreenShake.shake(camera: camera, intensity: 6, duration: 0.3)
                                }
                            ]))
                        }

                        // Call completion after a brief delay
                        scene.run(SKAction.sequence([
                            SKAction.wait(forDuration: 0.3),
                            SKAction.run { completion?() }
                        ]))
                    }
                }
            ]))

            delay += delayBetween
        }
    }
}
