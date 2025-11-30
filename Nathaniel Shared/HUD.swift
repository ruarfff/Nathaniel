//
//  HUD.swift
//  Nathaniel Shared
//
//  Heads-up display for game information: lives, score, resources, and selected character.
//

import SpriteKit

// MARK: - HUD

/// Heads-up display overlay showing game status
class HUD: SKNode {

    // MARK: - Properties

    /// Size of the viewport
    private let viewportSize: CGSize

    /// Container for top-left info (lives, score)
    private let topLeftContainer: SKNode

    /// Container for top-right info (resources)
    private let topRightContainer: SKNode

    /// Container for bottom info (selected character)
    private let bottomContainer: SKNode

    /// Lives display
    private let livesLabel: SKLabelNode
    private var livesIcons: [SKSpriteNode] = []

    /// Score display
    private let scoreLabel: SKLabelNode
    private let scoreValueLabel: SKLabelNode

    /// Resources display
    private let resourcesLabel: SKLabelNode
    private let resourcesValueLabel: SKLabelNode

    /// Selected character indicator
    private let selectedLabel: SKLabelNode
    private let selectedCharacterLabel: SKLabelNode

    /// Timer display
    private let timerLabel: SKLabelNode

    /// Padding from screen edges
    private let padding: CGFloat = 16

    /// Spacing between elements
    private let spacing: CGFloat = 8

    // MARK: - Initialization

    init(size: CGSize) {
        self.viewportSize = size

        // Create containers
        topLeftContainer = SKNode()
        topRightContainer = SKNode()
        bottomContainer = SKNode()

        // Lives label
        livesLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        livesLabel.fontSize = 16
        livesLabel.fontColor = .white
        livesLabel.horizontalAlignmentMode = .left
        livesLabel.verticalAlignmentMode = .top
        livesLabel.text = "LIVES"

        // Score label
        scoreLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        scoreLabel.fontSize = 16
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.verticalAlignmentMode = .top
        scoreLabel.text = "SCORE"

        scoreValueLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        scoreValueLabel.fontSize = 24
        scoreValueLabel.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
        scoreValueLabel.horizontalAlignmentMode = .left
        scoreValueLabel.verticalAlignmentMode = .top
        scoreValueLabel.text = "0"

        // Resources label
        resourcesLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        resourcesLabel.fontSize = 16
        resourcesLabel.fontColor = .white
        resourcesLabel.horizontalAlignmentMode = .right
        resourcesLabel.verticalAlignmentMode = .top
        resourcesLabel.text = "RESOURCES"

        resourcesValueLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        resourcesValueLabel.fontSize = 24
        resourcesValueLabel.fontColor = SKColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1.0)
        resourcesValueLabel.horizontalAlignmentMode = .right
        resourcesValueLabel.verticalAlignmentMode = .top
        resourcesValueLabel.text = "30"

        // Selected character
        selectedLabel = SKLabelNode(fontNamed: "Helvetica")
        selectedLabel.fontSize = 14
        selectedLabel.fontColor = SKColor(white: 0.7, alpha: 1.0)
        selectedLabel.horizontalAlignmentMode = .center
        selectedLabel.verticalAlignmentMode = .bottom
        selectedLabel.text = "SELECTED"

        selectedCharacterLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        selectedCharacterLabel.fontSize = 18
        selectedCharacterLabel.fontColor = .white
        selectedCharacterLabel.horizontalAlignmentMode = .center
        selectedCharacterLabel.verticalAlignmentMode = .bottom
        selectedCharacterLabel.text = "NATHANIEL"

        // Timer
        timerLabel = SKLabelNode(fontNamed: "Menlo")
        timerLabel.fontSize = 14
        timerLabel.fontColor = SKColor(white: 0.8, alpha: 1.0)
        timerLabel.horizontalAlignmentMode = .center
        timerLabel.verticalAlignmentMode = .top
        timerLabel.text = "00:00"

        super.init()

