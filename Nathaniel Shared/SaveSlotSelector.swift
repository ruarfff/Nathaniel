//
//  SaveSlotSelector.swift
//  Nathaniel Shared
//
//  UI overlay for selecting a save slot (save or load).
//

import SpriteKit

// MARK: - Save Slot Selector Mode

/// Mode for the save slot selector
enum SaveSlotSelectorMode {
    case save   // Selecting a slot to save to
    case load   // Selecting a slot to load from
}

// MARK: - Save Slot Selector

/// Overlay for selecting a save slot
class SaveSlotSelector: SKNode {

    // MARK: - Properties

    /// Size of the viewport
    private let viewportSize: CGSize

    /// Current mode (save or load)
    private(set) var mode: SaveSlotSelectorMode = .save

    /// Dark overlay background
    private var overlayBackground: SKShapeNode?

    /// Panel container
    private var panel: SKNode?

    /// Whether the selector is currently visible
    private(set) var isVisible: Bool = false

    // MARK: - Callbacks

    /// Called when a slot is selected
    var onSlotSelected: ((Int) -> Void)?

    /// Called when cancel is tapped
    var onCancel: (() -> Void)?

    // MARK: - Constants

    private let panelWidth: CGFloat = 320
    private let panelHeight: CGFloat = 300
    private let slotHeight: CGFloat = 60
    private let slotSpacing: CGFloat = 10
    private let animationDuration: TimeInterval = 0.2

    // MARK: - Initialization

    init(size: CGSize) {
        self.viewportSize = size
        super.init()

        setupOverlay()
        setupPanel()

        // Start hidden
        isHidden = true
        alpha = 0
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupOverlay() {
        let overlay = SKShapeNode(rectOf: CGSize(width: viewportSize.width * 2, height: viewportSize.height * 2))
        overlay.fillColor = SKColor.black.withAlphaComponent(0.8)
        overlay.strokeColor = .clear
        overlay.zPosition = 0
        overlay.name = "slotSelectorOverlay"
        addChild(overlay)
        overlayBackground = overlay
    }

    private func setupPanel() {
        let panelNode = SKNode()
        panelNode.zPosition = 1

        // Panel background
        let panelBg = SKShapeNode(rectOf: CGSize(width: panelWidth, height: panelHeight), cornerRadius: 16)
        panelBg.fillColor = SKColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 0.95)
        panelBg.strokeColor = SKColor.white.withAlphaComponent(0.3)
        panelBg.lineWidth = 2
        panelNode.addChild(panelBg)

        addChild(panelNode)
        panel = panelNode
    }

    // MARK: - Show/Hide

    /// Show the slot selector in the specified mode
    func show(mode: SaveSlotSelectorMode) {
        guard !isVisible else { return }

        self.mode = mode
        isVisible = true
        isHidden = false

        // Rebuild content based on mode
        rebuildContent()

        // Reset scale and alpha
        panel?.setScale(0.8)
        alpha = 0

        // Animate in
        let fadeIn = SKAction.fadeIn(withDuration: animationDuration)
        let scaleUp = SKAction.scale(to: 1.0, duration: animationDuration)
        scaleUp.timingMode = .easeOut

        run(fadeIn)
        panel?.run(scaleUp)
    }

    /// Hide the slot selector
    func hide(completion: (() -> Void)? = nil) {
        guard isVisible else {
            completion?()
            return
        }

        let fadeOut = SKAction.fadeOut(withDuration: animationDuration)
        let scaleDown = SKAction.scale(to: 0.8, duration: animationDuration)
        scaleDown.timingMode = .easeIn

        let hideAction = SKAction.run { [weak self] in
            self?.isHidden = true
            self?.isVisible = false
            completion?()
        }

        run(SKAction.sequence([fadeOut, hideAction]))
        panel?.run(scaleDown)
    }

    // MARK: - Content Building

    private func rebuildContent() {
        guard let panel = panel else { return }

        // Remove old content (except background)
        panel.children.filter { $0.name?.hasPrefix("slot_") == true || $0.name == "title" || $0.name == "cancelButton" }.forEach { $0.removeFromParent() }

        // Title
        let title = SKLabelNode(fontNamed: "Helvetica-Bold")
        title.text = mode == .save ? "SAVE GAME" : "LOAD GAME"
        title.fontSize = 24
        title.fontColor = .white
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: panelHeight / 2 - 40)
        title.name = "title"
        panel.addChild(title)

        // Get save slots
        let slots = SaveManager.shared.getSaveSlots()

        // Create slot buttons
        let startY = panelHeight / 2 - 90
        for (index, slot) in slots.enumerated() {
            let yPos = startY - CGFloat(index) * (slotHeight + slotSpacing)
            createSlotButton(slot: slot, at: yPos, in: panel)
        }

