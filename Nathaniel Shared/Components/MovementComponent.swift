import SpriteKit

/// Component handling movement and pathfinding for game entities
class MovementComponent {
    // MARK: - Properties

    /// Movement speed in points per second
    var speed: CGFloat

    /// Maximum speed (for resetting after effects)
    let maxSpeed: CGFloat

    /// Current movement destination (nil if not moving)
    var destination: CGPoint?

    /// Whether the entity is currently moving
    var isMoving: Bool { self.destination != nil }

    /// Pathfinding component for A* navigation (optional)
    var pathfinding: PathfindingMovement?

    /// Final destination when using pathfinding (may differ from current waypoint)
    private var finalDestination: CGPoint?

    /// Stuck detection: count of frames without significant movement
    private var stuckFrameCount: Int = 0

    /// Last position for stuck detection
    private var lastPositionForStuckCheck: CGPoint = .zero

    /// Threshold for stuck detection (frames at 60fps = ~0.5 seconds)
    private let stuckFrameThreshold: Int = 30

    // MARK: - Callbacks

    /// Called when facing direction changes
    var onFacingDirectionChanged: ((FacingDirection) -> Void)?

    /// Called when movement state changes (moving vs idle)
    var onMovementStateChanged: ((Bool) -> Void)?

    // MARK: - Initialization

    init(speed: CGFloat) {
        self.speed = speed
        self.maxSpeed = speed
    }

    // MARK: - Movement Update

    /// Update movement toward destination
    /// - Parameters:
    ///   - currentPosition: The current position of the entity
    ///   - deltaTime: Time elapsed since last update
    ///   - collisionRadius: Radius for collision checking
    /// - Returns: The new position after movement
    func update(currentPosition: CGPoint, deltaTime: TimeInterval, collisionRadius: CGFloat) -> CGPoint {
        // If using pathfinding, get next waypoint
        if let pathfinding, pathfinding.hasActivePath {
            return self.updatePathfindingMovement(
                currentPosition: currentPosition,
                deltaTime: deltaTime,
                collisionRadius: collisionRadius,
                pathfinding: pathfinding
            )
        }

        // Direct movement (no pathfinding)
        guard let dest = destination else {
            return currentPosition
        }

        let newPosition = self.moveTowardPoint(
            from: currentPosition,
            to: dest,
            deltaTime: deltaTime,
            collisionRadius: collisionRadius
        )

        // Check if we've arrived at final destination
        if newPosition.distance(to: dest) <= 5 {
            self.destination = nil
            self.finalDestination = nil
            self.onMovementStateChanged?(false)
        }

        return newPosition
    }

    // MARK: - Pathfinding Movement

    /// Update movement using pathfinding waypoints
    private func updatePathfindingMovement(
        currentPosition: CGPoint,
        deltaTime: TimeInterval,
        collisionRadius: CGFloat,
        pathfinding: PathfindingMovement
    ) -> CGPoint {
        // Get next waypoint from path follower, passing finalDestination for recalculation if blocked
        guard let waypoint = pathfinding.update(currentPosition: currentPosition, destination: self.finalDestination)
        else {
            // Path complete or blocked with no alternative - clear destinations
            self.destination = nil
            self.finalDestination = nil
            self.stuckFrameCount = 0
            self.onMovementStateChanged?(false)
            return currentPosition
        }

        // Move toward current waypoint
        let newPosition = self.moveTowardPoint(
            from: currentPosition,
            to: waypoint,
            deltaTime: deltaTime,
            collisionRadius: collisionRadius
        )

        // Update destination to current waypoint for isMoving check
        self.destination = waypoint

        // Stuck detection: if character hasn't moved significantly, increment counter
        if self.lastPositionForStuckCheck.distance(to: newPosition) < 0.5 {
            self.stuckFrameCount += 1
            if self.stuckFrameCount > self.stuckFrameThreshold {
                // Character is stuck - clear path and try to recalculate
                pathfinding.clearPath()
                if let dest = finalDestination {
                    _ = pathfinding.calculatePath(from: newPosition, to: dest)
                }
                self.stuckFrameCount = 0
            }
        } else {
            self.stuckFrameCount = 0
        }
        self.lastPositionForStuckCheck = newPosition

        return newPosition
    }

    // MARK: - Core Movement

    /// Move toward a specific point
    /// - Parameters:
    ///   - from: Starting position
    ///   - to: Target position
    ///   - deltaTime: Time elapsed
    ///   - collisionRadius: Radius for collision checking
    /// - Returns: The new position after movement
    private func moveTowardPoint(
        from: CGPoint,
        to: CGPoint,
        deltaTime: TimeInterval,
        collisionRadius: CGFloat
    ) -> CGPoint {
        let direction = CGVector(dx: to.x - from.x, dy: to.y - from.y)
        let distance = from.distance(to: to)

        guard distance > 0 else { return from }

        // Normalize and calculate move distance
        let normalizedDir = CGVector(dx: direction.dx / distance, dy: direction.dy / distance)
        let moveDistance = self.speed * CGFloat(deltaTime)
        let actualMove = min(moveDistance, distance)

        // Calculate new position
        var newPosition = CGPoint(
            x: from.x + normalizedDir.dx * actualMove,
            y: from.y + normalizedDir.dy * actualMove
        )

        // Check collision if pathfinding is configured
        if let pathfinding {
            if pathfinding.isWalkable(at: newPosition, entityRadius: collisionRadius) {
                // Position is valid
            } else {
                // Try sliding along X axis
                let slideX = CGPoint(x: newPosition.x, y: from.y)
                if pathfinding.isWalkable(at: slideX, entityRadius: collisionRadius) {
                    newPosition = slideX
                } else {
                    // Try sliding along Y axis
                    let slideY = CGPoint(x: from.x, y: newPosition.y)
                    if pathfinding.isWalkable(at: slideY, entityRadius: collisionRadius) {
                        newPosition = slideY
                    } else {
                        // Both blocked - don't move
                        newPosition = from
                    }
                }
            }
        }

        // Update facing direction
        let newFacing = FacingDirection.from(direction: direction)
        self.onFacingDirectionChanged?(newFacing)
        self.onMovementStateChanged?(true)

        return newPosition
    }

    // MARK: - Movement Commands

    /// Move toward a destination point
    /// If pathfinding is configured, calculates an A* path around obstacles.
    /// Otherwise, moves in a direct line.
    /// - Parameters:
    ///   - point: The destination point
    ///   - from: The starting position
    func moveTo(_ point: CGPoint, from currentPosition: CGPoint) {
        self.finalDestination = point

        // Try pathfinding if available
        if let pathfinding, pathfinding.isEnabled {
            if pathfinding.calculatePath(from: currentPosition, to: point) {
                // Path found - movement will follow waypoints
                self.destination = pathfinding.currentWaypoint ?? point
                return
            }
            // No path found - fall through to direct movement
        }

        // Direct movement (no pathfinding or path not found)
        self.destination = point
    }

    /// Stop movement immediately
    func stop() {
        self.destination = nil
        self.finalDestination = nil
        self.pathfinding?.clearPath()
        self.onMovementStateChanged?(false)
    }

    /// Configure pathfinding for this component
    /// - Parameter renderer: The TMXRenderer providing collision data
    func configurePathfinding(with renderer: TMXRenderer) {
        let pathfinding = PathfindingMovement()
        pathfinding.configure(with: renderer)
        self.pathfinding = pathfinding
    }
}
