import SpriteKit

// MARK: - Build Configuration

/// Configuration for Hermes's build system (delegates to GameBalance.Towers)
enum BuildConfig {
    /// Radius around Hermes within which towers can be placed
    static var buildRadius: CGFloat { GameBalance.Towers.buildRadius }

    /// Tower costs (in resources)
    enum TowerCosts {
        static var gunTower: Int { GameBalance.Towers.gunTowerCost }
        static var laserTower: Int { GameBalance.Towers.laserTowerCost }
        static var healTower: Int { GameBalance.Towers.healTowerCost }
    }

    /// Tower placement collision radius (for overlap checks)
    /// Adjusted to match 1.25x scale (50% smaller than original 2.5x)
    static var towerCollisionRadius: CGFloat { GameBalance.Towers.collisionRadius }
}
