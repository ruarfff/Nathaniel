# Nathaniel

## Project Overview

This is a game porting project: "Nathaniel", is a legacy Windows Phone 7 game built with XNA Framework 4.0 and C#. The codebase is located in the `Legacy/` folder and was originally developed in Visual Studio 2010.

**Note:** The legacy code is from the Windows Phone 7 era (~2011-2012). The XNA Framework and Windows Phone 7 SDK are no longer supported by Microsoft.

### The Game

Nathaniel is a top-down RTS game for mobile. The player controls Nathaniel and his robot companion Hermes, fighting through alien invaders from a crashed vessel to save Earth.

### Development Context

This is a learning project. The developer is experienced with other platforms (Android, Windows Phone, Godot) but new to Swift and SpriteKit. Architecture decisions should be discussed and explained rather than assumed.

## Source Control

This project uses standard **git** for version control.

## Repository Structure

```
Nathaniel/
├── Legacy/                         # Original Windows Phone 7 codebase (C#/XNA)
│   ├── NathanielGamePhone/         # Main game project
│   ├── EasyStorage/                # Storage library for save games
│   └── NathanielGame.sln           # Visual Studio solution
├── Nathaniel Shared/               # Shared Swift/SpriteKit code
│   └── GameCommandServer/          # Agent testing HTTP server (DEBUG only)
├── Nathaniel iOS/                  # iOS-specific code
├── Nathaniel macOS/                # macOS-specific code
├── game-mcp-server/                # MCP server for agent testing
└── Nathaniel.xcodeproj             # Xcode project
```

## Prerequisites

- **Xcode**: Version 15.0 or later (required for Swift/SpriteKit development)
- **macOS**: Sonoma (14.0) or later recommended
- **iOS Simulator or Device**: For iOS builds, requires iOS 17.0+ target

## Building and Running

### Quick Start with Make (Recommended)

The project uses a Makefile for common operations. **Prefer Make commands** over raw `xcodebuild`:

```bash
# See all available commands
make help

# Build and run
make ios                    # iOS simulator
make ios-device             # Physical iOS device
make macos                  # macOS native

# Build only (no run)
make ios-build
make ios-device-build
make macos-build

# Fresh install (cleans everything first)
make ios-fresh

# Clean up
make clean                  # Clean build products
make clean-derived          # Remove DerivedData (fixes stale builds)
make stop                   # Stop all running instances
```

### Available Make Targets

| Command | Description |
|---------|-------------|
| `make ios` | Build and run iOS app in simulator |
| `make ios-device` | Build and install iOS app on connected device |
| `make macos` | Build and run macOS app |
| `make ios-fresh` | Clean install (removes old app data) |
| `make ios-build` | Build iOS only (simulator) |
| `make ios-device-build` | Build iOS only (device) |
| `make macos-build` | Build macOS only |
| `make test` | Run all smoke tests |
| `make test-ios` | Run iOS smoke tests |
| `make test-macos` | Run macOS smoke tests |
| `make lint` | Run SwiftLint |
| `make format` | Run SwiftFormat |
| `make health` | Check GameCommandServer status |
| `make stop` | Stop all running instances |
| `make clean` | Clean build products |
| `make list-simulators` | List available simulators |
| `make list-devices` | List connected iOS devices |

### Running from Xcode

1. Open `Nathaniel.xcodeproj` in Xcode (or `make open-project`)
2. Select the desired scheme:
   - **Nathaniel iOS** - for iPhone/iPad
   - **Nathaniel macOS** - for Mac
3. Choose a destination (iOS Simulator or "My Mac")
4. Press **Cmd+R** to build and run

### Deploying to Physical iOS Device

To install the game on your iPhone or iPad:

**Prerequisites:**
- Apple Developer account (free or paid)
- Device connected via USB or WiFi
- Device unlocked and trusted on your Mac
- Developer Mode enabled on device (iOS 16+: Settings > Privacy & Security > Developer Mode)

**Quick deployment:**
```bash
# Check if device is connected
make list-devices

# Build, install, and launch on device
make ios-device

# Build only (no install)
make ios-device-build
```

