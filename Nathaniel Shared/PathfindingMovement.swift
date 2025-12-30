//
//  PathfindingMovement.swift
//  Nathaniel Shared
//
//  Component for A* pathfinding-based character movement.
//

import Foundation

// MARK: - Pathfinding Movement

/// Component that integrates A* pathfinding with character movement.
/// Attach to a Character to enable navigation around obstacles.
class PathfindingMovement {
    // MARK: - Properties

    /// The map renderer for coordinate conversion and collision data
    private weak var renderer: TMXRenderer?

    /// Cached pathfinder instance (avoid recreating each call)
    private var pathFinder: PathFinder?

    /// Active path follower for current movement
    private var pathFollower: PathFollower?

    /// Whether pathfinding is enabled (falls back to direct movement if false)
    var isEnabled: Bool = true

    /// Distance at which waypoints are considered reached
    var waypointArrivalDistance: CGFloat = 16

    /// Whether we currently have an active path
    var hasActivePath: Bool {
        guard let follower = pathFollower else { return false }
        return !follower.isComplete
    }

    /// Current waypoint target (in world coordinates)
    var currentWaypoint: CGPoint? {
        return pathFollower?.currentTarget
    }

    // MARK: - Initialization

    init() {}

    /// Configure the pathfinding component with a map renderer
    /// - Parameter renderer: The TMXRenderer providing collision data and coordinate conversion
    func configure(with renderer: TMXRenderer) {
        self.renderer = renderer

        // Create cached pathfinder using the renderer's collision data
        let collisionGrid = TMXCollisionGrid(renderer: renderer)
        pathFinder = PathFinder(grid: collisionGrid)

        // Create path follower
        pathFollower = PathFollower(renderer: renderer)
    }

    // MARK: - Path Calculation

    /// Calculate a path from current position to destination
    /// - Parameters:
    ///   - from: Starting world position
    ///   - to: Target world position
    /// - Returns: true if a valid path was found, false otherwise
    @discardableResult
    func calculatePath(from start: CGPoint, to end: CGPoint) -> Bool {
        guard isEnabled,
              let renderer = renderer,
              let pathFinder = pathFinder,
              let pathFollower = pathFollower
        else {
            return false
        }

        // Convert world positions to tile coordinates
        let startTile = renderer.worldToTile(point: start)
        let endTile = renderer.worldToTile(point: end)

        let startGrid = GridPosition(x: startTile.x, y: startTile.y)
        let endGrid = GridPosition(x: endTile.x, y: endTile.y)

        // Find path using A*
        guard let path = pathFinder.findPath(from: startGrid, to: endGrid) else {
            // No path found - clear any existing path
            pathFollower.clear()
            return false
        }

        // Set the path on the follower
        pathFollower.setPath(path)
        return true
    }

    /// Update pathfinding and get the next movement target
    /// - Parameter currentPosition: Character's current world position
    /// - Returns: The next waypoint to move toward, or nil if path is complete
    func update(currentPosition: CGPoint) -> CGPoint? {
        guard let pathFollower = pathFollower, !pathFollower.isComplete else {
            return nil
        }

        return pathFollower.update(
            currentPosition: currentPosition,
            arrivalDistance: waypointArrivalDistance
        )
    }

    /// Clear the current path (stop following)
    func clearPath() {
        pathFollower?.clear()
    }

    /// Check if a position is walkable
    /// - Parameter point: World position to check
    /// - Returns: true if the tile at this position is walkable
    func isWalkable(at point: CGPoint) -> Bool {
        guard let renderer = renderer else { return true }
        let tile = renderer.worldToTile(point: point)
        return renderer.isWalkable(tileX: tile.x, tileY: tile.y)
    }

    /// Recalculate path if blocked
    /// - Parameters:
    ///   - currentPosition: Current world position
    ///   - destination: Final destination
    /// - Returns: true if path was recalculated successfully
    @discardableResult
    func recalculateIfBlocked(currentPosition: CGPoint, destination: CGPoint) -> Bool {
        // Check if current waypoint is still valid
        if let waypoint = currentWaypoint, !isWalkable(at: waypoint) {
            // Waypoint became blocked, recalculate
            return calculatePath(from: currentPosition, to: destination)
        }
        return true
    }
}
