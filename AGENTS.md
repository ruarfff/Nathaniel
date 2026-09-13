# Nathaniel

## Project Overview

A simple top-down RTS game where the player controls Nathaniel and his robot companion Hermes, fighting through alien invaders to save Earth.


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

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Classes/Structs/Enums | PascalCase | `Character`, `GunTower`, `LevelConfig` |
| Properties/Methods | camelCase | `currentHP`, `maxSpeed`, `updateTexture()` |
| Static Constants | PascalCase | `Nathaniel.defaultMaxHP` |
| Enum Cases | camelCase | `.gunTower`, `.following`, `.south` |
| Boolean Properties | `is`/`has` prefix | `isAlive`, `hasRangedWeapon` |

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
