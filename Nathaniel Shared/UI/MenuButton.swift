//
//  MenuButton.swift
//  Nathaniel Shared
//
//  Reusable menu button component with factory methods for consistent styling.
//

import SpriteKit

// MARK: - Button Style

/// Predefined button styles for menu buttons
enum MenuButtonStyle {
    /// Simple text-only button (MainMenuScene style)
    case text
    /// Button with background, icon, and text (PauseMenu style)
    case panel
    /// Highlighted button with accent color
    case highlighted

    // MARK: - Style Properties

    var font: String {
        switch self {
        case .text:
            return "Copperplate-Bold"
        case .panel, .highlighted:
            return "Helvetica-Bold"
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .text:
            return 36
        case .panel, .highlighted:
            return 18
        }
    }

    var hasBackground: Bool {
        switch self {
        case .text:
            return false
        case .panel, .highlighted:
            return true
        }
    }
}

// MARK: - Menu Button Factory

/// Factory for creating standardized menu buttons
enum MenuButtonFactory {
    // MARK: - Layout Constants

    static let defaultButtonWidth: CGFloat = 220
    static let defaultButtonHeight: CGFloat = 50
    static let buttonCornerRadius: CGFloat = 10
    static let iconOffset: CGFloat = 30
    static let textOffset: CGFloat = 55

    // MARK: - Colors

    static let defaultTextColor = SKColor.white
    static let defaultBackgroundColor = SKColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 1.0)
    static let highlightedColor = SKColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1.0)
    static let borderColor = SKColor.white.withAlphaComponent(0.5)

    // MARK: - Factory Methods

    /// Create a text-only menu button (MainMenuScene style)
    /// - Parameters:
    ///   - text: Button text
    ///   - name: Node name for identification
    ///   - color: Text color (default white)
    /// - Returns: MenuButton instance
    static func createTextButton(
        text: String,
        name: String,
        color: SKColor = defaultTextColor
    ) -> MenuButton {
        MenuButton(
            text: text,
            name: name,
            style: .text,
            textColor: color,
            backgroundColor: nil,
            icon: nil
        )
    }

    /// Create a panel button with background and optional icon (PauseMenu style)
    /// - Parameters:
    ///   - text: Button text
    ///   - name: Node name for identification
    ///   - icon: Emoji icon (optional)
    ///   - backgroundColor: Button background color
    ///   - size: Button size (default 220x50)
    /// - Returns: MenuButton instance
    static func createPanelButton(
        text: String,
        name: String,
        icon: String? = nil,
        backgroundColor: SKColor = defaultBackgroundColor,
        size: CGSize = CGSize(width: defaultButtonWidth, height: defaultButtonHeight)
    ) -> MenuButton {
        MenuButton(
            text: text,
            name: name,
            style: .panel,
            textColor: defaultTextColor,
            backgroundColor: backgroundColor,
            icon: icon,
            size: size
        )
    }

    /// Create a highlighted button (for primary actions)
    /// - Parameters:
    ///   - text: Button text
    ///   - name: Node name for identification
    ///   - highlightColor: Highlight color for text
    /// - Returns: MenuButton instance
    static func createHighlightedButton(
        text: String,
        name: String,
        highlightColor: SKColor = highlightedColor
    ) -> MenuButton {
        MenuButton(
            text: text,
            name: name,
            style: .highlighted,
            textColor: highlightColor,
            backgroundColor: nil,
            icon: nil
        )
    }
}

// MARK: - Menu Button Component

/// Reusable menu button with configurable style
class MenuButton: SKNode {
    // MARK: - Properties

    /// The button's display text
    private(set) var text: String

    /// The button style
    private(set) var style: MenuButtonStyle

    /// Button size (for panel style)
    private(set) var buttonSize: CGSize

    /// Background shape node (for panel style)
    private var backgroundNode: SKShapeNode?

    /// Text label node
    private var textLabel: SKLabelNode?

    /// Icon label node (for panel style)
    private var iconLabel: SKLabelNode?

    /// Action to execute when button is tapped
    var onTap: (() -> Void)?

    // MARK: - Initialization

