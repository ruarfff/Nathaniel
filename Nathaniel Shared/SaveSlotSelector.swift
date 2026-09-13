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
    case save // Selecting a slot to save to
    case load // Selecting a slot to load from
}

// MARK: - Save Slot Selector

/// Overlay for selecting a save slot
class SaveSlotSelector: OverlayMenu {
    // MARK: - Properties

    /// Current mode (save or load)
    private(set) var mode: SaveSlotSelectorMode = .save

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

    // MARK: - Initialization

    override init(size: CGSize) {
        super.init(size: size)
        animationDuration = 0.2
        overlayBackground?.fillColor = SKColor.black.withAlphaComponent(0.8)
        overlayBackground?.name = "slotSelectorOverlay"
    }

    // MARK: - Setup

    override func setupMenuPanel() {
        _ = createPanelContainer(width: self.panelWidth, height: self.panelHeight)
    }

    // MARK: - Show/Hide

    /// Show the slot selector in the specified mode
    func show(mode: SaveSlotSelectorMode) {
        guard !isVisible else { return }

        self.mode = mode
        // Rebuild content based on mode
        self.rebuildContent()
        super.show()
    }

    // MARK: - Content Building

    private func rebuildContent() {
        guard let panel = menuPanel else { return }

        // Remove old content (except background)
        panel.children.filter { $0.name?.hasPrefix("slot_") == true || $0.name == "title" || $0.name == "cancelButton" }
            .forEach { $0.removeFromParent() }

        // Title
        let title = SKLabelNode(fontNamed: "Helvetica-Bold")
        title.text = self.mode == .save ? "SAVE GAME" : "LOAD GAME"
        title.fontSize = 24
        title.fontColor = .white
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: self.panelHeight / 2 - 40)
        title.name = "title"
        panel.addChild(title)

        // Get save slots
        let slots = SaveManager.shared.getSaveSlots()

        // Create slot buttons
        let startY = self.panelHeight / 2 - 90
        for (index, slot) in slots.enumerated() {
            let yPos = startY - CGFloat(index) * (self.slotHeight + self.slotSpacing)
            self.createSlotButton(slot: slot, at: yPos, in: panel)
        }

        // Cancel button
        let cancelY = -self.panelHeight / 2 + 35
        self.createCancelButton(at: cancelY, in: panel)
    }

    private func createSlotButton(slot: SaveSlot, at yPosition: CGFloat, in parent: SKNode) {
        let buttonNode = SKNode()
        buttonNode.name = "slot_\(slot.id)"
        buttonNode.position = CGPoint(x: 0, y: yPosition)

        // Button background
        let buttonWidth = self.panelWidth - 40
        let bgColor = if self.mode == .load && !slot.hasSave {
            // Empty slots are dimmed in load mode
            SKColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 0.5)
        } else if slot.hasSave {
            SKColor(red: 0.3, green: 0.4, blue: 0.5, alpha: 1.0)
        } else {
            SKColor(red: 0.25, green: 0.3, blue: 0.35, alpha: 1.0)
        }

        let buttonBg = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: slotHeight), cornerRadius: 8)
        buttonBg.fillColor = bgColor
        buttonBg.strokeColor = slot.hasSave
            ? SKColor.white.withAlphaComponent(0.5)
            : SKColor.white.withAlphaComponent(0.2)
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
        infoLabel.fontColor = slot.hasSave
            ? SKColor.white.withAlphaComponent(0.8)
            : SKColor.white.withAlphaComponent(0.5)
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
    override func handleTouch(at point: CGPoint) -> Bool {
        guard isVisible else { return false }

        let localPoint = convert(point, from: parent!)

        // Check panel content
        guard let panel = menuPanel else { return false }
        let panelPoint = panel.convert(localPoint, from: self)

        // Check cancel button
        if let cancelButton = panel.childNode(withName: "cancelButton"),
           nodeContainsPoint(
               cancelButton,
               point: panelPoint,
               fallbackSize: CGSize(width: panelWidth - 40, height: slotHeight)
           )
        {
            animateButtonPress(cancelButton)
            hide()
            self.onCancel?()
            return true
        }

        // Check slot buttons
        for slotId in 1 ... SaveManager.slotCount {
            if let slotButton = panel.childNode(withName: "slot_\(slotId)"),
               nodeContainsPoint(
                   slotButton,
                   point: panelPoint,
                   fallbackSize: CGSize(width: panelWidth - 40, height: slotHeight)
               )
            {
                // In load mode, check if slot has save
                if self.mode == .load {
                    guard let slot = SaveManager.shared.getSlot(slotId), slot.hasSave else {
                        // Empty slot in load mode - ignore tap
                        return true
                    }
                }

                animateButtonPress(slotButton)
                hide()
                self.onSlotSelected?(slotId)
                return true
            }
        }

        // Touch on overlay but not on any button - close
        hide()
        self.onCancel?()
        return true
    }
}
