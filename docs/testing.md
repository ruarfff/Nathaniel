# Testing Guide

This guide covers how to test the Nathaniel game using the GameCommandServer API and other testing approaches.

## Testing Architecture

```
┌─────────────────┐     HTTP      ┌──────────────────────┐
│  Test Client    │ ◄──────────► │  GameCommandServer   │
│  (curl/scripts) │    :8765     │  (in-game, Swift)    │
└─────────────────┘              └──────────────────────┘
        │                                  │
        │                                  │ SpriteKit
        ▼                                  ▼
┌─────────────────┐              ┌──────────────────────┐
│ XcodeBuildMCP   │              │    Game Scenes       │
│ (build/run/ss)  │              │ (MainMenu, Game, etc)│
└─────────────────┘              └──────────────────────┘
```

## Quick Start

### 1. Build and Run

```bash
# Set up XcodeBuildMCP session
mcp__XcodeBuildMCP__session-set-defaults \
  projectPath=/Users/ruairi/dev/Nathaniel/Nathaniel.xcodeproj \
  scheme="Nathaniel iOS" \
  simulatorId=<UUID> \
  useLatestOS=true

# Build and run
mcp__XcodeBuildMCP__boot_sim
mcp__XcodeBuildMCP__open_sim
mcp__XcodeBuildMCP__build_run_sim
```

### 2. Verify Server Running

```bash
# Wait 2-3 seconds for app launch, then:
curl -s http://localhost:8765/health
# {"status":"ok","server":"GameCommandServer","version":"1.0.0"}
```

### 3. Navigate and Test

```bash
# Start game
curl -s -X POST http://localhost:8765/action \
  -H "Content-Type: application/json" \
  -d '{"name":"startGame"}'

# Select level
curl -s -X POST http://localhost:8765/action \
  -H "Content-Type: application/json" \
  -d '{"name":"level_1"}'

# Check game state
curl -s http://localhost:8765/state | jq .
```

## GameCommandServer API

### Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Check server status |
| `/state` | GET | Get current game state |
| `/nodes` | GET | List interactive UI elements |
| `/screenshot` | GET | Capture scene as base64 PNG |
| `/screenshot/annotated` | GET | Capture screenshot with bounding boxes around nodes |
| `/describe` | GET | Get semantic scene description for agents |
| `/tap` | POST | Inject tap at coordinates |
| `/swipe` | POST | Inject swipe gesture |
| `/action` | POST | Execute named action |

### GET /state

Returns current game state:

```json
{
  "scene": "GameScene",
  "score": 150,
  "lives": 3,
  "resources": 25,
  "elapsedTime": 45.2,
  "gameStatus": "playing",
  "isPaused": false,
  "playerPosition": {"x": 400, "y": 300},
  "hermesPosition": {"x": 350, "y": 280},
  "enemyCount": 5
}
```

### GET /nodes

Returns interactive elements with frame coordinates:

```json
[
  {
    "name": "pauseButton",
    "frame": {"x": 650, "y": 480, "width": 44, "height": 44},
    "interactive": true
  },
  {
    "name": "nathaniel",
    "frame": {"x": 380, "y": 280, "width": 48, "height": 64},
    "interactive": true
  }
]
```

### POST /tap

Inject a tap at scene coordinates:

```bash
curl -X POST http://localhost:8765/tap \
  -H "Content-Type: application/json" \
  -d '{"x": 683, "y": 350}'
```

### POST /action

Execute a named action:

```bash
curl -X POST http://localhost:8765/action \
  -H "Content-Type: application/json" \
  -d '{"name":"selectHermes"}'

# With parameters
curl -X POST http://localhost:8765/action \
  -H "Content-Type: application/json" \
  -d '{"name":"moveNathaniel", "params":{"x":"500","y":"400"}}'
```

## Available Actions by Scene

### MainMenuScene

| Action | Description |
|--------|-------------|
| `startGame` | Navigate to level select |
| `options` | Open options screen |
| `credits` | Open credits screen |
| `loadGame` | Open save slot selector |

### LevelSelectScene

| Action | Description |
|--------|-------------|
| `level_1` - `level_5` | Start specific level |
| `survival` | Start survival mode |
| `back` | Return to main menu |

### GameScene

| Action | Parameters | Description |
|--------|------------|-------------|
| `selectNathaniel` | - | Select Nathaniel |
| `selectHermes` | - | Select Hermes |
| `moveNathaniel` | `x`, `y` | Move Nathaniel to position |
| `moveHermes` | `x`, `y` | Move Hermes to position |
| `targetEnemy` | `index` | Target enemy by index |
| `pause` | - | Pause game |
| `resume` | - | Resume game |

### OptionsScene

| Action | Description |
|--------|-------------|
| `back` | Return to previous screen |
| `toggleSound` | Toggle sound effects |
| `toggleMusic` | Toggle background music |

## Testing Patterns

### Smoke Test

Verify basic functionality:

```bash
#!/bin/bash
# smoke_test.sh

# Check server
curl -sf http://localhost:8765/health || exit 1

# Navigate to gameplay
curl -sf -X POST http://localhost:8765/action -d '{"name":"startGame"}' || exit 1
sleep 0.5
curl -sf -X POST http://localhost:8765/action -d '{"name":"level_1"}' || exit 1
sleep 2

# Verify game started
STATE=$(curl -s http://localhost:8765/state)
SCENE=$(echo $STATE | jq -r '.scene')
if [ "$SCENE" != "GameScene" ]; then
  echo "FAIL: Expected GameScene, got $SCENE"
  exit 1
fi

echo "PASS: Smoke test completed"
```