**First-time setup:**
1. Connect your device via USB
2. Trust your Mac when prompted on the device
3. Enable Developer Mode (Settings > Privacy & Security > Developer Mode)
4. In Xcode, sign in with your Apple ID (Xcode > Settings > Accounts)
5. Select the "Nathaniel iOS" scheme and your device as destination
6. If you see signing errors, Xcode will prompt you to fix them

**Troubleshooting:**
- "Device not found": Run `make list-devices` to verify connection
- Signing errors: Open Xcode and let it manage provisioning automatically
- "Untrusted Developer": On device, go to Settings > General > VPN & Device Management, trust your developer certificate

### Advanced: Raw xcodebuild

For CI or custom builds, you can use `xcodebuild` directly:

```bash
# iOS Debug build
xcodebuild -project Nathaniel.xcodeproj -scheme "Nathaniel iOS" -configuration Debug build

# macOS Release build
xcodebuild -project Nathaniel.xcodeproj -scheme "Nathaniel macOS" -configuration Release build
```

## Testing

### Gameplay Validation

After significant game changes, build and run both platforms with Make.
Use the game MCP tools below to test gameplay and capture screenshots.
Report the results and any limits of the checks performed.

### Smoke Tests

```bash
make test           # All platforms
make test-ios       # iOS only
make test-macos     # macOS only
make health         # Check GameCommandServer
```

## Game MCP Server (`nathaniel-game`)

**CRITICAL**: Use MCP tools for all in-game interaction. Do NOT use:
- ❌ XcodeBuildMCP's tap/describe_ui/swipe (coordinate issues with SpriteKit)
- ❌ curl commands to localhost:8765
- ❌ Bash scripts for game interaction

XcodeBuildMCP is fine for: building, running, booting simulators, screenshots.

### Prerequisites

- Game running in DEBUG mode (port 8765)
- Works with both iOS Simulator and macOS

### MCP Tools

| Tool | Purpose |
|------|---------|
| `game_health` | Check if game is running |
| `game_state` | Scene, score, lives, positions, enemy count (for programmatic checks) |
| `game_nodes` | All interactive elements with coordinates |
| `game_screenshot` | Capture screen (base64 PNG) |
| `game_screenshot_annotated` | Screenshot with color-coded bounding boxes |
| `game_describe` | **RECOMMENDED FIRST CALL** - Human-readable scene summary |
| `game_list_actions` | Discover available actions for current scene |
| `game_tap(x, y)` | Tap at scene coordinates |
| `game_tap(node: "name")` | **RECOMMENDED** - Tap by node name (auto-finds center) |
| `game_swipe(fromX, fromY, toX, toY)` | Swipe gesture |
| `game_action(name, params)` | Execute named action |
| `game_action(name, wait_for_scene)` | Execute action + wait for scene transition |
| `game_start_level(level)` | **CONVENIENCE** - Navigate to level from anywhere (handles all steps) |
| `game_goto_menu()` | **CONVENIENCE** - Return to main menu from anywhere |

> **Aliases**: `game_get_state` and `game_get_nodes` are aliases for backwards compatibility.

### Workflow Pattern (Simplified)

**Option 1: High-level navigation (recommended for common workflows)**
```
1. game_start_level(1)    → Navigate to level 1 from anywhere
2. game_goto_menu()       → Return to main menu when done
```

**Option 2: By node name (for custom navigation)**
```
1. game_describe()                              → Understand scene
2. game_tap(node: "startButton")                → Tap by name
3. game_action("level_1", wait_for_scene: "GameScene")  → Navigate + wait
```

**Option 3: By coordinates (legacy)**
```
1. game_health()      → Verify game running
2. game_state()       → Check current scene
3. game_nodes()       → Find elements
4. game_tap(x, y)     → Interact
5. game_state()       → Verify result
```

### Scene Coordinates

- Origin (0, 0) at **bottom-left**
- Scene size: **1366 x 1024**
- Use `game_nodes()` for exact frame coordinates

### Available Actions by Scene

**MainMenuScene:**
- `startGame`, `continueGame`, `loadGame`, `options`, `credits`
- `hasSaves`, `getSaveSlots`

**LevelSelectScene:**
- `level_1` through `level_5`, `back`

**OptionsScene / CreditsScene:**
- `back`, `toggleSound`, `toggleMusic`

**GameScene - Character Control:**
- `selectNathaniel`, `selectHermes`, `toggleCharacter`
- `moveNathaniel` (params: x, y)
- `targetEnemy` (params: index)

