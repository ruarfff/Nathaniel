//
//  Resource.swift
//  Nathaniel Shared
//
//  A Soldier corpse that Nathaniel can carry to Hermes for resources.
//

import SpriteKit

enum ResourceCollectionState {
    case idle
    case collecting
    case collected
}

class Resource: GameEntity {
    // MARK: - Constants

    static let defaultExpirationTime: TimeInterval = 10

    // MARK: - Properties

    let sprite: SKSpriteNode
    let amount: Int
    var isActive = true
    private(set) var collectionState: ResourceCollectionState = .idle
    private(set) var timeToExpiration: TimeInterval
    private weak var carrier: Nathaniel?

    var position: CGPoint {
        get { self.sprite.position }
        set { self.sprite.position = newValue }
    }

    // MARK: - Initialization

    init(amount: Int, position: CGPoint, expirationTime: TimeInterval = Resource.defaultExpirationTime) {
        self.amount = amount
        self.timeToExpiration = expirationTime
        let texture = SKTexture(imageNamed: "corpse")
        texture.filteringMode = .nearest
        self.sprite = SKSpriteNode(texture: texture, size: CGSize(width: 70, height: 60))
        self.sprite.name = "resource"
        self.sprite.position = position
        self.sprite.zPosition = 50
    }

    // MARK: - Public Methods

    func update(deltaTime: TimeInterval) {
        guard self.isActive else { return }

        if self.collectionState == .collecting {
            if let carrier, carrier.isAlive {
                self.position = carrier.position
                return
            }
            // A corpse dropped on death can be recovered after respawning.
            self.drop()
        }

        if self.collectionState == .idle {
            self.timeToExpiration -= deltaTime
            self.isActive = self.timeToExpiration > 0
        }
    }

    func isInCollectRange(of character: Character) -> Bool {
        self.sprite.frame.intersects(character.sprite.frame)
    }

    func startCollecting(toward target: Character) {
        guard self.collectionState == .idle, let nathaniel = target as? Nathaniel else { return }
        self.carrier = nathaniel
        self.collectionState = .collecting
        self.position = nathaniel.position
    }

    func collect() {
        self.carrier = nil
        self.collectionState = .collected
        self.isActive = false
    }

    func drop() {
        self.carrier = nil
        self.collectionState = .idle
        self.timeToExpiration = Self.defaultExpirationTime
    }
}
