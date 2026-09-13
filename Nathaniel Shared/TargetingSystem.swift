import Foundation
import SpriteKit

// MARK: - Targeting Behavior

/// Targeting behavior modes that determine how an entity acquires targets
enum TargetingBehavior {
    /// Actively seek targets within vision range
    case aggressive

    /// Only attack enemies within weapon range (don't pursue)
    case defensive

    /// Prioritize threats to a protected ally (e.g., Hermes protecting Nathaniel)
    case supportive
}

// MARK: - Threat Assessment Configuration

/// Configuration for threat assessment scoring
enum ThreatAssessmentConfig {
    /// Weight for distance factor (closer = higher score)
    static let distanceWeight: Float = 1.0

    /// Weight for low HP factor (nearly dead = higher score to finish)
    static let lowHPWeight: Float = 0.5

    /// Weight for aggro factor (attacking allies = highest priority)
    static let aggroWeight: Float = 3.0

    /// HP threshold below which enemy is considered "low HP" (percentage)
    static let lowHPThreshold: Float = 0.25

    /// Bonus score for enemies attacking protected ally (supportive mode)
    static let protectedAllyBonus: Float = 5.0
}

// MARK: - Threat Assessment

/// Utility for assessing enemy threats from the friendly perspective
/// Evaluates which enemies
/// friendlies should prioritize attacking.
enum ThreatAssessment {
    /// Assess all enemies and return sorted by threat score (highest first)
    /// - Parameters:
    ///   - from: Position to measure distances from
    ///   - enemies: Enemies to assess
    ///   - allies: Allied entities (for checking who enemies are attacking)
    ///   - behavior: Targeting behavior mode
    ///   - maxRange: Maximum range to consider
    /// - Returns: Array of (enemy, score) pairs sorted by score descending
    static func assessThreats(
        from position: CGPoint,
        enemies: [Enemy],
        allies: [Damageable],
        behavior: TargetingBehavior,
        maxRange: CGFloat
    ) -> [(enemy: Enemy, score: Float)] {
        var results: [(Enemy, Float)] = []

        for enemy in enemies where enemy.isAlive {
            // Check distance
            let distance = position.distance(to: enemy.position)
            guard distance <= maxRange else { continue }

            // Calculate threat score
            let score = calculateScore(
                for: enemy,
                distance: distance,
                maxRange: maxRange,
                allies: allies,
                behavior: behavior
            )

            results.append((enemy, score))
        }

        // Sort by score descending (highest threat first)
        return results.sorted { $0.1 > $1.1 }
    }

    /// Find the single best target
    static func findBestTarget(
        from position: CGPoint,
        enemies: [Enemy],
        allies: [Damageable],
        behavior: TargetingBehavior,
        maxRange: CGFloat
    ) -> Enemy? {
        let assessed = self.assessThreats(
            from: position,
            enemies: enemies,
            allies: allies,
            behavior: behavior,
            maxRange: maxRange
        )
        return assessed.first?.enemy
    }

    /// Calculate threat score for a single enemy
    private static func calculateScore(
        for enemy: Enemy,
        distance: CGFloat,
        maxRange: CGFloat,
        allies: [Damageable],
        behavior: TargetingBehavior
    ) -> Float {
        var score: Float = 0

        // Distance factor: closer enemies score higher
        // Normalized to 0-1 range, then scaled by weight
        let distanceFactor = 1.0 - Float(distance / maxRange)
        score += distanceFactor * ThreatAssessmentConfig.distanceWeight

        // Low HP factor: nearly dead enemies score higher (finish the kill)
        let hpPercentage = Float(enemy.currentHP) / Float(enemy.maxHP)
        if hpPercentage <= ThreatAssessmentConfig.lowHPThreshold {
            let lowHPFactor = 1.0 - (hpPercentage / ThreatAssessmentConfig.lowHPThreshold)
            score += lowHPFactor * ThreatAssessmentConfig.lowHPWeight
        }

        // Aggro factor: enemies attacking allies score higher
        if let enemyTarget = enemy.target {
            for ally in allies where ally === enemyTarget {
                // Check if this is in supportive mode protecting specific ally
                if behavior == .supportive {
                    // In supportive mode, the first ally is the protected one
                    if ally === allies.first {
                        score += ThreatAssessmentConfig.protectedAllyBonus
                    } else {
                        score += ThreatAssessmentConfig.aggroWeight
                    }
                } else {
                    score += ThreatAssessmentConfig.aggroWeight
                }
                break
            }
        }

        return score
    }
}

// MARK: - Targeting Component

