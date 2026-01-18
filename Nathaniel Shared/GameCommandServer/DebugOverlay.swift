#if DEBUG

    import SpriteKit

    /// Debug overlay that draws bounding boxes around interactive elements
    public class DebugOverlay: SKNode {
        // MARK: - Properties

        /// Whether the overlay is currently visible
        public private(set) var isVisible: Bool = false

        /// The scene this overlay is attached to
        private weak var parentScene: SKScene?

        /// Container for highlight boxes
        private let highlightContainer = SKNode()

        /// Update timer for refreshing highlights
        private var updateTimer: Timer?

        /// Colors for different node types
        private let colors: [String: SKColor] = [
            "Player": .green,
            "Companion": .green,
            "Enemy": .red,
            "Tower": .cyan,
            "Button": .yellow,
            "Projectile": .orange,
            "Default": .white,
        ]

        // MARK: - Initialization

        override public init() {
            super.init()
            name = "debugOverlay"
            zPosition = 10_000 // Above everything
            addChild(highlightContainer)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: - Public Methods

        /// Attach the overlay to a scene
        public func attach(to scene: SKScene) {
            parentScene = scene
            if parent == nil {
                scene.addChild(self)
            }
        }

        /// Show the debug overlay
        public func show() {
            guard !isVisible else { return }
            isVisible = true
            isHidden = false
            startUpdating()
            updateHighlights()
        }

        /// Hide the debug overlay
        public func hide() {
            guard isVisible else { return }
            isVisible = false
            isHidden = true
            stopUpdating()
            clearHighlights()
        }

        /// Toggle the overlay visibility
        public func toggle() {
            if isVisible {
                hide()
            } else {
                show()
            }
        }

        /// Manually refresh the highlights
        public func refresh() {
            if isVisible {
                updateHighlights()
            }
        }

        // MARK: - Private Methods

        private func startUpdating() {
            stopUpdating()
            // Update every 0.5 seconds to catch node changes
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateHighlights()
                }
            }
        }

        private func stopUpdating() {
            updateTimer?.invalidate()
            updateTimer = nil
        }

        private func clearHighlights() {
            highlightContainer.removeAllChildren()
        }

        private func updateHighlights() {
            clearHighlights()

            guard let scene = parentScene,
                  let delegate = scene as? GameCommandDelegate
            else {
                return
            }

            let nodes = delegate.getInteractiveNodes()

            for node in nodes {
                let highlight = createHighlight(for: node)
                highlightContainer.addChild(highlight)
            }
        }

        private func createHighlight(for node: GameCommandServer.NodeInfo) -> SKNode {
            let container = SKNode()

            // Create bounding box
            let boxSize = CGSize(width: node.frame.width, height: node.frame.height)
            let box = SKShapeNode(rectOf: boxSize)
            box.strokeColor = colorForNode(node)
            box.fillColor = colorForNode(node).withAlphaComponent(0.1)
            box.lineWidth = 2.0
            box.glowWidth = 1.0

            // Position at center of frame
            let centerX = node.frame.x + node.frame.width / 2
            let centerY = node.frame.y + node.frame.height / 2
            container.position = CGPoint(x: centerX, y: centerY)
            container.addChild(box)

            // Add label
            let label = SKLabelNode(fontNamed: "Menlo-Bold")
            label.text = node.name
            label.fontSize = 10
            label.fontColor = colorForNode(node)
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .bottom
            label.position = CGPoint(x: 0, y: boxSize.height / 2 + 2)

            // Add background for label readability
            let labelBg = SKShapeNode(rectOf: CGSize(width: label.frame.width + 4, height: label.frame.height + 2))
            labelBg.fillColor = SKColor.black.withAlphaComponent(0.7)
            labelBg.strokeColor = .clear
            labelBg.position = CGPoint(x: 0, y: boxSize.height / 2 + 2 + label.frame.height / 2)
            labelBg.zPosition = -1

            container.addChild(labelBg)
            container.addChild(label)

            return container
        }

        private func colorForNode(_ node: GameCommandServer.NodeInfo) -> SKColor {
            let defaultColor: SKColor = .white

            // Check by name patterns
            if node.name == "nathaniel" || node.name == "hermes" {
                return colors["Player"] ?? defaultColor
            }
            if node.name.hasPrefix("enemy_") {
                return colors["Enemy"] ?? defaultColor
            }
            if node.name.contains("tower") || node.name.contains("Tower") {
                return colors["Tower"] ?? defaultColor
            }
            if node.name.contains("Button") || node.name.contains("button") {
                return colors["Button"] ?? defaultColor
            }
            if node.name.contains("projectile") {
                return colors["Projectile"] ?? defaultColor
            }

            // Check by type
            if let color = colors[node.type] {
                return color
            }

            return defaultColor
        }

        deinit {
            stopUpdating()
        }
    }

    // MARK: - SKScene Extension for Debug Overlay

    extension SKScene {
        private static var debugOverlayKey: UInt8 = 0

        /// Get or create the debug overlay for this scene
        public var debugOverlay: DebugOverlay {
            if let existing = objc_getAssociatedObject(self, &SKScene.debugOverlayKey) as? DebugOverlay {
                return existing
            }
            let overlay = DebugOverlay()
            overlay.attach(to: self)
            objc_setAssociatedObject(self, &SKScene.debugOverlayKey, overlay, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return overlay
        }

        /// Check if debug overlay is currently visible
        public var isDebugOverlayVisible: Bool {
            debugOverlay.isVisible
        }

        /// Toggle the debug overlay
        public func toggleDebugOverlay() {
            debugOverlay.toggle()
        }

        /// Show the debug overlay
        public func showDebugOverlay() {
            debugOverlay.show()
        }

        /// Hide the debug overlay
        public func hideDebugOverlay() {
            debugOverlay.hide()
        }
    }

#endif
