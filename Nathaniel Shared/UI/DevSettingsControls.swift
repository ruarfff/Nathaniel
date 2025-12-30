#if DEBUG

    import SpriteKit

    /// Factory for creating DevSettings UI rows
    enum DevSettingsControls {
        // MARK: - Layout Constants

        static let rowWidth: CGFloat = 500
        static let rowHeight: CGFloat = 45
        static let rowSpacing: CGFloat = 8
        static let labelFontSize: CGFloat = 16
        static let toggleTrackWidth: CGFloat = 55
        static let toggleTrackHeight: CGFloat = 28
        static let toggleThumbRadius: CGFloat = 11

        // MARK: - Colors

        static let toggleOnColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        static let toggleOffColor = SKColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        static let labelColor = SKColor(white: 0.9, alpha: 1.0)
        static let rowBgColor = SKColor.white.withAlphaComponent(0.03)

        // MARK: - Toggle Row

        /// Create a toggle row for boolean settings
        /// - Parameters:
        ///   - label: Display label for the setting
        ///   - key: Unique identifier for the row
        ///   - getValue: Closure to get the current value
        ///   - setValue: Closure to set the new value
        /// - Returns: SKNode containing the toggle row
        static func createToggleRow(
            label: String,
            key: String,
            getValue: @escaping () -> Bool,
            setValue: @escaping (Bool) -> Void
        ) -> DevSettingsToggleRow {
            DevSettingsToggleRow(
                label: label,
                key: key,
                getValue: getValue,
                setValue: setValue
            )
        }

        // MARK: - Slider Row

        /// Create a slider row for CGFloat settings
        /// - Parameters:
        ///   - label: Display label for the setting
        ///   - key: Unique identifier for the row
        ///   - min: Minimum value
        ///   - max: Maximum value
        ///   - getValue: Closure to get the current value
        ///   - setValue: Closure to set the new value
        ///   - format: Printf-style format string (default "%.0f")
        /// - Returns: SKNode containing the slider row
        static func createSliderRow(
            label: String,
            key: String,
            min: CGFloat,
            max: CGFloat,
            getValue: @escaping () -> CGFloat,
            setValue: @escaping (CGFloat) -> Void,
            format: String = "%.0f"
        ) -> DevSettingsSliderRow {
            DevSettingsSliderRow(
                label: label,
                key: key,
                minValue: min,
                maxValue: max,
                getValue: getValue,
                setValue: setValue,
                format: format
            )
        }

        /// Create a slider row for Int settings
        static func createIntSliderRow(
            label: String,
            key: String,
            min: Int,
            max: Int,
            getValue: @escaping () -> Int,
            setValue: @escaping (Int) -> Void
        ) -> DevSettingsSliderRow {
            DevSettingsSliderRow(
                label: label,
                key: key,
                minValue: CGFloat(min),
                maxValue: CGFloat(max),
                getValue: { CGFloat(getValue()) },
                setValue: { setValue(Int($0.rounded())) },
                format: "%.0f"
            )
        }
    }

    // MARK: - Toggle Row

    /// A row containing a label and toggle switch
    class DevSettingsToggleRow: SKNode {
        // MARK: - Properties

        let key: String
        private let getValue: () -> Bool
        private let setValue: (Bool) -> Void
        private var isOn: Bool
        private var toggleSwitch: SKNode!

        // MARK: - Initialization

        init(label: String, key: String, getValue: @escaping () -> Bool, setValue: @escaping (Bool) -> Void) {
            self.key = key
            self.getValue = getValue
            self.setValue = setValue
            isOn = getValue()
            super.init()

            name = key
            setupUI(label: label)
        }

        @available(*, unavailable)
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: - Setup

        private func setupUI(label: String) {
            let rowWidth = DevSettingsControls.rowWidth
            let rowHeight = DevSettingsControls.rowHeight

            // Row background
            let rowBg = SKShapeNode(rectOf: CGSize(width: rowWidth, height: rowHeight), cornerRadius: 6)
            rowBg.fillColor = DevSettingsControls.rowBgColor
            rowBg.strokeColor = .clear
            addChild(rowBg)

            // Label (left aligned)
            let labelNode = SKLabelNode(fontNamed: "Helvetica")
            labelNode.text = label
            labelNode.fontSize = DevSettingsControls.labelFontSize
            labelNode.fontColor = DevSettingsControls.labelColor
            labelNode.horizontalAlignmentMode = .left
            labelNode.verticalAlignmentMode = .center
            labelNode.position = CGPoint(x: -rowWidth / 2 + 15, y: 0)
            addChild(labelNode)

            // Toggle switch (right aligned)
            toggleSwitch = createToggleSwitch()
            toggleSwitch.position = CGPoint(x: rowWidth / 2 - 45, y: 0)
            addChild(toggleSwitch)
        }

        private func createToggleSwitch() -> SKNode {
            let toggle = SKNode()
            toggle.name = "\(key)Switch"

            let trackWidth = DevSettingsControls.toggleTrackWidth
            let trackHeight = DevSettingsControls.toggleTrackHeight
            let thumbRadius = DevSettingsControls.toggleThumbRadius

            // Track
            let track = SKShapeNode(
                rectOf: CGSize(width: trackWidth, height: trackHeight),
                cornerRadius: trackHeight / 2
            )
            track.fillColor = isOn ? DevSettingsControls.toggleOnColor : DevSettingsControls.toggleOffColor
            track.strokeColor = .clear
            track.name = "track"
            toggle.addChild(track)

            // Thumb
            let thumbX = isOn ? (trackWidth / 2 - thumbRadius - 3) : (-trackWidth / 2 + thumbRadius + 3)
            let thumb = SKShapeNode(circleOfRadius: thumbRadius)
            thumb.fillColor = .white
            thumb.strokeColor = .clear
            thumb.position = CGPoint(x: thumbX, y: 0)
            thumb.name = "thumb"
            toggle.addChild(thumb)

            return toggle
        }

        // MARK: - Touch Handling

        /// Check if point is within this row
        func hitTestPoint(_ point: CGPoint) -> Bool {
            let rowWidth = DevSettingsControls.rowWidth
            let rowHeight = DevSettingsControls.rowHeight
            let rect = CGRect(x: -rowWidth / 2, y: -rowHeight / 2, width: rowWidth, height: rowHeight)
            return rect.contains(point)
        }

        /// Handle tap on this row
        func handleTap() {
            isOn.toggle()
            setValue(isOn)
            updateToggleUI(animated: true)
        }

        /// Refresh from current value
        func refresh() {
            isOn = getValue()
            updateToggleUI(animated: false)
        }

        private func updateToggleUI(animated: Bool) {
            guard let track = toggleSwitch.childNode(withName: "track") as? SKShapeNode,
                  let thumb = toggleSwitch.childNode(withName: "thumb") else { return }

            let trackWidth = DevSettingsControls.toggleTrackWidth
            let thumbRadius = DevSettingsControls.toggleThumbRadius
            let targetX = isOn ? (trackWidth / 2 - thumbRadius - 3) : (-trackWidth / 2 + thumbRadius + 3)
            let targetColor = isOn ? DevSettingsControls.toggleOnColor : DevSettingsControls.toggleOffColor

            track.fillColor = targetColor

            if animated {
                let move = SKAction.moveTo(x: targetX, duration: 0.15)
                move.timingMode = .easeOut
                thumb.run(move)
            } else {
                thumb.position.x = targetX
            }
        }
    }

    // MARK: - Slider Row

    /// A row containing a label and slider
    class DevSettingsSliderRow: SKNode {
        // MARK: - Properties

        let key: String
        private let getValue: () -> CGFloat
        private let setValue: (CGFloat) -> Void
        private var slider: DevSettingsSlider!

        // MARK: - Initialization

        init(
            label: String,
            key: String,
            minValue: CGFloat,
            maxValue: CGFloat,
            getValue: @escaping () -> CGFloat,
            setValue: @escaping (CGFloat) -> Void,
            format: String
        ) {
            self.key = key
            self.getValue = getValue
            self.setValue = setValue
            super.init()

            name = key
            setupUI(label: label, minValue: minValue, maxValue: maxValue, format: format)
        }

        @available(*, unavailable)
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: - Setup

        private func setupUI(label: String, minValue: CGFloat, maxValue: CGFloat, format: String) {
            let rowWidth = DevSettingsControls.rowWidth
            let rowHeight = DevSettingsControls.rowHeight

            // Row background
            let rowBg = SKShapeNode(rectOf: CGSize(width: rowWidth, height: rowHeight), cornerRadius: 6)
            rowBg.fillColor = DevSettingsControls.rowBgColor
            rowBg.strokeColor = .clear
            addChild(rowBg)

            // Label (left aligned)
            let labelNode = SKLabelNode(fontNamed: "Helvetica")
            labelNode.text = label
            labelNode.fontSize = DevSettingsControls.labelFontSize
            labelNode.fontColor = DevSettingsControls.labelColor
            labelNode.horizontalAlignmentMode = .left
            labelNode.verticalAlignmentMode = .center
            labelNode.position = CGPoint(x: -rowWidth / 2 + 15, y: 0)
            addChild(labelNode)

            // Slider (right aligned)
            slider = DevSettingsSlider(
                minValue: minValue,
                maxValue: maxValue,
                initialValue: getValue(),
                format: format
            )
            slider.position = CGPoint(x: rowWidth / 2 - slider.totalWidth / 2 - 10, y: 0)
            slider.onValueChanged = { [weak self] value in
                self?.setValue(value)
            }
            addChild(slider)
        }

        // MARK: - Touch Handling

        /// Check if point is within this row
        func hitTestPoint(_ point: CGPoint) -> Bool {
            let rowWidth = DevSettingsControls.rowWidth
            let rowHeight = DevSettingsControls.rowHeight
            let rect = CGRect(x: -rowWidth / 2, y: -rowHeight / 2, width: rowWidth, height: rowHeight)
            return rect.contains(point)
        }

        /// Handle touch/drag at point (converts to slider coordinates)
        func handleTouch(at point: CGPoint) -> Bool {
            let sliderPoint = slider.convert(point, from: self)
            return slider.handleTouch(at: sliderPoint)
        }

        /// Refresh from current value
        func refresh() {
            slider.setValue(getValue(), animated: false)
        }
    }

#endif