**GameScene - Hermes Modes:**
- `setHermesMode` (params: mode=following|independent)
- `toggleHermesFollow`, `getHermesMode`

**GameScene - Pause Menu:**
- `pause`, `resume`, `isPaused`
- `showPauseMenu`, `hidePauseMenu`, `pauseMenuIsVisible`
- `pauseMenuTapResume`, `pauseMenuTapSettings`, `pauseMenuTapSaveGame`
- `pauseMenuTapExitToMenu`, `pauseMenuConfirmExit`, `pauseMenuCancelExit`
- `exitToMenu` (params: skipConfirm=true for direct exit)

**GameScene - Settings:**
- `openSettings`, `closeSettings`, `settingsMenuIsVisible`
- `toggleSoundEffects`, `toggleMusic`
- `getSoundEffectsEnabled`, `getMusicEnabled`, `getCurrentSettings`
- `setSoundEffects` (params: enabled=true|false)
- `setMusic` (params: enabled=true|false)
- `settingsMenuTapBack`

**GameScene - Save/Load:**
- `saveGame` (params: slot=1-3)
- `getSaveSlots`, `hasSaves`
- `showSaveSlotSelector`, `hideSaveSlotSelector`, `saveSlotSelectorIsVisible`
- `deleteSaveSlot` (params: slot), `deleteAllSaves`

**GameScene - Debug/Testing:**
- `spawnEnemy` (params: type=grunt|soldier|boss, x, y)
- `killAllEnemies`, `healPlayer`
- `addResources` (params: amount)

### Source Files

```
Nathaniel Shared/GameCommandServer/
├── GameCommandServer.swift         # HTTP server
├── GameCommandProtocol.swift       # Protocol definition
└── GameScene+CommandDelegate.swift # Scene implementations
```


## Legacy Architecture

### Core Game Structure

- **NathanielGame.cs** - Main game class extending XNA's `Game`. Initializes graphics (800x480 landscape), content managers, and the ScreenManager.

- **ScreenManager** (`ScreenManager/ScreenManager.cs`) - Stack-based screen management system. Maintains a list of `GameScreen` instances, handles transitions, routes input to active screens, and supports state serialization to isolated storage.

- **GameManager** (`GameManager.cs`) - Static class that coordinates level loading and game state (GameOver, LevelWon). Dispatches to appropriate Level class based on level number.

### Game Entity Hierarchy

```
DrawableGameAgent (abstract base)
└── GameCharacter
    ├── Player (Nathaniel, Hermes)
    ├── BadGameCharacter (Grunt, Soldier, Boss, Spawner)
    └── DefensiveStructure (GunTower, HealTower, LaserTower)
```

- **DrawableGameAgent** - Base class providing position, collision detection (box and circle), sprite sheet animation, and drawing.
- **GameCharacter** - Extends DrawableGameAgent with health, weapons, movement, pathfinding integration.

### Level System

Levels inherit from abstract `Level` class and use Tiled map editor format (via TiledLib). Maps define spawn points and triggers through a MapObjectLayer. Level classes: LevelOne through LevelFour, FinalLevel, SurvivalLevel.

### Key Managers (Static)

- **PlayerManager** - Manages player characters (Nathaniel, Hermes)
- **EnemyManager** - Manages enemy spawning and updates
- **AnimationManager** - Centralized sprite animation
- **Camera** - Viewport management with matrix transformations

### Supporting Systems

