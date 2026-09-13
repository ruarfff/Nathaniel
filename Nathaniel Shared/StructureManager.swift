//
//  StructureManager.swift
//  Nathaniel Shared
//
//  Manages defensive towers and their battlefield lifetime.
//

import SpriteKit

// MARK: - Structure Manager Delegate

/// Delegate for structure manager events
protocol StructureManagerDelegate: AnyObject {
    /// Called when a Hermes-owned tower is destroyed by enemies
    /// - Parameters:
    ///   - manager: The structure manager
    ///   - remainingCount: Number of Hermes towers still standing
    func structureManager(
        _ manager: StructureManager,
        hermesTowerDestroyed remainingCount: Int
    )
}

// MARK: - Structure Manager

/// Manages all defensive structures in the game
class StructureManager {
    // MARK: - Properties

    /// Delegate for tower destruction events
    weak var delegate: StructureManagerDelegate?

    /// All structures
    private(set) var structures: [DefensiveStructure] = []

    /// Towers owned by Hermes's current deployment
    private var hermesTowers: [DefensiveStructure] = []

    /// Reference to the scene
    weak var scene: SKScene?

    /// Enemy manager for finding targets
    weak var enemyManager: EnemyManager?

    /// Player characters for heal tower targeting
    var playerCharacters: [Character] = []

    /// Z position for structure sprites
    var structureZPosition: CGFloat = 100

    /// Scale for structure sprites
    var structureScale: CGFloat = 1.0

    /// Whether Hermes has any deployed towers
    var hasHermesTowers: Bool {
        !self.hermesTowers.isEmpty
    }

    /// Count of Hermes's deployed towers
    var hermesTowerCount: Int {
        self.hermesTowers.count
    }

    // MARK: - Initialization

    init(scene: SKScene) {
        self.scene = scene
    }

    // MARK: - Structure Management

    /// Add a gun tower at the specified position
    func addGunTower(at position: CGPoint) -> GunTower {
        let tower = GunTower()
        self.setupStructure(tower, at: position)

        // Set up gun tower callbacks
        tower.onFire = { [weak self] projectile in
            guard let scene = self?.scene else { return }
            projectile.sprite.setScale(1.0)
            scene.addChild(projectile.sprite)
        }

        tower.onCheckCollision = { [weak self] projectile in
            self?.enemyManager?.checkProjectileCollision(projectile)
        }

        // Wire up targeting component callbacks
        self.setupTargetingCallbacks(for: tower)

        return tower
    }

    /// Add a heal tower at the specified position
    func addHealTower(at position: CGPoint) -> HealTower {
        let tower = HealTower()
        self.setupStructure(tower, at: position)

        // Set heal targets
        tower.healTargets = self.playerCharacters

        return tower
    }

    /// Add a laser tower at the specified position
    func addLaserTower(at position: CGPoint) -> LaserTower {
        let tower = LaserTower()
        self.setupStructure(tower, at: position)

        // Add beam node to scene
        if let scene {
            tower.setupBeamNode(in: scene)
        }

        // Wire up targeting component callbacks
        self.setupTargetingCallbacks(for: tower)

        return tower
    }

    // MARK: - Hermes Tower Management

    /// Add a tower for Hermes at the specified position
    /// - Parameters:
    ///   - type: The type of tower to build
    ///   - position: Where to place the tower
    /// - Returns: The created tower
    @discardableResult
    func addHermesTower(type: TowerType, at position: CGPoint) -> DefensiveStructure {
        let tower: DefensiveStructure = switch type {
        case .gunTower:
            self.addGunTower(at: position)
        case .laserTower:
            self.addLaserTower(at: position)
        case .healTower:
            self.addHealTower(at: position)
        }

        // Track as Hermes tower
        self.hermesTowers.append(tower)

        print(
            "StructureManager: Added Hermes tower (\(type.displayName)), total Hermes towers: \(self.hermesTowerCount)"
        )

        return tower
    }

    /// Mark an existing tower as Hermes-owned (for restoring saved game)
    func markAsHermesOwned(_ tower: DefensiveStructure) {
        guard !self.hermesTowers.contains(where: { $0 === tower }) else { return }
        self.hermesTowers.append(tower)
    }