        setupLayout()
        zPosition = 500
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    private func setupLayout() {
        // Use percentage-based positioning that works regardless of scene size
        // Scene size may be 800x480 (from SKS) or something else
        let halfWidth = viewportSize.width / 2
        let halfHeight = viewportSize.height / 2

        // Fixed inset values that work well for most sizes
        let insetX: CGFloat = 20
        let insetY: CGFloat = 20

        print("HUD: viewportSize = \(viewportSize), halfWidth = \(halfWidth), halfHeight = \(halfHeight)")

        // Top-left container position
        topLeftContainer.position = CGPoint(
            x: -halfWidth + insetX + padding,
            y: halfHeight - insetY - padding
        )
        addChild(topLeftContainer)

        // Add background panel for top-left
        let topLeftBg = createBackgroundPanel(width: 120, height: 100)
        topLeftBg.position = CGPoint(x: 50, y: -40)
        topLeftContainer.addChild(topLeftBg)

        // Lives display
        livesLabel.position = CGPoint(x: 0, y: 0)
        livesLabel.zPosition = 1
        topLeftContainer.addChild(livesLabel)

        // Create initial lives icons (heart shapes or circles)
        updateLivesDisplay(lives: 3)

        // Score display (below lives)
        scoreLabel.position = CGPoint(x: 0, y: -50)
        scoreLabel.zPosition = 1
        topLeftContainer.addChild(scoreLabel)

        scoreValueLabel.position = CGPoint(x: 0, y: -70)
        scoreValueLabel.zPosition = 1
        topLeftContainer.addChild(scoreValueLabel)

        // Top-right container position
        topRightContainer.position = CGPoint(
            x: halfWidth - insetX - padding - 100,  // Extra offset for right-aligned text
            y: halfHeight - insetY - padding
        )
        addChild(topRightContainer)

        // Add background panel for top-right
        let topRightBg = createBackgroundPanel(width: 120, height: 60)
        topRightBg.position = CGPoint(x: 50, y: -20)
        topRightContainer.addChild(topRightBg)

        // Resources display
        resourcesLabel.position = CGPoint(x: 0, y: 0)
        resourcesLabel.zPosition = 1
        resourcesLabel.horizontalAlignmentMode = .left
        topRightContainer.addChild(resourcesLabel)

        resourcesValueLabel.position = CGPoint(x: 0, y: -20)
        resourcesValueLabel.zPosition = 1
        resourcesValueLabel.horizontalAlignmentMode = .left
        topRightContainer.addChild(resourcesValueLabel)

        // Timer (top center)
        timerLabel.position = CGPoint(x: 0, y: halfHeight - insetY - padding)
        addChild(timerLabel)

        // Add background for timer
        let timerBg = createBackgroundPanel(width: 80, height: 30)
        timerBg.position = CGPoint(x: 0, y: halfHeight - insetY - padding - 5)
        addChild(timerBg)
        timerLabel.zPosition = 1

        // Bottom container (selected character)
        bottomContainer.position = CGPoint(
            x: 0,
            y: -halfHeight + insetY + padding + 30
        )
        addChild(bottomContainer)

        // Add background for bottom
        let bottomBg = createBackgroundPanel(width: 160, height: 50)
        bottomBg.position = CGPoint(x: 0, y: 10)
        bottomContainer.addChild(bottomBg)

        selectedLabel.position = CGPoint(x: 0, y: 20)
        selectedLabel.zPosition = 1
        bottomContainer.addChild(selectedLabel)

        selectedCharacterLabel.position = CGPoint(x: 0, y: 0)
        selectedCharacterLabel.zPosition = 1
        bottomContainer.addChild(selectedCharacterLabel)
    }