- **PathFinding/** - A* pathfinding with TiledMap integration
- **EasyStorage/** - Cross-platform save game library (Phone/Windows/Xbox variants)
- **Controls/** - UI controls including scrolling panels and high score display
- **Utility/** - Animation, audio, camera, primitives drawing

## Legacy Solution Structure

```
Legacy/NathanielGame.sln
├── NathanielGamePhone/     # Main game project
├── NathanielGameContent/   # XNA content pipeline assets
└── EasyStorage/            # Save/load library (Phone variant used)
```

## Legacy Build Notes

The original build requires:
- Visual Studio 2010
- XNA Game Studio 4.0
- Windows Phone 7 SDK

External dependencies referenced absolute paths (RestSharp, Newtonsoft.Json, TiledLib) that no longer exist. Building would require either locating compatible WP7 versions of these libraries or porting to a modern framework.

## Planning Documents

Store temporary planning and design documents in `history/`.
Keep the repository root focused on permanent project files.
Read past planning documents when the user asks to review them.

## Coding Standards

### File Structure

Every Swift file follows this header format:

```swift
//
//  FileName.swift
//  Nathaniel Shared
//
//  One-line description of what this file does.
//

import SpriteKit
```

### Code Organization

Use `// MARK:` comments to organize code sections in this order:

```swift
class MyClass {
    // MARK: - Constants
    static let defaultValue = 100

    // MARK: - Properties
    var myProperty: String

    // MARK: - Initialization
    init() { }

    // MARK: - Public Methods
    func publicMethod() { }

    // MARK: - Private Methods
    private func privateHelper() { }

    // MARK: - Protocol Conformance
    // Group by protocol name
}
```

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Classes/Structs/Enums | PascalCase | `Character`, `GunTower`, `LevelConfig` |
| Properties/Methods | camelCase | `currentHP`, `maxSpeed`, `updateTexture()` |
| Static Constants | PascalCase | `Nathaniel.defaultMaxHP` |
| Enum Cases | camelCase | `.gunTower`, `.following`, `.south` |
| Boolean Properties | `is`/`has` prefix | `isAlive`, `hasRangedWeapon` |

### Memory Management

**Always use weak references for:**
- Delegates: `weak var delegate: MyDelegate?`
- Targets that may be deallocated: `weak var target: Character?`
- Closure captures that reference `self`: `{ [weak self] in ... }`

```swift
// Correct - avoids retain cycle
weapon.onFire = { [weak self] projectile in
    guard let self = self else { return }
    self.scene?.addChild(projectile.sprite)
}

// Correct - delegate is weak
weak var delegate: LevelManagerDelegate?
```

### Optionals

Prefer safe unwrapping over force unwraps:

```swift
// Good - safe unwrapping
if let target = currentTarget, target.isAlive {
    attackTarget(target)
}

// Good - optional chaining
if currentTarget?.isAlive != true {
    findNewTarget()
}

// Avoid - force unwrap can crash
if currentTarget != nil && currentTarget!.isAlive { ... }
```

### Error Handling

Use `fatalError()` for programming errors (missing resources, invalid state):

```swift
guard let scene = SKScene(fileNamed: "GameScene") as? GameScene else {
    fatalError("Failed to load GameScene.sks - ensure the file exists")
}
```

Use optionals and graceful degradation for runtime conditions:

```swift
guard let target = findTarget() else {
    // No target available - this is normal, not an error
    return
}
```

### DEBUG-Only Code

Use `#if DEBUG` for development features:

```swift
#if DEBUG
if DevSettings.shared.playerInvincible {
    return  // Skip damage in god mode
}
#endif
```

### Game Loop Performance

Avoid allocations in `update(deltaTime:)`:
- Cache values that don't change every frame
- Compare integers, not strings
- Reuse objects where possible

```swift
// Good - compare integers
private var cachedScore: Int = -1

func update(score: Int) {
    if score != cachedScore {
        cachedScore = score
        updateScoreLabel(score)
    }
}

// Bad - creates strings every frame
if scoreLabel.text != String(score) { ... }
```

### Comments

- Add comments for non-obvious logic
- Don't comment obvious code
- Use `///` for documentation comments on public APIs

```swift
/// Find the nearest enemy within attack range
/// - Returns: The closest enemy, or nil if none in range
func findTargetInRange() -> Enemy? {
    // Implementation
}
```

## Documentation

Additional documentation is available in the `docs/` directory:

- [Adding Characters](docs/adding-characters.md) - How to create new player or enemy types
- [Adding Levels](docs/adding-levels.md) - How to create new game levels
- [Adding Towers](docs/adding-towers.md) - How to create new defensive structures
- [Testing Guide](docs/testing.md) - How to test the game with GameCommandServer
- [Automation](docs/automation.md) - Smoke tests and CI setup


## Completing Work

Run the relevant formatter and checks after changes to code or configuration.
Preserve existing work and report any incomplete checks or follow-up work.
Create commits, push, or change remote systems only when the user explicitly asks.
Finish with the verified result and any required next step.