        // Cancel button
        let cancelY = -panelHeight / 2 + 35
        createCancelButton(at: cancelY, in: panel)
    }

    private func createSlotButton(slot: SaveSlot, at yPosition: CGFloat, in parent: SKNode) {
        let buttonNode = SKNode()
        buttonNode.name = "slot_\(slot.id)"
        buttonNode.position = CGPoint(x: 0, y: yPosition)

        // Button background
        let buttonWidth = panelWidth - 40
        let bgColor: SKColor
        if mode == .load && !slot.hasSave {
            // Empty slots are dimmed in load mode
            bgColor = SKColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 0.5)
        } else if slot.hasSave {
            bgColor = SKColor(red: 0.3, green: 0.4, blue: 0.5, alpha: 1.0)
        } else {
            bgColor = SKColor(red: 0.25, green: 0.3, blue: 0.35, alpha: 1.0)
        }

        let buttonBg = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: slotHeight), cornerRadius: 8)
        buttonBg.fillColor = bgColor
        buttonBg.strokeColor = slot.hasSave ? SKColor.white.withAlphaComponent(0.5) : SKColor.white.withAlphaComponent(0.2)
        buttonBg.lineWidth = 1
        buttonBg.name = "slot_\(slot.id)"
        buttonNode.addChild(buttonBg)

        // Slot number
        let slotLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        slotLabel.text = "Slot \(slot.id)"
        slotLabel.fontSize = 16
        slotLabel.fontColor = .white
        slotLabel.verticalAlignmentMode = .center
        slotLabel.horizontalAlignmentMode = .left
        slotLabel.position = CGPoint(x: -buttonWidth / 2 + 15, y: 10)
        slotLabel.name = "slot_\(slot.id)"
        buttonNode.addChild(slotLabel)

        // Slot info
        let infoLabel = SKLabelNode(fontNamed: "Helvetica")
        infoLabel.text = slot.displaySummary
        infoLabel.fontSize = 12
        infoLabel.fontColor = slot.hasSave ? SKColor.white.withAlphaComponent(0.8) : SKColor.white.withAlphaComponent(0.5)
        infoLabel.verticalAlignmentMode = .center
        infoLabel.horizontalAlignmentMode = .left
        infoLabel.position = CGPoint(x: -buttonWidth / 2 + 15, y: -10)
        infoLabel.name = "slot_\(slot.id)"
        buttonNode.addChild(infoLabel)

        // Timestamp (if saved)
        if let formattedDate = slot.formattedDate {
            let dateLabel = SKLabelNode(fontNamed: "Helvetica")
            dateLabel.text = formattedDate
            dateLabel.fontSize = 10
            dateLabel.fontColor = SKColor.white.withAlphaComponent(0.6)
            dateLabel.verticalAlignmentMode = .center
            dateLabel.horizontalAlignmentMode = .right
            dateLabel.position = CGPoint(x: buttonWidth / 2 - 15, y: 0)
            dateLabel.name = "slot_\(slot.id)"
            buttonNode.addChild(dateLabel)
        }

        parent.addChild(buttonNode)
    }

    private func createCancelButton(at yPosition: CGFloat, in parent: SKNode) {
        let buttonNode = SKNode()
        buttonNode.name = "cancelButton"
        buttonNode.position = CGPoint(x: 0, y: yPosition)

        let buttonBg = SKShapeNode(rectOf: CGSize(width: 100, height: 35), cornerRadius: 6)
        buttonBg.fillColor = SKColor(red: 0.5, green: 0.3, blue: 0.3, alpha: 1.0)
        buttonBg.strokeColor = SKColor.white.withAlphaComponent(0.5)
        buttonBg.lineWidth = 1
        buttonBg.name = "cancelButton"
        buttonNode.addChild(buttonBg)

        let label = SKLabelNode(fontNamed: "Helvetica-Bold")
        label.text = "Cancel"
        label.fontSize = 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.name = "cancelButton"
        buttonNode.addChild(label)

        parent.addChild(buttonNode)
    }

    // MARK: - Touch Handling

    /// Handle touch - returns true if touch was handled
    func handleTouch(at point: CGPoint) -> Bool {
        guard isVisible else { return false }

        let localPoint = convert(point, from: parent!)

        // Check panel content
        guard let panel = panel else { return false }
        let panelPoint = panel.convert(localPoint, from: self)

        // Check cancel button
        if let cancelButton = panel.childNode(withName: "cancelButton"),
           nodeContainsPoint(cancelButton, point: panelPoint) {
            animateButtonPress(cancelButton)
            hide {
                self.onCancel?()
            }
            return true
        }

        // Check slot buttons
        for slotId in 1...SaveManager.slotCount {
            if let slotButton = panel.childNode(withName: "slot_\(slotId)"),
               nodeContainsPoint(slotButton, point: panelPoint) {

                // In load mode, check if slot has save
                if mode == .load {
                    guard let slot = SaveManager.shared.getSlot(slotId), slot.hasSave else {
                        // Empty slot in load mode - ignore tap
                        return true
                    }
                }

                animateButtonPress(slotButton)
                let selectedSlot = slotId
                hide {
                    self.onSlotSelected?(selectedSlot)
                }
                return true
            }
        }

        // Touch on overlay but not on any button - close
        hide {
            self.onCancel?()
        }
        return true
    }

    private func nodeContainsPoint(_ node: SKNode, point: CGPoint) -> Bool {
        let nodePoint = node.convert(point, from: node.parent!)
        if let shape = node.children.first as? SKShapeNode {
            return shape.contains(nodePoint)
        }
        // Fallback to frame check
        let frame = CGRect(x: -panelWidth/2 + 20, y: -slotHeight/2, width: panelWidth - 40, height: slotHeight)
        return frame.contains(nodePoint)
    }

    private func animateButtonPress(_ button: SKNode) {
        let scaleDown = SKAction.scale(to: 0.95, duration: 0.05)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.1)
        button.run(SKAction.sequence([scaleDown, scaleUp]))
    }
}
