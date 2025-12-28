//
//  PauseMenu.swift
//  Nathaniel Shared
//
//  Pause menu overlay with Resume, Settings, Save, and Exit options.
//

import SpriteKit

// MARK: - Pause Menu

/// Overlay menu displayed when the game is paused
class PauseMenu: SKNode {

    // MARK: - Types

    /// Menu button identifiers
    enum MenuButton: String {
        case resume = "resumeButton"
        case settings = "settingsButton"
        case saveGame = "saveGameButton"
        case exitToMenu = "exitToMenuButton"
    }

    // MARK: - Properties

    /// Size of the viewport
    private let viewportSize: CGSize

    /// Dark overlay background
    private var overlayBackground: SKShapeNode?

    /// Menu panel container
    private var menuPanel: SKNode?

    /// Whether the menu is currently visible
    private(set) var isVisible: Bool = false

    /// Whether exit confirmation is showing
    private(set) var isShowingConfirmation: Bool = false

    /// Confirmation dialog node
    private var confirmationDialog: SKNode?

    // MARK: - Callbacks

    /// Called when Resume button is tapped
    var onResume: (() -> Void)?

    /// Called when Settings button is tapped
    var onSettings: (() -> Void)?

    /// Called when Save Game button is tapped
    var onSaveGame: (() -> Void)?

    /// Called when Exit to Menu is confirmed
    var onExitToMenu: (() -> Void)?

    // MARK: - Constants

    private let panelWidth: CGFloat = 300
    private let panelHeight: CGFloat = 350
    private let buttonWidth: CGFloat = 220
    private let buttonHeight: CGFloat = 50
    private let buttonSpacing: CGFloat = 15
    private let animationDuration: TimeInterval = 0.25

    // MARK: - Initialization

    init(size: CGSize) {
        self.viewportSize = size
        super.init()

        setupOverlay()
        setupMenuPanel()

        // Start hidden
        isHidden = true
        alpha = 0
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupOverlay() {
        // Full-screen dark overlay
        let overlay = SKShapeNode(rectOf: CGSize(width: viewportSize.width * 2, height: viewportSize.height * 2))
        overlay.fillColor = SKColor.black.withAlphaComponent(0.7)
        overlay.strokeColor = .clear
        overlay.zPosition = 0
        overlay.name = "pauseOverlay"
        addChild(overlay)
        overlayBackground = overlay
    }

    private func setupMenuPanel() {
        let panel = SKNode()
        panel.zPosition = 1

        // Panel background
        let panelBg = SKShapeNode(rectOf: CGSize(width: panelWidth, height: panelHeight), cornerRadius: 16)
        panelBg.fillColor = SKColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 0.95)
        panelBg.strokeColor = SKColor.white.withAlphaComponent(0.3)
        panelBg.lineWidth = 2
        panel.addChild(panelBg)

        // Title
        let titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        titleLabel.text = "PAUSED"
        titleLabel.fontSize = 32
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: panelHeight / 2 - 50)
        panel.addChild(titleLabel)

        // Buttons (from top to bottom)
        let buttonStartY: CGFloat = panelHeight / 2 - 110

