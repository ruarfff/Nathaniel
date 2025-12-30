#if DEBUG

    import SpriteKit

    /// Debug overlay that visualizes pathfinding for characters.
    /// Shows the current path as a colored line with waypoint markers.
    class PathfindingDebugOverlay: SKNode {
        // MARK: - Constants

        /// Color for player (Nathaniel) path
        private static let playerPathColor = SKColor.cyan

        /// Color for companion (Hermes) path
        private static let companionPathColor = SKColor.yellow

        /// Color for enemy paths
        private static let enemyPathColor = SKColor.red

        /// Size of waypoint markers
        private static let waypointSize: CGFloat = 8

        /// Width of path lines
        private static let lineWidth: CGFloat = 2

        // MARK: - Properties

        /// Weak references to characters to visualize
        private weak var player: Character?
        private weak var companion: Character?
        private var enemies: [Weak<Character>] = []

        /// Shape nodes for paths
        private var playerPathNode: SKShapeNode?
        private var companionPathNode: SKShapeNode?
        private var enemyPathNodes: [SKShapeNode] = []

        /// Waypoint marker nodes
        private var waypointNodes: [SKShapeNode] = []

        // MARK: - Initialization

        override init() {
            super.init()
            name = "pathfindingDebugOverlay"
            zPosition = 9_000 // Above most game elements
        }

        @available(*, unavailable)
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: - Configuration

        /// Configure the overlay with characters to track
        /// - Parameters:
        ///   - player: The player character (Nathaniel)
        ///   - companion: The companion character (Hermes)
        ///   - enemies: Array of enemy characters
        func configure(player: Character?, companion: Character?, enemies: [Character] = []) {
            self.player = player
            self.companion = companion
            self.enemies = enemies.map { Weak($0) }
        }

        /// Update enemy list (call when enemies spawn/die)
        func updateEnemies(_ enemies: [Character]) {
            self.enemies = enemies.map { Weak($0) }
        }

        // MARK: - Update

        /// Update the visualization (call each frame when enabled)
        func update() {
            // Clear existing visualizations
            clearVisualization()

            // Draw player path
            if let player, let pathfinding = player.pathfinding {
                drawPath(
                    pathfinding.remainingPathWorldCoordinates,
                    color: Self.playerPathColor,
                    showWaypoints: true
                )
            }

            // Draw companion path
            if let companion, let pathfinding = companion.pathfinding {
                drawPath(
                    pathfinding.remainingPathWorldCoordinates,
                    color: Self.companionPathColor,
                    showWaypoints: true
                )
            }

            // Draw enemy paths (limit to prevent performance issues)
            let maxEnemyPaths = 5
            for (index, weakEnemy) in enemies.prefix(maxEnemyPaths).enumerated() {
                guard let enemy = weakEnemy.value, let pathfinding = enemy.pathfinding else { continue }
                drawPath(
                    pathfinding.remainingPathWorldCoordinates,
                    color: Self.enemyPathColor.withAlphaComponent(0.5),
                    showWaypoints: false,
                    tag: "enemy_\(index)"
                )
            }
        }

        // MARK: - Drawing

        /// Draw a path with optional waypoint markers
        private func drawPath(_ points: [CGPoint], color: SKColor, showWaypoints: Bool, tag: String? = nil) {
            guard points.count >= 2 else { return }

            // Create path
            let path = CGMutablePath()
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }

            // Create and add shape node
            let shapeNode = SKShapeNode(path: path)
            shapeNode.strokeColor = color
            shapeNode.lineWidth = Self.lineWidth
            shapeNode.lineCap = .round
            shapeNode.lineJoin = .round
            shapeNode.zPosition = 1
            addChild(shapeNode)

            // Add waypoint markers
            if showWaypoints {
                for (index, point) in points.enumerated() {
                    let marker = createWaypointMarker(
                        at: point,
                        color: color,
                        isDestination: index == points.count - 1
                    )
                    addChild(marker)
                    waypointNodes.append(marker)
                }
            }
        }

        /// Create a waypoint marker at the specified position
        private func createWaypointMarker(at position: CGPoint, color: SKColor, isDestination: Bool) -> SKShapeNode {
            let size = isDestination ? Self.waypointSize * 1.5 : Self.waypointSize

            let marker: SKShapeNode
            if isDestination {
                // Destination marker is a filled circle
                marker = SKShapeNode(circleOfRadius: size / 2)
                marker.fillColor = color
                marker.strokeColor = .white
                marker.lineWidth = 1
            } else {
                // Waypoint marker is a small diamond
                let path = CGMutablePath()
                path.move(to: CGPoint(x: 0, y: size / 2))
                path.addLine(to: CGPoint(x: size / 2, y: 0))
                path.addLine(to: CGPoint(x: 0, y: -size / 2))
                path.addLine(to: CGPoint(x: -size / 2, y: 0))
                path.closeSubpath()
                marker = SKShapeNode(path: path)
                marker.fillColor = color.withAlphaComponent(0.5)
                marker.strokeColor = color
                marker.lineWidth = 1
            }

            marker.position = position
            marker.zPosition = 2
            return marker
        }

        /// Clear all visualization nodes
        private func clearVisualization() {
            removeAllChildren()
            waypointNodes.removeAll()
        }
    }

    // MARK: - Weak Reference Wrapper

    /// Weak reference wrapper for storing characters without retaining them
    private class Weak<T: AnyObject> {
        weak var value: T?
        init(_ value: T) {
            self.value = value
        }
    }

#endif
