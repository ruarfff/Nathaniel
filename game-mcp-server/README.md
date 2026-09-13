# Nathaniel MCP server

A small adapter for the game's DEBUG-only inspection and test setup interface. Use computer use for real mouse, keyboard, and touch validation; see [the testing guide](../docs/testing.md).

## Setup

Requires Node.js 18+. Start a debug game explicitly with `make debug` or `godot --path . -- --debug-server` from the repository root. Release exports omit the server.

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
      "env": {"GAME_SERVER_URL": "http://127.0.0.1:8766"}
    }
  }
}
```

`GAME_SERVER_URL` defaults to `http://127.0.0.1:8766`. `GAME_SERVER_TIMEOUT` defaults to 5000 milliseconds. Run one Debug game at a time to avoid a port conflict. Restart the MCP client after rebuilding this adapter so it refreshes the tool list.

## Tools

| Tool | Purpose |
|---|---|
| `game_health` | Check the debug server |
| `game_state` | Read exact live game state |
| `game_nodes` | Inspect named controls and viewport bounds (origin top-left) |
| `game_screenshot` | Capture a scene PNG |
| `game_list_actions` | Discover setup actions and parameter hints |
| `game_action` | Execute a setup action with string parameters |
| `game_tap` | Fallback pointer input by node name or viewport x,y |
| `game_swipe` | Fallback tower drag; otherwise tap its endpoint |

Actions and pointer injection bypass OS input. Swipe duration is accepted for the pointer protocol but does not control timing. Automated tests use an isolated HTTP fixture:

```sh
npm test
```

Use action discovery for setup and visible controls for menu navigation. State entity positions use logical Y-up world coordinates; node bounds and fallback pointer coordinates use a top-left viewport origin. See [the debug contract](../docs/debug-interface.md) for routes, isolation, and coordinate details.
