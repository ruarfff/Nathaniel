import SpriteKit

// MARK: - Settings Menu

/// Overlay menu displayed for game settings
class SettingsMenu: OverlayMenu {
    // MARK: - Types

    /// Setting item identifiers
    enum SettingItem: String {
        case soundEffects = "soundEffectsToggle"
        case music = "musicToggle"
        case devSettings = "devSettingsButton"
        case back = "backButton"
    }

    // MARK: - Properties

    /// Sound effects toggle state
    private var soundEffectsEnabled: Bool = true

    /// Music toggle state
    private var musicEnabled: Bool = true

    // MARK: - Callbacks

    /// Called when Back button is tapped
    var onBack: (() -> Void)?

    /// Called when a setting changes
    var onSettingChanged: ((SettingItem, Bool) -> Void)?

    // MARK: - Constants

    #if DEBUG
        private let panelHeight: CGFloat = 340 // Taller to fit Dev Settings button
    #else
        private let panelHeight: CGFloat = 280
    #endif
    private let panelWidth: CGFloat = 320
    private let rowWidth: CGFloat = 280
    private let rowHeight: CGFloat = 50
    private let rowSpacing: CGFloat = 15
    private let buttonWidth: CGFloat = 180
    private let buttonHeight: CGFloat = 45

    // MARK: - UI References

    private var soundEffectsToggle: SKNode?
    private var musicToggle: SKNode?

    #if DEBUG
        /// DevSettings panel (DEBUG builds only)
        private var devSettingsPanel: DevSettingsPanel?
    #endif

    // MARK: - Initialization

    override init(size: CGSize) {
        super.init(size: size)

        // Load current settings
        soundEffectsEnabled = GameSettings.shared.soundEffectsEnabled
        musicEnabled = GameSettings.shared.musicEnabled
    }

    // MARK: - Setup

    override func setupMenuPanel() {
        let panel = createPanelContainer(width: panelWidth, height: panelHeight)

        // Title
        createTitle("SETTINGS", fontSize: 28, in: panel, panelHeight: panelHeight)

        // Setting rows (from top to bottom)
        let rowStartY: CGFloat = panelHeight / 2 - 100

        // Sound Effects toggle
        soundEffectsToggle = createToggleRow(
            in: panel,
            name: SettingItem.soundEffects.rawValue,
            title: "Sound Effects",
            isOn: soundEffectsEnabled,
            yPosition: rowStartY
        )

        // Music toggle
        musicToggle = createToggleRow(
            in: panel,
            name: SettingItem.music.rawValue,
            title: "Music",
            isOn: musicEnabled,
            yPosition: rowStartY - (rowHeight + rowSpacing)
        )

        #if DEBUG
            // Dev Settings button (DEBUG builds only)
            createButton(
                in: panel,
                name: SettingItem.devSettings.rawValue,
                title: "Developer Settings",
                width: buttonWidth,
                height: buttonHeight,
                yPosition: rowStartY - 2 * (rowHeight + rowSpacing),
                color: SKColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0)
            )
        #endif

