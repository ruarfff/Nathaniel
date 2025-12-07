//
//  BuildMenu.swift
//  Nathaniel Shared
//
//  Bottom panel build menu for Hermes to construct defensive towers.
//  Shows tower types with icons, names, and costs. Supports drag-to-place.
//

import SpriteKit

// MARK: - BuildMenu Delegate

/// Protocol for build menu events
protocol BuildMenuDelegate: AnyObject {
    /// Called when the player starts dragging a tower from the menu
    func buildMenu(_ menu: BuildMenu, didStartDragging type: TowerType, from position: CGPoint)

    /// Called when the player finishes dragging (releases touch)
    func buildMenu(_ menu: BuildMenu, didEndDragging type: TowerType, at position: CGPoint)

    /// Called when dragging is cancelled (e.g., touch moved back to menu)
    func buildMenu(_ menu: BuildMenu, didCancelDragging type: TowerType)

    /// Get current resource count for affordability display
    func buildMenuCurrentResources(_ menu: BuildMenu) -> Int
}

// MARK: - BuildMenuItem Node

/// Visual representation of a tower type in the build menu
class BuildMenuItemNode: SKNode {

    // MARK: - Properties

    let towerType: TowerType

    private let backgroundNode: SKShapeNode
    private let iconNode: SKSpriteNode
    private let nameLabel: SKLabelNode
    private let costLabel: SKLabelNode

    /// Whether this item can currently be afforded
    var isAffordable: Bool = true {
        didSet {
            updateAffordabilityVisuals()
        }
    }

    /// Whether this item is currently being dragged
    var isDragging: Bool = false {
        didSet {
            updateDraggingVisuals()
        }
    }

    // MARK: - Constants

    static let itemWidth: CGFloat = 100
    static let itemHeight: CGFloat = 90

    // MARK: - Initialization

    init(type: TowerType) {
        self.towerType = type

        // Create background
        backgroundNode = SKShapeNode(rectOf: CGSize(width: Self.itemWidth, height: Self.itemHeight), cornerRadius: 8)
        backgroundNode.fillColor = SKColor(white: 0.2, alpha: 0.8)
        backgroundNode.strokeColor = SKColor.white.withAlphaComponent(0.5)
        backgroundNode.lineWidth = 2

        // Create icon (using tower texture or placeholder)
        let iconTexture = SKTexture(imageNamed: type.iconTextureName)
        iconNode = SKSpriteNode(texture: iconTexture)
        iconNode.size = CGSize(width: 40, height: 40)

        // Create name label
        nameLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        nameLabel.fontSize = 12
        nameLabel.fontColor = .white
        nameLabel.text = type.displayName
        nameLabel.horizontalAlignmentMode = .center
        nameLabel.verticalAlignmentMode = .top

        // Create cost label
        costLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        costLabel.fontSize = 14
        costLabel.fontColor = SKColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 1.0)
        costLabel.text = "\(type.cost)"
        costLabel.horizontalAlignmentMode = .center
        costLabel.verticalAlignmentMode = .top

        super.init()

        setupLayout()
        name = "buildMenuItem_\(type.rawValue)"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    private func setupLayout() {
        // Background
        addChild(backgroundNode)

        // Icon at top
        iconNode.position = CGPoint(x: 0, y: 15)
        iconNode.zPosition = 1
        addChild(iconNode)

        // Name below icon
        nameLabel.position = CGPoint(x: 0, y: -15)
        nameLabel.zPosition = 1
        addChild(nameLabel)

        // Cost at bottom
        costLabel.position = CGPoint(x: 0, y: -32)
        costLabel.zPosition = 1
        addChild(costLabel)
    }

    // MARK: - Visual Updates

    private func updateAffordabilityVisuals() {
        if isAffordable {
            alpha = 1.0
            backgroundNode.fillColor = SKColor(white: 0.2, alpha: 0.8)
            backgroundNode.strokeColor = SKColor.white.withAlphaComponent(0.5)
            costLabel.fontColor = SKColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 1.0)
        } else {
            alpha = 0.5
            backgroundNode.fillColor = SKColor(white: 0.1, alpha: 0.8)
            backgroundNode.strokeColor = SKColor.gray.withAlphaComponent(0.3)
            costLabel.fontColor = SKColor.red.withAlphaComponent(0.7)
        }
    }

    private func updateDraggingVisuals() {
        if isDragging {
            backgroundNode.strokeColor = SKColor.yellow
            backgroundNode.lineWidth = 3
        } else {
            backgroundNode.strokeColor = isAffordable ? SKColor.white.withAlphaComponent(0.5) : SKColor.gray.withAlphaComponent(0.3)
            backgroundNode.lineWidth = 2
        }
    }

    // MARK: - Hit Testing

    func containsTouchPoint(_ point: CGPoint) -> Bool {
        let localPoint = convert(point, from: parent ?? self)
        return backgroundNode.contains(localPoint)
    }
}