/// Unified targeting component that can be used by any combat entity.
/// Encapsulates all targeting logic including manual override, sticky targeting,
/// and auto-acquisition via ThreatAssessment.
///
/// Usage:
/// ```swift
/// class MyCharacter: Character {
///     let targeting = TargetingComponent(behavior: .aggressive)
///
///     override func update(deltaTime: TimeInterval) {
///         super.update(deltaTime: deltaTime)
///         targeting.update(position: position, isActive: isActive && isAlive)
///     }
/// }
/// ```
class TargetingComponent {
    // MARK: - Configuration

    /// Targeting behavior mode
    var behavior: TargetingBehavior

    /// Range at which this entity can attack
    var attackRange: CGFloat

    /// Range at which this entity can detect enemies
    var visionRange: CGFloat

    // MARK: - State

    /// Current target (may be auto-acquired or from manual override)
    private(set) weak var currentTarget: Character? {
        didSet {
            if oldValue !== self.currentTarget {
                self.onTargetChanged?(self.currentTarget)
            }
        }
    }

    /// Manual target override set by player (takes priority over auto-targeting)
    private(set) weak var manualTargetOverride: Character?

    // MARK: - Callbacks

    /// Called when the current target changes (for updating visual indicators)
    var onTargetChanged: ((Character?) -> Void)?

    /// Provider for enemies in range. Must be set for auto-targeting to work.
    var findEnemies: (() -> [Enemy])?

    /// Provider for allied entities. Used for threat assessment scoring.
    var getAllies: (() -> [Damageable])?

    // MARK: - Initialization

    /// Create a new targeting component
    /// - Parameters:
    ///   - behavior: Initial targeting behavior mode
    ///   - attackRange: Range at which entity can attack
    ///   - visionRange: Range at which entity can detect enemies
    init(behavior: TargetingBehavior, attackRange: CGFloat, visionRange: CGFloat) {
        self.behavior = behavior
        self.attackRange = attackRange
        self.visionRange = visionRange
    }

    // MARK: - Manual Targeting

    /// Set a manual target (called when player taps an enemy)
    /// - Parameter target: The enemy to target, or nil to clear
    func setManualTarget(_ target: Enemy?) {
        self.manualTargetOverride = target
        self.currentTarget = target
    }

    /// Clear manual target (called when player taps ground or deselects)
    func clearManualTarget() {
        self.manualTargetOverride = nil
    }

    // MARK: - Target Validation

    /// Check if current target is in attack range
    /// - Parameter position: Current position of the targeting entity
    /// - Returns: true if target is within attack range
    func isTargetInAttackRange(from position: CGPoint) -> Bool {
        guard let target = currentTarget else { return false }
        return position.distance(to: target.position) <= self.attackRange
    }

    // MARK: - Targeting Update

    /// Update targeting logic. Call this each frame.
    /// Handles manual override, sticky targeting, and auto-acquisition.
    /// - Parameters:
    ///   - position: Current position of the targeting entity
    ///   - isActive: Whether the entity is active and can target (e.g., isActive && isAlive)
    func update(position: CGPoint, isActive: Bool) {
        guard isActive else {
            self.currentTarget = nil
            return
        }

        // Manual override always takes priority
        if let manual = manualTargetOverride, manual.isAlive {
            self.currentTarget = manual
            return
        }

        // Clear manual override if target is dead
        if self.manualTargetOverride != nil, self.manualTargetOverride?.isAlive != true {
            self.manualTargetOverride = nil
        }

        // Check if current target is still valid (sticky targeting)
        if let current = currentTarget {
            if !current.isAlive {
                // Target died - clear it
                self.currentTarget = nil
            } else {
                // Check if target is still in vision range
                if position.distance(to: current.position) > self.visionRange {
                    // Target left vision range - clear it
                    self.currentTarget = nil
                } else {
                    // Keep current target (sticky targeting)
                    return
                }
            }
        }

        // No valid target - find a new one using threat assessment
        self.currentTarget = self.findBestTarget(from: position)
    }

    /// Find the best target using ThreatAssessment
    /// - Parameter position: Position to search from
    /// - Returns: Best enemy target, or nil if none found
    func findBestTarget(from position: CGPoint) -> Enemy? {
        guard let enemies = findEnemies?() else { return nil }
        let allies = self.getAllies?() ?? []

        // Determine search range based on behavior
        let searchRange: CGFloat = switch self.behavior {
        case .aggressive, .supportive:
            self.visionRange
        case .defensive:
            self.attackRange
        }

        guard searchRange > 0 else { return nil }

        return ThreatAssessment.findBestTarget(
            from: position,
            enemies: enemies,
            allies: allies,
            behavior: self.behavior,
            maxRange: searchRange
        )
    }

    // MARK: - Utility

    /// Clear all targeting state
    func clearAll() {
        self.manualTargetOverride = nil
        self.currentTarget = nil
    }
}
