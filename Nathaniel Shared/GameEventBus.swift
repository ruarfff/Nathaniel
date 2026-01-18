import Foundation
import SpriteKit

// MARK: - Game Events

/// All events that can be published through the event bus
enum GameEvent {
    // MARK: - Enemy Events

    /// An enemy died
    case enemyDied(enemy: Enemy, score: Int)

    /// A boss was defeated
    case bossDefeated

    /// All enemies cleared from the level
    case allEnemiesCleared

    // MARK: - Player Events

    /// A player character died
    case playerDied(character: Character)

    /// A player character respawned
    case playerRespawned(character: Character)

    /// Player took damage
    case playerDamaged(character: Character, damage: Int, remainingHP: Int)

    // MARK: - Resource Events

    /// Resources should be spawned at a position
    case spawnResources(amount: Int, position: CGPoint)

    /// Resources were collected
    case resourcesCollected(amount: Int, total: Int)

    /// Resources were spent
    case resourcesSpent(amount: Int, remaining: Int)

    // MARK: - Structure Events

    /// A structure was built
    case structureBuilt(structure: DefensiveStructure, type: TowerType)

    /// A structure was destroyed
    case structureDestroyed(structure: DefensiveStructure)

    /// Hermes towers were released (for recoup)
    case hermesTowersReleased(count: Int, recoupAmount: Int)

    // MARK: - Level Events

    /// Level state changed
    case levelStateChanged(newState: LevelState)

    /// Score updated
    case scoreUpdated(newScore: Int)

    /// Lives updated
    case livesUpdated(remainingLives: Int)

    /// Level completed (victory)
    case levelCompleted(levelNumber: Int)

    /// Game over
    case gameOver

    // MARK: - Audio Events

    /// Play a sound effect
    case playSoundEffect(effect: AudioManager.SoundEffect)

    /// Play background music
    case playMusic(music: AudioManager.Music)

    /// Stop background music
    case stopMusic
}

// MARK: - Subscription Token

/// Token returned when subscribing, used to unsubscribe
final class EventSubscription {
    fileprivate let id: UUID
    fileprivate weak var bus: GameEventBus?

    fileprivate init(id: UUID, bus: GameEventBus) {
        self.id = id
        self.bus = bus
    }

    /// Cancel this subscription
    func cancel() {
        self.bus?.unsubscribe(id: self.id)
    }

    deinit {
        cancel()
    }
}

// MARK: - Subscriber Wrapper

/// Internal wrapper to hold subscriber references
private final class SubscriberWrapper {
    let id: UUID
    private let handler: (GameEvent) -> Void
    private weak var owner: AnyObject?

    init(id: UUID, owner: AnyObject?, handler: @escaping (GameEvent) -> Void) {
        self.id = id
        self.owner = owner
        self.handler = handler
    }

    /// Returns true if this subscriber is still valid
    var isValid: Bool {
        // If owner was set and is now nil, subscriber is invalid
        self.owner != nil || self.owner == nil
    }

    func handle(_ event: GameEvent) {
        // Only handle if owner is still alive (or no owner was set)
        if self.owner != nil || self.owner == nil {
            self.handler(event)
        }
    }
}

// MARK: - Game Event Bus

/// Central event bus for game-wide communication
/// Use this to decouple managers from direct references to each other
final class GameEventBus {
    // MARK: - Singleton

    static let shared = GameEventBus()

    // MARK: - Properties

    private var subscribers: [UUID: SubscriberWrapper] = [:]
    private let lock = NSLock()

    // MARK: - Initialization

    private init() {}

    // MARK: - Subscribe

