#if DEBUG

    import SpriteKit

    /// A slider control for adjusting numeric DevSettings values
    class DevSettingsSlider: SKNode {
        // MARK: - Constants

        private let trackWidth: CGFloat = 220
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
                updateUI()
                onValueChanged?(currentValue)
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
            currentValue = initialValue
            formatString = format
            super.init()

            setupUI()
            updateUI()
        }

        @available(*, unavailable)
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: - Setup

        private func setupUI() {
            // Track background
            trackNode = SKShapeNode(
                rectOf: CGSize(width: trackWidth, height: trackHeight),
                cornerRadius: trackHeight / 2
            )
            trackNode.fillColor = trackColor
            trackNode.strokeColor = .clear
            trackNode.zPosition = 0
            addChild(trackNode)

            // Fill (left portion showing current value)
            fillNode = SKShapeNode()
            fillNode.fillColor = fillColor
            fillNode.strokeColor = .clear
            fillNode.zPosition = 1
            addChild(fillNode)

            // Thumb
            thumbNode = SKShapeNode(circleOfRadius: thumbRadius)
            thumbNode.fillColor = thumbColor
            thumbNode.strokeColor = SKColor.gray.withAlphaComponent(0.5)
            thumbNode.lineWidth = 1
            thumbNode.zPosition = 2
            addChild(thumbNode)

            // Value label (right of slider)
            valueLabel = SKLabelNode(fontNamed: "Helvetica")
            valueLabel.fontSize = 14
            valueLabel.fontColor = SKColor(white: 0.9, alpha: 1.0)
            valueLabel.horizontalAlignmentMode = .left
            valueLabel.verticalAlignmentMode = .center
            valueLabel.position = CGPoint(x: trackWidth / 2 + 15, y: 0)
            valueLabel.zPosition = 0
            addChild(valueLabel)
        }

        private func updateUI() {
            // Calculate normalized position (0 to 1)
            let normalized = (currentValue - minValue) / (maxValue - minValue)
            let clampedNormalized = max(0, min(1, normalized))

            // Update thumb position
            let thumbX = -trackWidth / 2 + trackWidth * clampedNormalized
            thumbNode.position = CGPoint(x: thumbX, y: 0)

            // Update fill
            updateFill(normalized: clampedNormalized)

            // Update value label
            valueLabel.text = String(format: formatString, currentValue)
        }

        private func updateFill(normalized: CGFloat) {
            let fillWidth = trackWidth * normalized
            if fillWidth > 0 {
                let fillRect = CGRect(
                    x: -trackWidth / 2,
                    y: -trackHeight / 2,
                    width: fillWidth,
                    height: trackHeight
                )
                let path = CGPath(
                    roundedRect: fillRect,
                    cornerWidth: trackHeight / 2,
                    cornerHeight: trackHeight / 2,
                    transform: nil
                )
                fillNode.path = path
            } else {
                fillNode.path = nil
            }
        }

        // MARK: - Value Setting

        /// Set the slider value programmatically
        func setValue(_ value: CGFloat, animated: Bool = false) {
            let clamped = max(minValue, min(maxValue, value))
            if animated {
                // Animate thumb movement
                let normalized = (clamped - minValue) / (maxValue - minValue)
                let thumbX = -trackWidth / 2 + trackWidth * normalized
                let moveAction = SKAction.moveTo(x: thumbX, duration: 0.15)
                moveAction.timingMode = .easeOut
                thumbNode.run(moveAction)
            }
            currentValue = clamped
        }

        // MARK: - Touch Handling

        /// Check if a point is within the slider's interactive area
        func hitTestPoint(_ point: CGPoint) -> Bool {
            // Expand hit area vertically for easier touch
            let hitRect = CGRect(
                x: -trackWidth / 2 - thumbRadius,
                y: -thumbRadius * 1.5,
                width: trackWidth + thumbRadius * 2,
                height: thumbRadius * 3
            )
            return hitRect.contains(point)
        }

        /// Handle touch/drag at the given point
        /// - Parameter point: Point in the slider's coordinate space
        /// - Returns: True if the touch was handled
        func handleTouch(at point: CGPoint) -> Bool {
            guard hitTestPoint(point) else { return false }

            // Calculate value from x position
            let clampedX = max(-trackWidth / 2, min(trackWidth / 2, point.x))
            let normalized = (clampedX + trackWidth / 2) / trackWidth
            let newValue = minValue + (maxValue - minValue) * normalized

            currentValue = newValue
            return true
        }

        /// Get the width of the slider including value label
        var totalWidth: CGFloat {
            trackWidth + 60 // Track + spacing + value label
        }
    }

#endif
