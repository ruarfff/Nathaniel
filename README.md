# Nathaniel

A strategy/action game with the original Windows Phone 7 XNA code, a Swift/SpriteKit
edition for iOS/macOS, and an isometric Godot edition.

## Godot edition

The isometric Godot port is in `godot/`. The Swift and Xcode projects remain
available with their existing commands. Use **Godot 4.7.2 stable**:

```sh
make godot-editor                 # Open the visual editor
make godot                        # Run the game menu
make godot-level GODOT_LEVEL=1     # Run one campaign level (0 = survival)
make godot-test                   # Content, gameplay, saves, UI and MCP checks
make godot-profile                # Simulation workload
make godot-profile-rendered       # Rendered workload and screenshot
make godot-export-macos           # Local macOS release app
make godot-export-ios             # Unsigned iOS Xcode project
```

All five campaign levels and survival use native editable Godot scenes. Open a
level and press F6 to run its edited content. Mouse/keyboard commands retain the
Swift actions; touch uses the same HUD and world commands. Godot saves use a
separate three-slot store. Existing Swift saves can be imported from an explicit
JSON export into an empty Godot slot.

See [migration status and verification](docs/godot-migration.md),
[content authoring and exports](docs/godot-authoring.md),
[save import](docs/godot-saves.md), and [debug/MCP setup](docs/godot-debug.md).
The verification record states platform limits; the Swift app has not been retired.

## The Game

Nathaniel is a top-down RTS mobile game. Control Nathaniel and his robot companion Hermes as they fight alien invaders from a crashed vessel to save Earth.

## Project Structure

```
Nathaniel/
├── Legacy/              # Original WP7/XNA codebase (C#, ~2011)
├── Nathaniel Shared/    # Swift/SpriteKit game code
├── Nathaniel iOS/       # iOS app target
├── Nathaniel macOS/     # macOS app target
└── godot/               # Separate isometric game and native editor content
```

## Quick Start

**Requirements:** Xcode 26.1+, macOS 26.1+; iOS 26.1+ for the iOS target.

**Run from Xcode:**
1. Open `Nathaniel.xcodeproj`
2. Select `Nathaniel iOS` or `Nathaniel macOS` scheme
3. Press Cmd+R

**Build from command line:**
```bash
# iOS
make ios-build

# macOS
make macos-build
```

**Smoke test from command line:**
```bash
# macOS (builds + runs a headless smoke test)
bash scripts/smoke_macos.sh

# iOS Simulator (builds + installs + launches + screenshots)
bash scripts/smoke_ios_sim.sh
```

`make ios` and `make macos` build and run the app from `build/DerivedData`. Set `DERIVED_DATA_PATH` to use another directory. Normal iOS installs keep saved games; `make ios-fresh` explicitly removes app data.

See [docs/automation.md](docs/automation.md) for script options.

## Gameplay

The Swift port restores the original XNA campaign and survival rules:

- Tap or click the ground to move Nathaniel; tap an enemy to target it.
- Select Hermes to focus the camera. He starts stationary in build mode.
- Use **Hermes Follow** (or **R** on macOS) to make him follow Nathaniel. Leaving build mode destroys his surviving towers and refunds 25% of each tower's build cost, rounded down. Towers destroyed by enemies give no refund.
- Use **Hermes Stop** to stop him, then select him to build again. Selecting a character does not change Hermes's mode.
- Drag a tower from the build menu to clear ground. Towers cost 5, 10, or 15 resources.
- Only Soldiers drop corpses, worth 10 resources. Walk Nathaniel over them, then tap stationary Hermes to deliver them. Loose corpses expire after 10 seconds; carried corpses do not.
- Campaign levels start with three spare lives. Nathaniel respawns at the map start; losing Hermes ends the game. Survival has no spare lives.
- Defeat a boss to complete a campaign level. Survival continues until a player dies.

The port retains pathfinding, desktop controls, zoom, level selection, three save slots, and fog of war. Saves include carried corpses, Spawner production timers, tower build costs, and the requested movement destination. Loading recalculates routes around restored towers. Older save slots remain readable; their tower refunds use the current build cost.

**macOS controls:** Space switches camera focus, R changes Hermes mode, S stops Nathaniel, Escape pauses or closes the top menu, and the mouse wheel zooms. Right-click or F fires Nathaniel's gun.

**Regression tests:**

```bash
make test-unit       # macOS XCTest suite
make test-tooling    # Build-command tests with stubbed platform tools
```

Tests cover gameplay parity, save compatibility and navigation, menu input, music settings, and the debug HTTP interface. Use computer use for real input and the small debug interface for exact state and setup; see [docs/testing.md](docs/testing.md).

## Development

This is a learning project for Swift/SpriteKit development. See `AGENTS.md` for detailed architecture docs and legacy code reference.

**Source control:** Uses `git`

## Code Quality

This project uses automated code quality tools:

- **SwiftFormat** - Auto-formats Swift code
- **SwiftLint** - Catches code quality issues
- **pre-commit** - Runs checks on every commit

### Setup

```bash
./scripts/setup-hooks.sh
```

This installs the tools via Homebrew and configures git hooks.

### Manual Usage

```bash
# Format all Swift files
swiftformat .

# Lint all Swift files
swiftlint

# Auto-fix some lint issues
swiftlint --fix
```
