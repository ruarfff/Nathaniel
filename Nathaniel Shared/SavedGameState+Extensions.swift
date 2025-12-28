//
//  SavedGameState+Extensions.swift
//  Nathaniel Shared
//
//  Extensions to add serialization/deserialization methods to game classes.
//

import SpriteKit

// MARK: - Character Extensions

extension Character {
    /// Create a saved state from this character
    func toSavedCharacterState() -> SavedCharacterState {
        return SavedCharacterState(
            position: SavedPoint(position),
            currentHP: currentHP,
            maxHP: maxHP,
            facingDirection: SavedFacingDirection(from: facingDirection),
            destination: destination.map { SavedPoint($0) }
        )
    }

    /// Restore character state from saved state
    func restoreFromSaved(_ state: SavedCharacterState) {
        position = state.position.cgPoint
        currentHP = state.currentHP
        facingDirection = state.facingDirection.facingDirection
        destination = state.destination?.cgPoint
        updateHealthBar()
        updateTexture()
    }
}

// MARK: - Nathaniel Extensions

extension Nathaniel {
    /// Restore Nathaniel from saved state
    func restoreFromSavedState(_ state: SavedCharacterState) {
        position = state.position.cgPoint
        currentHP = state.currentHP
        facingDirection = state.facingDirection.facingDirection
        destination = state.destination?.cgPoint

        // Reset sprite visibility in case it was dead
        sprite.alpha = 1.0
        sprite.removeAllActions()
        isActive = true

        updateHealthBar()
        updateTexture()
    }
}

// MARK: - Hermes Extensions

extension Hermes {
    /// Create a saved state from Hermes
    func toSavedHermesState() -> SavedHermesState {
        return SavedHermesState(
            characterState: toSavedCharacterState(),
            mode: SavedHermesMode(from: mode)
        )
    }

    /// Restore Hermes from saved state
    func restoreFromSavedState(_ state: SavedHermesState) {
        // Restore base character state
        position = state.characterState.position.cgPoint
        currentHP = state.characterState.currentHP
        facingDirection = state.characterState.facingDirection.facingDirection
        destination = state.characterState.destination?.cgPoint

        // Restore Hermes-specific state
        mode = state.mode.hermesMode

        // Reset sprite visibility
        sprite.alpha = 1.0
        sprite.removeAllActions()
        isActive = true

        updateHealthBar()
        updateTexture()
    }
}

// MARK: - Enemy Extensions

extension Enemy {
    /// Determine the saved enemy type from this enemy instance
    var savedEnemyType: SavedEnemyType? {
        switch self {
        case is Grunt: return .grunt
        case is Soldier: return .soldier
        case is Boss: return .boss
        default: return nil
        }
    }

    /// Create a saved state from this enemy
    func toSavedEnemyState(targetIndex: Int?) -> SavedEnemyState? {
        guard let type = savedEnemyType else { return nil }

        return SavedEnemyState(
            type: type,
            position: SavedPoint(position),
            currentHP: currentHP,
            maxHP: maxHP,
            facingDirection: SavedFacingDirection(from: facingDirection),
            destination: destination.map { SavedPoint($0) },
            targetIndex: targetIndex
        )
    }

    /// Restore enemy state from saved state
    func restore(from state: SavedEnemyState) {
        position = state.position.cgPoint
        currentHP = state.currentHP
        facingDirection = state.facingDirection.facingDirection
        destination = state.destination?.cgPoint

        updateHealthBar()
        updateTexture()
    }
}

// MARK: - DefensiveStructure Extensions

extension DefensiveStructure {
    /// Determine the saved tower type from this structure instance
    var savedTowerType: SavedTowerType? {
        switch self {
        case is GunTower: return .gunTower
        case is LaserTower: return .laserTower
        case is HealTower: return .healTower
        default: return nil
        }
    }

    /// Create a saved state from this tower
    func toSavedTowerState(isHermesOwned: Bool) -> SavedTowerState? {
        guard let type = savedTowerType else { return nil }

        return SavedTowerState(
            type: type,
            position: SavedPoint(position),
            currentHP: currentHP,
            maxHP: maxHP,
            isHermesOwned: isHermesOwned,
            cooldownRemaining: 0  // Cooldown resets on load
        )
    }
}

// MARK: - GameScene Save Extension