        // Back button
        createButton(
            in: panel,
            name: SettingItem.back.rawValue,
            title: "Back",
            width: buttonWidth,
            height: buttonHeight,
            yPosition: -panelHeight / 2 + 50,
            color: SKColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 1.0)
        )

        #if DEBUG
            // Setup DevSettingsPanel
            devSettingsPanel = DevSettingsPanel(size: viewportSize)
            devSettingsPanel?.zPosition = 10
            addChild(devSettingsPanel!)

            devSettingsPanel?.onBack = { [weak self] in
                // Panel handles its own hide animation
            }
        #endif
    }

    private func createToggleRow(
        in parent: SKNode,
        name: String,
        title: String,
        isOn: Bool,
        yPosition: CGFloat
    ) -> SKNode {
        let row = SKNode()
        row.name = name
        row.position = CGPoint(x: 0, y: yPosition)

        // Row background (for touch detection)
        let rowBg = SKShapeNode(rectOf: CGSize(width: rowWidth, height: rowHeight), cornerRadius: 8)
        rowBg.fillColor = SKColor.white.withAlphaComponent(0.05)
        rowBg.strokeColor = .clear
        rowBg.name = name
        row.addChild(rowBg)

        // Title label (left aligned)
        let titleLabel = SKLabelNode(fontNamed: "Helvetica")
        titleLabel.text = title
        titleLabel.fontSize = 18
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.position = CGPoint(x: -rowWidth / 2 + 20, y: 0)
        titleLabel.name = name
        row.addChild(titleLabel)

        // Toggle switch (right aligned)
        let toggle = createToggleSwitch(name: name, isOn: isOn)
        toggle.position = CGPoint(x: rowWidth / 2 - 50, y: 0)
        row.addChild(toggle)

        parent.addChild(row)
        return row
    }

    private func createToggleSwitch(name: String, isOn: Bool) -> SKNode {
        let toggle = SKNode()
        toggle.name = "\(name)Switch"

        // Track background
        let trackWidth: CGFloat = 55
        let trackHeight: CGFloat = 28
        let track = SKShapeNode(rectOf: CGSize(width: trackWidth, height: trackHeight), cornerRadius: trackHeight / 2)
        track.fillColor = isOn
            ? SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
            : SKColor(
                red: 0.4,
                green: 0.4,
                blue: 0.4,
                alpha: 1.0
            )
        track.strokeColor = .clear
        track.name = name
        toggle.addChild(track)

        // Thumb
        let thumbRadius: CGFloat = 11
        let thumbX = isOn ? (trackWidth / 2 - thumbRadius - 3) : (-trackWidth / 2 + thumbRadius + 3)
        let thumb = SKShapeNode(circleOfRadius: thumbRadius)
        thumb.fillColor = .white
        thumb.strokeColor = .clear
        thumb.position = CGPoint(x: thumbX, y: 0)
        thumb.name = "\(name)Thumb"
        toggle.addChild(thumb)

        return toggle
    }

    // MARK: - Toggle Animation

    private func updateToggle(_ toggle: SKNode?, isOn: Bool, name: String) {
        guard let toggle else { return }

        // Find switch node
        guard let switchNode = toggle.childNode(withName: "\(name)Switch") else { return }

        // Find track and update color
        if let track = switchNode.children.first as? SKShapeNode {
            let targetColor = isOn
                ? SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
                : SKColor(
                    red: 0.4,
                    green: 0.4,
                    blue: 0.4,
                    alpha: 1.0
                )
            track.fillColor = targetColor
        }

        // Find thumb and animate position
        let trackWidth: CGFloat = 55
        let thumbRadius: CGFloat = 11
        let targetX = isOn ? (trackWidth / 2 - thumbRadius - 3) : (-trackWidth / 2 + thumbRadius + 3)

        if let thumb = switchNode.childNode(withName: "\(name)Thumb") {
            let moveAction = SKAction.moveTo(x: targetX, duration: 0.15)
            moveAction.timingMode = .easeOut
            thumb.run(moveAction)
        }
    }

    // MARK: - Show/Hide

    override func show() {
        // Refresh from current settings
        soundEffectsEnabled = GameSettings.shared.soundEffectsEnabled
        musicEnabled = GameSettings.shared.musicEnabled

        // Update UI to match current settings
        updateToggle(soundEffectsToggle, isOn: soundEffectsEnabled, name: SettingItem.soundEffects.rawValue)
        updateToggle(musicToggle, isOn: musicEnabled, name: SettingItem.music.rawValue)

        super.show()
    }

    // MARK: - Touch Handling

    override func handleTouch(at point: CGPoint) -> Bool {
        guard isVisible else { return false }

        #if DEBUG
            // If DevSettingsPanel is visible, route touches to it
            if let devPanel = devSettingsPanel, devPanel.isVisible {
                return devPanel.handleTouch(at: point)
            }
        #endif

        // Convert point to local coordinates
        let localPoint = convert(point, from: parent!)

        // Check menu buttons
        guard let panel = menuPanel else { return false }
        let panelPoint = panel.convert(localPoint, from: self)
        let rowSize = CGSize(width: rowWidth, height: rowHeight)

        // Sound Effects toggle
        if let row = panel.childNode(withName: SettingItem.soundEffects.rawValue),
           nodeContainsPoint(row, point: panelPoint, fallbackSize: rowSize)
        {
            animateButtonPress(row)
            soundEffectsEnabled = !soundEffectsEnabled
            GameSettings.shared.soundEffectsEnabled = soundEffectsEnabled
            updateToggle(soundEffectsToggle, isOn: soundEffectsEnabled, name: SettingItem.soundEffects.rawValue)
            onSettingChanged?(.soundEffects, soundEffectsEnabled)
            return true
        }

        // Music toggle
        if let row = panel.childNode(withName: SettingItem.music.rawValue),
           nodeContainsPoint(row, point: panelPoint, fallbackSize: rowSize)
        {
            animateButtonPress(row)
            musicEnabled = !musicEnabled
            GameSettings.shared.musicEnabled = musicEnabled
            updateToggle(musicToggle, isOn: musicEnabled, name: SettingItem.music.rawValue)
            onSettingChanged?(.music, musicEnabled)

            // Apply music setting immediately
            if musicEnabled {
                AudioManager.shared.resumeMusic()
            } else {
                AudioManager.shared.pauseMusic()
            }

            return true
        }

        #if DEBUG
            // Dev Settings button
            if let button = panel.childNode(withName: SettingItem.devSettings.rawValue),
               nodeContainsPoint(button, point: panelPoint, fallbackSize: CGSize(width: buttonWidth, height: buttonHeight))
            {
                animateButtonPress(button)
                devSettingsPanel?.show()
                return true
            }
        #endif

        // Back button
        if let button = panel.childNode(withName: SettingItem.back.rawValue),
           nodeContainsPoint(button, point: panelPoint, fallbackSize: CGSize(width: buttonWidth, height: buttonHeight))
        {
            animateButtonPress(button)
            hide {
                self.onBack?()
            }
            return true
        }

        // Touch on overlay (outside panel) does nothing (keeps menu open)
        return true
    }

    #if DEBUG
        /// Handle drag for slider adjustment in DevSettingsPanel
        func handleDrag(from start: CGPoint, to end: CGPoint) -> Bool {
            guard isVisible else { return false }

            if let devPanel = devSettingsPanel, devPanel.isVisible {
                return devPanel.handleDrag(from: start, to: end)
            }
            return false
        }
    #endif
}
