//
//  SavedGameState.swift
//  Nathaniel Shared
//
//  Codable structures for game state serialization (save/load system).
//

import Foundation
import CoreGraphics

// MARK: - Saved Game State

/// Top-level structure representing a complete saved game
struct SavedGameState: Codable {

    // MARK: - Metadata

    /// Version number for save format compatibility
    let saveVersion: Int = 1

    /// Timestamp when the game was saved
    let savedAt: Date

    /// Display name for this save slot
    var displayName: String

    // MARK: - Level State

    /// Level number (1-5 for campaign, 0 for survival)
    let levelNumber: Int

    /// Elapsed time in seconds
    let elapsedTime: TimeInterval

    /// Current score
    let score: Int

    /// Remaining lives
    let lives: Int

    /// Current resources
    let resources: Int

    // MARK: - Character States

    /// Nathaniel's state
    let nathaniel: SavedCharacterState

    /// Hermes' state
    let hermes: SavedHermesState

    // MARK: - Entity States

    /// All enemies currently in the level
    let enemies: [SavedEnemyState]

    /// All towers currently deployed
    let towers: [SavedTowerState]

    // MARK: - Wave State (for wave-based levels)

    /// Current wave number (nil for map-based levels)
    let currentWave: Int?

    /// Time until next wave spawn (nil if not applicable)
    let timeUntilNextWave: TimeInterval?

    // MARK: - Initialization

    init(
        savedAt: Date = Date(),
        displayName: String,
        levelNumber: Int,
        elapsedTime: TimeInterval,
        score: Int,
        lives: Int,
        resources: Int,
        nathaniel: SavedCharacterState,
        hermes: SavedHermesState,
        enemies: [SavedEnemyState],
        towers: [SavedTowerState],
        currentWave: Int? = nil,
        timeUntilNextWave: TimeInterval? = nil
    ) {
        self.savedAt = savedAt
        self.displayName = displayName
        self.levelNumber = levelNumber
        self.elapsedTime = elapsedTime
        self.score = score
        self.lives = lives
        self.resources = resources
        self.nathaniel = nathaniel
        self.hermes = hermes
        self.enemies = enemies
        self.towers = towers
        self.currentWave = currentWave
        self.timeUntilNextWave = timeUntilNextWave
    }
}

// MARK: - Point Type (for Codable CGPoint)

/// Codable wrapper for CGPoint
struct SavedPoint: Codable, Equatable {
    let x: CGFloat
    let y: CGFloat

    init(_ point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }

    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

// MARK: - Facing Direction (Codable)

/// Serializable version of FacingDirection
enum SavedFacingDirection: Int, Codable, CaseIterable {
    case south = 0
    case southWest = 1
    case north = 2
    case west = 3
    case southEast = 4
    case northEast = 5
    case east = 6
    case northWest = 7

    init(from facingDirection: FacingDirection) {
        self = SavedFacingDirection(rawValue: facingDirection.rawValue) ?? .south
    }

    var facingDirection: FacingDirection {
        FacingDirection(rawValue: rawValue) ?? .south
    }
}

// MARK: - Saved Character State

/// Base character state for serialization
struct SavedCharacterState: Codable {
    /// Position in the scene
    let position: SavedPoint

    /// Current health points
    let currentHP: Int

    /// Maximum health points
    let maxHP: Int

    /// Direction the character is facing
    let facingDirection: SavedFacingDirection

    /// Current movement destination (nil if not moving)
    let destination: SavedPoint?

    init(
        position: SavedPoint,
        currentHP: Int,
        maxHP: Int,
        facingDirection: SavedFacingDirection,
        destination: SavedPoint? = nil
    ) {
        self.position = position
        self.currentHP = currentHP
        self.maxHP = maxHP
        self.facingDirection = facingDirection
        self.destination = destination
    }
}

// MARK: - Hermes Mode (Codable)

/// Serializable version of HermesMode
enum SavedHermesMode: String, Codable {
    case following
    case independent
    case locked

    init(from mode: HermesMode) {
        switch mode {
        case .following: self = .following
        case .independent: self = .independent
        case .locked: self = .locked
        }
    }

    var hermesMode: HermesMode {
        switch self {
        case .following: return .following
        case .independent: return .independent
        case .locked: return .locked
        }
    }
}

// MARK: - Saved Hermes State

/// Hermes-specific state for serialization
struct SavedHermesState: Codable {
    /// Base character state
    let characterState: SavedCharacterState

