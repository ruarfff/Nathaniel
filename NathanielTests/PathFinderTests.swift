@testable import Nathaniel
import XCTest

// MARK: - Mock Collision Grid

/// A simple grid for testing with configurable blocked tiles
class MockCollisionGrid: CollisionGrid {
    let gridWidth: Int
    let gridHeight: Int
    private var blockedTiles: Set<GridPosition>

    init(width: Int, height: Int, blocked: [GridPosition] = []) {
        self.gridWidth = width
        self.gridHeight = height
        self.blockedTiles = Set(blocked)
    }

    func isBlocked(x: Int, y: Int) -> Bool {
        self.blockedTiles.contains(GridPosition(x: x, y: y))
    }

    func block(_ position: GridPosition) {
        self.blockedTiles.insert(position)
    }

    func unblock(_ position: GridPosition) {
        self.blockedTiles.remove(position)
    }
}

// MARK: - PathFinder Tests

final class PathFinderTests: XCTestCase {
    // MARK: - Basic Path Finding

    func testPathFinderFindsDirectPath() {
        // Given: A 5x5 grid with no obstacles
        let grid = MockCollisionGrid(width: 5, height: 5)
        let pathFinder = PathFinder(grid: grid)

        // When: Finding path from (0,0) to (4,4)
        let start = GridPosition(x: 0, y: 0)
        let end = GridPosition(x: 4, y: 4)
        let path = pathFinder.findPath(from: start, to: end)

        // Then: Path should exist and include start and end
        XCTAssertNotNil(path, "Path should be found")
        XCTAssertEqual(path?.first, start, "Path should start at start position")
        XCTAssertEqual(path?.last, end, "Path should end at end position")
    }

    func testPathFinderReturnsNilForBlockedStart() {
        // Given: A grid where the start position is blocked
        let start = GridPosition(x: 0, y: 0)
        let grid = MockCollisionGrid(width: 5, height: 5, blocked: [start])
        let pathFinder = PathFinder(grid: grid)

        // When: Finding path from blocked start
        let end = GridPosition(x: 4, y: 4)
        let path = pathFinder.findPath(from: start, to: end)

        // Then: No path should be found
        XCTAssertNil(path, "Path should not be found when start is blocked")
    }

    func testPathFinderReturnsNilForBlockedEnd() {
        // Given: A grid where the end position is blocked
        let end = GridPosition(x: 4, y: 4)
        let grid = MockCollisionGrid(width: 5, height: 5, blocked: [end])
        let pathFinder = PathFinder(grid: grid)

        // When: Finding path to blocked end
        let start = GridPosition(x: 0, y: 0)
        let path = pathFinder.findPath(from: start, to: end)

        // Then: No path should be found
        XCTAssertNil(path, "Path should not be found when end is blocked")
    }

    func testPathFinderReturnsSingleNodeWhenStartEqualsEnd() {
        // Given: A simple grid
        let grid = MockCollisionGrid(width: 5, height: 5)
        let pathFinder = PathFinder(grid: grid)

        // When: Finding path to same position
        let position = GridPosition(x: 2, y: 2)
        let path = pathFinder.findPath(from: position, to: position)

        // Then: Path should contain just that position
        XCTAssertNotNil(path, "Path should be found")
        XCTAssertEqual(path?.count, 1, "Path should contain exactly one node")
        XCTAssertEqual(path?.first, position, "Path should contain the position")
    }

    // MARK: - Obstacle Avoidance

