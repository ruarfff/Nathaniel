# Automation & Testing

This repo supports lightweight “smoke tests” so an agent (or CI-style workflow) can verify the game builds and launches.

## Regression Tests

`make test-unit` runs the macOS XCTest suite. `make test-tooling` checks build and run commands with stubbed tools; it does not launch apps or change saved games.

Make targets use `build/DerivedData` by default. Override `DERIVED_DATA_PATH` to choose another build directory. `make ios` updates the installed app and keeps its data. Only `make ios-fresh` removes that data. Build, lint, and format failures stop their Make targets.

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

- `DERIVED_DATA_PATH`: where Xcode writes DerivedData (standalone smoke scripts default to `test-artifacts/DerivedData`; Make targets use `build/DerivedData`)
- `CONFIGURATION`: Xcode configuration (default: `Debug`)
- `SIMULATOR_UDID`: force a specific simulator device
- `DESTINATION`: xcodebuild destination string (default: `generic/platform=iOS Simulator`)
- `SMOKE_WAIT_SECONDS`: how long to wait before screenshot (default: `5`)

## Live validation

Use Make to build and launch, then computer use to check real input. The optional [game MCP adapter](../game-mcp-server/README.md) supplies exact state and controlled setup. No build or Simulator MCP server is required by these scripts. See [testing.md](testing.md) for the playtest workflow.

Run `npm --prefix game-mcp-server test` when changing the adapter. Its integration tests start an isolated HTTP fixture and the actual MCP stdio process; they do not change game saves.
