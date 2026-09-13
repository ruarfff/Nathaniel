# Nathaniel MCP server

A small adapter for the game's DEBUG-only inspection and test setup interface. Use computer use for real mouse, keyboard, and touch validation; see [the testing guide](../docs/testing.md).

## Setup

Requires Node.js 18+ and a Debug game running on macOS or iOS Simulator.

```sh
cd game-mcp-server
npm ci
npm run build
```

Add the server to your MCP client's configuration, using the absolute path to the compiled entry point:

```json
{
  "mcpServers": {
    "nathaniel-game": {
      "command": "node",
      "args": ["/path/to/Nathaniel/game-mcp-server/dist/index.js"],
      "env": {"GAME_SERVER_URL": "http://localhost:8765"}
    }
  }
}
```

`GAME_SERVER_URL` defaults to `http://localhost:8765`. `GAME_SERVER_TIMEOUT` defaults to 5000 milliseconds. Run one Debug game at a time to avoid a port conflict. Restart the MCP client after rebuilding this adapter so it refreshes the tool list.

## Tools

| Tool | Purpose |
|---|---|
| `game_health` | Check the debug server |
| `game_state` | Read exact live game state |
| `game_nodes` | Inspect named controls and scene-space bounds |
| `game_screenshot` | Capture a scene PNG |
| `game_list_actions` | Discover setup actions and parameter hints |
| `game_action` | Execute a setup action with string parameters |
| `game_tap` | Fallback pointer input by node name or scene x,y |
| `game_swipe` | Fallback tower drag; otherwise tap its endpoint |

Actions and pointer injection bypass OS input. Swipe duration is accepted for the pointer protocol but does not control timing. Automated tests use an isolated HTTP fixture:

```sh
npm test
```

Old aliases, menu-specific actions, scene-wait commands, annotated screenshots, and visual baseline tools have been removed. Use action discovery for setup and visible controls for menu navigation.
