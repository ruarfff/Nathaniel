# Adding Levels

This guide explains how to create new game levels for Nathaniel.

## Level System Overview

Levels are defined by:
1. **LevelConfig** - Game settings (lives, resources, spawn mode)
2. **TMX Map** - Tiled map with terrain and spawn points
3. **Spawn Points** - Named objects that define where enemies appear

## Key Files

| File | Purpose |
|------|---------|
| `LevelManager.swift` | Level configs and game state |
| `TMXRenderer.swift` | Renders Tiled maps |
| `TMXParser.swift` | Parses TMX XML format |
| `GameScene.swift` | Loads and runs levels |
| `LevelSelectScene.swift` | Level selection UI |

## Creating a New Level

### Step 1: Define the Level Configuration

In `LevelManager.swift`, add a new static config:

```swift
static let levelSix = LevelConfig(
    levelNumber: 6,
    mapName: "levelsix",          // TMX filename (without extension)
    startingLives: 3,             // Player respawns
    startingResources: 25,        // Starting building resources
    hasBoss: true,                // Level has a boss to defeat
    spawnMode: .mapBased,         // Enemies from map objects
    nextLevelNumber: nil          // nil = final level, or next level number
)
```

### Step 2: Add to Factory Method

Update the `level(_:)` factory:

```swift
static func level(_ number: Int) -> LevelConfig? {
    switch number {
    case 1: return .levelOne
    case 2: return .levelTwo
    case 3: return .levelThree
    case 4: return .levelFour
    case 5: return .levelFive
    case 6: return .levelSix      // Add new level
    default: return nil
    }
}
```

### Step 3: Create the TMX Map

Use [Tiled Map Editor](https://www.mapeditor.org/) to create the map.

#### Required Layers

| Layer Name | Type | Purpose |
|------------|------|---------|
| `Ground` | Tile Layer | Base terrain |
| `Collision` | Tile Layer | Walkable/blocked tiles |
| `Objects` | Object Layer | Spawn points and triggers |

#### Spawn Point Naming

Create point objects with these prefixes:

| Prefix | Enemy Type | Example Names |
|--------|------------|---------------|
| `Gr` | Grunt | `Gr1`, `Gr2`, `GrNorth` |
| `So` | Soldier | `So1`, `So2`, `SoEast` |
| `Bo` | Boss | `Bo1`, `Boss` |
| `Sp` | Spawner | `Sp1` (continuous spawning) |

#### Player Start Point

Add an object named `PlayerStart` or `NathanielStart` for the player spawn.

### Step 4: Add Map Assets

1. Export from Tiled as TMX format
2. Place `levelsix.tmx` in the project
3. Add tileset images to Assets.xcassets
4. Ensure the TMX references tilesets correctly

### Step 5: Update Level Select

In `LevelSelectScene.swift`, add a button for the new level:

```swift
// In setupLevelButtons() or similar
let level6Button = createLevelButton(
    levelNumber: 6,
    title: "Level 6",
    position: CGPoint(x: 0, y: -200)
)
addChild(level6Button)
```

## Level Configuration Options

### LevelConfig Properties

```swift
struct LevelConfig {
    let levelNumber: Int        // Unique level identifier
    let mapName: String         // TMX filename (no extension)
    let startingLives: Int      // Player respawn count
    let startingResources: Int  // Initial building resources
    let hasBoss: Bool           // Victory requires killing boss
    let spawnMode: SpawnMode    // How enemies spawn
    let nextLevelNumber: Int?   // Progression (nil = end)
}
```

### Spawn Modes

```swift
enum SpawnMode {
    case mapBased   // Enemies placed via map objects
    case waveBased  // Enemies spawn in timed waves
}
```

**Map-Based**: Good for story levels with fixed enemy placement.

**Wave-Based**: Good for survival modes with increasing difficulty.

## Existing Level Reference

| Level | Map | Lives | Resources | Boss | Mode | Description |
|-------|-----|-------|-----------|------|------|-------------|
| 1 | levelone | 3 | 30 | Yes | Map | Tutorial level |
| 2 | leveltwo | 3 | 30 | Yes | Map | Forest area |
| 3 | levelthree | 3 | 30 | Yes | Map | Desert area |
| 4 | survivalmap | 3 | 0 | Yes | Wave | Wave survival |
| 5 | survivalmap | 3 | 0 | Yes | Wave | Hard survival |
| Survival | survivalmap | 1 | 50 | No | Wave | Endless mode |

## Map Design Tips

### Tile Size

The game uses 32x32 pixel tiles. Design maps with this in mind.

### Collision Tiles

Mark tiles as walkable or blocked using tile properties:
- Walkable: `collision = false` or no property
- Blocked: `collision = true`

### Camera Bounds

The map size defines camera bounds. Larger maps = more scrolling area.

### Enemy Placement

- Spread enemies across the map for pacing
- Group enemies for challenging encounters
- Place boss at a strategic location
- Consider player visibility range (~500 points)

## Testing Levels

### Quick Test with GameCommandServer

```bash
# Start the game
mcp__XcodeBuildMCP__build_run_sim

# Navigate to level select
curl -X POST http://localhost:8765/action \
  -H "Content-Type: application/json" \
  -d '{"name":"startGame"}'

# Start your new level
curl -X POST http://localhost:8765/action \
  -H "Content-Type: application/json" \
  -d '{"name":"level_6"}'

# Check game state
curl http://localhost:8765/state | jq .
```

### Add Level Action

In `LevelSelectScene+CommandDelegate.swift`, add the action:

```swift
case "level_6":
    startLevel(6)
    return .success("Starting Level 6")
```

### Verify Map Loading

Check console output for map loading:
```
Loading map: levelsix
Map size: 50x40 tiles
Found 12 enemy spawn points
Found player start at (400, 600)
```

## Troubleshooting

### Map Not Loading

- Verify TMX file is in the bundle
- Check filename matches `mapName` in config
- Ensure tileset images are included

### Enemies Not Spawning

- Check object layer is named correctly
- Verify spawn point prefixes (Gr, So, Bo)
- Look for parsing errors in console

### Collision Not Working

- Ensure collision layer exists
- Check tile properties for `collision` flag
- Verify TMXRenderer is processing collision data
