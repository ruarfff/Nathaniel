# Adding Characters

This guide explains how to add new character types to Nathaniel.

## Character Hierarchy

```
GameEntity (Protocol)
  └── Character (Base Class)
      ├── Nathaniel (Player)
      ├── Hermes (AI Companion)
      └── Enemy (Base for All Enemies)
          ├── Grunt (Melee Enemy)
          ├── Soldier (Ranged Enemy)
          └── Boss (Special Enemy)
```

## Key Files

| File | Purpose |
|------|---------|
| `GameEntity.swift` | Base protocol and Character class |
| `Nathaniel.swift` | Main player character |
| `Hermes.swift` | Robot companion with modes |
| `Enemy.swift` | Base enemy class with AI |
| `EnemyManager.swift` | Spawning and enemy lifecycle |

## Adding a New Enemy Type

### Step 1: Create the Enemy Subclass

Create a new file or add to `Enemy.swift`:

```swift
class Hunter: Enemy {
    // MARK: - Constants
    static let defaultMaxHP = 300
    static let defaultSpeed: CGFloat = 80
    static let defaultDamage = 25
    static let defaultKillScore = 75
    static let defaultAttackRange: CGFloat = 50  // Melee range

    // MARK: - Initialization
    init() {
        super.init(
            name: "Hunter",
            maxHP: Hunter.defaultMaxHP,
            speed: Hunter.defaultSpeed,
            damage: Hunter.defaultDamage,
            killScore: Hunter.defaultKillScore,
            attackRange: Hunter.defaultAttackRange,
            visibleRange: 400,
            hasRangedWeapon: false
        )

        // Load sprite sheet (8 directions x 2 rows: idle + moving)
        loadSpriteSheet(named: "hunter_spritesheet", cols: 8, rows: 2)
        facingDirection = .south
    }

    // MARK: - AI Behavior
    override func updateAI(deltaTime: TimeInterval) {
        guard let target = target, target.isAlive else { return }

        let dx = target.position.x - position.x
        let dy = target.position.y - position.y
        let distance = hypot(dx, dy)

        if distance <= attackRange {
            // In range - attack
            performAttack()
        } else {
            // Move toward target (hunters are fast!)
            destination = target.position
        }
    }
}
```

### Step 2: Register in EnemyManager

In `EnemyManager.swift`, update the `addEnemy(name:at:target:)` method:

```swift
func addEnemy(name: String, at position: CGPoint, target: Character? = nil) {
    let enemy: Enemy

    if name.hasPrefix("Hu") {
        // Hunter enemies
        enemy = Hunter()
    } else if name.hasPrefix("Gr") {
        enemy = Grunt()
    } else if name.hasPrefix("So") {
        enemy = Soldier()
    } else if name.hasPrefix("Bo") {
        enemy = Boss()
    } else {
        enemy = Grunt()  // Default fallback
    }

    // ... rest of setup
}
```

### Step 3: Add Sprite Assets

1. Create a sprite sheet image (e.g., `hunter_spritesheet.png`)
2. Add to `Assets.xcassets` in the Xcode project
3. Sprite sheet format: columns = directions, rows = animation states

### Step 4: Add to Maps

In your TMX map files, add spawn points with the prefix:
- `Hu1`, `Hu2`, etc. for Hunter spawns

## Adding a New Player Character

Player characters require more setup than enemies.

### Step 1: Create the Character Class

```swift
class NewHero: Character {
    // MARK: - Constants
    static let defaultMaxHP = 5000
    static let defaultSpeed: CGFloat = 55

    // MARK: - Properties
    var specialAbilityCooldown: TimeInterval = 0

    // MARK: - Initialization
    init() {
        super.init(
            name: "NewHero",
            maxHP: NewHero.defaultMaxHP,
            speed: NewHero.defaultSpeed,
            spriteSheetCols: 8,
            spriteSheetRows: 2
        )

        loadSpriteSheet(named: "newhero_spritesheet")
        setupWeapon()
        setupHealthBar(width: 60, yOffset: 40)
    }

    private func setupWeapon() {
        // Create weapon (see Weapon.swift for types)
        let gun = Gun(damage: 30, range: 400, cooldown: 0.3)
        self.weapon = gun
    }

    // MARK: - Special Ability
    func useSpecialAbility() {
        guard specialAbilityCooldown <= 0 else { return }
        // Implement ability
        specialAbilityCooldown = 10.0  // 10 second cooldown
    }

    override func update(deltaTime: TimeInterval) {
        super.update(deltaTime: deltaTime)

        // Update cooldowns
        if specialAbilityCooldown > 0 {
            specialAbilityCooldown -= deltaTime
        }
    }
}
```

### Step 2: Add to GameScene

In `GameScene.swift`, instantiate and manage the new character:

```swift
// Add property
var newHero: NewHero?

// In loadMap() or setup
func setupNewHero(at position: CGPoint) {
    newHero = NewHero()
    newHero?.position = position
    newHero?.sprite.setScale(3.0)
    newHero?.sprite.zPosition = 100
    addChild(newHero!.sprite)
}
```

### Step 3: Add Selection and Control

Update touch handling to allow selecting the new character:

```swift
// In handleTap or touch handling
if newHero?.sprite.contains(location) == true {
    selectedCharacter = newHero
    return
}
```

## Character Properties Reference

### Health System

```swift
var currentHP: Int          // Current health
var maxHP: Int { get }      // Maximum health
var isAlive: Bool { get }   // currentHP > 0
func takeDamage(_ amount: Int)
func heal(_ amount: Int)
func onDeath()              // Called when HP reaches 0
```

### Movement

```swift
var position: CGPoint       // Current position
var destination: CGPoint?   // nil = not moving
var speed: CGFloat          // Points per second
var facingDirection: FacingDirection  // 8 directions
var collisionRadius: CGFloat { get }  // Calculated from sprite
func moveTo(_ point: CGPoint)
func stop()
```

### Animation

```swift
var animationState: AnimationState  // idle, moving, attacking, dead
func loadSpriteSheet(named: String, cols: Int, rows: Int)
func updateTexture()        // Updates sprite based on direction/state
```

### Combat

```swift
var weapon: Weapon?         // Optional weapon
var attackRange: CGFloat    // Range for attacks
var damage: Int             // Base damage dealt
func performAttack()        // Execute attack
```

## Sprite Sheet Format

Sprite sheets should be organized as:

- **Columns**: 8 directions (S, SW, W, NW, N, NE, E, SE)
- **Rows**: Animation states (idle, moving, attacking, etc.)

Example for an 8x2 sprite sheet:
```
Row 0: Idle frames for each direction
Row 1: Walking frames for each direction
```

## Testing New Characters

Use the GameCommandServer to test:

```bash
# Get game state including character positions
curl http://localhost:8765/state

# Check if new enemy appears
curl http://localhost:8765/state | jq '.enemyCount'
```

For player characters, add a test action in `GameScene+CommandDelegate.swift`:

```swift
case "selectNewHero":
    if let hero = newHero {
        selectedCharacter = hero
        return .success("Selected NewHero")
    }
    return .failure("NewHero not available")
```
