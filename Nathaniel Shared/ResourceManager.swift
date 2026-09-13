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

    /// Nathaniel carries corpses; Hermes converts them into building resources.
    var collectors: [Character] = []

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

        for case let nathaniel as Nathaniel in self.collectors {
            nathaniel.hasCorpse = false
        }
        self.collectors.removeAll()

        // Notify delegate
        self.delegate?.resourceManager(self, didUpdateTotal: self.totalCollected)
    }

    /// Reset only the battlefield resources (keep wallet for level transitions)
    func resetBattlefield() {
        for resource in self.resources {
            resource.sprite.removeFromParent()
        }
        self.resources.removeAll()
    }

    /// Restore resource total from saved game
    func restore(total: Int) {
        self.totalCollected = total
        self.delegate?.resourceManager(self, didUpdateTotal: self.totalCollected)
    }

    /// Restore loose and carried corpses without crediting the wallet again.
    func restoreBattlefield(_ states: [SavedResourceState], carrier: Nathaniel?) {
        self.resetBattlefield()
        for state in states {
            let resource = Resource(
                amount: state.amount,
                position: state.position.cgPoint,
                expirationTime: state.timeToExpiration
            )
            if state.isCarried, let carrier, carrier.isAlive {
                resource.startCollecting(toward: carrier)
            }
            self.scene?.addChild(resource.sprite)
            self.resources.append(resource)
        }
        carrier?.hasCorpse = self.resources.contains { $0.collectionState == .collecting }
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

        // Add spawn effect
        self.addSpawnEffect(at: position)

        return resource
    }

    /// Spawn resources from a dying enemy
    /// - Parameter enemy: The enemy that died
    func spawnFromEnemy(_ enemy: Enemy) {
        guard enemy is Soldier else { return }
        self.spawnResource(amount: 10, at: enemy.position)
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
        let nathaniel = self.collectors.first { $0 is Nathaniel } as? Nathaniel
        let hermes = self.collectors.first { $0 is Hermes } as? Hermes

        for (index, resource) in self.resources.enumerated() {
            if resource.collectionState == .idle,
               let nathaniel, nathaniel.isAlive, resource.isInCollectRange(of: nathaniel)
            {
                resource.startCollecting(toward: nathaniel)
            }

            // Update the resource
            resource.update(deltaTime: deltaTime)

            if resource.isActive, let hermes, hermes.isAlive, resource.isInCollectRange(of: hermes) {
                resource.collect()
            }

            // Check if should be removed
            if !resource.isActive {
                if resource.collectionState == .collected {
                    // Successfully collected
                    self.collectResource(resource)
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
        nathaniel?.hasCorpse = self.resources.contains { $0.collectionState == .collecting }
    }

    // MARK: - Collection

    func dropCarriedResources() {
        for resource in self.resources where resource.collectionState == .collecting {
            resource.drop()
        }
        for case let nathaniel as Nathaniel in self.collectors {
            nathaniel.hasCorpse = false
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
        guard amount >= 0, self.totalCollected >= amount else {
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
}