extension GameScene {
    /// Create a complete saved game state from the current scene
    func createSaveState(displayName: String) -> SavedGameState? {
        // Get references using Mirror (same approach as command delegate)
        guard let nathaniel = findNathanielForSave(),
              let hermes = findHermesForSave(),
              let levelManager = findLevelManagerForSave() else {
            return nil
        }

        // Collect enemy states
        var enemyStates: [SavedEnemyState] = []
        if let enemyManager = findEnemyManagerForSave() {
            for enemy in enemyManager.enemies where enemy.isAlive {
                // Determine target index
                var targetIndex: Int? = nil
                if let target = enemy.target {
                    if target === nathaniel {
                        targetIndex = 0
                    } else if target === hermes {
                        targetIndex = 1
                    }
                }

                if let state = enemy.toSavedEnemyState(targetIndex: targetIndex) {
                    enemyStates.append(state)
                }
            }
        }

        // Collect tower states
        var towerStates: [SavedTowerState] = []
        if let structureManager = findStructureManagerForSave() {
            let allStructures = structureManager.getAllStructuresForSave()
            let hermesOwnedSet = Set(structureManager.getHermesTowersForSave().map { ObjectIdentifier($0) })

            for structure in allStructures where structure.isActive {
                let isHermesOwned = hermesOwnedSet.contains(ObjectIdentifier(structure))
                if let state = structure.toSavedTowerState(isHermesOwned: isHermesOwned) {
                    towerStates.append(state)
                }
            }
        }

        // Get wave state for wave-based levels
        var currentWave: Int? = nil
        var timeUntilNextWave: TimeInterval? = nil
        if let waveSpawner = findWaveSpawnerForSave() {
            currentWave = waveSpawner.currentWave
            timeUntilNextWave = waveSpawner.timeUntilNextWave
        }

        return SavedGameState(
            savedAt: Date(),
            displayName: displayName,
            levelNumber: levelManager.config.levelNumber,
            elapsedTime: levelManager.elapsedTime,
            score: levelManager.score,
            lives: levelManager.lives,
            resources: ResourceManager.shared.totalCollected,
            nathaniel: nathaniel.toSavedCharacterState(),
            hermes: hermes.toSavedHermesState(),
            enemies: enemyStates,
            towers: towerStates,
            currentWave: currentWave,
            timeUntilNextWave: timeUntilNextWave
        )
    }

    // MARK: - Private Helper Methods (Mirror-based access)

    private func findNathanielForSave() -> Nathaniel? {
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if child.label == "nathaniel", let nathaniel = child.value as? Nathaniel {
                return nathaniel
            }
        }
        return nil
    }

    private func findHermesForSave() -> Hermes? {
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if child.label == "hermes", let hermes = child.value as? Hermes {
                return hermes
            }
        }
        return nil
    }

    private func findLevelManagerForSave() -> LevelManager? {
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if child.label == "levelManager", let manager = child.value as? LevelManager {
                return manager
            }
        }
        return nil
    }

    private func findEnemyManagerForSave() -> EnemyManager? {
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if child.label == "enemyManager", let manager = child.value as? EnemyManager {
                return manager
            }
        }
        return nil
    }

    private func findStructureManagerForSave() -> StructureManager? {
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if child.label == "structureManager", let manager = child.value as? StructureManager {
                return manager
            }
        }
        return nil
    }

    private func findWaveSpawnerForSave() -> WaveSpawner? {
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if child.label == "waveSpawner", let spawner = child.value as? WaveSpawner {
                return spawner
            }
        }
        return nil
    }
}

// MARK: - StructureManager Extension

extension StructureManager {
    /// Get all structures for save (using Mirror to access private property)
    func getAllStructuresForSave() -> [DefensiveStructure] {
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if child.label == "structures", let structures = child.value as? [DefensiveStructure] {
                return structures
            }
        }
        return []
    }

    /// Get Hermes-owned towers for save (using Mirror to access private property)
    func getHermesTowersForSave() -> [DefensiveStructure] {
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if child.label == "hermesTowers", let towers = child.value as? [DefensiveStructure] {
                return towers
            }
        }
        return []
    }
}

// MARK: - WaveSpawner Extension

extension WaveSpawner {
    /// Current wave number for serialization
    var currentWave: Int {
        // Access through Mirror if needed, or expose property
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if child.label == "currentWave", let wave = child.value as? Int {
                return wave
            }
        }
        return 0
    }

    /// Time until next wave for serialization
    var timeUntilNextWave: TimeInterval {
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if child.label == "spawnTimer", let timer = child.value as? TimeInterval {
                return timer
            }
        }
        return 0
    }
}
