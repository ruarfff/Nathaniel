# Adding Towers

This guide explains how to create new defensive structures (towers) for Nathaniel.

## Tower System Overview

Towers are static defensive structures that Hermes can place. They:
- Have fixed positions (cannot move)
- Automatically target nearby enemies
- Have health and can be destroyed
- Cost resources to build

## Tower Hierarchy

```
GameEntity (Protocol)
  └── Character (Base Class)
      └── DefensiveStructure (Base for Towers)
          ├── GunTower     - Fires bullets at enemies
          ├── LaserTower   - Continuous beam damage
          └── HealTower    - Heals nearby allies
```

## Key Files

| File | Purpose |
|------|---------|
| `DefensiveStructure.swift` | Base class and tower implementations |
| `TowerConfig.swift` | Cost and range constants |
| `StructureManager.swift` | Tower lifecycle and updates |
| `PlacementValidator.swift` | Placement validation |
| `BuildMenu.swift` | Tower selection UI |

## Creating a New Tower

### Step 1: Add to TowerType Enum

In `TowerConfig.swift`:

```swift
enum TowerType: String, CaseIterable {
    case gunTower
    case laserTower
    case healTower
    case slowTower      // New tower type

    var displayName: String {
        switch self {
        case .gunTower: return "Gun Tower"
        case .laserTower: return "Laser Tower"
        case .healTower: return "Heal Tower"
        case .slowTower: return "Slow Tower"
        }
    }

    var cost: Int {
        switch self {
        case .gunTower: return TowerConfig.gunTowerCost
        case .laserTower: return TowerConfig.laserTowerCost
        case .healTower: return TowerConfig.healTowerCost
        case .slowTower: return 8  // New cost
        }
    }

    var description: String {
        switch self {
        case .slowTower: return "Slows enemies in range"
        // ... other cases
        }
    }
}
```

### Step 2: Create the Tower Class

In `DefensiveStructure.swift` or a new file:

```swift
class SlowTower: DefensiveStructure {
    // MARK: - Constants
    static let defaultMaxHP = 400
    static let defaultAttackRange: CGFloat = 300
    static let slowAmount: CGFloat = 0.5      // 50% speed reduction
    static let slowDuration: TimeInterval = 2.0

    // MARK: - Properties
    private var affectedEnemies: Set<ObjectIdentifier> = []
    private var pulseTimer: TimeInterval = 0
    private let pulseInterval: TimeInterval = 1.0

    // MARK: - Visual
    private var slowAura: SKShapeNode?

    // MARK: - Initialization
    init() {
        super.init(
            name: "SlowTower",
            maxHP: SlowTower.defaultMaxHP,
            attackRange: SlowTower.defaultAttackRange
        )

        // Load tower texture
        loadTexture(named: "slowtower", size: CGSize(width: 48, height: 64))
        setupSlowAura()
    }

    private func setupSlowAura() {
        let aura = SKShapeNode(circleOfRadius: attackRange)
        aura.strokeColor = SKColor(red: 0.3, green: 0.3, blue: 0.8, alpha: 0.3)
        aura.fillColor = SKColor(red: 0.3, green: 0.3, blue: 0.8, alpha: 0.1)
        aura.zPosition = -1
        sprite.addChild(aura)
        slowAura = aura

        // Pulse animation
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 1.0),
            SKAction.scale(to: 1.0, duration: 1.0)
        ])
        aura.run(SKAction.repeatForever(pulse))
    }

    // MARK: - Update
    override func update(deltaTime: TimeInterval) {
        guard isActive && isAlive else { return }

        pulseTimer += deltaTime
        if pulseTimer >= pulseInterval {
            pulseTimer = 0
            applySlowToNearbyEnemies()
        }
    }

    private func applySlowToNearbyEnemies() {
        guard let enemies = findEnemiesInRange?() else { return }

        for enemy in enemies {
            // Apply slow effect
            enemy.applySpeedModifier(SlowTower.slowAmount, duration: SlowTower.slowDuration)

            // Visual feedback
            showSlowEffect(on: enemy)
        }
    }

    private func showSlowEffect(on enemy: Enemy) {
        let effect = SKShapeNode(circleOfRadius: 15)
        effect.fillColor = .clear
        effect.strokeColor = SKColor(red: 0.3, green: 0.3, blue: 0.8, alpha: 0.8)
        effect.lineWidth = 2
        effect.position = enemy.position
        effect.zPosition = 50

        scene?.addChild(effect)

        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let remove = SKAction.removeFromParent()
        effect.run(SKAction.sequence([fadeOut, remove]))
    }

    // MARK: - Callbacks
    var findEnemiesInRange: (() -> [Enemy])?
}
```

### Step 3: Add Factory Method to StructureManager

In `StructureManager.swift`:

