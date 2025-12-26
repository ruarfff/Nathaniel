//
//  CreditsScene.swift
//  Nathaniel Shared
//
//  Credits screen showing game information and developer attribution.
//

import SpriteKit

class CreditsScene: SKScene {

    // MARK: - Properties

    private var backButton: SKLabelNode!

    // MARK: - Scene Setup

    class func newCreditsScene() -> CreditsScene {
        let scene = CreditsScene(size: CGSize(width: 1366, height: 1024))
        scene.scaleMode = .aspectFill
        return scene
    }

    override func didMove(to view: SKView) {
        setupBackground()
        setupCreditsContent()
        setupBackButton()

        #if DEBUG
        // Notify the command server that a new scene is presented
        NotificationCenter.default.post(name: .skViewDidPresentScene, object: view)
        #endif
    }

    // MARK: - Setup Methods

    private func setupBackground() {
        // Match main menu background
        backgroundColor = SKColor(red: 0.15, green: 0.25, blue: 0.15, alpha: 1.0)
    }

    private func setupCreditsContent() {
        // Title
        let titleLabel = SKLabelNode(fontNamed: "Copperplate-Bold")
        titleLabel.text = "CREDITS"
        titleLabel.fontSize = 56
        titleLabel.fontColor = SKColor(red: 0.9, green: 0.8, blue: 0.5, alpha: 1.0)
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.8)
        titleLabel.horizontalAlignmentMode = .center
        addChild(titleLabel)

        // Credits content
        let credits: [(String, String)] = [
            ("NATHANIEL", "Defender of Earth"),
            ("", ""),
            ("Original Game", "Ruairi O'Brien"),
            ("SpriteKit Port", "Ruairi O'Brien"),
            ("", ""),
            ("Built with", "Swift & SpriteKit"),
            ("Original Platform", "Windows Phone 7 / XNA"),
            ("", ""),
            ("Special Thanks", ""),
            ("", "The XNA Community"),
            ("", "Apple Developer Tools")
        ]

        var yPosition = size.height * 0.65
        let lineSpacing: CGFloat = 40

        for (title, value) in credits {
            if title.isEmpty && value.isEmpty {
                yPosition -= lineSpacing / 2
                continue
            }

            if value.isEmpty {
                // Section header
                let headerLabel = SKLabelNode(fontNamed: "Copperplate-Bold")
                headerLabel.text = title
                headerLabel.fontSize = 28
                headerLabel.fontColor = SKColor(red: 0.8, green: 0.7, blue: 0.5, alpha: 1.0)
                headerLabel.position = CGPoint(x: size.width / 2, y: yPosition)
                headerLabel.horizontalAlignmentMode = .center
                addChild(headerLabel)
            } else if title.isEmpty {
                // Continuation line (indented value)
                let valueLabel = SKLabelNode(fontNamed: "Copperplate")
                valueLabel.text = value
                valueLabel.fontSize = 22
                valueLabel.fontColor = .white
                valueLabel.position = CGPoint(x: size.width / 2, y: yPosition)
                valueLabel.horizontalAlignmentMode = .center
                addChild(valueLabel)
            } else {
                // Title: Value pair
                let titleNode = SKLabelNode(fontNamed: "Copperplate-Bold")
                titleNode.text = title
                titleNode.fontSize = 24
                titleNode.fontColor = SKColor(red: 0.7, green: 0.6, blue: 0.4, alpha: 1.0)
                titleNode.position = CGPoint(x: size.width / 2 - 20, y: yPosition)
                titleNode.horizontalAlignmentMode = .right
                addChild(titleNode)

                let valueLabel = SKLabelNode(fontNamed: "Copperplate")
                valueLabel.text = value
                valueLabel.fontSize = 24
                valueLabel.fontColor = .white
                valueLabel.position = CGPoint(x: size.width / 2 + 20, y: yPosition)
                valueLabel.horizontalAlignmentMode = .left
                addChild(valueLabel)
            }

            yPosition -= lineSpacing
        }

        // Version info at bottom
        let versionLabel = SKLabelNode(fontNamed: "Copperplate")
        versionLabel.text = "Version 1.0"
        versionLabel.fontSize = 18
        versionLabel.fontColor = SKColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        versionLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.12)
        versionLabel.horizontalAlignmentMode = .center
        addChild(versionLabel)
    }

    private func setupBackButton() {
        backButton = SKLabelNode(fontNamed: "Copperplate-Bold")
        backButton.text = "Back"
        backButton.fontSize = 32
        backButton.fontColor = .white
        backButton.position = CGPoint(x: size.width / 2, y: size.height * 0.08)
        backButton.horizontalAlignmentMode = .center
        backButton.name = "backButton"
        addChild(backButton)
    }

    // MARK: - Button Actions

    /// Handle a tap at the given location (used by GameCommandServer)
    func handleTap(at location: CGPoint) {
        handleButtonTap(at: location)
    }

    private func handleButtonTap(at location: CGPoint) {
        let nodesAtPoint = nodes(at: location)

        for node in nodesAtPoint {
            if node.name == "backButton" {
                animateButtonPress(node as? SKLabelNode) {
                    self.returnToMenu()
                }
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

    private func returnToMenu() {
        let menuScene = MainMenuScene.newMenuScene()
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(menuScene, transition: transition)
    }
}

// MARK: - iOS Touch Handling

#if os(iOS) || os(tvOS)
extension CreditsScene {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        handleButtonTap(at: location)
    }
}
#endif

// MARK: - macOS Mouse Handling

#if os(OSX)
extension CreditsScene {

    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        handleButtonTap(at: location)
    }
}
#endif
