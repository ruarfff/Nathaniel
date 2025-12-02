//
//  GameOverlay.swift
//  Nathaniel Shared
//
//  Overlay UI elements for victory/game over screens.
//

import SpriteKit

// MARK: - Overlay State

/// The current state of the overlay
enum OverlayState {
    case hidden
    case victory
    case gameOver
    case lifeLost
}

// MARK: - Game Overlay

/// Overlay node for victory/game over screens
class GameOverlay: SKNode {

    // MARK: - Properties

    /// Background dim
    private let dimNode: SKShapeNode

    /// Title label
    private let titleLabel: SKLabelNode

    /// Subtitle label (score, time, etc.)
    private let subtitleLabel: SKLabelNode

    /// Instruction label (tap to continue)
    private let instructionLabel: SKLabelNode

    /// Size of the overlay
    private let overlaySize: CGSize

    /// Current overlay state
    private(set) var state: OverlayState = .hidden

    /// Whether there's a next level available
    private(set) var hasNextLevel: Bool = false

    /// Callback for when "Next Level" is selected
    var onNextLevel: (() -> Void)?

    /// Callback for when "Retry" is selected
    var onRetry: (() -> Void)?

    /// Callback for when "Main Menu" is selected
    var onMainMenu: (() -> Void)?

    // MARK: - Initialization

    init(size: CGSize) {
        self.overlaySize = size

        // Create dim background
        dimNode = SKShapeNode(rectOf: CGSize(width: size.width * 2, height: size.height * 2))
        dimNode.fillColor = SKColor.black.withAlphaComponent(0.7)
        dimNode.strokeColor = .clear
        dimNode.zPosition = 900

        // Title label
        titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        titleLabel.fontSize = 48
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: 60)
        titleLabel.zPosition = 910

        // Subtitle label
        subtitleLabel = SKLabelNode(fontNamed: "Helvetica")
        subtitleLabel.fontSize = 24
        subtitleLabel.fontColor = SKColor(white: 0.9, alpha: 1.0)
        subtitleLabel.position = CGPoint(x: 0, y: 0)
        subtitleLabel.zPosition = 910

        // Instruction label
        instructionLabel = SKLabelNode(fontNamed: "Helvetica")
        instructionLabel.fontSize = 18
        instructionLabel.fontColor = SKColor(white: 0.7, alpha: 1.0)
        instructionLabel.position = CGPoint(x: 0, y: -60)
        instructionLabel.zPosition = 910

        super.init()

        addChild(dimNode)
        addChild(titleLabel)
        addChild(subtitleLabel)
        addChild(instructionLabel)

        // Start hidden
        alpha = 0
        isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Display

    /// Show victory screen
    func showVictory(score: Int, time: TimeInterval, hasNextLevel: Bool = false) {
        state = .victory
        self.hasNextLevel = hasNextLevel

        titleLabel.text = "VICTORY!"
        titleLabel.fontColor = SKColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)

        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        subtitleLabel.text = "Score: \(score) | Time: \(minutes):\(String(format: "%02d", seconds))"

        if hasNextLevel {
            #if os(iOS) || os(tvOS)
            instructionLabel.text = "Tap for Next Level"
            #else
            instructionLabel.text = "Press any key for Next Level"
            #endif
        } else {
            // Final level or survival - completed the game
            titleLabel.text = "GAME COMPLETE!"
            #if os(iOS) || os(tvOS)
            instructionLabel.text = "Tap to return to menu"
            #else
            instructionLabel.text = "Press any key to return to menu"
            #endif
        }

        animateIn()
    }

    /// Show game over screen
    func showGameOver(score: Int, time: TimeInterval) {
        state = .gameOver
        hasNextLevel = false

        titleLabel.text = "GAME OVER"
        titleLabel.fontColor = SKColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)

        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        subtitleLabel.text = "Score: \(score) | Time: \(minutes):\(String(format: "%02d", seconds))"

        #if os(iOS) || os(tvOS)
        instructionLabel.text = "Tap to retry"
        #else
        instructionLabel.text = "Press any key to retry"
        #endif

        animateIn()
    }

    /// Handle user interaction with the overlay
    func handleInteraction() {
        switch state {
        case .hidden, .lifeLost:
            break
        case .victory:
            if hasNextLevel {
                onNextLevel?()
            } else {
                onMainMenu?()
            }
        case .gameOver:
            onRetry?()
        }
    }

    /// Show life lost notification (brief)
    func showLifeLost(remainingLives: Int) {
        state = .lifeLost

        titleLabel.text = "Life Lost!"
        titleLabel.fontColor = SKColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1.0)

        subtitleLabel.text = "Lives remaining: \(remainingLives)"
        instructionLabel.text = ""

        // Brief appearance
        isHidden = false
        alpha = 1

        let wait = SKAction.wait(forDuration: 1.5)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let hide = SKAction.run { [weak self] in
            self?.isHidden = true
            self?.state = .hidden
        }
        run(SKAction.sequence([wait, fadeOut, hide]))
    }

    /// Hide the overlay
    func hide() {
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let hide = SKAction.run { [weak self] in
            self?.isHidden = true
        }
        run(SKAction.sequence([fadeOut, hide]))
    }

    // MARK: - Animation

    private func animateIn() {
        isHidden = false

        // Fade in
        let fadeIn = SKAction.fadeIn(withDuration: 0.5)
        run(fadeIn)

        // Pulse instruction label
        let scaleUp = SKAction.scale(to: 1.1, duration: 0.8)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.8)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        instructionLabel.run(SKAction.repeatForever(pulse))
    }
}