    func testPathFinderAvoidsObstacles() {
        // Given: A 5x5 grid with a wall blocking the direct path
        //   0 1 2 3 4
        // 0 S . . . .
        // 1 . X X X .
        // 2 . . . . .
        // 3 . . . . .
        // 4 . . . . E
        let blocked = [
            GridPosition(x: 1, y: 1),
            GridPosition(x: 2, y: 1),
            GridPosition(x: 3, y: 1),
        ]
        let grid = MockCollisionGrid(width: 5, height: 5, blocked: blocked)
        let pathFinder = PathFinder(grid: grid)

        // When: Finding path around the wall
        let start = GridPosition(x: 0, y: 0)
        let end = GridPosition(x: 4, y: 4)
        let path = pathFinder.findPath(from: start, to: end)

        // Then: Path should exist and avoid blocked tiles
        XCTAssertNotNil(path, "Path should be found around obstacles")

        // Verify no blocked tiles in path
        if let path {
            for position in path {
                XCTAssertFalse(
                    blocked.contains(position),
                    "Path should not contain blocked tile at (\(position.x), \(position.y))"
                )
            }
        }
    }

    func testPathFinderReturnsNilWhenCompletelyBlocked() {
        // Given: A grid where the end is completely surrounded
        //   0 1 2 3 4
        // 0 S . . . .
        // 1 . . . X X
        // 2 . . . X E
        let blocked = [
            GridPosition(x: 3, y: 1),
            GridPosition(x: 4, y: 1),
            GridPosition(x: 3, y: 2),
        ]
        let grid = MockCollisionGrid(width: 5, height: 3, blocked: blocked)
        let pathFinder = PathFinder(grid: grid)

        // When: Finding path to surrounded position
        let start = GridPosition(x: 0, y: 0)
        let end = GridPosition(x: 4, y: 2)
        let path = pathFinder.findPath(from: start, to: end)

        // Then: No path should be found
        XCTAssertNil(path, "Path should not be found when destination is unreachable")
    }

    // MARK: - Diagonal Movement

    func testPathFinderUsesDiagonalMovement() {
        // Given: A 3x3 grid with no obstacles
        let grid = MockCollisionGrid(width: 3, height: 3)
        let pathFinder = PathFinder(grid: grid)

        // When: Finding path from corner to corner
        let start = GridPosition(x: 0, y: 0)
        let end = GridPosition(x: 2, y: 2)
        let path = pathFinder.findPath(from: start, to: end)

        // Then: Path should use diagonal movement (optimal path is 3 nodes: start, middle, end)
        XCTAssertNotNil(path, "Path should be found")
        // Optimal diagonal path: (0,0) -> (1,1) -> (2,2) = 3 nodes
        XCTAssertEqual(path?.count, 3, "Optimal diagonal path should have 3 nodes")
    }

    func testPathFinderDoesNotCutCorners() {
        // Given: A grid with a corner that would require cutting
        //   0 1 2
        // 0 S X .
        // 1 X . .
        // 2 . . E
        let blocked = [
            GridPosition(x: 1, y: 0),
            GridPosition(x: 0, y: 1),
        ]
        let grid = MockCollisionGrid(width: 3, height: 3, blocked: blocked)
        let pathFinder = PathFinder(grid: grid)

        // When: Finding path
        let start = GridPosition(x: 0, y: 0)
        let end = GridPosition(x: 2, y: 2)
        let path = pathFinder.findPath(from: start, to: end)

        // Then: Path should be nil since diagonal from (0,0) to (1,1) would cut corner
        // The implementation requires both adjacent cardinals to be open for diagonal
        XCTAssertNil(path, "Path should not cut corners through blocked tiles")
    }

    // MARK: - Grid Boundaries

    func testPathFinderRespectsGridBoundaries() {
        // Given: A small grid
        let grid = MockCollisionGrid(width: 3, height: 3)
        let pathFinder = PathFinder(grid: grid)

        // When: Finding path within bounds
        let start = GridPosition(x: 0, y: 0)
        let end = GridPosition(x: 2, y: 2)
        let path = pathFinder.findPath(from: start, to: end)

        // Then: All positions in path should be within bounds
        XCTAssertNotNil(path, "Path should be found")
        if let path {
            for position in path {
                XCTAssertGreaterThanOrEqual(position.x, 0, "X should be >= 0")
                XCTAssertLessThan(position.x, grid.gridWidth, "X should be < width")
                XCTAssertGreaterThanOrEqual(position.y, 0, "Y should be >= 0")
                XCTAssertLessThan(position.y, grid.gridHeight, "Y should be < height")
            }
        }
    }

