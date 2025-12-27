//
//  OptionsScene.swift
//  Nathaniel Shared
//
//  Options screen with audio settings toggles.
//

import SpriteKit

class OptionsScene: SKScene {

    // MARK: - Properties

    private var backButton: SKLabelNode!
    private var soundToggle: SKLabelNode!
    private var musicToggle: SKLabelNode!

    // MARK: - Scene Setup

    class func newOptionsScene() -> OptionsScene {
        let scene = OptionsScene(size: CGSize(width: 1366, height: 1024))
        scene.scaleMode = .aspectFill
        return scene
    }

    override func didMove(to view: SKView) {
        setupBackground()
        setupTitle()
        setupOptions()
        setupBackButton()

        #if DEBUG
        // Set this scene as the command server delegate
        GameCommandServer.shared.delegate = self
        #endif
    }

    // MARK: - Setup Methods

    private func setupBackground() {
        // Match main menu background
        backgroundColor = SKColor(red: 0.15, green: 0.25, blue: 0.15, alpha: 1.0)
    }

    private func setupTitle() {
        let titleLabel = SKLabelNode(fontNamed: "Copperplate-Bold")
        titleLabel.text = "OPTIONS"
        titleLabel.fontSize = 56
        titleLabel.fontColor = SKColor(red: 0.9, green: 0.8, blue: 0.5, alpha: 1.0)
        // Position lower to avoid being cut off on devices with different aspect ratios
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        titleLabel.horizontalAlignmentMode = .center
        addChild(titleLabel)
    }

    private func setupOptions() {
        let startY = size.height * 0.55
        let spacing: CGFloat = 80

        // Sound Effects toggle
        let soundLabel = SKLabelNode(fontNamed: "Copperplate-Bold")
        soundLabel.text = "Sound Effects"
        soundLabel.fontSize = 28
        soundLabel.fontColor = SKColor(red: 0.7, green: 0.6, blue: 0.4, alpha: 1.0)
        soundLabel.position = CGPoint(x: size.width / 2 - 100, y: startY)
        soundLabel.horizontalAlignmentMode = .right
        addChild(soundLabel)

        soundToggle = createToggleButton(
            enabled: GameSettings.shared.soundEffectsEnabled,
            yPosition: startY,
            name: "soundToggle"
        )
        addChild(soundToggle)

        // Music toggle
        let musicLabel = SKLabelNode(fontNamed: "Copperplate-Bold")
        musicLabel.text = "Music"
        musicLabel.fontSize = 28
        musicLabel.fontColor = SKColor(red: 0.7, green: 0.6, blue: 0.4, alpha: 1.0)
        musicLabel.position = CGPoint(x: size.width / 2 - 100, y: startY - spacing)
        musicLabel.horizontalAlignmentMode = .right
        addChild(musicLabel)

        musicToggle = createToggleButton(
            enabled: GameSettings.shared.musicEnabled,
            yPosition: startY - spacing,
            name: "musicToggle"
        )
        addChild(musicToggle)
    }

    private func createToggleButton(enabled: Bool, yPosition: CGFloat, name: String) -> SKLabelNode {
        let toggle = SKLabelNode(fontNamed: "Copperplate-Bold")
        toggle.text = enabled ? "ON" : "OFF"
        toggle.fontSize = 28
        toggle.fontColor = enabled ? SKColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 1.0) : SKColor(red: 0.6, green: 0.4, blue: 0.4, alpha: 1.0)
        toggle.position = CGPoint(x: size.width / 2 + 100, y: yPosition)
        toggle.horizontalAlignmentMode = .left
        toggle.name = name
        return toggle
    }

    private func updateToggle(_ toggle: SKLabelNode, enabled: Bool) {
        toggle.text = enabled ? "ON" : "OFF"
        toggle.fontColor = enabled ? SKColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 1.0) : SKColor(red: 0.6, green: 0.4, blue: 0.4, alpha: 1.0)
    }

    private func setupBackButton() {
        backButton = SKLabelNode(fontNamed: "Copperplate-Bold")
        backButton.text = "Back"
        backButton.fontSize = 32
        backButton.fontColor = .white
        // Position higher to avoid being cut off on devices with different aspect ratios
        backButton.position = CGPoint(x: size.width / 2, y: size.height * 0.25)
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
            guard let nodeName = node.name else { continue }

            switch nodeName {
            case "backButton":
                animateButtonPress(node as? SKLabelNode) {
                    self.returnToMenu()
                }
            case "soundToggle":
                toggleSound()
            case "musicToggle":
                toggleMusic()
            default:
                break
            }
        }
    }

    private func toggleSound() {
        GameSettings.shared.soundEffectsEnabled.toggle()
        updateToggle(soundToggle, enabled: GameSettings.shared.soundEffectsEnabled)
        animateToggle(soundToggle)
    }

    private func toggleMusic() {
        GameSettings.shared.musicEnabled.toggle()
        updateToggle(musicToggle, enabled: GameSettings.shared.musicEnabled)
        animateToggle(musicToggle)

        // Immediately start/stop music based on new setting
        AudioManager.shared.onMusicSettingChanged()
        if GameSettings.shared.musicEnabled {
            AudioManager.shared.playMusic(.menu)
        }
    }

    private func animateToggle(_ toggle: SKLabelNode) {
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.1)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
        toggle.run(SKAction.sequence([scaleUp, scaleDown]))
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
extension OptionsScene {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        handleButtonTap(at: location)
    }
}
#endif

// MARK: - macOS Mouse Handling

#if os(OSX)
extension OptionsScene {

    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        handleButtonTap(at: location)
    }
}
#endif