```swift
// MARK: - Slow Tower
func addSlowTower(at position: CGPoint) -> SlowTower {
    let tower = SlowTower()
    setupStructure(tower, at: position)

    // Set up callbacks
    tower.findEnemiesInRange = { [weak self] in
        guard let self = self else { return [] }
        return self.findEnemiesInRange(of: position, range: SlowTower.defaultAttackRange)
    }

    return tower
}

// Helper to find enemies in range
private func findEnemiesInRange(of position: CGPoint, range: CGFloat) -> [Enemy] {
    return enemyManager?.enemies.filter { enemy in
        let dx = enemy.position.x - position.x
        let dy = enemy.position.y - position.y
        return hypot(dx, dy) <= range
    } ?? []
}
```

### Step 4: Update Hermes Tower Placement

In `StructureManager.swift`, update `addHermesTower`:

```swift
func addHermesTower(type: TowerType, at position: CGPoint) {
    let tower: DefensiveStructure

    switch type {
    case .gunTower:
        tower = addGunTower(at: position)
    case .laserTower:
        tower = addLaserTower(at: position)
    case .healTower:
        tower = addHealTower(at: position)
    case .slowTower:
        tower = addSlowTower(at: position)
    }

    // Mark as Hermes tower for tracking
    hermesTowers.append(tower)
}
```

### Step 5: Add Tower Assets

1. Create tower sprite (`slowtower.png`)
2. Add to `Assets.xcassets`
3. Recommended size: 48x64 pixels

### Step 6: Update Build Menu

In `BuildMenu.swift`, the tower will automatically appear if it's in `TowerType.allCases`.

## Existing Tower Reference

| Tower | HP | Range | Cost | Effect |
|-------|-----|-------|------|--------|
| Gun Tower | 500 | 500 | 5 | Fires bullets (20 damage) |
| Laser Tower | 600 | 350 | 10 | Continuous beam (20 DPS) |
| Heal Tower | 400 | 400 | 15 | Heals allies (5 HP/sec) |

## Tower Behavior Patterns

### Targeting Towers (Gun, Laser)

Override `attackTarget` to deal damage:

```swift
override func attackTarget(_ target: Enemy, deltaTime: TimeInterval) {
    // Point-based damage
    let damage = 20
    target.takeDamage(damage, from: nil)

    // Or continuous damage
    let dps = 20
    let damage = Int(CGFloat(dps) * CGFloat(deltaTime))
    target.takeDamage(damage, from: nil)
}
```

### Area Effect Towers (Heal, Slow)

Override `update` to affect multiple targets:

```swift
override func update(deltaTime: TimeInterval) {
    guard isActive && isAlive else { return }

    // Get all targets in range
    let targets = findTargetsInRange()

    for target in targets {
        applyEffect(to: target, deltaTime: deltaTime)
    }
}
```

### Projectile Towers

Use callbacks for projectile management:

```swift
var onFire: ((Projectile) -> Void)?
var onCheckCollision: ((Projectile) -> Character?)?

override func attackTarget(_ target: Enemy, deltaTime: TimeInterval) {
    if let projectile = weapon?.fire(at: target.position) {
        onFire?(projectile)
    }
}
```

## Placement Validation

Towers cannot be placed:
- Outside Hermes's build radius
- On non-walkable terrain
- Overlapping other structures
- Overlapping characters

The `PlacementValidator` handles all validation automatically.

## Testing Towers

### Via GameCommandServer

```bash
# Select Hermes and enter build mode
curl -X POST http://localhost:8765/action \
  -d '{"name":"selectHermes"}'

curl -X POST http://localhost:8765/action \
  -d '{"name":"enterBuildMode"}'

# Place tower (if action exists)
curl -X POST http://localhost:8765/action \
  -d '{"name":"placeTower", "params":{"type":"slowTower","x":"400","y":"300"}}'
```

### Via DevSettings

In DEBUG builds, reduce tower costs for testing:

```swift
DevSettings.shared.towerCostGun = 1
DevSettings.shared.towerCostLaser = 1
DevSettings.shared.towerCostHeal = 1
```

## Visual Effects

### Tower Aura

Show attack range with a translucent circle:

```swift
let rangeIndicator = SKShapeNode(circleOfRadius: attackRange)
rangeIndicator.strokeColor = .white.withAlphaComponent(0.3)
rangeIndicator.fillColor = .clear
sprite.addChild(rangeIndicator)
```

### Attack Effects

Show damage with particles or shape nodes:

```swift
func showAttackEffect(from: CGPoint, to: CGPoint) {
    let line = SKShapeNode()
    let path = CGMutablePath()
    path.move(to: from)
    path.addLine(to: to)
    line.path = path
    line.strokeColor = .yellow
    line.lineWidth = 2

    scene?.addChild(line)
    line.run(SKAction.sequence([
        SKAction.fadeOut(withDuration: 0.1),
        SKAction.removeFromParent()
    ]))
}
```

### Destruction Effect

Override `onDeath` for destruction animation:

```swift
override func onDeath() {
    // Explosion effect
    let explosion = SKEmitterNode(fileNamed: "Explosion")
    explosion?.position = position
    scene?.addChild(explosion!)

    // Remove after animation
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        explosion?.removeFromParent()
    }

    super.onDeath()
}
```