    /// Subscribe to all events
    /// - Parameters:
    ///   - owner: Optional weak reference owner. When owner is deallocated, subscription auto-cancels.
    ///   - handler: Called when any event is published
    /// - Returns: Subscription token. Store this to keep the subscription alive, or call cancel() to unsubscribe.
    @discardableResult
    func subscribe(owner: AnyObject? = nil, handler: @escaping (GameEvent) -> Void) -> EventSubscription {
        self.lock.lock()
        defer { lock.unlock() }

        let id = UUID()
        let wrapper = SubscriberWrapper(id: id, owner: owner, handler: handler)
        self.subscribers[id] = wrapper

        return EventSubscription(id: id, bus: self)
    }

    /// Subscribe to specific event types using a filter
    /// - Parameters:
    ///   - owner: Optional weak reference owner
    ///   - filter: Return true for events you want to receive
    ///   - handler: Called when matching events are published
    /// - Returns: Subscription token
    @discardableResult
    func subscribe(
        owner: AnyObject? = nil,
        filter: @escaping (GameEvent) -> Bool,
        handler: @escaping (GameEvent) -> Void
    ) -> EventSubscription {
        self.subscribe(owner: owner) { event in
            if filter(event) {
                handler(event)
            }
        }
    }

    // MARK: - Unsubscribe

    /// Unsubscribe using the subscription ID
    fileprivate func unsubscribe(id: UUID) {
        self.lock.lock()
        defer { lock.unlock() }

        self.subscribers.removeValue(forKey: id)
    }

    /// Remove all subscriptions (for testing or reset)
    func removeAllSubscriptions() {
        self.lock.lock()
        defer { lock.unlock() }

        self.subscribers.removeAll()
    }

    // MARK: - Publish

    /// Publish an event to all subscribers
    /// - Parameter event: The event to publish
    func publish(_ event: GameEvent) {
        self.lock.lock()
        let currentSubscribers = Array(subscribers.values)
        self.lock.unlock()

        for subscriber in currentSubscribers {
            subscriber.handle(event)
        }
    }

    // MARK: - Convenience Publishers

    /// Publish enemy death event
    func enemyDied(_ enemy: Enemy, score: Int) {
        self.publish(.enemyDied(enemy: enemy, score: score))
    }

    /// Publish boss defeated event
    func bossDefeated() {
        self.publish(.bossDefeated)
    }

    /// Publish spawn resources event
    func spawnResources(amount: Int, at position: CGPoint) {
        self.publish(.spawnResources(amount: amount, position: position))
    }

    /// Publish score update event
    func scoreUpdated(_ newScore: Int) {
        self.publish(.scoreUpdated(newScore: newScore))
    }

    /// Publish sound effect event
    func playSoundEffect(_ effect: AudioManager.SoundEffect) {
        self.publish(.playSoundEffect(effect: effect))
    }
}

// MARK: - Event Matching Helpers

extension GameEvent {
    /// Check if this is an enemy-related event
    var isEnemyEvent: Bool {
        switch self {
        case .enemyDied, .bossDefeated, .allEnemiesCleared:
            true
        default:
            false
        }
    }

    /// Check if this is a player-related event
    var isPlayerEvent: Bool {
        switch self {
        case .playerDied, .playerRespawned, .playerDamaged:
            true
        default:
            false
        }
    }

    /// Check if this is a resource-related event
    var isResourceEvent: Bool {
        switch self {
        case .spawnResources, .resourcesCollected, .resourcesSpent:
            true
        default:
            false
        }
    }

    /// Check if this is a structure-related event
    var isStructureEvent: Bool {
        switch self {
        case .structureBuilt, .structureDestroyed, .hermesTowersReleased:
            true
        default:
            false
        }
    }

    /// Check if this is a level-related event
    var isLevelEvent: Bool {
        switch self {
        case .levelStateChanged, .scoreUpdated, .livesUpdated, .levelCompleted, .gameOver:
            true
        default:
            false
        }
    }

    /// Check if this is an audio-related event
    var isAudioEvent: Bool {
        switch self {
        case .playSoundEffect, .playMusic, .stopMusic:
            true
        default:
            false
        }
    }
}
