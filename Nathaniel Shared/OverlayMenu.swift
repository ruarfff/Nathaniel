//
//  OverlayMenu.swift
//  Nathaniel Shared
//
//  Base class for modal overlay menus (pause, settings, etc.)
//

import SpriteKit

// MARK: - Overlay Menu

/// Base class for modal overlay menus with a dark background and centered panel
class OverlayMenu: SKNode {

    // MARK: - Properties

    /// Size of the viewport
    let viewportSize: CGSize

    /// Dark overlay background
    private(set) var overlayBackground: SKShapeNode?

    /// Menu panel container
    private(set) var menuPanel: SKNode?

    /// Whether the menu is currently visible
    private(set) var isVisible: Bool = false

    // MARK: - Configuration

    /// Duration for show/hide animations
    var animationDuration: TimeInterval = 0.25

    /// Background overlay opacity (0.0 - 1.0)
    var overlayOpacity: CGFloat = 0.7

    /// Panel corner radius
    var panelCornerRadius: CGFloat = 16

    /// Panel background color
    var panelBackgroundColor: SKColor = SKColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 0.95)

    /// Panel border color
    var panelBorderColor: SKColor = SKColor.white.withAlphaComponent(0.3)

    /// Panel border width
    var panelBorderWidth: CGFloat = 2

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

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    /// Set up the dark background overlay. Called automatically during init.
    func setupOverlay() {
        let overlay = SKShapeNode(rectOf: CGSize(width: viewportSize.width * 2, height: viewportSize.height * 2))
        overlay.fillColor = SKColor.black.withAlphaComponent(overlayOpacity)
        overlay.strokeColor = .clear
        overlay.zPosition = 0
        overlay.name = "overlayBackground"
        addChild(overlay)
        overlayBackground = overlay
    }

    /// Set up the menu panel. Override in subclasses to add custom content.
    /// Subclasses should call `createPanelContainer(width:height:)` to create the panel,
    /// then add their content to it.
    func setupMenuPanel() {
        // Default empty implementation - subclasses override
    }

    /// Create the panel container with background. Returns the panel node.
    /// - Parameters:
    ///   - width: Panel width
    ///   - height: Panel height
    /// - Returns: The panel node to add content to
    func createPanelContainer(width: CGFloat, height: CGFloat) -> SKNode {
        let panel = SKNode()
        panel.zPosition = 1

        // Panel background
        let panelBg = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: panelCornerRadius)
        panelBg.fillColor = panelBackgroundColor
        panelBg.strokeColor = panelBorderColor
        panelBg.lineWidth = panelBorderWidth
        panelBg.name = "panelBackground"
        panel.addChild(panelBg)

        addChild(panel)
        menuPanel = panel

        return panel
    }

    // MARK: - Show/Hide

    /// Show the menu with animation
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

    /// Hide the menu with animation
    /// - Parameter completion: Called after hide animation completes
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
    }

    // MARK: - Touch Handling

    /// Handle touch on the menu. Override in subclasses for custom button handling.
    /// - Parameter point: Touch point in parent coordinate space
    /// - Returns: True if touch was handled
    func handleTouch(at point: CGPoint) -> Bool {
        guard isVisible else { return false }
        // Default: consume all touches when visible
        return true
    }

    // MARK: - Button Utilities

    /// Create a standard menu button
    /// - Parameters:
    ///   - parent: Node to add the button to
    ///   - name: Button identifier name
    ///   - title: Display text
    ///   - width: Button width
    ///   - height: Button height
    ///   - yPosition: Y position within parent
    ///   - color: Button background color
    /// - Returns: The created button node
    @discardableResult
    func createButton(
        in parent: SKNode,
        name: String,
        title: String,
        width: CGFloat = 220,
        height: CGFloat = 50,
        yPosition: CGFloat,
        color: SKColor
    ) -> SKNode {
        let button = SKNode()
        button.name = name
        button.position = CGPoint(x: 0, y: yPosition)

        // Button background
        let buttonBg = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 10)
        buttonBg.fillColor = color
        buttonBg.strokeColor = SKColor.white.withAlphaComponent(0.5)
        buttonBg.lineWidth = 1
        buttonBg.name = name
        button.addChild(buttonBg)

        // Title
        let titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        titleLabel.text = title
        titleLabel.fontSize = 18
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.name = name
        button.addChild(titleLabel)

        parent.addChild(button)
        return button
    }

    /// Create a button with an icon (emoji) and title
    /// - Parameters:
    ///   - parent: Node to add the button to
    ///   - name: Button identifier name
    ///   - title: Display text
    ///   - emoji: Emoji to show as icon
    ///   - width: Button width
    ///   - height: Button height
    ///   - yPosition: Y position within parent
    ///   - color: Button background color
    /// - Returns: The created button node
    @discardableResult
    func createButtonWithIcon(
        in parent: SKNode,
        name: String,
        title: String,
        emoji: String,
        width: CGFloat = 220,
        height: CGFloat = 50,
        yPosition: CGFloat,
        color: SKColor
    ) -> SKNode {
        let button = SKNode()
        button.name = name
        button.position = CGPoint(x: 0, y: yPosition)

        // Button background
        let buttonBg = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 10)
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
        iconLabel.position = CGPoint(x: -width / 2 + 30, y: 0)
        iconLabel.name = name
        button.addChild(iconLabel)

        // Title
        let titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        titleLabel.text = title
        titleLabel.fontSize = 18
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.position = CGPoint(x: -width / 2 + 55, y: 0)
        titleLabel.name = name
        button.addChild(titleLabel)

        parent.addChild(button)
        return button
    }

    /// Create a title label for the panel
    /// - Parameters:
    ///   - text: Title text
    ///   - fontSize: Font size (default 32)
    ///   - panelHeight: Height of the panel (for positioning)
    /// - Returns: The created label node
    @discardableResult
    func createTitle(_ text: String, fontSize: CGFloat = 32, in panel: SKNode, panelHeight: CGFloat) -> SKLabelNode {
        let titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        titleLabel.text = text
        titleLabel.fontSize = fontSize
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: panelHeight / 2 - 50)
        panel.addChild(titleLabel)
        return titleLabel
    }

    // MARK: - Hit Testing

    /// Check if a point is within a node's bounds
    /// - Parameters:
    ///   - node: Node to check
    ///   - point: Point in parent's coordinate space
    ///   - fallbackSize: Fallback size if shape bounds can't be determined
    /// - Returns: True if point is within node bounds
    func nodeContainsPoint(_ node: SKNode, point: CGPoint, fallbackSize: CGSize? = nil) -> Bool {
        let nodePoint = node.convert(point, from: node.parent!)
        if let shape = node.children.first as? SKShapeNode {
            return shape.contains(nodePoint)
        }
        // Fallback to frame check
        if let size = fallbackSize {
            let frame = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
            return frame.contains(nodePoint)
        }
        return false
    }

    /// Animate a button press effect
    /// - Parameter button: Button node to animate
    func animateButtonPress(_ button: SKNode) {
        let scaleDown = SKAction.scale(to: 0.95, duration: 0.05)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.1)
        button.run(SKAction.sequence([scaleDown, scaleUp]))
    }
}