### Gameplay Test

Test game mechanics:

```bash
#!/bin/bash
# gameplay_test.sh

# Start level 1
curl -X POST http://localhost:8765/action -d '{"name":"startGame"}'
sleep 0.5
curl -X POST http://localhost:8765/action -d '{"name":"level_1"}'
sleep 2

# Get initial state
INITIAL=$(curl -s http://localhost:8765/state)
INITIAL_ENEMIES=$(echo $INITIAL | jq '.enemyCount')

# Move player toward enemies
curl -X POST http://localhost:8765/action \
  -d '{"name":"moveNathaniel", "params":{"x":"600","y":"400"}}'
sleep 5

# Check if enemies were killed (score increased)
FINAL=$(curl -s http://localhost:8765/state)
FINAL_SCORE=$(echo $FINAL | jq '.score')

if [ "$FINAL_SCORE" -gt 0 ]; then
  echo "PASS: Player killed enemies (score: $FINAL_SCORE)"
else
  echo "FAIL: No enemies killed"
fi
```

### Visual Verification

Take screenshots for visual testing:

```bash
# Via XcodeBuildMCP (recommended)
mcp__XcodeBuildMCP__screenshot

# Via GameCommandServer (base64 PNG)
curl -s http://localhost:8765/screenshot | base64 -d > screenshot.png
```

## Adding Test Actions

### Implement GameCommandDelegate

In your scene, implement the protocol:

```swift
extension MyScene: GameCommandDelegate {
    func executeAction(name: String, params: [String: String]?) -> ActionResult {
        switch name {
        case "myAction":
            performMyAction()
            return .success("Action completed")

        case "myActionWithParams":
            guard let x = params?["x"], let xVal = Double(x) else {
                return .failure("Missing x parameter")
            }
            performAction(at: xVal)
            return .success("Action with params completed")

        default:
            return .failure("Unknown action: \(name)")
        }
    }

    func getCurrentGameState() -> GameCommandServer.GameState {
        return GameCommandServer.GameState(
            scene: "MyScene",
            score: score,
            lives: lives,
            // ... other state
        )
    }

    func getInteractiveNodes() -> [GameCommandServer.NodeInfo] {
        var nodes: [GameCommandServer.NodeInfo] = []

        // Add buttons
        if let button = myButton {
            nodes.append(button.toNodeInfo())
        }

        // Add characters
        nodes.append(player.sprite.toNodeInfo(interactive: true))

        return nodes
    }
}
```

### Register the Delegate

In your scene's `didMove(to:)`:

```swift
override func didMove(to view: SKView) {
    super.didMove(to: view)

    #if DEBUG
    GameCommandServer.shared.delegate = self
    #endif
}
```

## DevSettings for Testing

In DEBUG builds, adjust settings for easier testing:

```swift
// In DevSettings.swift or via code
DevSettings.shared.playerInvincible = true      // God mode
DevSettings.shared.nathanielSpeed = 200         // Fast movement
DevSettings.shared.towerCostGun = 1             // Cheap towers
DevSettings.shared.enemyDamage = 0              // Enemies don't hurt
DevSettings.shared.spawnInterval = 30           // Slow spawning
```

## Coordinate Systems

### SpriteKit Scene Coordinates

- **Origin (0, 0)**: Bottom-left of scene
- **Scene Size**: 1366 x 1024 (design resolution)
- **Y-axis**: Increases upward

### Converting Coordinates

Use `/nodes` to get exact frame coordinates for UI elements. Don't guess from screenshots.

```bash
# Get button position
NODES=$(curl -s http://localhost:8765/nodes)
PAUSE_X=$(echo $NODES | jq '.[] | select(.name=="pauseButton") | .frame.x')
PAUSE_Y=$(echo $NODES | jq '.[] | select(.name=="pauseButton") | .frame.y')

# Tap the button
curl -X POST http://localhost:8765/tap \
  -d "{\"x\": $PAUSE_X, \"y\": $PAUSE_Y}"
```

## Common Issues

### Server Not Responding

- Ensure DEBUG build (server only runs in debug)
- Wait 2-3 seconds after app launch
- Check port 8765 isn't blocked

### Actions Not Working

- Verify scene implements `GameCommandDelegate`
- Check action name spelling (case-sensitive)
- Look for errors in Xcode console

### Coordinates Don't Match

- Use `/nodes` for precise coordinates
- Remember Y=0 is at bottom in SpriteKit
- Scene coordinates differ from screen coordinates

## XcodeBuildMCP vs GameCommandServer

| Task | Use |
|------|-----|
| Building the app | XcodeBuildMCP |
| Running the app | XcodeBuildMCP |
| Taking screenshots | XcodeBuildMCP |
| Booting simulators | XcodeBuildMCP |
| Tapping UI elements | GameCommandServer |
| Getting game state | GameCommandServer |
| Navigating menus | GameCommandServer |
| In-game interactions | GameCommandServer |

**Important**: XcodeBuildMCP's tap/swipe tools have coordinate issues with landscape SpriteKit games. Always use GameCommandServer for in-game interaction.
