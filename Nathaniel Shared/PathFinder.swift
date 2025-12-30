import Foundation

// MARK: - Path Node

/// Represents a node in the A* search tree
class PathNode {
    /// Parent node in the path (nil for start node)
    var parent: PathNode?

    /// The goal node for heuristic calculation
    weak var endNode: PathNode?

    /// Grid position (tile coordinates)
    let gridPosition: GridPosition

    /// Cost from start to this node (g-score)
    let directCost: Float

    /// Total estimated cost (f-score = g + h)
    var totalCost: Float {
        directCost + heuristicCost
    }

    /// Heuristic cost to goal (h-score)
    var heuristicCost: Float {
        guard let end = endNode else { return 0 }
        let dx = Float(abs(gridPosition.x - end.gridPosition.x))
        let dy = Float(abs(gridPosition.y - end.gridPosition.y))
        // Use Euclidean distance for heuristic
        return sqrt(dx * dx + dy * dy)
    }

    init(parent: PathNode?, endNode: PathNode?, gridPosition: GridPosition, directCost: Float) {
        self.parent = parent
        self.endNode = endNode
        self.gridPosition = gridPosition
        self.directCost = directCost
    }

    /// Check if this node represents the same position as another
    func isEqual(to other: PathNode) -> Bool {
        gridPosition == other.gridPosition
    }
}

// MARK: - Grid Position

/// A position in the tile grid
struct GridPosition: Hashable, Equatable {
    let x: Int
    let y: Int

