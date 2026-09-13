#if DEBUG

    import SpriteKit

    /// A slider control for adjusting numeric DevSettings values
    class DevSettingsSlider: SKNode {
        // MARK: - Constants

        private let trackWidth: CGFloat = 180
        private let trackHeight: CGFloat = 8
        private let thumbRadius: CGFloat = 14
        private let trackColor = SKColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 1.0)
        private let fillColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        private let thumbColor = SKColor.white

        // MARK: - Properties

        /// Minimum slider value
        let minValue: CGFloat

        /// Maximum slider value
        let maxValue: CGFloat

        /// Format string for displaying the value (e.g., "%.0f" or "%.1f")
        let formatString: String

        /// Current slider value
        private(set) var currentValue: CGFloat {
            didSet {
                self.updateUI()
                self.onValueChanged?(self.currentValue)
            }
        }

        /// Callback when value changes
        var onValueChanged: ((CGFloat) -> Void)?

        // MARK: - UI Elements

        private var trackNode: SKShapeNode!
        private var fillNode: SKShapeNode!
        private var thumbNode: SKShapeNode!
        private var valueLabel: SKLabelNode!

        // MARK: - Initialization

        /// Create a slider with the specified range
        /// - Parameters:
        ///   - minValue: Minimum value
        ///   - maxValue: Maximum value
        ///   - initialValue: Starting value
        ///   - format: Printf-style format string for displaying the value
        init(minValue: CGFloat, maxValue: CGFloat, initialValue: CGFloat, format: String = "%.0f") {
            self.minValue = minValue
            self.maxValue = maxValue
            self.currentValue = initialValue
            self.formatString = format
            super.init()

            self.setupUI()
            self.updateUI()
        }

        @available(*, unavailable)
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: - Setup

        private func setupUI() {
            // Track background
            self.trackNode = SKShapeNode(
                rectOf: CGSize(width: self.trackWidth, height: self.trackHeight),
                cornerRadius: self.trackHeight / 2
            )
            self.trackNode.fillColor = self.trackColor
            self.trackNode.strokeColor = .clear
            self.trackNode.zPosition = 0
            addChild(self.trackNode)

            // Fill (left portion showing current value)
            self.fillNode = SKShapeNode()
            self.fillNode.fillColor = self.fillColor
            self.fillNode.strokeColor = .clear
            self.fillNode.zPosition = 1
            addChild(self.fillNode)

            // Thumb
            self.thumbNode = SKShapeNode(circleOfRadius: self.thumbRadius)
            self.thumbNode.fillColor = self.thumbColor
            self.thumbNode.strokeColor = SKColor.gray.withAlphaComponent(0.5)
            self.thumbNode.lineWidth = 1
            self.thumbNode.zPosition = 2
            addChild(self.thumbNode)

            // Value label (right of slider)
            self.valueLabel = SKLabelNode(fontNamed: "Helvetica")
            self.valueLabel.fontSize = 14
            self.valueLabel.fontColor = SKColor(white: 0.9, alpha: 1.0)
            self.valueLabel.horizontalAlignmentMode = .left
            self.valueLabel.verticalAlignmentMode = .center
            self.valueLabel.position = CGPoint(x: self.trackWidth / 2 + 15, y: 0)
            self.valueLabel.zPosition = 0
            addChild(self.valueLabel)
        }

        private func updateUI() {
            // Calculate normalized position (0 to 1)
            let normalized = (currentValue - self.minValue) / (self.maxValue - self.minValue)
            let clampedNormalized = max(0, min(1, normalized))

            // Update thumb position
            let thumbX = -self.trackWidth / 2 + self.trackWidth * clampedNormalized
            self.thumbNode.position = CGPoint(x: thumbX, y: 0)

            // Update fill
            self.updateFill(normalized: clampedNormalized)

            // Update value label
            self.valueLabel.text = String(format: self.formatString, self.currentValue)
        }

        private func updateFill(normalized: CGFloat) {
            let fillWidth = self.trackWidth * normalized
            if fillWidth > 0 {
                let fillRect = CGRect(
                    x: -self.trackWidth / 2,
                    y: -self.trackHeight / 2,
                    width: fillWidth,
                    height: self.trackHeight
                )
                let path = CGPath(
                    roundedRect: fillRect,
                    cornerWidth: trackHeight / 2,
                    cornerHeight: trackHeight / 2,
                    transform: nil
                )
                self.fillNode.path = path
            } else {
                self.fillNode.path = nil
            }
        }

        // MARK: - Value Setting

        /// Set the slider value programmatically
        func setValue(_ value: CGFloat) {
            self.currentValue = max(self.minValue, min(self.maxValue, value))
        }

        // MARK: - Touch Handling

        /// Check if a point is within the slider's interactive area
        func hitTestPoint(_ point: CGPoint) -> Bool {
            // Expand hit area vertically for easier touch
            let hitRect = CGRect(
                x: -self.trackWidth / 2 - self.thumbRadius,
                y: -self.thumbRadius * 1.5,
                width: self.trackWidth + self.thumbRadius * 2,
                height: self.thumbRadius * 3
            )
            return hitRect.contains(point)
        }

        /// Handle touch/drag at the given point
        /// - Parameter point: Point in the slider's coordinate space
        /// - Returns: True if the touch was handled
        func handleTouch(at point: CGPoint) -> Bool {
            guard self.hitTestPoint(point) else { return false }

            // Calculate value from x position
            let clampedX = max(-self.trackWidth / 2, min(self.trackWidth / 2, point.x))
            let normalized = (clampedX + self.trackWidth / 2) / self.trackWidth
            let newValue = self.minValue + (self.maxValue - self.minValue) * normalized

            self.currentValue = newValue
            return true
        }

        /// Get the width of the slider including value label
        var totalWidth: CGFloat {
            self.trackWidth + 60 // Track + spacing + value label
        }
    }

#endif