    /// Current operational mode
    let mode: SavedHermesMode

    init(characterState: SavedCharacterState, mode: SavedHermesMode) {
        self.characterState = characterState
        self.mode = mode
    }
}

// MARK: - Enemy Type (Codable)

/// Serializable enemy type identifier
enum SavedEnemyType: String, Codable {
    case grunt
    case soldier
    case boss

    /// Create the appropriate enemy instance
    func createEnemy() -> Enemy {
        switch self {
        case .grunt:
            return Grunt()
        case .soldier:
            return Soldier()
        case .boss:
            return Boss()
        }
    }
}

// MARK: - Saved Enemy State

/// Enemy state for serialization
struct SavedEnemyState: Codable {
    /// Type of enemy
    let type: SavedEnemyType

    /// Position in the scene
    let position: SavedPoint

    /// Current health points
    let currentHP: Int

    /// Maximum health points
    let maxHP: Int

    /// Direction the enemy is facing
    let facingDirection: SavedFacingDirection

    /// Current movement destination (nil if not moving)
    let destination: SavedPoint?

    /// Index of targeted player character (0 = Nathaniel, 1 = Hermes, nil = no target)
    let targetIndex: Int?

    init(
        type: SavedEnemyType,
        position: SavedPoint,
        currentHP: Int,
        maxHP: Int,
        facingDirection: SavedFacingDirection,
        destination: SavedPoint? = nil,
        targetIndex: Int? = nil
    ) {
        self.type = type
        self.position = position
        self.currentHP = currentHP
        self.maxHP = maxHP
        self.facingDirection = facingDirection
        self.destination = destination
        self.targetIndex = targetIndex
    }
}

// MARK: - Tower Type (Codable)

/// Serializable tower type identifier
enum SavedTowerType: String, Codable {
    case gunTower
    case laserTower
    case healTower

    init(from towerType: TowerType) {
        switch towerType {
        case .gunTower: self = .gunTower
        case .laserTower: self = .laserTower
        case .healTower: self = .healTower
        }
    }

    var towerType: TowerType {
        switch self {
        case .gunTower: return .gunTower
        case .laserTower: return .laserTower
        case .healTower: return .healTower
        }
    }
}

// MARK: - Saved Tower State

/// Tower state for serialization
struct SavedTowerState: Codable {
    /// Type of tower
    let type: SavedTowerType

    /// Position in the scene
    let position: SavedPoint

    /// Current health points
    let currentHP: Int

    /// Maximum health points
    let maxHP: Int

    /// Whether this tower was placed by Hermes (vs map-placed)
    let isHermesOwned: Bool

    /// Attack cooldown remaining (seconds)
    let cooldownRemaining: TimeInterval

    init(
        type: SavedTowerType,
        position: SavedPoint,
        currentHP: Int,
        maxHP: Int,
        isHermesOwned: Bool,
        cooldownRemaining: TimeInterval = 0
    ) {
        self.type = type
        self.position = position
        self.currentHP = currentHP
        self.maxHP = maxHP
        self.isHermesOwned = isHermesOwned
        self.cooldownRemaining = cooldownRemaining
    }
}

// MARK: - Save Slot

/// Represents a save slot with metadata for the save/load UI
struct SaveSlot: Codable, Identifiable {
    /// Unique slot identifier (1-3 typically)
    let id: Int

    /// Whether this slot has a saved game
    var hasSave: Bool

    /// Display name for the save
    var displayName: String?

    /// Level number of the saved game
    var levelNumber: Int?

    /// Timestamp when last saved
    var savedAt: Date?

    /// Elapsed time at save point (for display)
    var elapsedTime: TimeInterval?

    /// Score at save point (for display)
    var score: Int?

    init(id: Int) {
        self.id = id
        self.hasSave = false
    }

    mutating func update(from savedState: SavedGameState) {
        self.hasSave = true
        self.displayName = savedState.displayName
        self.levelNumber = savedState.levelNumber
        self.savedAt = savedState.savedAt
        self.elapsedTime = savedState.elapsedTime
        self.score = savedState.score
    }

    mutating func clear() {
        self.hasSave = false
        self.displayName = nil
        self.levelNumber = nil
        self.savedAt = nil
        self.elapsedTime = nil
        self.score = nil
    }
}
