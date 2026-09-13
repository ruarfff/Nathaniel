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
        SavedCharacterState(
            position: SavedPoint(position),
            currentHP: currentHP,
            maxHP: maxHP,
            facingDirection: SavedFacingDirection(from: facingDirection),
            destination: destination.map { SavedPoint($0) }
        )
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
        SavedHermesState(
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
        case is Grunt: .grunt
        case is Soldier: .soldier
        case is Boss: .boss
        case is Spawner: .spawner
        default: nil
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
            targetIndex: targetIndex,
            timeUntilNextSpawn: (self as? Spawner)?.timeUntilNextSpawn,
            initialSpawnsRemaining: (self as? Spawner)?.initialSpawnsRemaining
        )
    }

    /// Restore enemy state from saved state
    func restore(from state: SavedEnemyState) {
        if let spawner = self as? Spawner,
           let remainingTime = state.timeUntilNextSpawn,
           let initialSpawns = state.initialSpawnsRemaining
        {
            spawner.restoreSpawnState(timeUntilNextSpawn: remainingTime, initialSpawnsRemaining: initialSpawns)
        }
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
        case is GunTower: .gunTower
        case is LaserTower: .laserTower
        case is HealTower: .healTower
        default: nil
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
            cooldownRemaining: 0, // Cooldown resets on load
            constructionCost: self.constructionCost
        )
    }
}

// MARK: - Resource Extension

extension Resource {
    func toSavedResourceState() -> SavedResourceState {
        SavedResourceState(
            position: SavedPoint(position),
            amount: amount,
            timeToExpiration: timeToExpiration,
            isCarried: collectionState == .collecting
        )
    }
}