    // MARK: - Path Optimality

    func testPathFinderFindsOptimalStraightPath() {
        // Given: A 10x1 corridor
        let grid = MockCollisionGrid(width: 10, height: 1)
        let pathFinder = PathFinder(grid: grid)

        // When: Finding path from start to end of corridor
        let start = GridPosition(x: 0, y: 0)
        let end = GridPosition(x: 9, y: 0)
        let path = pathFinder.findPath(from: start, to: end)

        // Then: Path should have exactly 10 nodes (straight line)
        XCTAssertNotNil(path, "Path should be found")
        XCTAssertEqual(path?.count, 10, "Straight path should have 10 nodes")
    }

    func testPathFinderPrefersShortestPath() {
        // Given: A grid with two possible paths
        //   0 1 2 3 4
        // 0 S . . . .
        // 1 X X X . .
        // 2 . . . . E
        // Path 1: around top (shorter)
        // Path 2: around left (longer)
        let blocked = [
            GridPosition(x: 0, y: 1),
            GridPosition(x: 1, y: 1),
            GridPosition(x: 2, y: 1),
        ]
        let grid = MockCollisionGrid(width: 5, height: 3, blocked: blocked)
        let pathFinder = PathFinder(grid: grid)

        // When: Finding path
        let start = GridPosition(x: 0, y: 0)
        let end = GridPosition(x: 4, y: 2)
        let path = pathFinder.findPath(from: start, to: end)

        // Then: Path should exist and be reasonably short
        XCTAssertNotNil(path, "Path should be found")
        // The optimal path goes around the right side using diagonals
        // Path length should be efficient (not excessively long)
        if let path {
            XCTAssertLessThanOrEqual(path.count, 7, "Path should be reasonably short")
        }
    }

    // MARK: - Edge Cases

    func testPathFinderHandlesLargeGrid() {
        // Given: A large grid with no obstacles
        let grid = MockCollisionGrid(width: 100, height: 100)
        let pathFinder = PathFinder(grid: grid)

        // When: Finding path across the grid
        let start = GridPosition(x: 0, y: 0)
        let end = GridPosition(x: 99, y: 99)
        let path = pathFinder.findPath(from: start, to: end)

        // Then: Path should be found within reasonable iterations
        XCTAssertNotNil(path, "Path should be found in large grid")
    }

    func testPathFinderHandlesMaze() {
        // Given: A maze-like grid
        //   0 1 2 3 4
        // 0 S X . . .
        // 1 . X . X .
        // 2 . X . X .
        // 3 . . . X .
        // 4 X X X X E
        // Note: E at (4,4) is reachable from (3,3) -> (4,3) -> (4,4)
        // Actually with these blocks, (4,4) is blocked by the wall, let me fix this
        // Let me make a solvable maze:
        //   0 1 2 3 4
        // 0 S X . . .
        // 1 . X . X .
        // 2 . . . X .
        // 3 X X . . .
        // 4 . . . . E
        let blocked = [
            GridPosition(x: 1, y: 0),
            GridPosition(x: 1, y: 1),
            GridPosition(x: 3, y: 1),
            GridPosition(x: 3, y: 2),
            GridPosition(x: 0, y: 3),
            GridPosition(x: 1, y: 3),
        ]
        let grid = MockCollisionGrid(width: 5, height: 5, blocked: blocked)
        let pathFinder = PathFinder(grid: grid)

        // When: Finding path through the maze
        let start = GridPosition(x: 0, y: 0)
        let end = GridPosition(x: 4, y: 4)
        let path = pathFinder.findPath(from: start, to: end)

        // Then: Path should be found navigating through the maze
        XCTAssertNotNil(path, "Path should be found through maze")
        if let path {
            // Verify path validity
            for position in path {
                XCTAssertFalse(
                    blocked.contains(position),
                    "Path should not contain blocked tile"
                )
            }
        }
    }

