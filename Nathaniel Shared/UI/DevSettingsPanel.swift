#if DEBUG

    import SpriteKit

    /// Main panel for viewing and editing DevSettings
    class DevSettingsPanel: SKNode {
        // MARK: - Types

        /// Setting category tabs
        enum Tab: String, CaseIterable {
            case player = "Player"
            case enemy = "Enemy"
            case projectile = "Projectile"
            case spawn = "Spawn"
            case camera = "Camera"
            case tower = "Tower"
            case debug = "Debug"
        }

        // MARK: - Constants

        private let headerHeight: CGFloat = 50
        private let tabBarHeight: CGFloat = 44
        private let footerHeight: CGFloat = 50
        private let contentPadding: CGFloat = 12
        private let animationDuration: TimeInterval = 0.25
        private let tabWidth: CGFloat = 100
        private let tabHeight: CGFloat = 34

        // MARK: - Computed Dimensions

        /// Panel width based on viewport (max 850, with 60pt margin)
        private var panelWidth: CGFloat {
            min(850, self.viewportSize.width - 60)
        }

        /// Panel height based on viewport (max 550, with 50pt margin)
        private var panelHeight: CGFloat {
            min(550, self.viewportSize.height - 50)
        }

        // MARK: - Colors

        private let panelBgColor = SKColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 0.95)
        private let panelStrokeColor = SKColor.white.withAlphaComponent(0.3)
        private let tabSelectedColor = SKColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1.0)
        private let tabUnselectedColor = SKColor(red: 0.25, green: 0.25, blue: 0.3, alpha: 1.0)
        private let buttonColor = SKColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 1.0)
        private let resetButtonColor = SKColor(red: 0.6, green: 0.3, blue: 0.3, alpha: 1.0)

        // MARK: - Properties

        /// Whether the panel is currently visible
        private(set) var isVisible: Bool = false

        /// Currently selected tab
        private var selectedTab: Tab = .player

        /// Viewport size for overlay
        private let viewportSize: CGSize

        // MARK: - Callbacks

        /// Called when Back button is tapped
        var onBack: (() -> Void)?

        // MARK: - UI Elements

        private var overlayBackground: SKShapeNode!
        private var panelNode: SKNode!
        private var tabButtons: [Tab: SKNode] = [:]
        private var contentContainer: SKNode!
        private var contentClipNode: SKCropNode!
        private var scrollContent: SKNode!
        private var settingsRows: [SKNode] = []

        // MARK: - Scroll State

        private var scrollOffset: CGFloat = 0
        private var maxScrollOffset: CGFloat = 0

        // MARK: - Initialization

        init(size: CGSize) {
            self.viewportSize = size
            super.init()

            self.setupOverlay()
            self.setupPanel()
            self.setupHeader()
            self.setupTabBar()
            self.setupContentArea()
            self.setupFooter()

            // Load initial tab content
            self.loadTabContent(tab: .player)

            // Start hidden
            isHidden = true
            alpha = 0
        }

        @available(*, unavailable)
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: - Setup

        private func setupOverlay() {
            self.overlayBackground = SKShapeNode(rectOf: CGSize(
                width: self.viewportSize.width * 2,
                height: self.viewportSize.height * 2
            ))
            self.overlayBackground.fillColor = SKColor.black.withAlphaComponent(0.7)
            self.overlayBackground.strokeColor = .clear
            self.overlayBackground.zPosition = 0
            addChild(self.overlayBackground)
        }

        private func setupPanel() {
            self.panelNode = SKNode()
            self.panelNode.zPosition = 1

            let panelBg = SKShapeNode(rectOf: CGSize(width: panelWidth, height: panelHeight), cornerRadius: 16)
            panelBg.fillColor = self.panelBgColor
            panelBg.strokeColor = self.panelStrokeColor
            panelBg.lineWidth = 2
            self.panelNode.addChild(panelBg)

            addChild(self.panelNode)
        }

        private func setupHeader() {
            let headerY = self.panelHeight / 2 - self.headerHeight / 2

            // Title
            let titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
            titleLabel.text = "DEV SETTINGS"
            titleLabel.fontSize = 24
            titleLabel.fontColor = .white
            titleLabel.horizontalAlignmentMode = .center
            titleLabel.verticalAlignmentMode = .center
            titleLabel.position = CGPoint(x: 0, y: headerY)
            self.panelNode.addChild(titleLabel)

            // Reset button (right side of header)
            let resetButton = self.createButton(title: "Reset", width: 70, height: 30, color: self.resetButtonColor)
            resetButton.name = "resetButton"
            resetButton.position = CGPoint(x: self.panelWidth / 2 - 50, y: headerY)
            self.panelNode.addChild(resetButton)
        }

        private func setupTabBar() {
            let tabBarY = self.panelHeight / 2 - self.headerHeight - self.tabBarHeight / 2

            let tabs = Tab.allCases
            let tabSpacing: CGFloat = 8
            let totalWidth = CGFloat(tabs.count) * self.tabWidth + CGFloat(tabs.count - 1) * tabSpacing
            var startX = -totalWidth / 2 + self.tabWidth / 2

            for tab in tabs {
                let tabButton = self.createTabButton(tab: tab)
                tabButton.position = CGPoint(x: startX, y: tabBarY)
                tabButton.name = "tab_\(tab.rawValue)"
                self.panelNode.addChild(tabButton)
                self.tabButtons[tab] = tabButton
                startX += self.tabWidth + tabSpacing
            }

            self.updateTabSelection()
        }

        private func createTabButton(tab: Tab) -> SKNode {
            let button = SKNode()

            let bg = SKShapeNode(rectOf: CGSize(width: tabWidth, height: tabHeight), cornerRadius: 6)
            bg.fillColor = tab == self.selectedTab ? self.tabSelectedColor : self.tabUnselectedColor
            bg.strokeColor = .clear
            bg.name = "tabBg"
            button.addChild(bg)

            let label = SKLabelNode(fontNamed: "Helvetica-Bold")
            label.text = tab.rawValue
            label.fontSize = 14
            label.fontColor = .white
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            button.addChild(label)

            return button
        }

        private func setupContentArea() {
            let contentY = self.panelHeight / 2 - self.headerHeight - self.tabBarHeight - self.contentPadding
            let contentHeight = self.panelHeight - self.headerHeight - self.tabBarHeight - self.footerHeight - self
                .contentPadding * 2

            // Container for clipping
            self.contentContainer = SKNode()
            self.contentContainer.position = CGPoint(x: 0, y: contentY - contentHeight / 2)
            self.panelNode.addChild(self.contentContainer)

            // Crop node for scrolling
            self.contentClipNode = SKCropNode()

            let maskNode = SKShapeNode(rectOf: CGSize(width: panelWidth - 20, height: contentHeight))
            maskNode.fillColor = .white
            self.contentClipNode.maskNode = maskNode

            self.contentContainer.addChild(self.contentClipNode)

            // Scroll content
            self.scrollContent = SKNode()
            self.contentClipNode.addChild(self.scrollContent)
        }

        private func setupFooter() {
            let footerY = -self.panelHeight / 2 + self.footerHeight / 2

            let backButton = self.createButton(title: "Back", width: 120, height: 40, color: self.buttonColor)
            backButton.name = "backButton"
            backButton.position = CGPoint(x: 0, y: footerY)
            self.panelNode.addChild(backButton)
        }

        private func createButton(title: String, width: CGFloat, height: CGFloat, color: SKColor) -> SKNode {
            let button = SKNode()

            let bg = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 8)
            bg.fillColor = color
            bg.strokeColor = SKColor.white.withAlphaComponent(0.3)
            bg.lineWidth = 1
            button.addChild(bg)

            let label = SKLabelNode(fontNamed: "Helvetica-Bold")
            label.text = title
            label.fontSize = 16
            label.fontColor = .white
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            button.addChild(label)

            return button
        }

        // MARK: - Tab Selection

        private func updateTabSelection() {
            for (tab, button) in self.tabButtons {
                if let bg = button.childNode(withName: "tabBg") as? SKShapeNode {
                    bg.fillColor = tab == self.selectedTab ? self.tabSelectedColor : self.tabUnselectedColor
                }
            }
        }

        private func selectTab(_ tab: Tab) {
            guard tab != self.selectedTab else { return }
            self.selectedTab = tab
            self.updateTabSelection()
            self.loadTabContent(tab: tab)
        }

        // MARK: - Content Loading

        private func loadTabContent(tab: Tab) {
            // Clear existing content
            self.scrollContent.removeAllChildren()
            self.settingsRows.removeAll()
            self.scrollOffset = 0
            self.scrollContent.position = .zero

            // Build rows for this tab
            let rows = self.buildRows(for: tab)
            self.settingsRows = rows

            // Layout rows
            let rowHeight = DevSettingsControls.rowHeight
            let rowSpacing = DevSettingsControls.rowSpacing
            var yOffset: CGFloat = 0

            for row in rows {
                row.position = CGPoint(x: 0, y: -yOffset - rowHeight / 2)
                self.scrollContent.addChild(row)
                yOffset += rowHeight + rowSpacing
            }

            // Calculate max scroll
            let contentHeight = self.panelHeight - self.headerHeight - self.tabBarHeight - self.footerHeight - self
                .contentPadding * 2
            let totalContentHeight = yOffset
            self.maxScrollOffset = max(0, totalContentHeight - contentHeight)
        }

        // swiftlint:disable function_body_length
        private func buildRows(for tab: Tab) -> [SKNode] {
            var rows: [SKNode] = []

            switch tab {
            case .player:
                rows.append(DevSettingsControls.createSliderRow(
                    label: "Nathaniel Speed", key: "nathanielSpeed",
                    min: 10, max: 200,
                    getValue: { DevSettings.shared.nathanielSpeed },
                    setValue: { DevSettings.shared.nathanielSpeed = $0 }
                ))
                rows.append(DevSettingsControls.createSliderRow(
                    label: "Hermes Speed", key: "hermesSpeed",
                    min: 10, max: 150,
                    getValue: { DevSettings.shared.hermesSpeed },
                    setValue: { DevSettings.shared.hermesSpeed = $0 }
                ))
                rows.append(DevSettingsControls.createIntSliderRow(
                    label: "Nathaniel Max HP", key: "nathanielMaxHealth",
                    min: 1_000, max: 20_000,
                    getValue: { DevSettings.shared.nathanielMaxHealth },
                    setValue: { DevSettings.shared.nathanielMaxHealth = $0 }
                ))
                rows.append(DevSettingsControls.createIntSliderRow(
                    label: "Hermes Max HP", key: "hermesMaxHealth",
                    min: 500, max: 10_000,
                    getValue: { DevSettings.shared.hermesMaxHealth },
                    setValue: { DevSettings.shared.hermesMaxHealth = $0 }
                ))
                rows.append(DevSettingsControls.createToggleRow(
                    label: "Player Invincible", key: "playerInvincible",
                    getValue: { DevSettings.shared.playerInvincible },
                    setValue: { DevSettings.shared.playerInvincible = $0 }
                ))
                rows.append(DevSettingsControls.createSliderRow(
                    label: "Respawn Delay", key: "respawnDelay",
                    min: 0.5, max: 10,
                    getValue: { CGFloat(DevSettings.shared.respawnDelay) },
                    setValue: { DevSettings.shared.respawnDelay = TimeInterval($0) },
                    format: "%.1fs"
                ))

            case .enemy:
                rows.append(DevSettingsControls.createSliderRow(
                    label: "Grunt Speed", key: "gruntSpeed",
                    min: 20, max: 150,
                    getValue: { DevSettings.shared.gruntSpeed },
                    setValue: { DevSettings.shared.gruntSpeed = $0 }
                ))
                rows.append(DevSettingsControls.createSliderRow(
                    label: "Soldier Speed", key: "soldierSpeed",
                    min: 10, max: 100,
                    getValue: { DevSettings.shared.soldierSpeed },
                    setValue: { DevSettings.shared.soldierSpeed = $0 }
                ))
                rows.append(DevSettingsControls.createSliderRow(
                    label: "Boss Speed", key: "bossSpeed",
                    min: 20, max: 120,
                    getValue: { DevSettings.shared.bossSpeed },
                    setValue: { DevSettings.shared.bossSpeed = $0 }
                ))
                rows.append(DevSettingsControls.createSliderRow(
                    label: "Visible Range", key: "enemyVisibleRange",
                    min: 100, max: 1_000,
                    getValue: { DevSettings.shared.enemyVisibleRange },
                    setValue: { DevSettings.shared.enemyVisibleRange = $0 }
                ))
                rows.append(DevSettingsControls.createSliderRow(
                    label: "Attack Range", key: "enemyAttackRange",
                    min: 50, max: 500,
                    getValue: { DevSettings.shared.enemyAttackRange },
                    setValue: { DevSettings.shared.enemyAttackRange = $0 }
                ))
                rows.append(DevSettingsControls.createIntSliderRow(
                    label: "Enemy Damage", key: "enemyDamage",
                    min: 1, max: 100,
                    getValue: { DevSettings.shared.enemyDamage },
                    setValue: { DevSettings.shared.enemyDamage = $0 }
                ))

            case .projectile:
                rows.append(DevSettingsControls.createSliderRow(
                    label: "Bullet Speed", key: "bulletSpeed",
                    min: 100, max: 800,
                    getValue: { DevSettings.shared.bulletSpeed },
                    setValue: { DevSettings.shared.bulletSpeed = $0 }
                ))
                rows.append(DevSettingsControls.createSliderRow(
                    label: "Arrow Speed", key: "arrowSpeed",
                    min: 100, max: 700,
                    getValue: { DevSettings.shared.arrowSpeed },
                    setValue: { DevSettings.shared.arrowSpeed = $0 }
                ))
                rows.append(DevSettingsControls.createIntSliderRow(
                    label: "Projectile Damage", key: "projectileDamage",
                    min: 1, max: 100,
                    getValue: { DevSettings.shared.projectileDamage },
                    setValue: { DevSettings.shared.projectileDamage = $0 }
                ))

            case .spawn:
                rows.append(DevSettingsControls.createSliderRow(
                    label: "Spawn Interval", key: "spawnInterval",
                    min: 1, max: 30,
                    getValue: { CGFloat(DevSettings.shared.spawnInterval) },
                    setValue: { DevSettings.shared.spawnInterval = TimeInterval($0) },
                    format: "%.1fs"
                ))

            case .camera:
                rows.append(DevSettingsControls.createSliderRow(
                    label: "Camera Zoom", key: "cameraZoom",
                    min: 0.5, max: 2.0,
                    getValue: { DevSettings.shared.cameraZoom },
                    setValue: { DevSettings.shared.cameraZoom = $0 },
                    format: "%.2f"
                ))
                rows.append(DevSettingsControls.createSliderRow(
                    label: "Min Zoom", key: "cameraMinZoom",
                    min: 0.25, max: 1.0,
                    getValue: { DevSettings.shared.cameraMinZoom },
                    setValue: { DevSettings.shared.cameraMinZoom = $0 },
                    format: "%.2f"
                ))
                rows.append(DevSettingsControls.createSliderRow(
                    label: "Max Zoom", key: "cameraMaxZoom",
                    min: 1.0, max: 4.0,
                    getValue: { DevSettings.shared.cameraMaxZoom },
                    setValue: { DevSettings.shared.cameraMaxZoom = $0 },
                    format: "%.2f"
                ))
                rows.append(DevSettingsControls.createSliderRow(
                    label: "Follow Smoothing", key: "cameraFollowSmoothing",
                    min: 0.01, max: 1.0,
                    getValue: { DevSettings.shared.cameraFollowSmoothing },
                    setValue: { DevSettings.shared.cameraFollowSmoothing = $0 },
                    format: "%.2f"
                ))
                rows.append(DevSettingsControls.createToggleRow(
                    label: "Free Camera Mode", key: "cameraFreeMode",
                    getValue: { DevSettings.shared.cameraFreeMode },
                    setValue: { DevSettings.shared.cameraFreeMode = $0 }
                ))

            case .tower:
                rows.append(DevSettingsControls.createIntSliderRow(
                    label: "Tower Damage", key: "towerDamage",
                    min: 1, max: 100,
                    getValue: { DevSettings.shared.towerDamage },
                    setValue: { DevSettings.shared.towerDamage = $0 }
                ))
                rows.append(DevSettingsControls.createSliderRow(
                    label: "Tower Range", key: "towerRange",
                    min: 100, max: 600,
                    getValue: { DevSettings.shared.towerRange },
                    setValue: { DevSettings.shared.towerRange = $0 }
                ))
                rows.append(DevSettingsControls.createIntSliderRow(
                    label: "Gun Tower Cost", key: "towerCostGun",
                    min: 1, max: 50,
                    getValue: { DevSettings.shared.towerCostGun },
                    setValue: { DevSettings.shared.towerCostGun = $0 }
                ))
                rows.append(DevSettingsControls.createIntSliderRow(
                    label: "Laser Tower Cost", key: "towerCostLaser",
                    min: 1, max: 50,
                    getValue: { DevSettings.shared.towerCostLaser },
                    setValue: { DevSettings.shared.towerCostLaser = $0 }
                ))
                rows.append(DevSettingsControls.createIntSliderRow(
                    label: "Heal Tower Cost", key: "towerCostHeal",
                    min: 1, max: 50,
                    getValue: { DevSettings.shared.towerCostHeal },
                    setValue: { DevSettings.shared.towerCostHeal = $0 }
                ))
                rows.append(DevSettingsControls.createToggleRow(
                    label: "Instant Build", key: "instantBuild",
                    getValue: { DevSettings.shared.instantBuild },
                    setValue: { DevSettings.shared.instantBuild = $0 }
                ))

            case .debug:
                rows.append(DevSettingsControls.createToggleRow(
                    label: "Infinite Resources", key: "infiniteResources",
                    getValue: { DevSettings.shared.infiniteResources },
                    setValue: { DevSettings.shared.infiniteResources = $0 }
                ))
                rows.append(DevSettingsControls.createToggleRow(
                    label: "Show Debug Info", key: "showDebugInfo",
                    getValue: { DevSettings.shared.showDebugInfo },
                    setValue: { DevSettings.shared.showDebugInfo = $0 }
                ))
                rows.append(DevSettingsControls.createToggleRow(
                    label: "Show Collision Bounds", key: "showCollisionBounds",
                    getValue: { DevSettings.shared.showCollisionBounds },
                    setValue: { DevSettings.shared.showCollisionBounds = $0 }
                ))
                rows.append(DevSettingsControls.createToggleRow(
                    label: "Show Pathfinding Debug", key: "showPathfindingDebug",
                    getValue: { DevSettings.shared.showPathfindingDebug },
                    setValue: { DevSettings.shared.showPathfindingDebug = $0 }
                ))
            }

            return rows
        }

        // swiftlint:enable function_body_length

        // MARK: - Show/Hide

        /// Show the panel with animation
        func show() {
            guard !self.isVisible else { return }
            self.isVisible = true
            isHidden = false

            // Refresh content
            self.loadTabContent(tab: self.selectedTab)

            // Reset scale and alpha
            self.panelNode.setScale(0.8)
            alpha = 0

            // Animate in
            let fadeIn = SKAction.fadeIn(withDuration: self.animationDuration)
            let scaleUp = SKAction.scale(to: 1.0, duration: self.animationDuration)
            scaleUp.timingMode = .easeOut

            run(fadeIn)
            self.panelNode.run(scaleUp)
        }

        /// Hide the panel with animation
        func hide(completion: (() -> Void)? = nil) {
            guard self.isVisible else {
                completion?()
                return
            }

            let fadeOut = SKAction.fadeOut(withDuration: self.animationDuration)
            let scaleDown = SKAction.scale(to: 0.8, duration: self.animationDuration)
            scaleDown.timingMode = .easeIn

            let hideAction = SKAction.run { [weak self] in
                self?.isHidden = true
                self?.isVisible = false
                completion?()
            }

            run(SKAction.sequence([fadeOut, hideAction]))
            self.panelNode.run(scaleDown)
        }

        // MARK: - Touch Handling

        /// Handle touch at point - returns true if handled
        func handleTouch(at point: CGPoint) -> Bool {
            guard self.isVisible else { return false }

            let localPoint = convert(point, from: parent!)
            let panelPoint = self.panelNode.convert(localPoint, from: self)

            // Check tabs
            for (tab, button) in self.tabButtons {
                if self.nodeContainsPoint(
                    button,
                    point: panelPoint,
                    size: CGSize(width: self.tabWidth, height: self.tabHeight)
                ) {
                    self.animateButtonPress(button)
                    self.selectTab(tab)
                    return true
                }
            }

            // Check reset button
            if let resetButton = panelNode.childNode(withName: "resetButton"),
               nodeContainsPoint(resetButton, point: panelPoint, size: CGSize(width: 70, height: 30))
            {
                self.animateButtonPress(resetButton)
                DevSettings.shared.reset()
                self.loadTabContent(tab: self.selectedTab)
                return true
            }

            // Check back button
            if let backButton = panelNode.childNode(withName: "backButton"),
               nodeContainsPoint(backButton, point: panelPoint, size: CGSize(width: 120, height: 40))
            {
                self.animateButtonPress(backButton)
                self.hide {
                    self.onBack?()
                }
                return true
            }

            // Check content rows
            let contentPoint = self.contentContainer.convert(panelPoint, from: self.panelNode)
            let scrollPoint = CGPoint(x: contentPoint.x, y: contentPoint.y - self.scrollOffset)

            for row in self.settingsRows {
                let rowPoint = row.convert(scrollPoint, from: self.scrollContent)

                if let toggleRow = row as? DevSettingsToggleRow {
                    if toggleRow.hitTestPoint(rowPoint) {
                        toggleRow.handleTap()
                        return true
                    }
                } else if let sliderRow = row as? DevSettingsSliderRow {
                    if sliderRow.hitTestPoint(rowPoint) {
                        return sliderRow.handleTouch(at: rowPoint)
                    }
                }
            }

            // Touch on panel consumes event
            let panelRect = CGRect(
                x: -self.panelWidth / 2,
                y: -self.panelHeight / 2,
                width: self.panelWidth,
                height: self.panelHeight
            )
            return panelRect.contains(panelPoint)
        }

        /// Handle drag for slider adjustment and scrolling
        func handleDrag(from start: CGPoint, to end: CGPoint) -> Bool {
            guard self.isVisible else { return false }

            let localStart = convert(start, from: parent!)
            let localEnd = convert(end, from: parent!)
            let panelStart = self.panelNode.convert(localStart, from: self)
            let panelEnd = self.panelNode.convert(localEnd, from: self)

            // Check if dragging on a slider row
            let contentPoint = self.contentContainer.convert(panelEnd, from: self.panelNode)
            let scrollPoint = CGPoint(x: contentPoint.x, y: contentPoint.y - self.scrollOffset)

            for row in self.settingsRows {
                if let sliderRow = row as? DevSettingsSliderRow {
                    let rowPoint = row.convert(scrollPoint, from: self.scrollContent)
                    if sliderRow.hitTestPoint(rowPoint) {
                        return sliderRow.handleTouch(at: rowPoint)
                    }
                }
            }

            // Otherwise handle as scroll
            let deltaY = panelEnd.y - panelStart.y
            self.scrollOffset = max(0, min(self.maxScrollOffset, self.scrollOffset + deltaY))
            self.scrollContent.position.y = self.scrollOffset

            return true
        }

        private func nodeContainsPoint(_ node: SKNode, point: CGPoint, size: CGSize) -> Bool {
            let nodePoint = node.convert(point, from: node.parent!)
            let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
            return rect.contains(nodePoint)
        }

        private func animateButtonPress(_ button: SKNode) {
            let scaleDown = SKAction.scale(to: 0.95, duration: 0.05)
            let scaleUp = SKAction.scale(to: 1.0, duration: 0.1)
            button.run(SKAction.sequence([scaleDown, scaleUp]))
        }
    }

#endif
