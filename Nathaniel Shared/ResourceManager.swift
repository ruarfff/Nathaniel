import SpriteKit

// MARK: - ResourceManager Delegate

/// Protocol for resource manager events
protocol ResourceManagerDelegate: AnyObject {
    /// Called when the total resource count changes
    func resourceManager(_ manager: ResourceManager, didUpdateTotal total: Int)

    /// Called when a resource is collected
    func resourceManager(_ manager: ResourceManager, didCollectResource amount: Int)
}

// MARK: - ResourceManager

/// Central manager for the resource system
class ResourceManager {
    // MARK: - Singleton

    static let shared = ResourceManager()

    // MARK: - Properties

    /// All active resources on the battlefield
    private(set) var resources: [Resource] = []

    /// Total collected resources (player's wallet)
    private(set) var totalCollected: Int = 0

    /// Reference to the scene for adding sprites
    weak var scene: SKScene?

    /// Delegate for events
    weak var delegate: ResourceManagerDelegate?

    /// Characters that can collect resources (players)
    var collectors: [Character] = []

    // MARK: - Statistics

    /// Total resources spawned this session
    private(set) var totalSpawned: Int = 0

    /// Total resources that expired without collection
    private(set) var totalExpired: Int = 0

    // MARK: - Initialization

    private init() {}

    /// Reset all state (for new game/level)
    func reset() {
        // Remove all resource sprites
        for resource in self.resources {
            resource.sprite.removeFromParent()
        }
        self.resources.removeAll()

        // Reset totals
        self.totalCollected = 0
        self.totalSpawned = 0
        self.totalExpired = 0

        // Notify delegate
        self.delegate?.resourceManager(self, didUpdateTotal: self.totalCollected)
    }

    /// Reset only the battlefield resources (keep wallet for level transitions)
    func resetBattlefield() {
        for resource in self.resources {
            resource.sprite.removeFromParent()
        }
        self.resources.removeAll()
        self.totalSpawned = 0
        self.totalExpired = 0
    }

    /// Restore resource total from saved game
    func restore(total: Int) {
        self.totalCollected = total
        self.delegate?.resourceManager(self, didUpdateTotal: self.totalCollected)
    }

    // MARK: - Spawning

    /// Spawn a resource at a position
    /// - Parameters:
    ///   - amount: The value of the resource
    ///   - position: Where to spawn
    /// - Returns: The created resource
    @discardableResult
    func spawnResource(amount: Int, at position: CGPoint) -> Resource {
        let resource = Resource(amount: amount, position: position)

        // Add to scene
        self.scene?.addChild(resource.sprite)

        // Track
        self.resources.append(resource)
        self.totalSpawned += 1

        // Add spawn effect
        self.addSpawnEffect(at: position)

        return resource
    }

    /// Spawn resources from a dying enemy
    /// - Parameter enemy: The enemy that died
    func spawnFromEnemy(_ enemy: Enemy) {
        let amount = enemy.calculateResourceDrop()
        guard amount > 0 else { return }

        // Spawn at enemy position with slight random offset
        let offsetX = CGFloat.random(in: -10 ... 10)
        let offsetY = CGFloat.random(in: -10 ... 10)
        let position = CGPoint(
            x: enemy.position.x + offsetX,
            y: enemy.position.y + offsetY
        )

        self.spawnResource(amount: amount, at: position)
    }

    /// Add a visual spawn effect
    private func addSpawnEffect(at position: CGPoint) {
        guard let scene else { return }

        // Create a brief flash/pop effect
        let flash = SKShapeNode(circleOfRadius: 15)
        flash.fillColor = SKColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 0.8)
        flash.strokeColor = .clear
        flash.position = position
        flash.zPosition = 49 // Just below resources
        scene.addChild(flash)

        // Animate: expand and fade out
        let expand = SKAction.scale(to: 2.0, duration: 0.2)
        let fade = SKAction.fadeOut(withDuration: 0.2)
        let group = SKAction.group([expand, fade])
        let remove = SKAction.removeFromParent()

        flash.run(SKAction.sequence([group, remove]))
    }

    // MARK: - Update

    /// Update all resources (call each frame)
    func update(deltaTime: TimeInterval) {
        var indicesToRemove: [Int] = []

        for (index, resource) in self.resources.enumerated() {
            // Check for auto-collection before updating
            if resource.collectionState == .idle {
                self.checkAutoCollection(for: resource)
            }

            // Update the resource
            resource.update(deltaTime: deltaTime)

            // Check if should be removed
            if !resource.isActive {
                if resource.collectionState == .collected {
                    // Successfully collected
                    self.collectResource(resource)
                } else {
                    // Expired
                    self.totalExpired += 1
                }
                indicesToRemove.append(index)
            }
        }

        // Remove inactive resources (in reverse order)
        for index in indicesToRemove.reversed() {
            let resource = self.resources[index]
            resource.sprite.removeFromParent()
            self.resources.remove(at: index)
        }
    }

    // MARK: - Collection

    /// Check if any collector is in range and start auto-collection
    private func checkAutoCollection(for resource: Resource) {
        for collector in self.collectors where collector.isAlive {
            if resource.isInCollectRange(of: collector) {
                resource.startCollecting(toward: collector)
                break
            }
        }
    }

    /// Add resource value to player's total
    private func collectResource(_ resource: Resource) {
        self.totalCollected += resource.amount

        // Notify delegate
        self.delegate?.resourceManager(self, didCollectResource: resource.amount)
        self.delegate?.resourceManager(self, didUpdateTotal: self.totalCollected)
    }

    /// Spend resources (for building)
    /// - Parameter amount: Amount to spend
    /// - Returns: True if successful, false if insufficient
    func spendResources(_ amount: Int) -> Bool {
        guard self.totalCollected >= amount else {
            return false
        }

        self.totalCollected -= amount
        self.delegate?.resourceManager(self, didUpdateTotal: self.totalCollected)
        return true
    }

    /// Check if player has enough resources
    func canAfford(_ amount: Int) -> Bool {
        self.totalCollected >= amount
    }

    /// Add resources to player's total (e.g., tower recoup, bonuses)
    /// - Parameter amount: Amount to add (must be positive)
    func addResources(_ amount: Int) {
        guard amount > 0 else { return }
        self.totalCollected += amount
        self.delegate?.resourceManager(self, didUpdateTotal: self.totalCollected)
    }

    // MARK: - Queries

    /// Get count of active resources on battlefield
    var activeCount: Int {
        self.resources.count
    }

    /// Get resources near a point
    func resources(near point: CGPoint, radius: CGFloat) -> [Resource] {
        self.resources.filter { resource in
            point.distance(to: resource.position) <= radius
        }
    }
}