    /// Create a semi-transparent background panel
    private func createBackgroundPanel(width: CGFloat, height: CGFloat) -> SKShapeNode {
        let panel = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 8)
        panel.fillColor = SKColor.black.withAlphaComponent(0.5)
        panel.strokeColor = SKColor.white.withAlphaComponent(0.3)
        panel.lineWidth = 1
        panel.zPosition = 0
        return panel
    }

    // MARK: - Updates

    /// Update lives display
    func updateLivesDisplay(lives: Int) {
        // Remove existing icons
        for icon in livesIcons {
            icon.removeFromParent()
        }
        livesIcons.removeAll()

        // Create new icons
        let iconSize: CGFloat = 20
        for i in 0..<lives {
            let icon = createHeartIcon(size: iconSize)
            icon.position = CGPoint(x: CGFloat(i) * (iconSize + 4), y: -25)
            topLeftContainer.addChild(icon)
            livesIcons.append(icon)
        }
    }

    /// Create a heart-shaped icon
    private func createHeartIcon(size: CGFloat) -> SKSpriteNode {
        // Create a simple circle for now (can be replaced with heart sprite)
        let node = SKShapeNode(circleOfRadius: size / 2)
        node.fillColor = SKColor(red: 0.9, green: 0.2, blue: 0.3, alpha: 1.0)
        node.strokeColor = .white
        node.lineWidth = 1

        // Convert to texture for better performance
        let texture = SKView().texture(from: node)
        let sprite = SKSpriteNode(texture: texture, size: CGSize(width: size, height: size))
        return sprite
    }

    /// Update score display
    func updateScore(_ score: Int) {
        scoreValueLabel.text = String(format: "%d", score)

        // Brief scale animation on score change
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.1)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
        scoreValueLabel.run(SKAction.sequence([scaleUp, scaleDown]))
    }

    /// Update resources display
    func updateResources(_ resources: Int) {
        resourcesValueLabel.text = String(format: "%d", resources)

        // Brief color flash on change
        let originalColor = resourcesValueLabel.fontColor
        resourcesValueLabel.fontColor = .white
        let restore = SKAction.run { [weak self] in
            self?.resourcesValueLabel.fontColor = originalColor
        }
        resourcesValueLabel.run(SKAction.sequence([SKAction.wait(forDuration: 0.1), restore]))
    }

    /// Update selected character display
    func updateSelectedCharacter(name: String, health: Int, maxHealth: Int) {
        selectedCharacterLabel.text = name.uppercased()

        // Color based on health percentage
        let healthPercent = CGFloat(health) / CGFloat(maxHealth)
        if healthPercent > 0.6 {
            selectedCharacterLabel.fontColor = .white
        } else if healthPercent > 0.3 {
            selectedCharacterLabel.fontColor = SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)
        } else {
            selectedCharacterLabel.fontColor = SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
        }
    }

    /// Update timer display
    func updateTimer(elapsedTime: TimeInterval) {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        timerLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }

    /// Full update from level manager state
    func update(lives: Int, score: Int, resources: Int, elapsedTime: TimeInterval) {
        // Only update lives if changed (to avoid recreating icons every frame)
        if livesIcons.count != lives {
            updateLivesDisplay(lives: lives)
        }

        // Update other values
        if scoreValueLabel.text != String(score) {
            updateScore(score)
        }

        if resourcesValueLabel.text != String(resources) {
            updateResources(resources)
        }

        updateTimer(elapsedTime: elapsedTime)
    }

    // MARK: - Animations

    /// Flash the lives display when a life is lost
    func flashLifeLost() {
        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: 0.15)
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.15)
        let flash = SKAction.sequence([fadeOut, fadeIn])
        topLeftContainer.run(SKAction.repeat(flash, count: 3))
    }

    /// Highlight score increase
    func highlightScoreIncrease(points: Int) {
        // Create floating "+points" text
        let floater = SKLabelNode(fontNamed: "Helvetica-Bold")
        floater.fontSize = 18
        floater.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
        floater.text = "+\(points)"
        floater.position = CGPoint(x: scoreValueLabel.position.x + 60, y: scoreValueLabel.position.y - 10)
        topLeftContainer.addChild(floater)

        // Animate up and fade out
        let moveUp = SKAction.moveBy(x: 0, y: 30, duration: 0.8)
        let fadeOut = SKAction.fadeOut(withDuration: 0.8)
        let remove = SKAction.removeFromParent()
        floater.run(SKAction.sequence([SKAction.group([moveUp, fadeOut]), remove]))
    }
}
