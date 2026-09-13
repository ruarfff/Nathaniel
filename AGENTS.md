# Nathaniel

This repository contains one Godot 4.7.2 game. `project.godot` is at the repository root. The retired Swift/SpriteKit and Windows Phone projects are available in Git history at `824c8f1`.

## Working boundaries

- Keep gameplay rules and use cases in `scripts/domain/`. `GameSimulation` owns mutable state; use its methods to add or remove entities because combat keeps indexes of those entities.
- Keep input, UI, camera projection, audio, effects, actor views and native level adapters in `scripts/presentation/`. `game_app.gd` is the composition root.
- Keep file persistence, Swift-save compatibility and debug HTTP in `scripts/infrastructure/`.
- Edit native levels, scenes and resources directly. Normal startup must preserve authored content.
- Use logical Y-up world coordinates for gameplay, snapshots and debug entity state. Viewport input and control bounds use a top-left origin. Presentation owns the conversion.
- Preserve the saved format identifiers and storage identity documented in [saves](docs/saves.md). Tests use explicit temporary storage, never live user saves or preferences.

## Task-specific references

- Before moving code across boundaries, read [architecture](docs/architecture.md).
- Before changing gameplay state, read [the domain boundary](scripts/domain/README.md).
- Before editing levels, actor resources, effects, or exports, read [authoring](docs/authoring.md).
- Before changing saves or Swift import, read [save compatibility](docs/saves.md).
- Before a gameplay playtest, read [testing](docs/testing.md). Before changing the debug protocol or MCP tools, also read [the debug interface](docs/debug-interface.md).
- Before reporting platform acceptance or performance, check [verification](docs/verification.md) and identify which checks were rerun.

## Commands and validation

Prefer Make targets. `make` runs the game; `make help` lists commands. Run `make format-check` and the relevant checks after edits. `make test` covers native content, gameplay, persistence, presentation, Python tooling and live MCP integration. The command runner fails on logged engine/script errors even if Godot exits zero.

After significant gameplay changes, export and run both target platforms when the environment supports them. Use real mouse, keyboard and touch input to verify controls. Synthetic events, MCP setup, and successful builds establish different facts; report each result and any untested platform or gesture explicitly.

Use typed GDScript with PascalCase classes, snake_case methods/properties, and SCREAMING_SNAKE_CASE constants. Keep saved field names and external protocol names stable even where their conventions differ.

## Completing work

Keep changes scoped and preserve existing work. Report failed or incomplete checks plainly. Create commits, push, or change remote systems only when the user explicitly asks.
