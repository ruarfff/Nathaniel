//
//  GameCommandProtocol.swift
//  Nathaniel Shared
//
//  Defines debug game commands and scene inspection helpers.
//

import Foundation
import SpriteKit

#if DEBUG

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
        ///   - name: The action name (e.g., "loadLevel", "spawnEnemy")
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

        /// Dispatch the small set of debug setup actions.
        public func executeAction(name: String, params: [String: String]?) -> ActionResult {
            guard let action = GameDebugAction(rawValue: name), let scene = self as? SKScene else {
                return .failure("Unknown action: \(name)")
            }
            return action.execute(on: scene, params: params)
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
    }

    extension SKNode {
        /// Convert node to NodeInfo for the command server
        public func toNodeInfo(interactive: Bool = false, properties: [String: String]? = nil) -> GameCommandServer
            .NodeInfo
        {
            let bounds = calculateAccumulatedFrame()
            let frame: CGRect
            if let scene, let parent {
                let corners = [
                    CGPoint(x: bounds.minX, y: bounds.minY),
                    CGPoint(x: bounds.minX, y: bounds.maxY),
                    CGPoint(x: bounds.maxX, y: bounds.minY),
                    CGPoint(x: bounds.maxX, y: bounds.maxY),
                ].map { scene.convert($0, from: parent) }
                let xs = corners.map(\.x)
                let ys = corners.map(\.y)
                let minX = xs.min() ?? 0
                let minY = ys.min() ?? 0
                frame = CGRect(x: minX, y: minY, width: (xs.max() ?? 0) - minX, height: (ys.max() ?? 0) - minY)
            } else {
                frame = bounds
            }
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

    extension SKNode {
        /// Find one visible control per name, including controls nested under a camera.
        func namedControls(_ names: [String]) -> [GameCommandServer.NodeInfo] {
            names.compactMap { name in
                guard let node = childNode(withName: ".//\(name)") else { return nil }
                var ancestor: SKNode? = node
                while let current = ancestor {
                    if current.isHidden {
                        return nil
                    }
                    ancestor = current.parent
                }
                return node.toNodeInfo(interactive: true)
            }
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
    }

#endif