    static func == (lhs: GridPosition, rhs: GridPosition) -> Bool {
        lhs.x == rhs.x && lhs.y == rhs.y
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

// MARK: - Collision Grid Protocol

/// Protocol for providing collision information to the pathfinder
protocol CollisionGrid {
    /// Map width in tiles
    var gridWidth: Int { get }

    /// Map height in tiles
    var gridHeight: Int { get }

    /// Check if a tile position is blocked/collision
    func isBlocked(x: Int, y: Int) -> Bool
}

// MARK: - Path Finder

/// A* pathfinding algorithm for finding paths on a tile grid
class PathFinder {
    // MARK: - Constants

    /// Cost for moving straight (horizontal/vertical)
    private let costStraight: Float = 10.0

    /// Cost for moving diagonally
    private let costDiagonal: Float = 14.14 // ~sqrt(2) * 10

    // MARK: - Properties

    /// The collision grid to use for pathfinding
    private let grid: CollisionGrid

    /// Maximum iterations to prevent infinite loops
    private let maxIterations: Int

    // MARK: - Initialization

    init(grid: CollisionGrid, maxIterations: Int = 10_000) {
        self.grid = grid
        self.maxIterations = maxIterations
    }

    // MARK: - Public Methods

    /// Find a path from start to end tile positions
    /// - Parameters:
    ///   - start: Starting tile position
    ///   - end: Target tile position
    /// - Returns: Array of grid positions forming the path, or nil if no path found
    func findPath(from start: GridPosition, to end: GridPosition) -> [GridPosition]? {
        // Check if start or end is blocked
        if grid.isBlocked(x: start.x, y: start.y) || grid.isBlocked(x: end.x, y: end.y) {
            return nil
        }

        // Check if already at destination
        if start == end {
            return [start]
        }

        // Initialize data structures
        var openList: [PathNode] = []
        var closedSet: Set<GridPosition> = []
        var nodeCosts: [GridPosition: Float] = [:]

        // Create end node for heuristic calculation
        let endNode = PathNode(parent: nil, endNode: nil, gridPosition: end, directCost: 0)

        // Create and add start node
        let startNode = PathNode(parent: nil, endNode: endNode, gridPosition: start, directCost: 0)
        insertSorted(node: startNode, into: &openList)
        nodeCosts[start] = startNode.totalCost

        var iterations = 0

        // A* main loop
        while !openList.isEmpty, iterations < maxIterations {
            iterations += 1

            // Get node with lowest cost (last in sorted list)
            let currentNode = openList.removeLast()

            // Check if we reached the goal
            if currentNode.gridPosition == end {
                return reconstructPath(from: currentNode)
            }

            // Add to closed set
            closedSet.insert(currentNode.gridPosition)

            // Explore neighbors
            for neighbor in getNeighbors(of: currentNode, endNode: endNode) {
                // Skip if already evaluated
                if closedSet.contains(neighbor.gridPosition) {
                    continue
                }

                // Check if this is a better path
                if let existingCost = nodeCosts[neighbor.gridPosition] {
                    if neighbor.totalCost >= existingCost {
                        continue
                    }
                    // Remove old node from open list (we found a better path)
                    openList.removeAll { $0.gridPosition == neighbor.gridPosition }
                }

                // Add to open list
                insertSorted(node: neighbor, into: &openList)
                nodeCosts[neighbor.gridPosition] = neighbor.totalCost
            }
        }

        // No path found
        return nil
    }

    // MARK: - Private Methods

    /// Insert a node into the open list, maintaining sort order by total cost (descending)
    private func insertSorted(node: PathNode, into list: inout [PathNode]) {
        let cost = node.totalCost
        var index = 0

        // Find insertion point (sorted descending so lowest cost is last)
        while index < list.count, cost < list[index].totalCost {
            index += 1
        }

        list.insert(node, at: index)
    }

    /// Get valid neighboring nodes
    private func getNeighbors(of node: PathNode, endNode: PathNode) -> [PathNode] {
        var neighbors: [PathNode] = []

        let x = node.gridPosition.x
        let y = node.gridPosition.y

        // Track which cardinal directions are open (for diagonal movement)
        var leftOpen = false
        var rightOpen = false
        var upOpen = false
        var downOpen = false

        // Check cardinal directions
        // Left
        if x > 0, !grid.isBlocked(x: x - 1, y: y) {
            leftOpen = true
            neighbors.append(PathNode(
                parent: node,
                endNode: endNode,
                gridPosition: GridPosition(x: x - 1, y: y),
                directCost: node.directCost + costStraight
            ))
        }

        // Right
        if x < grid.gridWidth - 1, !grid.isBlocked(x: x + 1, y: y) {
            rightOpen = true
            neighbors.append(PathNode(
                parent: node,
                endNode: endNode,
                gridPosition: GridPosition(x: x + 1, y: y),
                directCost: node.directCost + costStraight
            ))
        }

        // Up
        if y > 0, !grid.isBlocked(x: x, y: y - 1) {
            upOpen = true
            neighbors.append(PathNode(
                parent: node,
                endNode: endNode,
                gridPosition: GridPosition(x: x, y: y - 1),
                directCost: node.directCost + costStraight
            ))
        }

        // Down
        if y < grid.gridHeight - 1, !grid.isBlocked(x: x, y: y + 1) {
            downOpen = true
            neighbors.append(PathNode(
                parent: node,
                endNode: endNode,
                gridPosition: GridPosition(x: x, y: y + 1),
                directCost: node.directCost + costStraight
            ))
        }

        // Check diagonal directions (only if both adjacent cardinal directions are open)
        // Up-Left
        if upOpen, leftOpen, !grid.isBlocked(x: x - 1, y: y - 1) {
            neighbors.append(PathNode(
                parent: node,
                endNode: endNode,
                gridPosition: GridPosition(x: x - 1, y: y - 1),
                directCost: node.directCost + costDiagonal
            ))
        }

        // Up-Right
        if upOpen, rightOpen, !grid.isBlocked(x: x + 1, y: y - 1) {
            neighbors.append(PathNode(
                parent: node,
                endNode: endNode,
                gridPosition: GridPosition(x: x + 1, y: y - 1),
                directCost: node.directCost + costDiagonal
            ))
        }

        // Down-Left
        if downOpen, leftOpen, !grid.isBlocked(x: x - 1, y: y + 1) {
            neighbors.append(PathNode(
                parent: node,
                endNode: endNode,
                gridPosition: GridPosition(x: x - 1, y: y + 1),
                directCost: node.directCost + costDiagonal
            ))
        }

        // Down-Right
        if downOpen, rightOpen, !grid.isBlocked(x: x + 1, y: y + 1) {
            neighbors.append(PathNode(
                parent: node,
                endNode: endNode,
                gridPosition: GridPosition(x: x + 1, y: y + 1),
                directCost: node.directCost + costDiagonal
            ))
        }

        return neighbors
    }

    /// Reconstruct the path from end node to start
    private func reconstructPath(from endNode: PathNode) -> [GridPosition] {
        var path: [GridPosition] = []
        var current: PathNode? = endNode

        while let node = current {
            path.insert(node.gridPosition, at: 0)
            current = node.parent
        }

        return path
    }
}

// MARK: - TMX Collision Grid Adapter

/// Adapter to use TMXRenderer's collision layer as a CollisionGrid
class TMXCollisionGrid: CollisionGrid {
    private let renderer: TMXRenderer

    var gridWidth: Int { renderer.map.width }
    var gridHeight: Int { renderer.map.height }

    init(renderer: TMXRenderer) {
        self.renderer = renderer
    }

    func isBlocked(x: Int, y: Int) -> Bool {
        !renderer.isWalkable(tileX: x, tileY: y)
    }
}

// MARK: - Path Follower

/// Helper class for following a path smoothly
class PathFollower {
    /// The path to follow (grid positions)
    private var path: [GridPosition] = []

    /// Current index in the path
    private var currentIndex: Int = 0

    /// The map renderer for coordinate conversion
    private weak var renderer: TMXRenderer?

    /// Whether the follower has reached the end of the path
    var isComplete: Bool {
        path.isEmpty || currentIndex >= path.count
    }

    /// Current target position in world coordinates
    var currentTarget: CGPoint? {
        guard !isComplete, let renderer else { return nil }
        let gridPos = path[currentIndex]
        return renderer.tileToWorld(x: gridPos.x, y: gridPos.y)
    }

    /// Full path converted to world coordinates for debug visualization
    var pathInWorldCoordinates: [CGPoint] {
        guard let renderer else { return [] }
        return path.map { renderer.tileToWorld(x: $0.x, y: $0.y) }
    }

    /// Remaining path (from current index to end) in world coordinates
    var remainingPathInWorldCoordinates: [CGPoint] {
        guard let renderer, currentIndex < path.count else { return [] }
        return path[currentIndex...].map { renderer.tileToWorld(x: $0.x, y: $0.y) }
    }

    init(renderer: TMXRenderer?) {
        self.renderer = renderer
    }

    /// Set a new path to follow
    func setPath(_ path: [GridPosition]) {
        self.path = path
        currentIndex = 0
    }

    /// Clear the current path
    func clear() {
        path.removeAll()
        currentIndex = 0
    }

    /// Update the follower - call when reaching a waypoint
    /// - Parameter currentPosition: Current world position
    /// - Parameter arrivalDistance: Distance considered "arrived" at waypoint
    /// - Returns: The next target position, or nil if path complete
    func update(currentPosition: CGPoint, arrivalDistance: CGFloat = 16) -> CGPoint? {
        guard let target = currentTarget else { return nil }

        let dx = target.x - currentPosition.x
        let dy = target.y - currentPosition.y
        let distance = hypot(dx, dy)

        // Check if we've reached the current waypoint
        if distance <= arrivalDistance {
            currentIndex += 1
            return currentTarget
        }

        return target
    }
}
