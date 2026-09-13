# Godot migration

Status: full gameplay/content migration and local verification are complete,
with the acceptance limits below. macOS and iOS Simulator builds run, and real
controls have been exercised. The Swift app remains available and is not retired.
See [verification](godot-verification.md) for commands, evidence and limits.

## Baseline

- Starting checkout: clean on 13 September 2026.
- Installed Xcode: 26.6 (17F113). Actual project requirements supersede the older
  Xcode 15/iOS 17 prerequisites in AGENTS.md.
- Godot: pinned to **4.7.2-stable**, installed build
  `4.7.2.stable.nixpkgs.ed1daf0bf`.
- [Release](https://godotengine.org/download/archive/4.7.2-stable/),
  [matching documentation](https://docs.godotengine.org/en/4.7/).
- Stale `docs/adding-levels.md`: survival is zero spare lives and 30 resources.
  `LevelConfig` and regression tests are authoritative for existing behaviour.
- Baseline: Swift XCTest passes with a local ad-hoc signing override; iOS build
  and launch pass. Original desktop and Simulator input were exercised. The
  seven build-command tests and original MCP test pass. Initial sandbox/signing
  failures are recorded separately in the verification report.

## Plan

1. Establish Swift build/test baseline and actual map, save and gameplay contracts.
2. Add a separate typed GDScript project with logical gameplay state, reusable
   scene views, native editable levels and one shared isometric projection.
3. Port all campaign/survival content, combat, navigation, resources, saves,
   menus, audio, input and debug inspection.
4. Run regression checks, inspect rendered scenes, exercise real controls,
   profile busy scenes and test macOS/iOS exports.
5. Update evidence, authoring instructions and unresolved platform gates.

## Architecture decision

A physics-node port would couple distances to the projected screen and make
save restoration depend on scene construction. An ECS would add a new framework
without a current need. Use a deterministic logical simulation in small modules,
native Godot level/actor resources and scenes, and a presentation controller.
The model uses existing Swift world points; only rendering/input projects them.
Godot levels become authoritative after explicit conversion; normal runs never
regenerate edited levels. Save and debug services own their external formats.

## Feature parity checklist

Automated checks exercise rules and native scenes; actual OS input is recorded
separately. A platform build alone is not marked as an input check.

| Area | Required behaviour | Status/evidence |
|---|---|---|
| Nathaniel | Move, target, gun, death, three spare campaign lives, respawn | Implemented; gameplay and input integration checks |
| Hermes | Focus independent of mode, follow/stop/build, laser | Implemented; regression checks and real desktop/mobile mode/focus input |
| Towers | Gun/laser/heal, 5/10/15 cost, placement, destruction, per-cost 25% refund | Implemented; rule checks and real drag 30→25, follow refund 25→26 |
| Enemies | Grunt, Soldier, Boss, Spawner, target retention, weapons | Implemented; rule checks, rendered fights and dead-owner projectile cases |
| Resources | Soldier-only corpses, carry/delivery, 10-second loose expiry | Implemented; multiple-corpse, delivery, expiration and save checks |
| Campaign | All five levels, boss victory, progression, defeat | Six scenes load; fixed-map boss routes, terminal/progress rules checked |
| Survival | Wave timing, endless play, no spare lives | Implemented; timers checked and rendered survival played |
| Navigation | Static/dynamic obstacles, footprint, requested routes | Implemented; real-map paths, tower changes and save restoration checked |
| Projection | Terrain, inverse input, feet anchors, depth, logical distances | Implemented; native tile math and sprites checked; controlled tree occlusion rendered |
| Camera | Bounds, focus, smooth follow, zoom, fixed HUD | Implemented; inverse conversion at zoom and viewport tests; real focus and mobile zoom checked |
| Fog | Visible/explored/unexplored state | Implemented; visibility rules, rendering and native save state checked |
| Application | Menus, pause, settings, credits, audio, HUD, progression | Implemented; native menu/audio/slot tests; mobile layouts and scrollbar navigation checked |
| Saves | Three slots, complete resume, isolated tests, Swift import | Implemented; all-slot tests, real iOS slot save/load, v1/v2 synthetic imports and no-overwrite path tested; see save limits |
| Input | Desktop mouse/keyboard and iOS touch | Desktop keys/ground/Hermes/drag/wheel and iOS movement/focus/build/refund/zoom/menu/save/load verified; real menu swipe and pinch remain unverified |
| Debug | State, setup, discovery, screenshots, unchanged MCP | 133 live adapter checks; rendered PNG capture verified |
| Authoring | Native paint/blocking/markers/Inspector/current-scene run | 166 content checks; repack roundtrip, parameter overrides and depth preview |
| Verification | Rule, navigation, save, content and app checks | `make godot-test` passes; final counts in verification report |
| Performance | Busy scene workload and hardware | Simulation and full rendered 232-actor profiles recorded |
| Platforms | macOS and iOS exports/builds/runs | macOS release/debug exports pass; corrected ARM64 iOS Simulator build/run and real touch pass; physical-device run unverified |
| Original app | Sources, assets, tests and commands preserved | No Swift/Xcode/original map/asset/test changes; baseline builds/tests/input pass |

## Deviations and unresolved gates

- Isometric ground/scenery derivatives and original tower/character artwork
  are temporary. Wall/cliff faces and viewing angles need a dedicated art pass;
  projectiles and event effects use temporary circles, lines, and rings. All
  gameplay remains usable. See the [asset inventory](godot-authoring.md).
- Native Godot scenes/Inspector resources replace the Swift developer settings
  panel. The old panel and its global debug preference files are not copied.
  Scene parameters and the small debug action/state interface provide iteration.
- Fog visibility is a persisted normal Godot setting; Swift exposed that switch
  in its developer settings. Audio still defaults off.
- Native Godot saves additionally preserve fog, active projectiles and weapon/RNG
  phase. Swift imports cannot recover fields Swift never saved. Slot import does
  not import global preferences or campaign completion records, and never searches
  another app's live container. See [save compatibility](godot-saves.md).
- Official 4.7.2 iOS templates contain an Intel-only Simulator binary. A separate
  local template adds an ARM64 debug Simulator library built from the same source
  tag. The exact source, hashes and build command are documented. Device and
  release libraries remain original. Signing/notarization and physical-device
  input are separate, unverified distribution gates.
- Native automated input verifies menu swipe propagation and cancellation after
  fixing menu buttons that stopped drag events. The computer-use Simulator drag
  still activated its starting button, so real swipe scrolling remains unverified;
  scrollbar-track taps reach every menu item. Multi-touch pinch, audible output,
  and iOS performance also need manual/device acceptance. These limits and the
  measured desktop frame-time spike are recorded in the verification report.

The Godot implementation is ready for a separate replacement review. Do not
retire the Swift app until the remaining device and input acceptance checks are
complete and the owner makes that decision.
