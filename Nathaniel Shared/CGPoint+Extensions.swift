import CoreGraphics

extension CGPoint {
    /// Calculate the Euclidean distance to another point.
    /// - Parameter other: The target point to measure distance to.
    /// - Returns: The distance between this point and the other point.
    func distance(to other: CGPoint) -> CGFloat {
        hypot(other.x - x, other.y - y)
    }

    /// Check if this point is within a given range of another point.
    /// - Parameters:
    ///   - other: The target point to check against.
    ///   - range: The maximum distance to consider "within range".
    /// - Returns: True if the distance is less than or equal to range.
    func isWithinRange(_ range: CGFloat, of other: CGPoint) -> Bool {
        self.distance(to: other) <= range
    }
}
