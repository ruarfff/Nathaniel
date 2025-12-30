#if DEBUG

    import Foundation
    import SpriteKit

    #if os(iOS) || os(tvOS)
        import UIKit
    #elseif os(macOS)
        import AppKit
    #endif

    /// Utility class for injecting touch/mouse events into SpriteKit scenes
    public class TouchInjector {
        // MARK: - Types

        public enum TouchPhase {
            case began
            case moved
            case ended
            case cancelled
        }

        // MARK: - Properties

        /// The scene to inject touches into
        public weak var scene: SKScene?

        // MARK: - Initialization

        public init(scene: SKScene? = nil) {
            self.scene = scene
        }

        // MARK: - Touch Injection

        #if os(iOS) || os(tvOS)

            /// Inject a tap gesture at the given scene coordinates
            /// - Parameter point: Point in scene coordinates
            /// - Returns: true if the scene received the tap
            public func injectTap(at point: CGPoint) -> Bool {
                guard let scene else {
                    print("[TouchInjector] No scene attached")
                    return false
                }

                // Call the scene's touch handlers directly
                // This works better than trying to create fake UITouch objects
                scene.touchesBegan(at: point)
                scene.touchesEnded(at: point)

                return true
            }

            /// Inject a swipe gesture
            public func injectSwipe(from start: CGPoint, to end: CGPoint, duration: TimeInterval) -> Bool {
                guard let scene else { return false }

                // Simulate swipe with intermediate points
                let steps = max(2, Int(duration * 60)) // 60 fps
                let dx = (end.x - start.x) / CGFloat(steps)
                let dy = (end.y - start.y) / CGFloat(steps)

                scene.touchesBegan(at: start)

                for i in 1 ..< steps {
                    let point = CGPoint(x: start.x + dx * CGFloat(i), y: start.y + dy * CGFloat(i))
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration / Double(steps) * Double(i)) {
                        scene.touchesMoved(at: point)
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    scene.touchesEnded(at: end)
                }

                return true
            }

        #elseif os(macOS)

            /// Inject a click at the given scene coordinates
            public func injectTap(at point: CGPoint) -> Bool {
                guard let scene else {
                    print("[TouchInjector] No scene attached")
                    return false
                }

                // For macOS, call the mouse handlers directly
                scene.mouseDown(at: point)
                scene.mouseUp(at: point)

                return true
            }

            /// Inject a drag gesture
            public func injectSwipe(from start: CGPoint, to end: CGPoint, duration: TimeInterval) -> Bool {
                guard let scene else { return false }

                scene.mouseDown(at: start)

                let steps = max(2, Int(duration * 60))
                let dx = (end.x - start.x) / CGFloat(steps)
                let dy = (end.y - start.y) / CGFloat(steps)

                for i in 1 ..< steps {
                    let point = CGPoint(x: start.x + dx * CGFloat(i), y: start.y + dy * CGFloat(i))
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration / Double(steps) * Double(i)) {
                        scene.mouseDragged(at: point)
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    scene.mouseUp(at: end)
                }

                return true
            }

        #endif
    }

    // MARK: - SKScene Extensions for Simplified Touch Handling

    #if os(iOS) || os(tvOS)

        extension SKScene {
            /// Handle a programmatic touch began at a point
            func touchesBegan(at point: CGPoint) {
                // For GameScene, use the injected touch handler that includes menu logic
                if let gameScene = self as? GameScene {
                    gameScene.handleInjectedTouchBegan(at: point)
                } else if let menuScene = self as? MainMenuScene {
                    menuScene.handleTap(at: point)
                } else if let levelSelectScene = self as? LevelSelectScene {
                    levelSelectScene.handleTap(at: point)
                } else if let optionsScene = self as? OptionsScene {
                    optionsScene.handleTap(at: point)
                } else if let creditsScene = self as? CreditsScene {
                    creditsScene.handleTap(at: point)
                }
            }

            /// Handle a programmatic touch moved
            func touchesMoved(at point: CGPoint) {
                // Most scenes don't need move handling for basic testing
            }

            /// Handle a programmatic touch ended
            func touchesEnded(at point: CGPoint) {
                // Touch ended is handled by touchesBegan for tap gestures
            }
        }

    #elseif os(macOS)

        extension SKScene {
            /// Handle a programmatic mouse down at a point
            func mouseDown(at point: CGPoint) {
                // For GameScene, use the injected touch handler that includes menu logic
                if let gameScene = self as? GameScene {
                    gameScene.handleInjectedTouchBegan(at: point)
                } else if let menuScene = self as? MainMenuScene {
                    menuScene.handleTap(at: point)
                } else if let levelSelectScene = self as? LevelSelectScene {
                    levelSelectScene.handleTap(at: point)
                } else if let optionsScene = self as? OptionsScene {
                    optionsScene.handleTap(at: point)
                } else if let creditsScene = self as? CreditsScene {
                    creditsScene.handleTap(at: point)
                }
            }

            /// Handle a programmatic mouse dragged
            func mouseDragged(at point: CGPoint) {
                // Most scenes don't need drag handling for basic testing
            }

            /// Handle a programmatic mouse up
            func mouseUp(at point: CGPoint) {
                // Mouse up is handled by mouseDown for click gestures
            }
        }

    #endif

#endif
