# Nathaniel

A port of a Windows Phone 7 XNA game to iOS/macOS using Swift and SpriteKit.

## The Game

Nathaniel is a top-down RTS mobile game. Control Nathaniel and his robot companion Hermes as they fight alien invaders from a crashed vessel to save Earth.

## Project Structure

```
Nathaniel/
├── Legacy/              # Original WP7/XNA codebase (C#, ~2011)
├── Nathaniel Shared/    # Swift/SpriteKit game code
├── Nathaniel iOS/       # iOS app target
└── Nathaniel macOS/     # macOS app target
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

See `docs/automation.md` for Codex MCP setup and script options.

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

The port retains pathfinding, desktop controls, zoom, level selection, three save slots, and fog of war. Saves include carried corpses, Spawner production timers, and tower build costs. Older save slots remain readable; their tower refunds use the current build cost.

**macOS controls:** Space switches camera focus, R changes Hermes mode, S stops Nathaniel, Escape pauses, and the mouse wheel zooms. Right-click or F fires Nathaniel's gun.

**Regression tests:**

```bash
xcodebuild -project Nathaniel.xcodeproj -scheme "Nathaniel macOS" \
  -configuration Debug -destination 'platform=macOS' test
```

Tests cover pathfinding, corpse delivery, Hermes and tower behavior, enemy weapons, Spawners, level rules, and save compatibility. Use the game MCP server for live gameplay interaction; see `AGENTS.md`.

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

### Bypassing Hooks

If you need to commit without running checks:

```bash
git commit --no-verify
```
