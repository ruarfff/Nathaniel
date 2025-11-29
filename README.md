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

**Requirements:** Xcode 15+, macOS Sonoma+

**Run from Xcode:**
1. Open `Nathaniel.xcodeproj`
2. Select `Nathaniel iOS` or `Nathaniel macOS` scheme
3. Press Cmd+R

**Build from command line:**
```bash
# iOS
xcodebuild -project Nathaniel.xcodeproj -scheme "Nathaniel iOS" build

# macOS
xcodebuild -project Nathaniel.xcodeproj -scheme "Nathaniel macOS" build
```

## Current Status

- TMX map loading and rendering (Tiled format)
- Player character (Nathaniel) with sprite animations
- Touch/click-to-move controls
- Camera following player

## Development

This is a learning project for Swift/SpriteKit development. See `AGENTS.md` for detailed architecture docs and legacy code reference.

**Issue tracking:** Uses `bd` (beads) - run `bd ready` to see available work.

**Source control:** Uses `jj`
