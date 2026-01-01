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

    /// Optional callback to check structure collision at a position
    /// Returns true if the position collides with a structure
    var structureCollisionCheck: ((CGPoint, CGFloat) -> Bool)? {
        didSet {
            // Propagate to collision grid when set
            self.collisionGrid?.structureCollisionCheck = self.structureCollisionCheck
        }
    }

    /// Distance at which waypoints are considered reached
    var waypointArrivalDistance: CGFloat = 16

    /// Whether we currently have an active path
    var hasActivePath: Bool {
        guard let follower = pathFollower else { return false }
        return !follower.isComplete
    }

    /// Current waypoint target (in world coordinates)
    var currentWaypoint: CGPoint? {
        self.pathFollower?.currentTarget
    }

    /// Get the full path as world coordinates for debug visualization
    /// - Returns: Array of CGPoints representing the path, or empty if no path
    var pathWorldCoordinates: [CGPoint] {
        self.pathFollower?.pathInWorldCoordinates ?? []
    }

    /// Get remaining path (from current position to end) as world coordinates
    var remainingPathWorldCoordinates: [CGPoint] {
        self.pathFollower?.remainingPathInWorldCoordinates ?? []
    }

    // MARK: - Initialization

    init() {}

    /// The collision grid used by the pathfinder (stored to update structure callback)
    private var collisionGrid: TMXCollisionGrid?

    /// Configure the pathfinding component with a map renderer
    /// - Parameter renderer: The TMXRenderer providing collision data and coordinate conversion
    func configure(with renderer: TMXRenderer) {
        self.renderer = renderer

        // Create cached pathfinder using the renderer's collision data
        let grid = TMXCollisionGrid(renderer: renderer)
        self.collisionGrid = grid
        self.pathFinder = PathFinder(grid: grid)

        // Create path follower
        self.pathFollower = PathFollower(renderer: renderer)
    }

    /// Update the structure collision callback on the pathfinding grid
    /// Call this after setting structureCollisionCheck to ensure it's used during pathfinding
    func updateCollisionCallback() {
        self.collisionGrid?.structureCollisionCheck = self.structureCollisionCheck
    }

    // MARK: - Path Calculation

    /// Calculate a path from current position to destination
    /// - Parameters:
    ///   - from: Starting world position
    ///   - to: Target world position
    /// - Returns: true if a valid path was found, false otherwise
    @discardableResult
    func calculatePath(from start: CGPoint, to end: CGPoint) -> Bool {
        guard self.isEnabled,
              let renderer,
              let pathFinder,
              let pathFollower
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
    /// - Parameters:
    ///   - currentPosition: Character's current world position
    ///   - destination: Final destination (optional, used for recalculation if blocked)
    /// - Returns: The next waypoint to move toward, or nil if path is complete
    func update(currentPosition: CGPoint, destination: CGPoint? = nil) -> CGPoint? {
        guard let pathFollower, !pathFollower.isComplete else {
            return nil
        }

        // Check if current waypoint is blocked (e.g., tower placed on path)
        if let waypoint = currentWaypoint, !isWalkable(at: waypoint) {
            // Path is blocked - attempt to recalculate
            if let dest = destination {
                if self.calculatePath(from: currentPosition, to: dest) {
                    // Successfully recalculated, return new waypoint
                    return pathFollower.currentTarget
                }
            }
            // Can't recalculate or no destination - clear path
            self.clearPath()
            return nil
        }

        return pathFollower.update(
            currentPosition: currentPosition,
            arrivalDistance: self.waypointArrivalDistance
        )
    }

    /// Clear the current path (stop following)
    func clearPath() {
        self.pathFollower?.clear()
    }

    /// Check if a position is walkable (terrain + structures)
    /// - Parameters:
    ///   - point: World position to check
    ///   - entityRadius: Collision radius of the entity (default 0)
    /// - Returns: true if the position is walkable (no terrain or structure collision)
    func isWalkable(at point: CGPoint, entityRadius: CGFloat = 0) -> Bool {
        guard let renderer else { return true }

        // Check terrain collision
        let tile = renderer.worldToTile(point: point)
        if !renderer.isWalkable(tileX: tile.x, tileY: tile.y) {
            return false
        }

        // Check structure collision if callback is set
        if let check = structureCollisionCheck, check(point, entityRadius) {
            return false
        }

        return true
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
            return self.calculatePath(from: currentPosition, to: destination)
        }
        return true
    }
}
