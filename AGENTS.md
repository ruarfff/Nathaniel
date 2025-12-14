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

### Common Commands

```bash
# Check status
git status

# Stage and commit changes
git add <files>
git commit -m "Description of changes"

# View history
git log --oneline

# Create a branch
git checkout -b feature/my-feature

# Switch branches
git checkout main

# Pull latest changes
git pull origin main

# Push changes
git push origin <branch>
```

### Remote

- **Origin**: GitHub repository
- **Main branch**: `main`

## Repository Structure

```
Nathaniel/
├── Legacy/    # Original Windows Phone 7 codebase (C#/XNA)
│   ├── NathanielGamePhone/         # Main game project
│   ├── EasyStorage/                # Storage library for save games
│   └── NathanielGame.sln          # Visual Studio solution
├── Nathaniel Shared/               # Shared Swift/SpriteKit code
├── Nathaniel iOS/                  # iOS-specific code
├── Nathaniel macOS/                # macOS-specific code
└── Nathaniel.xcodeproj            # Xcode project
```

## Prerequisites

- **Xcode**: Version 15.0 or later (required for Swift/SpriteKit development)
- **macOS**: Sonoma (14.0) or later recommended
- **iOS Simulator or Device**: For iOS builds, requires iOS 17.0+ target

## Building and Running

### Available Schemes and Targets

| Scheme | Target | Platform |
|--------|--------|----------|
| `Nathaniel iOS` | iOS App | iPhone/iPad Simulator or Device |
| `Nathaniel macOS` | macOS App | Mac native |

### Command Line Builds

**iOS Build (Debug):**
```bash
xcodebuild -project Nathaniel.xcodeproj -scheme "Nathaniel iOS" -configuration Debug build
```

**iOS Build (Release):**
```bash
xcodebuild -project Nathaniel.xcodeproj -scheme "Nathaniel iOS" -configuration Release build
```

**macOS Build (Debug):**
```bash
xcodebuild -project Nathaniel.xcodeproj -scheme "Nathaniel macOS" -configuration Debug build
```

**macOS Build (Release):**
```bash
xcodebuild -project Nathaniel.xcodeproj -scheme "Nathaniel macOS" -configuration Release build
```

### Running from Xcode (Recommended)

1. Open `Nathaniel.xcodeproj` in Xcode
2. Select the desired scheme from the scheme picker:
   - **Nathaniel iOS** - for iPhone/iPad
   - **Nathaniel macOS** - for Mac
3. Choose a destination:
   - For iOS: Select an iOS Simulator (e.g., "iPhone 15 Pro") or a connected device
   - For macOS: "My Mac" is automatically selected
4. Press **Cmd+R** or click the Play button to build and run

### Running on iOS Simulator (Command Line)

```bash
# Build for simulator
xcodebuild -project Nathaniel.xcodeproj \
  -scheme "Nathaniel iOS" \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build

# To build and run in one step, use:
xcodebuild -project Nathaniel.xcodeproj \
  -scheme "Nathaniel iOS" \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build

# Then open the simulator and install manually, or use Xcode
```

### Running macOS Build Directly

After building, you can run the macOS app directly:
```bash
# Find the built app
find ~/Library/Developer/Xcode/DerivedData -name "Nathaniel.app" -path "*macOS*" 2>/dev/null

# Or run from the default build location
open ~/Library/Developer/Xcode/DerivedData/Nathaniel-*/Build/Products/Debug/Nathaniel.app
```

## Testing

### iOS Simulator Testing (XcodeBuildMCP)

This project uses **XcodeBuildMCP** for automated iOS simulator testing and interaction. The game runs in **landscape mode** which requires special handling for tap coordinates.

#### Quick Start - Running the Game in Simulator

```bash
# 1. List available simulators and find one with iOS 26.1+
mcp__XcodeBuildMCP__list_sims

# 2. Boot the simulator (use iPhone 17 Pro or similar)
mcp__XcodeBuildMCP__boot_sim({ simulatorUuid: "UUID" })

# 3. Open the Simulator app
mcp__XcodeBuildMCP__open_sim()

# 4. Build and run the iOS app
mcp__XcodeBuildMCP__build_run_sim({
  projectPath: "/Users/ruairi/dev/Nathaniel/Nathaniel.xcodeproj",
  scheme: "Nathaniel iOS",
  simulatorId: "UUID",
  configuration: "Debug"
})

# 5. Rotate simulator to landscape (game requires landscape)
# Use AppleScript - see "Rotating Simulator" section below

# 6. Take screenshots and interact
mcp__XcodeBuildMCP__screenshot({ simulatorUuid: "UUID" })
mcp__XcodeBuildMCP__describe_ui({ simulatorUuid: "UUID" })
mcp__XcodeBuildMCP__tap({ simulatorUuid: "UUID", x: X, y: Y })
```

