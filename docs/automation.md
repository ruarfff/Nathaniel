# Automation & Testing

This repo supports lightweight “smoke tests” so an agent (or CI-style workflow) can verify the game builds and launches.

## Smoke Test Mode

`--smoke-test` (or `NATHANIEL_SMOKE_TEST=1`) enables smoke-test behavior:

- macOS: runs resource + map-load checks and exits `0` on success (prints `SMOKE_TEST_PASS`).
- iOS: launches directly into Level 1 (`GameScene`) for easy screenshot validation.

Implementation lives in `Nathaniel Shared/SmokeTestRunner.swift`.

## Smoke Test Scripts

All outputs go to `test-artifacts/` (ignored by git).

### macOS

```bash
bash scripts/smoke_macos.sh
```

Writes a log to `test-artifacts/macos-smoke.log`.

### iOS Simulator

```bash
bash scripts/smoke_ios_sim.sh
```

Takes a screenshot at `test-artifacts/ios-sim-smoke.png`.

### Useful Overrides

- `DERIVED_DATA_PATH`: where Xcode writes DerivedData (default: `test-artifacts/DerivedData`)
- `CONFIGURATION`: Xcode configuration (default: `Debug`)
- `SIMULATOR_UDID`: force a specific simulator device
- `DESTINATION`: xcodebuild destination string (default: `generic/platform=iOS Simulator`)
- `SMOKE_WAIT_SECONDS`: how long to wait before screenshot (default: `5`)

## Codex MCP Setup (Recommended)

If you want a coding agent to reliably build/run/screenshot without “driving” Xcode manually, configure MCP servers for:

- `ios-simulator-mcp` (sim install/launch/screenshot)
- `xcodebuildmcp` (build + simulator helpers)

On a machine with Xcode + Node installed:

```bash
codex mcp add ios-simulator \
  --env IOS_SIMULATOR_MCP_DEFAULT_OUTPUT_DIR="$(pwd)/test-artifacts" \
  --env IOS_SIMULATOR_MCP_IDB_PATH="$(command -v idb)" \
  -- npx -y ios-simulator-mcp

codex mcp add XcodeBuildMCP \
  --env XCODEBUILDMCP_SENTRY_DISABLED=true \
  --env INCREMENTAL_BUILDS_ENABLED=false \
  -- npx -y xcodebuildmcp@latest

codex mcp list
```

Notes:

- UI automation tools may require Facebook IDB (`idb` + `idb_companion`).
- If you run Codex with sandboxing enabled, Xcode/Simulator may need extra writable dirs (e.g. `~/Library/Developer`, `~/Library/Logs`). MCP tools can help avoid relying on sandboxed shell commands for simulator control.
