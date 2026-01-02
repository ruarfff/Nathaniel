import Foundation

// MARK: - Targeting Behavior

/// Targeting behavior modes that determine how an entity acquires targets
enum TargetingBehavior {
    /// Actively seek targets within vision range
    case aggressive

    /// Only attack enemies within weapon range (don't pursue)
    case defensive

    /// Only attack when explicitly commanded by player
    case passive

    /// Prioritize threats to a protected ally (e.g., Hermes protecting Nathaniel)
    case supportive
}

// MARK: - Combat Capable Protocol

/// Protocol for entities that can engage in combat with targeting capabilities
protocol CombatCapable: AnyObject {
    /// Current target being attacked (may be auto-acquired or manual)
    var currentTarget: Character? { get set }

    /// Manual target override set by player (takes priority over auto-targeting)
    var manualTargetOverride: Character? { get set }

    /// Current targeting behavior mode
    var targetingBehavior: TargetingBehavior { get set }

    /// Range at which this entity can attack
    var attackRange: CGFloat { get }

    /// Range at which this entity can detect enemies
    var visionRange: CGFloat { get }

    /// Position of this entity
    var position: CGPoint { get }

    /// Find the best target based on current behavior and threat assessment
    /// - Parameters:
    ///   - enemies: Available enemies to target
    ///   - allies: Allied characters (for supportive targeting)
    /// - Returns: The best enemy to target, or nil if none suitable
    func findBestTarget(enemies: [Enemy], allies: [Character]) -> Enemy?

    /// Update combat state (called each frame)
    /// - Parameter deltaTime: Time since last update
    func updateCombat(deltaTime: TimeInterval)
}

// MARK: - Default Implementation

extension CombatCapable {
    /// Default target selection based on targeting behavior
    func findBestTarget(enemies: [Enemy], allies: [Character]) -> Enemy? {
        // Manual override always wins
        if let manual = manualTargetOverride, manual.isAlive {
            return manual as? Enemy
        }

        // Filter to alive enemies
        let aliveEnemies = enemies.filter(\.isAlive)
        guard !aliveEnemies.isEmpty else { return nil }

        // Determine range based on behavior
        let searchRange: CGFloat = switch targetingBehavior {
        case .aggressive, .supportive:
            visionRange
        case .defensive:
            attackRange
        case .passive:
            0 // Don't auto-acquire in passive mode
        }

        guard searchRange > 0 else { return nil }

        // Use ThreatAssessment to find best target
        return ThreatAssessment.findBestTarget(
            from: position,
            enemies: aliveEnemies,
            allies: allies,
            behavior: targetingBehavior,
            maxRange: searchRange
        )
    }

    /// Check if current target is still valid
    func isTargetValid(_ target: Character?) -> Bool {
        guard let target else { return false }
        guard target.isAlive else { return false }

        // Check if target is within vision range (not weapon range - allow chasing)
        let dx = target.position.x - position.x
        let dy = target.position.y - position.y
        let distance = hypot(dx, dy)

        return distance <= visionRange
    }
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

    /// Weight for attacking self (highest priority)
    static let selfDefenseWeight: Float = 4.0

    /// HP threshold below which enemy is considered "low HP" (percentage)
    static let lowHPThreshold: Float = 0.25

    /// Bonus score for enemies attacking protected ally (supportive mode)
    static let protectedAllyBonus: Float = 5.0
}

// MARK: - Threat Assessment

/// Utility for assessing enemy threats from the friendly perspective
/// This is the inverse of the enemy ThreatTable - evaluates which enemies
/// friendlies should prioritize attacking.
enum ThreatAssessment {
    /// Assess all enemies and return sorted by threat score (highest first)
    /// - Parameters:
    ///   - from: Position to measure distances from
    ///   - enemies: Enemies to assess
    ///   - allies: Allied characters (for checking who enemies are attacking)
    ///   - behavior: Targeting behavior mode
    ///   - maxRange: Maximum range to consider
    /// - Returns: Array of (enemy, score) pairs sorted by score descending
    static func assessThreats(
        from position: CGPoint,
        enemies: [Enemy],
        allies: [Character],
        behavior: TargetingBehavior,
        maxRange: CGFloat
    ) -> [(enemy: Enemy, score: Float)] {
        var results: [(Enemy, Float)] = []

        for enemy in enemies where enemy.isAlive {
            // Check distance
            let dx = enemy.position.x - position.x
            let dy = enemy.position.y - position.y
            let distance = hypot(dx, dy)

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
        allies: [Character],
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
        allies: [Character],
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

    /// Check if an enemy is attacking a specific character
    static func isEnemyAttacking(_ enemy: Enemy, target: Character) -> Bool {
        guard let enemyTarget = enemy.target else { return false }
        return enemyTarget === target
    }

    /// Get all enemies currently attacking a character
    static func enemiesAttacking(_ target: Character, from enemies: [Enemy]) -> [Enemy] {
        enemies.filter { enemy in
            enemy.isAlive && self.isEnemyAttacking(enemy, target: target)
        }
    }
}
