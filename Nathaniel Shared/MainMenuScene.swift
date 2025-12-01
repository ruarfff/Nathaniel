//
//  MainMenuScene.swift
//  Nathaniel Shared
//
//  Main menu scene with Start Game, Options, and Credits buttons.
//

import SpriteKit

class MainMenuScene: SKScene {

    // MARK: - Properties

    /// Title label
    private var titleLabel: SKLabelNode!

    /// Menu buttons
    private var startButton: SKLabelNode!
    private var optionsButton: SKLabelNode!
    private var creditsButton: SKLabelNode!

    /// Background node
    private var backgroundNode: SKSpriteNode?

    // MARK: - Scene Setup

    class func newMenuScene() -> MainMenuScene {
        let scene = MainMenuScene(size: CGSize(width: 1366, height: 1024))
        scene.scaleMode = .aspectFill
        return scene
    }

    override func didMove(to view: SKView) {
        setupBackground()
        setupTitle()
        setupMenuButtons()

        // Start menu music
        AudioManager.shared.playMusic(.menu)
    }

    // MARK: - Setup Methods

    private func setupBackground() {
        // Dark green gradient-like background to match game aesthetic
        backgroundColor = SKColor(red: 0.15, green: 0.25, blue: 0.15, alpha: 1.0)

        // Add some decorative elements
        let pattern = createGrassPattern()
        pattern.position = CGPoint(x: size.width / 2, y: size.height / 4)
        addChild(pattern)
    }

    private func createGrassPattern() -> SKNode {
        let container = SKNode()

        // Create a simple decorative pattern at the bottom
        let grassColor = SKColor(red: 0.2, green: 0.4, blue: 0.2, alpha: 0.5)

        for i in 0..<20 {
            let grass = SKShapeNode(rectOf: CGSize(width: 60, height: 8))
            grass.fillColor = grassColor
            grass.strokeColor = .clear
            grass.position = CGPoint(
                x: CGFloat(i - 10) * 70,
                y: CGFloat.random(in: -20...20)
            )
            container.addChild(grass)
        }

        return container
    }

    private func setupTitle() {
        // Main title
        titleLabel = SKLabelNode(fontNamed: "Copperplate-Bold")
        titleLabel.text = "NATHANIEL"
        titleLabel.fontSize = 72
        titleLabel.fontColor = SKColor(red: 0.9, green: 0.8, blue: 0.5, alpha: 1.0) // Gold-ish
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.7)
        titleLabel.horizontalAlignmentMode = .center
        addChild(titleLabel)

        // Subtitle
        let subtitleLabel = SKLabelNode(fontNamed: "Copperplate")
        subtitleLabel.text = "Defender of Earth"
        subtitleLabel.fontSize = 28
        subtitleLabel.fontColor = SKColor(red: 0.7, green: 0.6, blue: 0.4, alpha: 1.0)
        subtitleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.7 - 50)
        subtitleLabel.horizontalAlignmentMode = .center
        addChild(subtitleLabel)

        // Animate title
        let scaleUp = SKAction.scale(to: 1.05, duration: 1.5)
        let scaleDown = SKAction.scale(to: 1.0, duration: 1.5)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        titleLabel.run(SKAction.repeatForever(pulse))
    }

    private func setupMenuButtons() {
        let buttonSpacing: CGFloat = 70
        let startY = size.height * 0.45

        // Start Game button
        startButton = createMenuButton(text: "Start Game", yPosition: startY)
        startButton.name = "startButton"
        addChild(startButton)

        // Options button
        optionsButton = createMenuButton(text: "Options", yPosition: startY - buttonSpacing)
        optionsButton.name = "optionsButton"
        addChild(optionsButton)

        // Credits button
        creditsButton = createMenuButton(text: "Credits", yPosition: startY - buttonSpacing * 2)
        creditsButton.name = "creditsButton"
        addChild(creditsButton)
    }

    private func createMenuButton(text: String, yPosition: CGFloat) -> SKLabelNode {
        let button = SKLabelNode(fontNamed: "Copperplate-Bold")
        button.text = text
        button.fontSize = 36
        button.fontColor = .white
        button.position = CGPoint(x: size.width / 2, y: yPosition)
        button.horizontalAlignmentMode = .center

        return button
    }

    // MARK: - Button Actions

    private func handleButtonTap(at location: CGPoint) {
        let nodesAtPoint = nodes(at: location)

        for node in nodesAtPoint {
            guard let nodeName = node.name else { continue }

            switch nodeName {
            case "startButton":
                animateButtonPress(node as? SKLabelNode) {
                    self.startGame()
                }
            case "optionsButton":
                animateButtonPress(node as? SKLabelNode) {
                    self.showOptions()
                }
            case "creditsButton":
                animateButtonPress(node as? SKLabelNode) {
                    self.showCredits()
                }
            default:
                break
            }
        }
    }

    private func animateButtonPress(_ button: SKLabelNode?, completion: @escaping () -> Void) {
        guard let button = button else {
            completion()
            return
        }

        let scaleDown = SKAction.scale(to: 0.9, duration: 0.1)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.1)
        let sequence = SKAction.sequence([scaleDown, scaleUp, SKAction.run(completion)])
        button.run(sequence)
    }

    private func startGame() {
        let gameScene = GameScene.newGameScene()
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(gameScene, transition: transition)
    }

    private func showOptions() {
        let optionsScene = OptionsScene.newOptionsScene()
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(optionsScene, transition: transition)
    }

    private func showCredits() {
        let creditsScene = CreditsScene.newCreditsScene()
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(creditsScene, transition: transition)
    }
}

// MARK: - iOS Touch Handling

#if os(iOS) || os(tvOS)
extension MainMenuScene {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        handleButtonTap(at: location)
    }
}
#endif

// MARK: - macOS Mouse Handling

#if os(OSX)
extension MainMenuScene {

    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        handleButtonTap(at: location)
    }
}
#endif