    /// Initialize a menu button
    /// - Parameters:
    ///   - text: Button text
    ///   - name: Node name for identification
    ///   - style: Button style
    ///   - textColor: Text color
    ///   - backgroundColor: Background color (for panel style)
    ///   - icon: Emoji icon (for panel style)
    ///   - size: Button size (for panel style)
    init(
        text: String,
        name: String,
        style: MenuButtonStyle,
        textColor: SKColor,
        backgroundColor: SKColor?,
        icon: String?,
        size: CGSize = CGSize(
            width: MenuButtonFactory.defaultButtonWidth,
            height: MenuButtonFactory.defaultButtonHeight
        )
    ) {
        self.text = text
        self.style = style
        self.buttonSize = size
        super.init()

        self.name = name
        setupButton(textColor: textColor, backgroundColor: backgroundColor, icon: icon)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupButton(textColor: SKColor, backgroundColor: SKColor?, icon: String?) {
        switch style {
        case .text, .highlighted:
            setupTextButton(textColor: textColor)
        case .panel:
            setupPanelButton(textColor: textColor, backgroundColor: backgroundColor, icon: icon)
        }
    }

    private func setupTextButton(textColor: SKColor) {
        let label = SKLabelNode(fontNamed: style.font)
        label.text = text
        label.fontSize = style.fontSize
        label.fontColor = textColor
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.name = name
        addChild(label)
        textLabel = label
    }

    private func setupPanelButton(textColor: SKColor, backgroundColor: SKColor?, icon: String?) {
        // Background
        let bg = SKShapeNode(
            rectOf: buttonSize,
            cornerRadius: MenuButtonFactory.buttonCornerRadius
        )
        bg.fillColor = backgroundColor ?? MenuButtonFactory.defaultBackgroundColor
        bg.strokeColor = MenuButtonFactory.borderColor
        bg.lineWidth = 1
        bg.name = name
        addChild(bg)
        backgroundNode = bg

        // Icon (if provided)
        if let icon = icon {
            let iconNode = SKLabelNode(fontNamed: "Helvetica")
            iconNode.text = icon
            iconNode.fontSize = 22
            iconNode.verticalAlignmentMode = .center
            iconNode.horizontalAlignmentMode = .center
            iconNode.position = CGPoint(
                x: -buttonSize.width / 2 + MenuButtonFactory.iconOffset,
                y: 0
            )
            iconNode.name = name
            addChild(iconNode)
            iconLabel = iconNode
        }

        // Text label
        let label = SKLabelNode(fontNamed: style.font)
        label.text = text
        label.fontSize = style.fontSize
        label.fontColor = textColor
        label.verticalAlignmentMode = .center

        if icon != nil {
            // Left-aligned when icon is present
            label.horizontalAlignmentMode = .left
            label.position = CGPoint(
                x: -buttonSize.width / 2 + MenuButtonFactory.textOffset,
                y: 0
            )
        } else {
            // Center-aligned when no icon
            label.horizontalAlignmentMode = .center
            label.position = .zero
        }
        label.name = name
        addChild(label)
        textLabel = label
    }

    // MARK: - Public Methods

    /// Update button text
    func setText(_ newText: String) {
        text = newText
        textLabel?.text = newText
    }

    /// Update button text color
    func setTextColor(_ color: SKColor) {
        textLabel?.fontColor = color
    }

    /// Update button background color (panel style only)
    func setBackgroundColor(_ color: SKColor) {
        backgroundNode?.fillColor = color
    }

    /// Check if point is within button bounds
    func hitTest(_ point: CGPoint) -> Bool {
        let localPoint = convert(point, from: parent!)

        switch style {
        case .text, .highlighted:
            guard let label = textLabel else { return false }
            return label.frame.contains(localPoint)

        case .panel:
            let halfWidth = buttonSize.width / 2
            let halfHeight = buttonSize.height / 2
            let bounds = CGRect(
                x: -halfWidth,
                y: -halfHeight,
                width: buttonSize.width,
                height: buttonSize.height
            )
            return bounds.contains(localPoint)
        }
    }

    /// Animate button press with optional completion handler
    func animatePress(completion: (() -> Void)? = nil) {
        let scaleDown = SKAction.scale(to: 0.9, duration: 0.1)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.1)
        let sequence = SKAction.sequence([
            scaleDown,
            scaleUp,
            SKAction.run { [weak self] in
                completion?()
                self?.onTap?()
            }
        ])
        run(sequence)
    }

    /// Handle tap on this button - returns true if tap was handled
    func handleTap(at point: CGPoint) -> Bool {
        guard hitTest(point) else { return false }
        animatePress()
        return true
    }
}
