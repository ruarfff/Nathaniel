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

### Testing Agents (Recommended)

After significant code changes, use testing agents to validate:

```bash
/ios-game-testing    # iOS simulator - full test workflow
/macos-game-testing  # macOS desktop - full test workflow
```

These handle: build → launch → navigate → test features → screenshot → generate report.

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
| `game_get_state` | Scene, score, lives, positions, enemy count |
| `game_get_nodes` | All interactive elements with coordinates |
| `game_screenshot` | Capture screen (base64 PNG) |
| `game_screenshot_annotated` | Screenshot with color-coded bounding boxes |
| `game_describe` | Human-readable scene summary |
| `game_tap(x, y)` | Tap at scene coordinates |
| `game_swipe(fromX, fromY, toX, toY)` | Swipe gesture |
| `game_action(name, params)` | Execute named action |

### Workflow Pattern

```
1. game_health()      → Verify game running
2. game_get_state()   → Check current scene
3. game_get_nodes()   → Find elements
4. game_tap(x, y)     → Interact
5. game_get_state()   → Verify result
```

### Scene Coordinates

- Origin (0, 0) at **bottom-left**
- Scene size: **1366 x 1024**
- Use `game_get_nodes()` for exact frame coordinates

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
├── GameScene+CommandDelegate.swift # Scene implementations
└── TouchInjector.swift             # Touch injection
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

## Issue Tracking with bd (beads)

**IMPORTANT**: This project uses **bd (beads)** for ALL issue tracking. Do NOT use markdown TODOs, task lists, or other tracking methods.

### Why bd?

- Dependency-aware: Track blockers and relationships between issues
- Git-friendly: Auto-syncs to JSONL for version control
- Agent-optimized: JSON output, ready work detection, discovered-from links
- Prevents duplicate tracking systems and confusion

### Quick Start

**Check for ready work:**
```bash
bd ready --json
```

**Create new issues:**
```bash
bd create "Issue title" -t bug|feature|task -p 0-4 --json
bd create "Issue title" -p 1 --deps discovered-from:bd-123 --json
```

**Claim and update:**
```bash
bd update bd-42 --status in_progress --json
bd update bd-42 --priority 1 --json
```

**Complete work:**
```bash
bd close bd-42 --reason "Completed" --json
```

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Workflow for AI Agents

1. **Check ready work**: `bd ready` shows unblocked issues
2. **Claim your task**: `bd update <id> --status in_progress`
3. **Work on it**: Implement, test, document
4. **Discover new work?** Create linked issue:
   - `bd create "Found bug" -p 1 --deps discovered-from:<parent-id>`
5. **Complete**: `bd close <id> --reason "Done"`
6. **Commit together**: Always commit the `.beads/issues.jsonl` file together with the code changes so issue state stays in sync with code state

### Auto-Sync

bd automatically syncs with git:
- Exports to `.beads/issues.jsonl` after changes (5s debounce)
- Imports from JSONL when newer (e.g., after `git pull`)
- No manual export/import needed!

### Managing AI-Generated Planning Documents

AI assistants often create planning and design documents during development:
- PLAN.md, IMPLEMENTATION.md, ARCHITECTURE.md
- DESIGN.md, CODEBASE_SUMMARY.md, INTEGRATION_PLAN.md
- TESTING_GUIDE.md, TECHNICAL_DESIGN.md, and similar files

**Best Practice: Use a dedicated directory for these ephemeral files**

**Recommended approach:**
- Create a `history/` directory in the project root
- Store ALL AI-generated planning/design docs in `history/`
- Keep the repository root clean and focused on permanent project files
- Only access `history/` when explicitly asked to review past planning

### Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `bd ready` before asking "what should I work on?"
- ✅ Store AI planning docs in `history/` directory
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT use external issue trackers
- ❌ Do NOT duplicate tracking systems
- ❌ Do NOT clutter repo root with planning documents

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


## Wrapping Up

**When the user says "let's wrap up"**, follow this clean session-ending protocol:

1. **File beads issues for any remaining work** that needs follow-up.
2. **Ensure all quality gates pass** (only if code changes were made) - run tests, linters, builds (file P0 issues if broken)
3. **Updated beads issues** - close finished work, update status
4. **Sync issue tracker carefully** - Work methodically to ensure both local and remote issues merge safely. This may require pulling, conflict resolution, syncing database and verification.
5. **Clean up git state** - Clear old stashes and prune dead remote branches
6. **Verify clean state** - Ensure all changes are committed, no untracked files remain, and the working directory is clean.
7. **Choose a follow-up issue for next session**
    - Provide a prompt for the use to give you in the next session
    - Format: "Continue work on Nathaniel-X: [issue title]. [Brief context about what's been done and what's next]"

**Example "let's wrap up" session:**

```bash
# 1. File remaining work
bd create "Add integration tests for GameCommandServer" -t task -p 2 --json

# 2. Run quality gates
make test lint format

# 3. Update issue tracker
bd close "Some task"
bd update "Some task" -s done

# 4. Clean up git state
git stash clear
git remote prune origin

# 5. Verify clean state
git status
```
