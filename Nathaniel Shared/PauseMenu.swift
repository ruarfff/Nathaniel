//
//  PauseMenu.swift
//  Nathaniel Shared
//
//  Pause menu overlay with Resume, Settings, Save, and Exit options.
//

import SpriteKit

// MARK: - Pause Menu

/// Overlay menu displayed when the game is paused
class PauseMenu: OverlayMenu {

    // MARK: - Types

    /// Menu button identifiers
    enum MenuButton: String {
        case resume = "resumeButton"
        case settings = "settingsButton"
        case saveGame = "saveGameButton"
        case exitToMenu = "exitToMenuButton"
    }

    // MARK: - Properties

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

    // MARK: - Setup

    override func setupMenuPanel() {
        let panel = createPanelContainer(width: panelWidth, height: panelHeight)

        // Title
        createTitle("PAUSED", in: panel, panelHeight: panelHeight)

        // Buttons (from top to bottom)
        let buttonStartY: CGFloat = panelHeight / 2 - 110

        createButtonWithIcon(
            in: panel,
            name: MenuButton.resume.rawValue,
            title: "Resume",
            emoji: "▶️",
            width: buttonWidth,
            height: buttonHeight,
            yPosition: buttonStartY,
            color: SKColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1.0)
        )

        createButtonWithIcon(
            in: panel,
            name: MenuButton.settings.rawValue,
            title: "Settings",
            emoji: "⚙️",
            width: buttonWidth,
            height: buttonHeight,
            yPosition: buttonStartY - (buttonHeight + buttonSpacing),
            color: SKColor(red: 0.3, green: 0.4, blue: 0.6, alpha: 1.0)
        )

        createButtonWithIcon(
            in: panel,
            name: MenuButton.saveGame.rawValue,
            title: "Save Game",
            emoji: "💾",
            width: buttonWidth,
            height: buttonHeight,
            yPosition: buttonStartY - 2 * (buttonHeight + buttonSpacing),
            color: SKColor(red: 0.4, green: 0.5, blue: 0.3, alpha: 1.0)
        )

        createButtonWithIcon(
            in: panel,
            name: MenuButton.exitToMenu.rawValue,
            title: "Exit to Menu",
            emoji: "🚪",
            width: buttonWidth,
            height: buttonHeight,
            yPosition: buttonStartY - 3 * (buttonHeight + buttonSpacing),
            color: SKColor(red: 0.6, green: 0.3, blue: 0.3, alpha: 1.0)
        )
    }

    // MARK: - Show/Hide

    override func hide(completion: (() -> Void)? = nil) {
        // Also hide confirmation if showing
        hideConfirmation()
        super.hide(completion: completion)
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

    override func handleTouch(at point: CGPoint) -> Bool {
        guard isVisible else { return false }

        // Convert point to local coordinates
        let localPoint = convert(point, from: parent!)

        // Check confirmation dialog first if showing
        if isShowingConfirmation, let dialog = confirmationDialog {
            let dialogPoint = dialog.convert(localPoint, from: self)

            if let cancelButton = dialog.childNode(withName: "cancelExit"),
               nodeContainsPoint(cancelButton, point: dialogPoint, fallbackSize: CGSize(width: 100, height: 40)) {
                animateButtonPress(cancelButton)
                hideConfirmation()
                return true
            }

            if let confirmButton = dialog.childNode(withName: "confirmExit"),
               nodeContainsPoint(confirmButton, point: dialogPoint, fallbackSize: CGSize(width: 100, height: 40)) {
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
        let buttonSize = CGSize(width: buttonWidth, height: buttonHeight)

        // Resume button
        if let button = panel.childNode(withName: MenuButton.resume.rawValue),
           nodeContainsPoint(button, point: panelPoint, fallbackSize: buttonSize) {
            animateButtonPress(button)
            hide {
                self.onResume?()
            }
            return true
        }

        // Settings button
        if let button = panel.childNode(withName: MenuButton.settings.rawValue),
           nodeContainsPoint(button, point: panelPoint, fallbackSize: buttonSize) {
            animateButtonPress(button)
            onSettings?()
            return true
        }

        // Save Game button
        if let button = panel.childNode(withName: MenuButton.saveGame.rawValue),
           nodeContainsPoint(button, point: panelPoint, fallbackSize: buttonSize) {
            animateButtonPress(button)
            onSaveGame?()
            return true
        }

        // Exit to Menu button
        if let button = panel.childNode(withName: MenuButton.exitToMenu.rawValue),
           nodeContainsPoint(button, point: panelPoint, fallbackSize: buttonSize) {
            animateButtonPress(button)
            showExitConfirmation()
            return true
        }

        // Touch on overlay (outside panel) does nothing (keeps menu open)
        return true
    }
}