        createButton(
            in: panel,
            name: MenuButton.resume.rawValue,
            title: "Resume",
            icon: "play.fill",
            emoji: "▶️",
            yPosition: buttonStartY,
            color: SKColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1.0)
        )

        createButton(
            in: panel,
            name: MenuButton.settings.rawValue,
            title: "Settings",
            icon: "gear",
            emoji: "⚙️",
            yPosition: buttonStartY - (buttonHeight + buttonSpacing),
            color: SKColor(red: 0.3, green: 0.4, blue: 0.6, alpha: 1.0)
        )

        createButton(
            in: panel,
            name: MenuButton.saveGame.rawValue,
            title: "Save Game",
            icon: "square.and.arrow.down",
            emoji: "💾",
            yPosition: buttonStartY - 2 * (buttonHeight + buttonSpacing),
            color: SKColor(red: 0.4, green: 0.5, blue: 0.3, alpha: 1.0)
        )

        createButton(
            in: panel,
            name: MenuButton.exitToMenu.rawValue,
            title: "Exit to Menu",
            icon: "door.left.hand.open",
            emoji: "🚪",
            yPosition: buttonStartY - 3 * (buttonHeight + buttonSpacing),
            color: SKColor(red: 0.6, green: 0.3, blue: 0.3, alpha: 1.0)
        )

        addChild(panel)
        menuPanel = panel
    }

    private func createButton(in parent: SKNode, name: String, title: String, icon: String, emoji: String, yPosition: CGFloat, color: SKColor) {
        let button = SKNode()
        button.name = name
        button.position = CGPoint(x: 0, y: yPosition)

        // Button background
        let buttonBg = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 10)
        buttonBg.fillColor = color
        buttonBg.strokeColor = SKColor.white.withAlphaComponent(0.5)
        buttonBg.lineWidth = 1
        buttonBg.name = name
        button.addChild(buttonBg)

        // Icon (emoji)
        let iconLabel = SKLabelNode(fontNamed: "Helvetica")
        iconLabel.text = emoji
        iconLabel.fontSize = 22
        iconLabel.verticalAlignmentMode = .center
        iconLabel.horizontalAlignmentMode = .center
        iconLabel.position = CGPoint(x: -buttonWidth / 2 + 30, y: 0)
        iconLabel.name = name
        button.addChild(iconLabel)

        // Title
        let titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        titleLabel.text = title
        titleLabel.fontSize = 18
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.position = CGPoint(x: -buttonWidth / 2 + 55, y: 0)
        titleLabel.name = name
        button.addChild(titleLabel)

        parent.addChild(button)
    }

    // MARK: - Show/Hide

    /// Show the pause menu with animation
    func show() {
        guard !isVisible else { return }

        isVisible = true
        isHidden = false

        // Reset scale and alpha
        menuPanel?.setScale(0.8)
        alpha = 0

        // Animate in
        let fadeIn = SKAction.fadeIn(withDuration: animationDuration)
        let scaleUp = SKAction.scale(to: 1.0, duration: animationDuration)
        scaleUp.timingMode = .easeOut

        run(fadeIn)
        menuPanel?.run(scaleUp)
    }

    /// Hide the pause menu with animation
    func hide(completion: (() -> Void)? = nil) {
        guard isVisible else {
            completion?()
            return
        }

        // Animate out
        let fadeOut = SKAction.fadeOut(withDuration: animationDuration)
        let scaleDown = SKAction.scale(to: 0.8, duration: animationDuration)
        scaleDown.timingMode = .easeIn

        let hideAction = SKAction.run { [weak self] in
            self?.isHidden = true
            self?.isVisible = false
            completion?()
        }

        run(SKAction.sequence([fadeOut, hideAction]))
        menuPanel?.run(scaleDown)

        // Also hide confirmation if showing
        hideConfirmation()
    }

    // MARK: - Confirmation Dialog

    /// Show exit confirmation dialog
    func showExitConfirmation() {
        guard !isShowingConfirmation else { return }

        isShowingConfirmation = true

        // Dim the menu panel
        menuPanel?.alpha = 0.3

        // Create confirmation dialog
        let dialog = SKNode()
        dialog.zPosition = 2

        // Dialog background
        let dialogBg = SKShapeNode(rectOf: CGSize(width: 280, height: 180), cornerRadius: 12)
        dialogBg.fillColor = SKColor(red: 0.2, green: 0.15, blue: 0.15, alpha: 0.98)
        dialogBg.strokeColor = SKColor(red: 0.8, green: 0.4, blue: 0.4, alpha: 1.0)
        dialogBg.lineWidth = 2
        dialog.addChild(dialogBg)

        // Warning icon
        let warningIcon = SKLabelNode(fontNamed: "Helvetica")
        warningIcon.text = "⚠️"
        warningIcon.fontSize = 32
        warningIcon.position = CGPoint(x: 0, y: 50)
        dialog.addChild(warningIcon)

        // Message
        let messageLabel = SKLabelNode(fontNamed: "Helvetica")
        messageLabel.text = "Unsaved progress will be lost."
        messageLabel.fontSize = 16
        messageLabel.fontColor = .white
        messageLabel.verticalAlignmentMode = .center
        messageLabel.horizontalAlignmentMode = .center
        messageLabel.position = CGPoint(x: 0, y: 10)
        dialog.addChild(messageLabel)

        let questionLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        questionLabel.text = "Exit anyway?"
        questionLabel.fontSize = 18
        questionLabel.fontColor = .white
        questionLabel.verticalAlignmentMode = .center
        questionLabel.horizontalAlignmentMode = .center
        questionLabel.position = CGPoint(x: 0, y: -15)
        dialog.addChild(questionLabel)

        // Cancel button
        let cancelButton = createConfirmButton(
            name: "cancelExit",
            title: "Cancel",
            xPosition: -70,
            color: SKColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 1.0)
        )
        cancelButton.position.y = -60
        dialog.addChild(cancelButton)

        // Confirm button
        let confirmButton = createConfirmButton(
            name: "confirmExit",
            title: "Exit",
            xPosition: 70,
            color: SKColor(red: 0.7, green: 0.3, blue: 0.3, alpha: 1.0)
        )
        confirmButton.position.y = -60
        dialog.addChild(confirmButton)

        // Animate in
        dialog.setScale(0.8)
        dialog.alpha = 0
        addChild(dialog)
        confirmationDialog = dialog

        let fadeIn = SKAction.fadeIn(withDuration: 0.15)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.15)
        dialog.run(SKAction.group([fadeIn, scaleUp]))
    }

    private func createConfirmButton(name: String, title: String, xPosition: CGFloat, color: SKColor) -> SKNode {
        let button = SKNode()
        button.name = name
        button.position = CGPoint(x: xPosition, y: 0)

        let buttonBg = SKShapeNode(rectOf: CGSize(width: 100, height: 40), cornerRadius: 8)
        buttonBg.fillColor = color
        buttonBg.strokeColor = .white.withAlphaComponent(0.5)
        buttonBg.lineWidth = 1
        buttonBg.name = name
        button.addChild(buttonBg)

        let titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        titleLabel.text = title
        titleLabel.fontSize = 16
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.name = name
        button.addChild(titleLabel)

        return button
    }

    /// Hide the confirmation dialog
    func hideConfirmation() {
        guard isShowingConfirmation else { return }

        isShowingConfirmation = false
        menuPanel?.alpha = 1.0

        if let dialog = confirmationDialog {
            let fadeOut = SKAction.fadeOut(withDuration: 0.15)
            let scaleDown = SKAction.scale(to: 0.8, duration: 0.15)
            let remove = SKAction.removeFromParent()
            dialog.run(SKAction.sequence([SKAction.group([fadeOut, scaleDown]), remove]))
            confirmationDialog = nil
        }
    }

    // MARK: - Touch Handling

    /// Handle touch on pause menu - returns true if touch was handled
    func handleTouch(at point: CGPoint) -> Bool {
        guard isVisible else { return false }

        // Convert point to local coordinates
        let localPoint = convert(point, from: parent!)

        // Check confirmation dialog first if showing
        if isShowingConfirmation, let dialog = confirmationDialog {
            let dialogPoint = dialog.convert(localPoint, from: self)

            if let cancelButton = dialog.childNode(withName: "cancelExit"),
               nodeContainsPoint(cancelButton, point: dialogPoint) {
                animateButtonPress(cancelButton)
                hideConfirmation()
                return true
            }

            if let confirmButton = dialog.childNode(withName: "confirmExit"),
               nodeContainsPoint(confirmButton, point: dialogPoint) {
                animateButtonPress(confirmButton)
                hide {
                    self.onExitToMenu?()
                }
                return true
            }

            // Tap outside dialog cancels it
            hideConfirmation()
            return true
        }

        // Check menu buttons
        guard let panel = menuPanel else { return false }
        let panelPoint = panel.convert(localPoint, from: self)

        // Resume button
        if let button = panel.childNode(withName: MenuButton.resume.rawValue),
           nodeContainsPoint(button, point: panelPoint) {
            animateButtonPress(button)
            hide {
                self.onResume?()
            }
            return true
        }

        // Settings button
        if let button = panel.childNode(withName: MenuButton.settings.rawValue),
           nodeContainsPoint(button, point: panelPoint) {
            animateButtonPress(button)
            onSettings?()
            return true
        }

        // Save Game button
        if let button = panel.childNode(withName: MenuButton.saveGame.rawValue),
           nodeContainsPoint(button, point: panelPoint) {
            animateButtonPress(button)
            onSaveGame?()
            return true
        }

        // Exit to Menu button
        if let button = panel.childNode(withName: MenuButton.exitToMenu.rawValue),
           nodeContainsPoint(button, point: panelPoint) {
            animateButtonPress(button)
            showExitConfirmation()
            return true
        }

        // Touch on overlay (outside panel) does nothing (keeps menu open)
        return true
    }

    private func nodeContainsPoint(_ node: SKNode, point: CGPoint) -> Bool {
        // Check if point is within the node's bounding box
        let nodePoint = node.convert(point, from: node.parent!)
        if let shape = node.children.first as? SKShapeNode {
            return shape.contains(nodePoint)
        }
        // Fallback to frame check
        let frame = CGRect(x: -buttonWidth/2, y: -buttonHeight/2, width: buttonWidth, height: buttonHeight)
        return frame.contains(nodePoint)
    }

    private func animateButtonPress(_ button: SKNode) {
        let scaleDown = SKAction.scale(to: 0.95, duration: 0.05)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.1)
        button.run(SKAction.sequence([scaleDown, scaleUp]))
    }
}
