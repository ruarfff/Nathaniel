#if DEBUG

    import Foundation
    import SpriteKit

    /// Result of executing a custom game action
    public struct ActionResult {
        public let success: Bool
        public let message: String?
        public let error: String?

        public init(success: Bool, message: String? = nil, error: String? = nil) {
            self.success = success
            self.message = message
            self.error = error
        }

        public static func success(_ message: String? = nil) -> ActionResult {
            ActionResult(success: true, message: message, error: nil)
        }

        public static func failure(_ error: String) -> ActionResult {
            ActionResult(success: false, message: nil, error: error)
        }
    }

    /// Protocol that game scenes implement to support the command server
    public protocol GameCommandDelegate: AnyObject {
        // MARK: - State Queries

        /// Get the current game state
        func getCurrentGameState() -> GameCommandServer.GameState

        /// Get all interactive nodes that an agent can tap/interact with
        func getInteractiveNodes() -> [GameCommandServer.NodeInfo]

        /// Capture a screenshot of the current scene
        func captureScreenshot() -> Data?

        /// Capture a screenshot with bounding boxes drawn around interactive nodes
        /// - Parameter nodes: The nodes to annotate
        /// - Returns: PNG image data with annotations
        func captureAnnotatedScreenshot(nodes: [GameCommandServer.NodeInfo]) -> Data?

        // MARK: - Input Injection

        /// Inject a tap at the given scene coordinates
        /// - Parameter point: The point in scene coordinates
        /// - Returns: true if the tap was handled
        func injectTap(at point: CGPoint) -> Bool

        /// Inject a swipe gesture
        /// - Parameters:
        ///   - from: Starting point in scene coordinates
        ///   - to: Ending point in scene coordinates
        ///   - duration: Duration of the swipe in seconds
        /// - Returns: true if the swipe was handled
        func injectSwipe(from: CGPoint, to: CGPoint, duration: CGFloat) -> Bool

        // MARK: - Custom Actions

        /// Execute a named action
        /// - Parameters:
        ///   - name: The action name (e.g., "selectCharacter", "targetEnemy")
        ///   - params: Optional parameters for the action
        /// - Returns: The result of the action
        func executeAction(name: String, params: [String: String]?) -> ActionResult
    }

    // MARK: - Default Implementations

    extension GameCommandDelegate {
        /// Default swipe implementation - can be overridden
        public func injectSwipe(from: CGPoint, to: CGPoint, duration: CGFloat) -> Bool {
            // Default: treat as a tap at the end point
            injectTap(at: to)
        }

        /// Default action implementation - returns failure for unknown actions
        public func executeAction(name: String, params: [String: String]?) -> ActionResult {
            .failure("Unknown action: \(name)")
        }

        /// Default annotated screenshot - delegates to scene if available
        public func captureAnnotatedScreenshot(nodes: [GameCommandServer.NodeInfo]) -> Data? {
            // This will be called on the scene which can use captureAnnotatedAsPNG
            if let scene = self as? SKScene {
                return scene.captureAnnotatedAsPNG(nodes: nodes)
            }
            return nil
        }
    }

    // MARK: - Helper Extensions

    extension SKScene {
        /// Capture the scene as PNG data
        public func captureAsPNG() -> Data? {
            guard let view else { return nil }

            let texture = view.texture(from: self)
            guard let cgImage = texture?.cgImage() else { return nil }

            #if os(iOS) || os(tvOS)
                let image = UIImage(cgImage: cgImage)
                return image.pngData()
            #elseif os(macOS)
                let size = CGSize(width: cgImage.width, height: cgImage.height)
                let image = NSImage(cgImage: cgImage, size: size)
                guard let tiffData = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
                return bitmap.representation(using: .png, properties: [:])
            #else
                return nil
            #endif
        }

        /// Capture the scene with annotated bounding boxes around nodes
        public func captureAnnotatedAsPNG(nodes: [GameCommandServer.NodeInfo]) -> Data? {
            guard let view else { return nil }

            let texture = view.texture(from: self)
            guard let cgImage = texture?.cgImage() else { return nil }

            let imageWidth = CGFloat(cgImage.width)
            let imageHeight = CGFloat(cgImage.height)

            #if os(iOS) || os(tvOS)
                // Create a graphics context and draw the image
                UIGraphicsBeginImageContextWithOptions(CGSize(width: imageWidth, height: imageHeight), false, 1.0)
                guard let context = UIGraphicsGetCurrentContext() else {
                    UIGraphicsEndImageContext()
                    return nil
                }

                // Draw the original image (flipped because Core Graphics has inverted Y)
                context.saveGState()
                context.translateBy(x: 0, y: imageHeight)
                context.scaleBy(x: 1, y: -1)
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
                context.restoreGState()

                // Calculate scale from scene to image
                let scaleX = imageWidth / size.width
                let scaleY = imageHeight / size.height

                // Draw bounding boxes
                for node in nodes {
                    let color = colorForNodeType(node.type, name: node.name)
                    context.setStrokeColor(color.cgColor)
                    context.setLineWidth(2.0)

                    // Convert scene coordinates to image coordinates
                    // Scene origin is bottom-left, image origin is top-left
                    let x = node.frame.x * scaleX
                    let y = imageHeight - (node.frame.y + node.frame.height) * scaleY
                    let width = node.frame.width * scaleX
                    let height = node.frame.height * scaleY

                    let rect = CGRect(x: x, y: y, width: width, height: height)
                    context.stroke(rect)

                    // Draw label
                    let label = node.name
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 10),
                        .foregroundColor: color,
                        .backgroundColor: UIColor.black.withAlphaComponent(0.5),
                    ]
                    let labelRect = CGRect(x: x, y: y - 12, width: width, height: 12)
                    (label as NSString).draw(in: labelRect, withAttributes: attributes)
                }

                let annotatedImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                return annotatedImage?.pngData()

            #elseif os(macOS)
                // Create an NSImage and draw annotations
                let image = NSImage(cgImage: cgImage, size: CGSize(width: imageWidth, height: imageHeight))
                let annotatedImage = NSImage(size: image.size)

                annotatedImage.lockFocus()

                // Draw original image
                image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)

                // Calculate scale from scene to image
                let scaleX = imageWidth / size.width
                let scaleY = imageHeight / size.height

                // Draw bounding boxes
                for node in nodes {
                    let color = colorForNodeType(node.type, name: node.name)
                    color.setStroke()

                    // Convert scene coordinates to image coordinates
                    // Scene origin is bottom-left, NSImage origin is also bottom-left
                    let x = node.frame.x * scaleX
                    let y = node.frame.y * scaleY
                    let width = node.frame.width * scaleX
                    let height = node.frame.height * scaleY

                    let rect = NSRect(x: x, y: y, width: width, height: height)
                    let path = NSBezierPath(rect: rect)
                    path.lineWidth = 2.0
                    path.stroke()

                    // Draw label background and text
                    let label = node.name
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: 10),
                        .foregroundColor: color,
                        .backgroundColor: NSColor.black.withAlphaComponent(0.5),
                    ]
                    let labelSize = (label as NSString).size(withAttributes: attributes)
                    let labelRect = NSRect(
                        x: x,
                        y: y + height + 2,
                        width: labelSize.width + 4,
                        height: labelSize.height
                    )
                    (label as NSString).draw(in: labelRect, withAttributes: attributes)
                }

                annotatedImage.unlockFocus()

                guard let tiffData = annotatedImage.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
                return bitmap.representation(using: .png, properties: [:])
            #else
                return nil
            #endif
        }

        /// Get color for node type for annotation
        private func colorForNodeType(_ type: String, name: String) -> SKColor {
            // Player characters - green
            if name == "nathaniel" || name == "hermes" || type == "Player" || type == "Companion" {
                return SKColor.green
            }
            // Enemies - red
            if name.hasPrefix("enemy_") || type == "Enemy" {
                return SKColor.red
            }
            // Towers/defenses - cyan
            if type.contains("Tower") || name.contains("tower") {
                return SKColor.cyan
            }
            // UI elements - yellow
            if name.contains("Button") || name.contains("button") || type == "SKLabelNode" {
                return SKColor.yellow
            }
            // Projectiles - orange
            if type.contains("Projectile") || name.contains("projectile") {
                return SKColor.orange
            }
            // Default - white
            return SKColor.white
        }
    }

    extension SKNode {
        /// Convert node to NodeInfo for the command server
        public func toNodeInfo(interactive: Bool = false, properties: [String: String]? = nil) -> GameCommandServer
            .NodeInfo
        {
            let frame = frame
            return GameCommandServer.NodeInfo(
                name: name ?? "unnamed",
                type: String(describing: type(of: self)),
                frame: GameCommandServer.FrameInfo(
                    x: frame.origin.x,
                    y: frame.origin.y,
                    width: frame.size.width,
                    height: frame.size.height
                ),
                interactive: interactive,
                properties: properties
            )
        }
    }

    extension SKScene {
        /// Find a named button at the given point using frame-based hit testing with expanded hit area.
        /// This is more reliable than nodes(at:) for SKLabelNodes which have tight glyph-based hit areas.
        /// - Parameters:
        ///   - point: The point to test in scene coordinates
        ///   - hitAreaExpansion: How much to expand the hit area (default 20 points)
        /// - Returns: The name of the button if found, nil otherwise
        public func findButtonAtPoint(_ point: CGPoint, hitAreaExpansion: CGFloat = 20) -> String? {
            for child in children {
                guard let name = child.name, !name.isEmpty else { continue }

                // Get frame and expand it for easier hit testing
                let frame = child.frame
                let expandedFrame = frame.insetBy(dx: -hitAreaExpansion, dy: -hitAreaExpansion)

                if expandedFrame.contains(point) {
                    return name
                }
            }
            return nil
        }

        /// Inject a tap at a point, using frame-based hit testing for buttons.
        /// Falls back to tapping at button center if a button is found.
        /// - Parameter point: The point in scene coordinates
        /// - Returns: The button name if a button was tapped, nil if tap went to scene directly
        public func injectTapAtButton(_ point: CGPoint) -> String? {
            // First try to find a button at this point using expanded frame hit testing
            if let buttonName = findButtonAtPoint(point) {
                // Found a button - tap at its center for reliable hit
                if let button = children.first(where: { $0.name == buttonName }) {
                    return buttonName
                }
            }
            return nil
        }
    }

#endif

// Available in all builds - notification only posted in DEBUG
extension SKView {
    /// Present a scene and post a notification for scene change tracking.
    /// Use this instead of presentScene() directly for proper command server integration.
    public func presentSceneWithNotification(_ scene: SKScene, transition: SKTransition? = nil) {
        if let transition {
            presentScene(scene, transition: transition)
            #if DEBUG
                // Delay notification until after transition completes so skView.scene returns new scene
                // Use 0.6s delay which covers most common transition durations (0.3-0.5s)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    NotificationCenter.default.post(name: .skViewDidPresentScene, object: self)
                }
            #endif
        } else {
            presentScene(scene)
            #if DEBUG
                NotificationCenter.default.post(name: .skViewDidPresentScene, object: self)
            #endif
        }
    }
}