#### Important: Coordinate Transformation for Landscape Games

**The game runs in landscape mode but the simulator reports portrait coordinates.** You must transform coordinates:

1. Get UI element positions using `describe_ui` - returns landscape coordinates (874x402)
2. Transform for tapping:
   - Portrait X = Landscape Y
   - Portrait Y = 874 - Landscape X

**Example:**
```
# describe_ui shows "Level Select" at landscape (437, 227)
# Transform for tap:
#   portrait_x = 227
#   portrait_y = 874 - 437 = 437
# Tap at (227, 437)
```

#### Rotating Simulator to Landscape

There is no `xcrun simctl` command for rotation. Use AppleScript:

```bash
# Rotate simulator left (run multiple times for 90° increments)
osascript << 'EOF'
tell application "Simulator" to activate
delay 0.3
tell application "System Events"
    tell process "Simulator"
        click menu item "Rotate Left" of menu "Device" of menu bar 1
    end tell
end tell
EOF
```

#### Available XcodeBuildMCP Tools

**Simulator Management:**
- `mcp__XcodeBuildMCP__list_sims` - List available iOS simulators with UUIDs
- `mcp__XcodeBuildMCP__boot_sim` - Boot a simulator by UUID
- `mcp__XcodeBuildMCP__open_sim` - Open the Simulator.app window

**Building & Running:**
- `mcp__XcodeBuildMCP__build_sim` - Build for simulator without running
- `mcp__XcodeBuildMCP__build_run_sim` - Build and launch on simulator
- `mcp__XcodeBuildMCP__install_app_sim` - Install .app bundle
- `mcp__XcodeBuildMCP__launch_app_sim` - Launch app by bundle ID
- `mcp__XcodeBuildMCP__stop_app_sim` - Stop running app

**UI Interaction:**
- `mcp__XcodeBuildMCP__screenshot` - Capture screenshot (returns image)
- `mcp__XcodeBuildMCP__describe_ui` - Get accessibility hierarchy with frame coordinates
- `mcp__XcodeBuildMCP__tap` - Tap at coordinates
- `mcp__XcodeBuildMCP__swipe` - Swipe gesture
- `mcp__XcodeBuildMCP__type_text` - Type text input

#### Game-Specific Testing Workflow

1. **Main Menu → Level Select:**
   - describe_ui to find "Level Select" button
   - Transform coordinates and tap

2. **Level Select → Level 1:**
   - describe_ui to find "Level 1" button
   - Transform coordinates and tap

3. **In-Game Movement:**
   - Tap anywhere on the grass terrain to move Nathaniel
   - The selected character will move to the tap location

#### App Bundle ID

```
com.ruarfff.Nathaniel
```

#### Simulator Requirements

- **iOS 26.1+** required (the project targets this version)
- Use iPhone 17 Pro, iPhone 17 Pro Max, or similar iOS 26.1 simulators
- Older simulators (iOS 18.x) won't work with this project

### macOS App Testing

The macOS version can be built and run, but **automated UI interaction is unreliable**. Mouse clicks via `cliclick` or AppleScript don't properly translate to SpriteKit scene coordinates.

**Recommendation:** Use iOS Simulator for automated testing. Manual testing works fine for macOS.

```bash
# Build and run macOS version
mcp__XcodeBuildMCP__build_run_macos({
  projectPath: "/Users/ruairi/dev/Nathaniel/Nathaniel.xcodeproj",
  scheme: "Nathaniel macOS",
  configuration: "Debug"
})

# Stop macOS app
mcp__XcodeBuildMCP__stop_mac_app({ appName: "Nathaniel" })
```

### Unit Tests

The project does not yet have unit tests or UI tests configured. This section documents how to add and run tests when they are implemented.

### Adding Tests

To add a test target in Xcode:
1. Open `Nathaniel.xcodeproj`
2. File → New → Target
3. Choose "Unit Testing Bundle" for unit tests or "UI Testing Bundle" for UI tests
4. Name it `Nathaniel Tests` or `Nathaniel UITests`
5. Select the appropriate target to test (iOS or macOS)

### Running Tests (When Available)

**From Xcode:**
- Press **Cmd+U** to run all tests
- Use the Test Navigator (Cmd+6) to run individual tests

**From Command Line:**
```bash
# Run all tests for iOS
xcodebuild -project Nathaniel.xcodeproj \
  -scheme "Nathaniel iOS" \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  test

# Run all tests for macOS
xcodebuild -project Nathaniel.xcodeproj \
  -scheme "Nathaniel macOS" \
  test
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
