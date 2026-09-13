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
        self.dimNode = SKShapeNode(rectOf: CGSize(width: size.width * 2, height: size.height * 2))
        self.dimNode.fillColor = SKColor.black.withAlphaComponent(0.7)
        self.dimNode.strokeColor = .clear
        self.dimNode.zPosition = 900

        // Title label
        self.titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        self.titleLabel.fontSize = 48
        self.titleLabel.fontColor = .white
        self.titleLabel.position = CGPoint(x: 0, y: 60)
        self.titleLabel.zPosition = 910

        // Subtitle label
        self.subtitleLabel = SKLabelNode(fontNamed: "Helvetica")
        self.subtitleLabel.fontSize = 24
        self.subtitleLabel.fontColor = SKColor(white: 0.9, alpha: 1.0)
        self.subtitleLabel.position = CGPoint.zero
        self.subtitleLabel.zPosition = 910

        // Instruction label
        self.instructionLabel = SKLabelNode(fontNamed: "Helvetica")
        self.instructionLabel.fontSize = 18
        self.instructionLabel.fontColor = SKColor(white: 0.7, alpha: 1.0)
        self.instructionLabel.position = CGPoint(x: 0, y: -60)
        self.instructionLabel.zPosition = 910

        super.init()
        name = "resultOverlay"

        addChild(self.dimNode)
        addChild(self.titleLabel)
        addChild(self.subtitleLabel)
        addChild(self.instructionLabel)

        // Start hidden
        alpha = 0
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Display

    /// Show victory screen
    func showVictory(score: Int, time: TimeInterval, hasNextLevel: Bool = false) {
        self.state = .victory
        self.hasNextLevel = hasNextLevel

        self.titleLabel.text = "VICTORY!"
        self.titleLabel.fontColor = SKColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)

        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        self.subtitleLabel.text = "Score: \(score) | Time: \(minutes):\(String(format: "%02d", seconds))"

        if hasNextLevel {
            #if os(iOS) || os(tvOS)
                self.instructionLabel.text = "Tap for Next Level"
            #else
                self.instructionLabel.text = "Press any key for Next Level"
            #endif
        } else {
            // Final level or survival - completed the game
            self.titleLabel.text = "GAME COMPLETE!"
            #if os(iOS) || os(tvOS)
                self.instructionLabel.text = "Tap to return to menu"
            #else
                self.instructionLabel.text = "Press any key to return to menu"
            #endif
        }

        self.animateIn()
    }

    /// Show game over screen
    func showGameOver(score: Int, time: TimeInterval) {
        self.state = .gameOver
        self.hasNextLevel = false

        self.titleLabel.text = "GAME OVER"
        self.titleLabel.fontColor = SKColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)

        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        self.subtitleLabel.text = "Score: \(score) | Time: \(minutes):\(String(format: "%02d", seconds))"

        #if os(iOS) || os(tvOS)
            self.instructionLabel.text = "Tap to retry"
        #else
            self.instructionLabel.text = "Press any key to retry"
        #endif

        self.animateIn()
    }

    /// Handle user interaction with the overlay
    func handleInteraction() {
        switch self.state {
        case .hidden, .lifeLost:
            break
        case .victory:
            if self.hasNextLevel {
                self.onNextLevel?()
            } else {
                self.onMainMenu?()
            }
        case .gameOver:
            self.onRetry?()
        }
    }

    /// Show life lost notification (brief)
    func showLifeLost(remainingLives: Int) {
        guard self.state != .victory, self.state != .gameOver else { return }
        removeAction(forKey: "presentation")
        self.instructionLabel.removeAllActions()
        self.state = .lifeLost

        self.titleLabel.text = "Life Lost!"
        self.titleLabel.fontColor = SKColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1.0)

        self.subtitleLabel.text = "Lives remaining: \(remainingLives)"
        self.instructionLabel.text = ""

        // Brief appearance
        isHidden = false
        alpha = 1

        let wait = SKAction.wait(forDuration: 1.5)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let hide = SKAction.run { [weak self] in
            self?.isHidden = true
            self?.state = .hidden
        }
        run(SKAction.sequence([wait, fadeOut, hide]), withKey: "presentation")
    }

    /// Hide the overlay
    func hide() {
        removeAction(forKey: "presentation")
        self.instructionLabel.removeAllActions()
        self.state = .hidden
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let hide = SKAction.run { [weak self] in
            self?.isHidden = true
        }
        run(SKAction.sequence([fadeOut, hide]), withKey: "presentation")
    }

    // MARK: - Animation

    private func animateIn() {
        removeAction(forKey: "presentation")
        self.instructionLabel.removeAllActions()
        self.instructionLabel.setScale(1)
        isHidden = false

        // Fade in
        let fadeIn = SKAction.fadeIn(withDuration: 0.5)
        run(fadeIn, withKey: "presentation")

        // Pulse instruction label
        let scaleUp = SKAction.scale(to: 1.1, duration: 0.8)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.8)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        self.instructionLabel.run(SKAction.repeatForever(pulse))
    }
}
