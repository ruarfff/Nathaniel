# Debug and MCP interface

The optional debug server exposes game inspection and test setup through HTTP.
The MCP adapter uses the same protocol. The game server starts only in a debug
build when explicitly requested, binds only to `127.0.0.1`, and uses port
**8766** by default. Release exports cannot start it.

```sh
godot --path . -- --debug-server
```

For repeatable setup, use survival and an isolated storage directory:

```sh
godot --path . -- --debug-port=18766 --level=0 --storage-dir=/private/tmp/nathaniel-debug
```

Set `GAME_SERVER_URL=http://127.0.0.1:8766` in the adapter's environment.
See the [MCP adapter README](../game-mcp-server/README.md) for installation and
client configuration. The adapter defaults to this address.

## Contract and coordinates

The routes are: `GET /health`, `/state`, `/nodes`, `/actions`, and
`/screenshot`; `POST /action`, `/tap`, and `/swipe`. Screenshots use the
`{success, format:"png", data:<base64>}` response so MCP displays a native image.
Headless runs explicitly report screenshots unavailable.

State preserves score, resources, lives, elapsed time, result/pause, player and
Hermes positions/health, enemy/tower counts, and Hermes `following`/`independent`
mode. State also includes engine, scene size, entity details, camera zoom, and a
`coordinateSystem` description.

- State positions and `spawnEnemy` x/y are **logical world pixels, y up**.
- `/nodes` bounds and `/tap`/`swipe` input are **viewport pixels, origin top-left**.
- Rendering projects logical coordinates into the isometric world and camera.

Follow the returned `coordinateSystem` and node bounds. A named tap computes
the center of those bounds. Covered controls are excluded while a
modal menu is open. Coordinate input is a debug fallback and does not test OS
mouse, keyboard, or touch recognition.

`/actions` exposes `loadLevel` (0–5), `mainMenu`, `pause`, `resume`, `spawnEnemy`,
`killAllEnemies`, `healPlayer`, `addResources`, and `setHermesMode`; menus expose
only navigation. Parameters are strings. Setup retains its established action
names and parameter fields. Ordinary enemy death handling still applies, so
`killAllEnemies` can complete a campaign level and record progress. Use survival
and `--storage-dir` for fixtures.

The transport supports fragmented requests and one response per connection,
requires valid `Content-Length` framing, rejects duplicate lengths and transfer
encoding, limits headers to 16 KiB and bodies to 16 MiB, and expires unfinished
requests after ten seconds. It accepts at most sixteen simultaneous connections.

## Verification

The service suite includes HTTP framing, discovery, input dispatch, PNG envelopes,
and a real loopback HTTP round trip:

```sh
godot --headless --path . --script res://tests/test_services.gd
```

To check the MCP adapter against the actual game, start a separate
**headless**, isolated process, then run the integration script from another shell:

```sh
godot --headless --path . -- --debug-port=18766 --storage-dir=/private/tmp/nathaniel-mcp-fixture
npm --prefix game-mcp-server run build
node tests/test_live_mcp.mjs http://127.0.0.1:18766
```

The script loads all six modes, checks established state fields and setup actions,
taps the pause menu, checks entity bounds and swipe fallback, tests invalid input,
and expects a clear headless screenshot error. It ends at the main menu. These
checks establish protocol compatibility; rendered screenshots and real OS input
remain separate playtests, as described in [testing.md](testing.md).