    func testPathFinderWithMaxIterationsLimit() {
        // Given: A pathfinder with very low iteration limit
        let grid = MockCollisionGrid(width: 100, height: 100)
        let pathFinder = PathFinder(grid: grid, maxIterations: 10)

        // When: Finding a path that requires many iterations
        let start = GridPosition(x: 0, y: 0)
        let end = GridPosition(x: 99, y: 99)
        let path = pathFinder.findPath(from: start, to: end)

        // Then: Path should not be found due to iteration limit
        XCTAssertNil(path, "Path should not be found with low iteration limit")
    }
}

// MARK: - GridPosition Tests

final class GridPositionTests: XCTestCase {
    func testGridPositionEquality() {
        let pos1 = GridPosition(x: 5, y: 10)
        let pos2 = GridPosition(x: 5, y: 10)
        let pos3 = GridPosition(x: 5, y: 11)

        XCTAssertEqual(pos1, pos2, "Same coordinates should be equal")
        XCTAssertNotEqual(pos1, pos3, "Different coordinates should not be equal")
    }

    func testGridPositionHashable() {
        let pos1 = GridPosition(x: 5, y: 10)
        let pos2 = GridPosition(x: 5, y: 10)

        var set = Set<GridPosition>()
        set.insert(pos1)
        set.insert(pos2)

        XCTAssertEqual(set.count, 1, "Equal positions should hash to same value")
    }
}

// MARK: - PathNode Tests

final class PathNodeTests: XCTestCase {
    func testPathNodeHeuristicCost() {
        // Given: A goal node at (10, 10)
        let goalNode = PathNode(
            parent: nil,
            endNode: nil,
            gridPosition: GridPosition(x: 10, y: 10),
            directCost: 0
        )

        // When: Creating a node at (7, 6) with the goal as end node
        let testNode = PathNode(
            parent: nil,
            endNode: goalNode,
            gridPosition: GridPosition(x: 7, y: 6),
            directCost: 0
        )

        // Then: Heuristic should be Euclidean distance
        // sqrt((10-7)^2 + (10-6)^2) = sqrt(9 + 16) = sqrt(25) = 5
        XCTAssertEqual(testNode.heuristicCost, Float(5.0), accuracy: Float(0.01))
    }

    func testPathNodeTotalCost() {
        // Given: A goal node
        let goalNode = PathNode(
            parent: nil,
            endNode: nil,
            gridPosition: GridPosition(x: 10, y: 10),
            directCost: 0
        )

        // When: Creating a node with direct cost 30 and heuristic cost 5
        let testNode = PathNode(
            parent: nil,
            endNode: goalNode,
            gridPosition: GridPosition(x: 7, y: 6),
            directCost: 30
        )

        // Then: Total cost should be direct + heuristic
        XCTAssertEqual(testNode.totalCost, Float(35.0), accuracy: Float(0.01))
    }

    func testPathNodeIsEqual() {
        let node1 = PathNode(
            parent: nil,
            endNode: nil,
            gridPosition: GridPosition(x: 5, y: 5),
            directCost: 10
        )
        let node2 = PathNode(
            parent: nil,
            endNode: nil,
            gridPosition: GridPosition(x: 5, y: 5),
            directCost: 20 // Different cost, same position
        )
        let node3 = PathNode(
            parent: nil,
            endNode: nil,
            gridPosition: GridPosition(x: 6, y: 5),
            directCost: 10
        )

        XCTAssertTrue(node1.isEqual(to: node2), "Nodes at same position should be equal")
        XCTAssertFalse(node1.isEqual(to: node3), "Nodes at different positions should not be equal")
    }
}
