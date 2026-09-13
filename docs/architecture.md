# Architecture

`GameSimulation` owns gameplay state and use cases. `GameApp` connects it to native scenes, input, rendering and services. There is no separate application layer that forwards the same use cases.

```text
presentation/GameApp ──> domain/GameSimulation
         │                        │
         ├──> presentation        └──> balance, combat, navigation
         │    actors, levels,
         │    UI, input, audio
         └──> infrastructure
              save/settings/progress, import, debug HTTP
```

## Dependencies

| Boundary | Owns | Dependency rule |
| --- | --- | --- |
| `scripts/domain/` | Simulation use cases, mutable entities, combat, navigation, balance, snapshots | No presentation nodes, input events, file access or HTTP. Uses Godot value types, `RefCounted`, and `AStarGrid2D` intentionally. |
| `scripts/presentation/` | Isometric projection, camera, UI, input, audio, effects and actor views | Converts user input into simulation commands and state/events into views. |
| `scripts/presentation/actors/` | Native actor views and visual resources | Appearance and animation do not define combat distances or collision footprints. |
| `scripts/presentation/levels/` | Inspector resources, spawn markers and native level adapters | Converts authored scenes to level configuration data consumed by the simulation. |
| `scripts/infrastructure/` | Atomic JSON, slot/settings/progress storage, Swift-save conversion and debug HTTP | Receives values/configuration from its caller; it does not load gameplay scenes or own combat rules. |

The domain is independent of the scene tree, not independent of the engine. Godot's value types and pathfinding grid are suitable in-process dependencies. Its tests run in headless Godot. This design keeps logical distances stable while the outer view uses an isometric projection.

## Composition and state flow

`presentation/game_app.gd` is the composition root. It loads the selected level, obtains its configuration, creates the simulation and services, connects UI/input signals, and updates views from simulation state. It supplies debug callbacks and the matching level configuration for an explicit Swift-save import. Audio receives audio preferences as booleans; it does not depend on the settings store.

Native scenes and resources are the content source of truth. The level adapter translates marker positions from projected editor coordinates to logical world points. Simulation snapshots preserve logical Y-up positions and requested destinations. Restoration rebuilds navigation after tower obstacles. UI control bounds and pointer input remain in top-left viewport coordinates.

The simulation owns entity insertion and removal because combat maintains private indexes. Call its use cases rather than modifying the entity arrays. `take_events()` consumes one-time presentation/audio events. See [the domain boundary](../scripts/domain/README.md) for APIs and rule details.

Persistence owns format validation, three-slot metadata and atomic replacement. Settings and campaign records have independent files. The Swift converter is a compatibility adapter for explicit exported files; it has no dependency on retired source. See [save compatibility](saves.md).

Debug HTTP owns request framing and loopback transport. Its presentation bridge translates current game state and visible controls into the stable external protocol. The TypeScript MCP adapter forwards that protocol; it does not duplicate gameplay rules. See [the debug interface](debug-interface.md).