// MARK: - BuildMenu

/// Bottom panel build menu for tower construction
class BuildMenu: SKNode {

    // MARK: - Properties

    weak var delegate: BuildMenuDelegate?

    /// Menu items for each tower type
    private var menuItems: [BuildMenuItemNode] = []

    /// Background panel
    private let backgroundPanel: SKShapeNode

    /// Currently dragging item (nil if not dragging)
    private var draggingItem: BuildMenuItemNode?

    /// Ghost tower shown while dragging
    private var ghostTower: SKSpriteNode?

    /// Menu visibility
    private(set) var isVisible: Bool = false

    /// Size of the viewport
    private let viewportSize: CGSize

    // MARK: - Constants

    /// Menu height as percentage of viewport
    static let menuHeightRatio: CGFloat = 0.25

    /// Menu width as percentage of viewport
    static let menuWidthRatio: CGFloat = 0.8

    /// Spacing between menu items
    static let itemSpacing: CGFloat = 20

    // MARK: - Initialization

    init(size: CGSize) {
        self.viewportSize = size

        let menuWidth = size.width * Self.menuWidthRatio
        let menuHeight = size.height * Self.menuHeightRatio

        // Create background panel
        backgroundPanel = SKShapeNode(rectOf: CGSize(width: menuWidth, height: menuHeight), cornerRadius: 12)
        backgroundPanel.fillColor = SKColor.black.withAlphaComponent(0.7)
        backgroundPanel.strokeColor = SKColor.white.withAlphaComponent(0.4)
        backgroundPanel.lineWidth = 2

        super.init()

        setupMenu()
        zPosition = 400  // Below HUD but above game elements

        // Start hidden
        isHidden = true
        alpha = 0
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupMenu() {
        let halfHeight = viewportSize.height / 2
        let menuHeight = viewportSize.height * Self.menuHeightRatio

        // Position panel at bottom center
        position = CGPoint(x: 0, y: -halfHeight + menuHeight / 2 + 10)

        // Add background
        addChild(backgroundPanel)

        // Create menu items for each tower type
        let types = TowerType.allCases
        let totalWidth = CGFloat(types.count) * BuildMenuItemNode.itemWidth + CGFloat(types.count - 1) * Self.itemSpacing
        let startX = -totalWidth / 2 + BuildMenuItemNode.itemWidth / 2

        for (index, type) in types.enumerated() {
            let item = BuildMenuItemNode(type: type)
            item.position = CGPoint(
                x: startX + CGFloat(index) * (BuildMenuItemNode.itemWidth + Self.itemSpacing),
                y: 5
            )
            item.zPosition = 1
            addChild(item)
            menuItems.append(item)
        }

        // Add title label
        let titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        titleLabel.fontSize = 14
        titleLabel.fontColor = SKColor.white.withAlphaComponent(0.7)
        titleLabel.text = "BUILD TOWERS"
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .top
        titleLabel.position = CGPoint(x: 0, y: viewportSize.height * Self.menuHeightRatio / 2 - 10)
        titleLabel.zPosition = 1
        addChild(titleLabel)
    }

    // MARK: - Visibility

    /// Show the build menu with animation
    func show() {
        guard !isVisible else { return }
        isVisible = true
        isHidden = false

        // Update affordability before showing
        updateAffordability()

        // Animate in from bottom
        let targetY = position.y
        position.y = targetY - 50

        let moveUp = SKAction.moveTo(y: targetY, duration: 0.2)
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        moveUp.timingMode = .easeOut
        run(SKAction.group([moveUp, fadeIn]))
    }

    /// Hide the build menu with animation
    func hide() {
        guard isVisible else { return }
        isVisible = false

        // Cancel any active drag
        if let item = draggingItem {
            item.isDragging = false
            delegate?.buildMenu(self, didCancelDragging: item.towerType)
            draggingItem = nil
        }
        removeGhostTower()

        // Animate out
        let moveDown = SKAction.moveBy(x: 0, y: -50, duration: 0.2)
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        moveDown.timingMode = .easeIn

        run(SKAction.sequence([
            SKAction.group([moveDown, fadeOut]),
            SKAction.run { [weak self] in
                self?.isHidden = true
                // Reset position for next show
                if let halfHeight = self?.viewportSize.height {
                    self?.position.y = -halfHeight / 2 + halfHeight * Self.menuHeightRatio / 2 + 10
                }
            }
        ]))
    }

    /// Toggle visibility
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    // MARK: - Affordability

    /// Update which items can be afforded
    func updateAffordability() {
        guard let delegate = delegate else { return }
        let resources = delegate.buildMenuCurrentResources(self)

        for item in menuItems {
            item.isAffordable = TowerConfig.canAfford(item.towerType, currentResources: resources)
        }
    }

    // MARK: - Touch Handling

    /// Handle touch began - returns true if touch was handled
    func handleTouchBegan(at point: CGPoint) -> Bool {
        guard isVisible else { return false }

        let localPoint = convert(point, from: parent ?? self)

        // Check if touch is on a menu item
        for item in menuItems {
            if item.containsTouchPoint(localPoint) && item.isAffordable {
                // Start dragging
                draggingItem = item
                item.isDragging = true

                // Create ghost tower
                createGhostTower(for: item.towerType, at: point)

                // Notify delegate
                delegate?.buildMenu(self, didStartDragging: item.towerType, from: point)
                return true
            }
        }

        // Check if touch is on menu background
        if backgroundPanel.contains(localPoint) {
            return true  // Consume touch but don't do anything
        }

        return false
    }

    /// Handle touch moved - returns true if touch was handled
    func handleTouchMoved(to point: CGPoint) -> Bool {
        guard isVisible, draggingItem != nil else { return false }

        // Move ghost tower
        ghostTower?.position = point

        return true
    }

    /// Handle touch ended - returns true if touch was handled
    func handleTouchEnded(at point: CGPoint) -> Bool {
        guard isVisible, let dragging = draggingItem else { return false }

        dragging.isDragging = false
        draggingItem = nil
        removeGhostTower()

        // Check if released outside menu
        let localPoint = convert(point, from: parent ?? self)
        if !backgroundPanel.contains(localPoint) {
            // Valid placement attempt
            delegate?.buildMenu(self, didEndDragging: dragging.towerType, at: point)
        } else {
            // Released back on menu - cancel
            delegate?.buildMenu(self, didCancelDragging: dragging.towerType)
        }

        return true
    }

    /// Handle touch cancelled
    func handleTouchCancelled() {
        guard let dragging = draggingItem else { return }

        dragging.isDragging = false
        draggingItem = nil
        removeGhostTower()

        delegate?.buildMenu(self, didCancelDragging: dragging.towerType)
    }

    // MARK: - Ghost Tower

    /// Create a ghost tower sprite that follows the drag
    private func createGhostTower(for type: TowerType, at position: CGPoint) {
        removeGhostTower()

        let ghost = SKSpriteNode(imageNamed: type.iconTextureName)
        ghost.size = CGSize(width: 50, height: 50)
        ghost.position = position
        ghost.alpha = 0.6
        ghost.zPosition = 450  // Above menu but below HUD
        ghost.name = "ghostTower"

        parent?.addChild(ghost)
        ghostTower = ghost
    }

    /// Remove the ghost tower
    private func removeGhostTower() {
        ghostTower?.removeFromParent()
        ghostTower = nil
    }

    /// Update ghost tower validity visual (red if invalid, normal if valid)
    func updateGhostValidity(isValid: Bool) {
        if isValid {
            ghostTower?.color = .white
            ghostTower?.colorBlendFactor = 0
        } else {
            ghostTower?.color = .red
            ghostTower?.colorBlendFactor = 0.7
        }
    }

    // MARK: - Queries

    /// Check if currently dragging
    var isDragging: Bool {
        return draggingItem != nil
    }

    /// Get currently dragging tower type
    var draggingTowerType: TowerType? {
        return draggingItem?.towerType
    }
}
