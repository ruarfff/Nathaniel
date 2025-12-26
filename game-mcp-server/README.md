# Nathaniel MCP Server

MCP (Model Context Protocol) server for testing the Nathaniel game. This server wraps the game's embedded HTTP command server, allowing LLM agents to control and test the game programmatically.

## Prerequisites

- Node.js 18+
- The Nathaniel game running in DEBUG mode (iOS Simulator or macOS)

## Installation

```bash
cd game-mcp-server
npm install
npm run build
```

## Usage

### With Claude Code

Add to your Claude Code MCP configuration (`.claude/config.json` or similar):

```json
{
  "mcpServers": {
    "nathaniel-game": {
      "command": "node",
      "args": ["/path/to/Nathaniel/game-mcp-server/dist/index.js"],
      "env": {
        "GAME_SERVER_URL": "http://localhost:8765"
      }
    }
  }
}
```

### Standalone

```bash
# Set environment variables (optional)
export GAME_SERVER_URL=http://localhost:8765
export GAME_SERVER_TIMEOUT=5000

# Run the server
npm start
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GAME_SERVER_URL` | `http://localhost:8765` | URL of the game's HTTP command server |
| `GAME_SERVER_TIMEOUT` | `5000` | Request timeout in milliseconds |

## Available Tools

### `game_health`
Check if the game command server is running and healthy.

### `game_get_state`
Get the current game state:
- Scene name
- Score, lives, resources
- Player/Hermes positions
- Enemy count
- Game status (playing, victory, gameOver)

### `game_get_nodes`
Get all interactive nodes in the current scene with their:
- Names and types
- Frame coordinates (x, y, width, height)
- Interactive status
- Custom properties

### `game_screenshot`
Capture a screenshot of the current game screen (base64-encoded PNG).

### `game_tap`
Tap at specific coordinates in the game.

Parameters:
- `x`: X coordinate (scene coordinates)
- `y`: Y coordinate (scene coordinates)

### `game_swipe`
Perform a swipe gesture.

Parameters:
- `fromX`, `fromY`: Starting coordinates
- `toX`, `toY`: Ending coordinates
- `duration`: Swipe duration in seconds (default: 0.3)

### `game_action`
Execute a named game action.

Parameters:
- `name`: Action name
- `params`: Optional parameters (key-value object)

Available actions vary by scene:
- **MainMenuScene**: `startGame`, `options`, `credits`
- **LevelSelectScene**: `level_1`, `level_2`, ..., `back`
- **GameScene**: `selectNathaniel`, `selectHermes`, `moveNathaniel`, `targetEnemy`

## Example Workflow

```typescript
// 1. Check if game is running
await game_health();

// 2. Get current state
const state = await game_get_state();
console.log(`Scene: ${state.scene}, Status: ${state.gameStatus}`);

// 3. Find the "Level Select" button
const nodes = await game_get_nodes();
const levelSelectBtn = nodes.find(n => n.name === "startButton");

// 4. Tap the button
await game_tap({ x: levelSelectBtn.frame.x, y: levelSelectBtn.frame.y });

// 5. Verify navigation
const newState = await game_get_state();
console.log(`Now in: ${newState.scene}`);
```

## Game Server Port

The game's command server runs on port **8765** by default. This is only active in DEBUG builds. Make sure the game is running before using the MCP server.

### iOS Simulator
When testing on iOS Simulator, the game server is accessible at `localhost:8765` from the host machine.

### macOS
When running the macOS version, the game server is accessible at `localhost:8765`.

## Troubleshooting

**"Connection refused"**: Make sure the game is running in DEBUG mode.

**"Request timeout"**: The game may be busy or unresponsive. Check if the game is frozen or loading.

**"No game delegate available"**: The current scene doesn't support the command server. Navigate to a supported scene (MainMenuScene, LevelSelectScene, GameScene).