    /// Common setup for all structures
    private func setupStructure(_ structure: DefensiveStructure, at position: CGPoint) {
        structure.position = position
        structure.sprite.zPosition = self.structureZPosition

        // Start with zero scale for placement animation
        structure.sprite.setScale(0)

        // Set up health bar (scaled for smaller tower size)
        structure.setupHealthBar(width: 25, yOffset: 5)
        structure.healthBar?.hideWhenFull = false
        structure.healthBar?.node.alpha = 0 // Hide health bar during animation

        // Add destruction callback
        structure.onDestroyed = { [weak self, weak structure] in
            guard let structure else { return }
            self?.removeStructure(structure)
        }

        // Add to scene
        self.scene?.addChild(structure.sprite)
        self.structures.append(structure)

        // Play placement animation and sound
        self.playPlacementFeedback(for: structure)

        let pos = "(\(Int(position.x)), \(Int(position.y)))"
        print("StructureManager: Added \(structure.name) at \(pos), scale: \(self.structureScale)")
    }

    /// Play visual and audio feedback when a tower is placed
    private func playPlacementFeedback(for structure: DefensiveStructure) {
        guard let scene else { return }

        // Play placement sound
        AudioManager.shared.playSoundEffect(.collect, on: scene)

        // Scale-in animation with slight overshoot for "pop" effect
        let targetScale = self.structureScale
        let scaleUp = SKAction.scale(to: targetScale * 1.15, duration: 0.15)
        scaleUp.timingMode = .easeOut
        let scaleDown = SKAction.scale(to: targetScale, duration: 0.1)
        scaleDown.timingMode = .easeIn
        let scaleSequence = SKAction.sequence([scaleUp, scaleDown])

        // Brief white flash effect
        let flashWhite = SKAction.colorize(with: .white, colorBlendFactor: 0.6, duration: 0.1)
        let flashBack = SKAction.colorize(withColorBlendFactor: 0, duration: 0.15)
        let flashSequence = SKAction.sequence([flashWhite, flashBack])

        // Run animations together
        let animationGroup = SKAction.group([scaleSequence, flashSequence])

        // Fade in health bar after animation completes
        let showHealthBar = SKAction.run { [weak structure] in
            structure?.healthBar?.node.alpha = 1.0
        }

        structure.sprite.run(SKAction.sequence([animationGroup, showHealthBar]))
    }

    /// Set up targeting component callbacks for a tower
    /// Wires up the tower's TargetingComponent to find enemies and allies via the manager
    private func setupTargetingCallbacks(for tower: DefensiveStructure) {
        // Provide enemies to the targeting component
        tower.targeting.findEnemies = { [weak self] in
            self?.enemyManager?.aliveEnemies ?? []
        }

        // Provide allies for threat assessment (tower itself + player characters)
        // Tower is first so enemies attacking it get the protectedAllyBonus
        tower.targeting.getAllies = { [weak self, weak tower] in
            guard let self, let tower else { return [] }
            var allies: [Damageable] = [tower]
            allies.append(contentsOf: self.playerCharacters)
            return allies
        }
    }

    /// Remove a structure from the manager
    private func removeStructure(_ structure: DefensiveStructure) {
        if let index = structures.firstIndex(where: { $0 === structure }) {
            self.structures.remove(at: index)
        }
        // Also remove from Hermes towers if applicable
        if let hermesIndex = hermesTowers.firstIndex(where: { $0 === structure }) {
            self.hermesTowers.remove(at: hermesIndex)
            print("StructureManager: Hermes tower destroyed, remaining: \(self.hermesTowerCount)")

            // Notify delegate of tower destruction (for HUD updates)
            self.delegate?.structureManager(
                self,
                hermesTowerDestroyed: self.hermesTowerCount
            )
        }
    }

    // MARK: - Update

    /// Update all structures
    func update(deltaTime: TimeInterval) {
        for structure in self.structures where structure.isActive {
            structure.update(deltaTime: deltaTime)
        }
    }

    // MARK: - Helpers

    /// Get all active structures
    var activeStructures: [DefensiveStructure] {
        self.structures.filter(\.isActive)
    }

    /// Get count of active structures
    var count: Int {
        self.structures.count
    }

    /// Check if a position collides with any active structure
    /// - Parameters:
    ///   - position: World position to check
    ///   - radius: Collision radius of the entity checking (default 0)
    /// - Returns: true if position overlaps any structure
    func collidesWithStructure(at position: CGPoint, entityRadius: CGFloat = 0) -> Bool {
        for structure in self.structures where structure.isActive {
            // Use tower collision radius plus entity radius
            if position.distance(to: structure.position) < BuildConfig.towerCollisionRadius + entityRadius {
                return true
            }
        }
        return false
    }

    /// Clear all structures
    func clear() {
        for structure in self.structures {
            structure.sprite.removeFromParent()
        }
        self.structures.removeAll()
        self.hermesTowers.removeAll()
    }
}
