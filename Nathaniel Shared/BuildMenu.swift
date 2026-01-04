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
            self.updateAffordabilityVisuals()
        }
    }

    /// Whether this item is currently being dragged
    var isDragging: Bool = false {
        didSet {
            self.updateDraggingVisuals()
        }
    }

    // MARK: - Constants

    static var itemWidth: CGFloat { GameBalance.UI.BuildMenu.itemWidth }
    static var itemHeight: CGFloat { GameBalance.UI.BuildMenu.itemHeight }

    // MARK: - Initialization

    init(type: TowerType) {
        self.towerType = type

        // Create background
        self.backgroundNode = SKShapeNode(
            rectOf: CGSize(width: Self.itemWidth, height: Self.itemHeight),
            cornerRadius: 8
        )
        self.backgroundNode.fillColor = SKColor(white: 0.2, alpha: 0.8)
        self.backgroundNode.strokeColor = SKColor.white.withAlphaComponent(0.5)
        self.backgroundNode.lineWidth = 2

        // Create icon (using tower texture or placeholder)
        let iconTexture = SKTexture(imageNamed: type.iconTextureName)
        self.iconNode = SKSpriteNode(texture: iconTexture)
        self.iconNode.size = CGSize(width: 40, height: 40)

        // Create name label
        self.nameLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        self.nameLabel.fontSize = 12
        self.nameLabel.fontColor = .white
        self.nameLabel.text = type.displayName
        self.nameLabel.horizontalAlignmentMode = .center
        self.nameLabel.verticalAlignmentMode = .top

        // Create cost label
        self.costLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        self.costLabel.fontSize = 14
        self.costLabel.fontColor = SKColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 1.0)
        self.costLabel.text = "\(type.cost)"
        self.costLabel.horizontalAlignmentMode = .center
        self.costLabel.verticalAlignmentMode = .top

        super.init()

        self.setupLayout()
        name = "buildMenuItem_\(type.rawValue)"
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    private func setupLayout() {
        // Background
        addChild(self.backgroundNode)

        // Icon at top
        self.iconNode.position = CGPoint(x: 0, y: 15)
        self.iconNode.zPosition = 1
        addChild(self.iconNode)

        // Name below icon
        self.nameLabel.position = CGPoint(x: 0, y: -15)
        self.nameLabel.zPosition = 1
        addChild(self.nameLabel)

        // Cost at bottom
        self.costLabel.position = CGPoint(x: 0, y: -32)
        self.costLabel.zPosition = 1
        addChild(self.costLabel)
    }

    // MARK: - Visual Updates

    private func updateAffordabilityVisuals() {
        if self.isAffordable {
            alpha = 1.0
            self.backgroundNode.fillColor = SKColor(white: 0.2, alpha: 0.8)
            self.backgroundNode.strokeColor = SKColor.white.withAlphaComponent(0.5)
            self.costLabel.fontColor = SKColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 1.0)
        } else {
            alpha = 0.5
            self.backgroundNode.fillColor = SKColor(white: 0.1, alpha: 0.8)
            self.backgroundNode.strokeColor = SKColor.gray.withAlphaComponent(0.3)
            self.costLabel.fontColor = SKColor.red.withAlphaComponent(0.7)
        }
    }

    private func updateDraggingVisuals() {
        if self.isDragging {
            self.backgroundNode.strokeColor = SKColor.yellow
            self.backgroundNode.lineWidth = 3
        } else {
            self.backgroundNode.strokeColor = self.isAffordable
                ? SKColor.white.withAlphaComponent(0.5)
                : SKColor.gray.withAlphaComponent(0.3)
            self.backgroundNode.lineWidth = 2
        }
    }

    // MARK: - Hit Testing

    func containsTouchPoint(_ point: CGPoint) -> Bool {
        let localPoint = convert(point, from: parent ?? self)
        return self.backgroundNode.contains(localPoint)
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
    static var menuHeightRatio: CGFloat { GameBalance.UI.BuildMenu.menuHeightRatio }

    /// Menu width as percentage of viewport
    static var menuWidthRatio: CGFloat { GameBalance.UI.BuildMenu.menuWidthRatio }

    /// Spacing between menu items
    static var itemSpacing: CGFloat { GameBalance.UI.BuildMenu.itemSpacing }

    // MARK: - Initialization

    init(size: CGSize) {
        self.viewportSize = size

        let menuWidth = size.width * Self.menuWidthRatio
        let menuHeight = size.height * Self.menuHeightRatio

        // Create background panel
        self.backgroundPanel = SKShapeNode(rectOf: CGSize(width: menuWidth, height: menuHeight), cornerRadius: 12)
        self.backgroundPanel.fillColor = SKColor.black.withAlphaComponent(0.7)
        self.backgroundPanel.strokeColor = SKColor.white.withAlphaComponent(0.4)
        self.backgroundPanel.lineWidth = 2

        super.init()

        self.setupMenu()
        zPosition = 400 // Below HUD but above game elements

        // Start hidden
        isHidden = true
        alpha = 0
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupMenu() {
        let halfHeight = self.viewportSize.height / 2
        let menuHeight = self.viewportSize.height * Self.menuHeightRatio

        // Position panel at bottom center with extra offset for safe areas
        // Add 60 points to clear the home indicator on iPhone
        let bottomOffset: CGFloat = 60
        position = CGPoint(x: 0, y: -halfHeight + menuHeight / 2 + bottomOffset)

        // Add background
        addChild(self.backgroundPanel)

        // Add title label at the top of the panel
        let titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        titleLabel.fontSize = 14
        titleLabel.fontColor = SKColor.white.withAlphaComponent(0.7)
        titleLabel.text = "BUILD TOWERS"
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: menuHeight / 2 - 20)
        titleLabel.zPosition = 1
        addChild(titleLabel)

        // Create menu items for each tower type
        // Position items below the title, centered vertically in remaining space
        let types = TowerType.allCases
        let totalWidth = CGFloat(types.count) * BuildMenuItemNode.itemWidth + CGFloat(types.count - 1) * Self
            .itemSpacing
        let startX = -totalWidth / 2 + BuildMenuItemNode.itemWidth / 2
        let itemY: CGFloat = -10 // Slightly below center to leave room for title

        for (index, type) in types.enumerated() {
            let item = BuildMenuItemNode(type: type)
            item.position = CGPoint(
                x: startX + CGFloat(index) * (BuildMenuItemNode.itemWidth + Self.itemSpacing),
                y: itemY
            )
            item.zPosition = 1
            addChild(item)
            self.menuItems.append(item)
        }
    }

    // MARK: - Visibility

    /// Show the build menu with animation
    func show() {
        guard !self.isVisible else { return }
        self.isVisible = true
        isHidden = false

        // Update affordability before showing
        self.updateAffordability()

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
        guard self.isVisible else { return }
        self.isVisible = false

        // Cancel any active drag
        if let item = draggingItem {
            item.isDragging = false
            self.delegate?.buildMenu(self, didCancelDragging: item.towerType)
            self.draggingItem = nil
        }
        self.removeGhostTower()

        // Animate out
        let moveDown = SKAction.moveBy(x: 0, y: -50, duration: 0.2)
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        moveDown.timingMode = .easeIn

        run(SKAction.sequence([
            SKAction.group([moveDown, fadeOut]),
            SKAction.run { [weak self] in
                self?.isHidden = true
                // Reset position for next show (with safe area offset)
                if let halfHeight = self?.viewportSize.height {
                    let bottomOffset: CGFloat = 60
                    self?.position.y = -halfHeight / 2 + halfHeight * Self.menuHeightRatio / 2 + bottomOffset
                }
            },
        ]))
    }

    /// Toggle visibility
    func toggle() {
        if self.isVisible {
            self.hide()
        } else {
            self.show()
        }
    }

    // MARK: - Affordability

    /// Update which items can be afforded
    func updateAffordability() {
        guard let delegate else { return }
        let resources = delegate.buildMenuCurrentResources(self)

        for item in self.menuItems {
            item.isAffordable = TowerConfig.canAfford(item.towerType, currentResources: resources)
        }
    }

    // MARK: - Touch Handling

    /// Handle touch began - returns true if touch was handled
    func handleTouchBegan(at point: CGPoint) -> Bool {
        guard self.isVisible else { return false }

        let localPoint = convert(point, from: parent ?? self)

        // Check if touch is on a menu item
        for item in self.menuItems {
            if item.containsTouchPoint(localPoint), item.isAffordable {
                // Start dragging
                self.draggingItem = item
                item.isDragging = true

                // Create ghost tower
                self.createGhostTower(for: item.towerType, at: point)

                // Notify delegate
                self.delegate?.buildMenu(self, didStartDragging: item.towerType, from: point)
                return true
            }
        }

        // Check if touch is on menu background
        if self.backgroundPanel.contains(localPoint) {
            return true // Consume touch but don't do anything
        }

        return false
    }

    /// Handle touch moved - returns true if touch was handled
    func handleTouchMoved(to point: CGPoint) -> Bool {
        guard self.isVisible, self.draggingItem != nil else { return false }

        // Move ghost tower
        self.ghostTower?.position = point

        return true
    }

    /// Handle touch ended - returns true if touch was handled
    /// - Parameters:
    ///   - hudPoint: Touch position in HUD/camera coordinates (for menu bounds check)
    ///   - worldPosition: Touch position in world/scene coordinates (for tower placement)
    func handleTouchEnded(at hudPoint: CGPoint, worldPosition: CGPoint) -> Bool {
        guard self.isVisible, let dragging = draggingItem else { return false }

        dragging.isDragging = false
        self.draggingItem = nil
        self.removeGhostTower()

        // Check if released outside menu (using HUD coordinates)
        let localPoint = convert(hudPoint, from: parent ?? self)
        if !self.backgroundPanel.contains(localPoint) {
            // Valid placement attempt - use world coordinates for placement
            self.delegate?.buildMenu(self, didEndDragging: dragging.towerType, at: worldPosition)
        } else {
            // Released back on menu - cancel
            self.delegate?.buildMenu(self, didCancelDragging: dragging.towerType)
        }

        return true
    }

    /// Handle touch cancelled
    func handleTouchCancelled() {
        guard let dragging = draggingItem else { return }

        dragging.isDragging = false
        self.draggingItem = nil
        self.removeGhostTower()

        self.delegate?.buildMenu(self, didCancelDragging: dragging.towerType)
    }

    // MARK: - Ghost Tower

    /// Create a ghost tower sprite that follows the drag
    private func createGhostTower(for type: TowerType, at position: CGPoint) {
        self.removeGhostTower()

        let ghost = SKSpriteNode(imageNamed: type.iconTextureName)
        ghost.size = CGSize(width: 50, height: 50)
        ghost.position = position
        ghost.alpha = 0.6
        ghost.zPosition = 750 // Above BuildMenu (700) but below PauseMenu (900)
        ghost.name = "ghostTower"

        parent?.addChild(ghost)
        self.ghostTower = ghost
    }

    /// Remove the ghost tower
    private func removeGhostTower() {
        self.ghostTower?.removeFromParent()
        self.ghostTower = nil
    }

    /// Update ghost tower validity visual (red if invalid, normal if valid)
    func updateGhostValidity(isValid: Bool) {
        if isValid {
            self.ghostTower?.color = .white
            self.ghostTower?.colorBlendFactor = 0
        } else {
            self.ghostTower?.color = .red
            self.ghostTower?.colorBlendFactor = 0.7
        }
    }

    // MARK: - Queries

    /// Check if currently dragging
    var isDragging: Bool {
        self.draggingItem != nil
    }

    /// Get currently dragging tower type
    var draggingTowerType: TowerType? {
        self.draggingItem?.towerType
    }
}
