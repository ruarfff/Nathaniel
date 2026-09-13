# Godot verification record

Test host: Apple M4 Pro (12 CPU cores), arm64 macOS, Xcode 26.6 (17F113).
Godot is pinned to 4.7.2 stable. Measurements below are local checks, not a
promise for other hardware or a substitute for device profiling.

## Original app baseline

The starting checkout was clean. No Swift, Xcode, TMX, original artwork, original
test, or existing MCP adapter source was changed.

| Check | Result |
| --- | --- |
| `make test-tooling` | 7 tests passed; also rerun after Make additions |
| `npm --prefix game-mcp-server test` | Passed after permitting its isolated localhost fixture |
| `make test-unit` | Default signing failed because the configured Mac Development certificate was absent |
| `make test-unit` with local ad-hoc xcconfig override | XCTest suite passed |
| `make ios-build` | Passed with Xcode/Simulator service access |
| `make ios-run` | Launched original app on iPhone 17 Pro / iOS 26.5 Simulator |
| Original macOS real input | Level Select → Survival; Space focus, R follow, Escape pause; screenshots inspected |
| Original iOS real input | Level Select → Survival; touch ground movement, focus button, pause; screenshots inspected |

The ad-hoc override was an ignored local test configuration, not a repository
signing change. Initial sandbox failures involved Xcode services and localhost
binding; they are baseline environment failures, not Godot regressions. Logs
are under ignored `test-artifacts/migration-*`.

## Automated Godot checks

`make godot-test` imports the project, checks source whitespace, runs Python
conversion/extraction tests, executes native GDScript suites, and tests the
unchanged MCP adapter against an isolated Godot process. `run_checked.py` treats
logged engine/script errors as failures even if Godot exits zero.

| Source regression area | Godot coverage |
| --- | --- |
| EnemyParity / EnemyDeath | Stats, target retention/acquisition, Soldier drops, boss victory, arrows after death, simultaneous terminal events |
| GunTower / HermesParity / HermesControl | All tower kinds, costs, paid-cost refund rounding, owner cleanup, movement-independent focus, follow, stationary modes |
| ResourceParity | Loose expiration, multiple carried corpses, direct Hermes collection, delivery, death drops, wallet accounting |
| LevelParity | Five campaign configs, survival spare lives, respawn count, defeat, boss win, wave/spawner timers |
| PathFinder / NavigationSave | Static and tower footprints, clearance, logical movement, destination preservation, rebuilt routes, real campaign boss approach routes |
| SaveCleanup / SaveSlotSelector | Three isolated slots, atomic replacement, corrupt data, explicit no-overwrite Swift import, missing metadata, older paid-cost defaults |
| MenuState / InteractiveControls / CameraInput | Native menus, pause/settings/back, save/load scene restoration, modal guards, focus/mode independence, inverse projection at zoom, HUD separation |
| AudioManager / settings | Defaults, settings persistence, requested music track behavior in presentation; audible output remains a manual check |
| GameCommandDispatch / GameHTTPTransport | Same adapter, strict string setup parameters, framing, fragmentation, bounds, node/tap/swipe, headless screenshot error |
| Map/editor integration | Exact converted collision cells/starts/enemies, six scenes, native tile-center math, actor anchors, Inspector overrides, edited-scene pack roundtrip |

The final complete `make godot-test` run passed:

| Suite | Passing checks/tests |
| --- | ---: |
| Content and native authoring | 166 checks |
| Gameplay | 229 assertions |
| Persistence, settings, import, and HTTP services | 185 checks |
| Native presentation and input dispatch | 123 checks |
| Unchanged MCP adapter against the live Godot game | 133 checks |
| Python converter/export tooling | 6 tests |
| Python Swift-save extraction | 4 tests |

Presentation checks include all three save-slot labels and load paths,
replacement/cancel confirmation, corrupt-slot handling, modal exit and Escape,
settings failure feedback, audio off/on and track changes, pinch cancellation,
scrolling-menu bounds, and native touch-scroll event propagation/cancelled button
activation. Synthetic input tests verify dispatch; only the
real-input section establishes OS input behavior. Audio tests inspect player
state, not audible output.

## Rendered play and real controls

The macOS debug export was launched with an isolated storage directory and
separate bundle identifier. Real input through computer use verified:

- Space switches focus; R changes Hermes mode; Escape opens/closes pause.
- The visible Hermes Stop button changes him to stationary build mode.
- Dragging Gun from the HUD onto clear terrain creates a tower and changes
  resources from 30 to 25.
- R then removes that surviving tower and changes resources from 25 to 26,
  confirming the per-tower floor(5/4) refund through actual controls.
- Ground clicks issue movement; gameplay, enemies, projectiles, lasers, fog,
  upright scenery and character feet were inspected in rendered screenshots.

The final macOS debug build also received Space, R, and Escape and reported
Hermes selected, following, and paused. A real mouse-wheel scroll changed camera
zoom from 1.0 to 1.1. Godot's native window capture sometimes
returned a blank image while the viewport screenshot was correct. Fitting the
native window restored computer-use capture. Some subsequent window-bound
changes interrupted mouse operations; failed operations are not counted as
verified. Re-selecting the app after resize restored the mouse target. Real
multi-touch pinch remains unverified because the computer-use tool exposes one
pointer; gesture dispatch and coordinate conversion have automated coverage.

The ARM64 iPhone 17 Pro / iOS 26.5 Simulator build used a fresh private-container
test directory. Computer-use clicks and drags delivered actual Simulator touch
input. Read-only state and viewport PNGs verified the results separately:

- A real main-menu tap started survival. A terrain tap moved Nathaniel from
  `(348, 605)` to approximately `(452, 528)` in logical coordinates.
- The Hermes HUD button selected him; Build exposed all three tower choices.
  A drag placed a gun tower. Another attempt on blocked ground retained the
  placement cursor; tapping clear ground then created the tower.
- A successful purchase changed resources from 30 to 25. Follow removed the
  surviving tower and changed resources to 26, with Hermes following.
- Pause stopped time. Saving to empty test slot 1 displayed its level and
  26-resource metadata. Loading restored the same resources and Hermes mode.
  All three slots have native automated coverage; this OS-input check used slot 1.
- The touch zoom button changed camera zoom from 1.0 to 1.15. Pause, settings,
  music toggle, Back, and exit confirmation worked through visible controls.
  Music was returned to off; audible output was not assessed.
- Mobile controls use a 960×540 minimum logical canvas that expands for the
  landscape aspect ratio. The final Simulator viewport is 1174×540 logical
  pixels, rendered at 2622×1206. HUD, tower tray, pause, save/load, settings,
  and confirmation layouts were inspected in saved viewport PNGs.

Simulator native-window screenshots intermittently became blank, but touch
actions continued to work and the game's rendered viewport remained correct.
Re-selecting the refreshed build restored native captures. Evidence is under
ignored `test-artifacts/godot/ios-final-*.png` and the computer-use record.

The menu swipe investigation found that menu buttons stopped drag events before
they could reach the ScrollContainer. Menu buttons and settings toggles now pass
events to that parent; HUD buttons retain their original filtering. A native
viewport test confirms scroll start, changed offset, cancelled button activation,
and a subsequent ordinary tap. On iOS, tapping below the scrollbar thumb scrolled
to Credits/Quit; the Credits tap and final text were verified in the actual
Simulator window. Final survival start, movement input, and pause were also
repeated after the refreshed export.

The computer-use Simulator drag still activated the starting button after the
fix. The iOS engine reports touchscreen support and has no Simulator-specific
scroll restriction. The result is consistent with a missing motion event, but
does not establish its cause. Real menu swipe scrolling remains unverified;
scrollbar-track navigation is verified. Multi-touch pinch also remains unverified.

## Performance

Simulation-only profile (`make godot-profile`): all original levels use
60 warmup ticks and 180 measured ticks. Normal-level medians were
0.010–0.127 ms. Busy workload: 200 enemies, 30 towers, 2 players, 600 measured
60 Hz steps with health raised to retain the population and 95 peak shots.
Final measured median **4.131 ms**, p95 **5.230 ms**, maximum **6.241 ms**.

The measured bottleneck was repeated combat-side and projectile-owner scans.
Indexing those existing relationships reduced the same workload from
9.291 ms median / 12.440 ms p95. No Swift frame-time comparison is claimed.

Final rendered profile (`make godot-profile-rendered`) exercised the complete
GameApp frame path on the same Apple M4 Pro, arm64 macOS, using the OpenGL/Metal
Compatibility renderer. The survival scene retained **232 actors**: 200 enemies
(50 of each kind), 30 towers (10 of each kind), and two players. Health was raised
to preserve that population; waves and fog were disabled, audio was muted, and
camera zoom was 0.55. After 60 warmup draw frames, the run measured 600 draw frames
and 600 physics ticks, covering 10.000 seconds of game time. The frame cap and
physics rate were 60 Hz, VSync was disabled, and the display reported 100 Hz.

| Rendered measurement | Median | p95 | Maximum |
| --- | ---: | ---: | ---: |
| Wall frame interval | 17.758 ms | 20.278 ms | 35.490 ms |
| Engine-reported process time | 11.598 ms | 14.827 ms | 19.626 ms |
| Engine-reported physics process time | 7.077 ms | 10.082 ms | 77.379 ms |

Mean wall frame interval was 16.669 ms. These results show variable frame pacing,
not a guarantee that every frame meets the 16.667 ms budget. Engine performance
monitors and wall intervals are different measurements; the process and physics
rows must not be added together or treated as matching per-frame samples. The
recorded physics maximum remains a measured spike, without an attributed cause.

The run recorded peaks of 128 projectiles, 805 draw calls, 2,876 rendered objects,
and 517 nodes. The logical viewport was 1280×800; the captured render target was
1708×1067 and the final reported window size was 1708×1361. All 232 actor views
remained present and the game stayed in `playing` state. A viewport PNG was saved.
The raw measurements and exact setup are in ignored local artifacts
`test-artifacts/godot-rendered-profile/rendered-profile.json` and
`test-artifacts/godot-rendered-profile-final.log`; the image is
`test-artifacts/godot-rendered-profile/rendered-profile.png`. No iOS performance
measurement or Swift rendered-frame comparison is claimed.

## Exports and unresolved gates

macOS release and debug exports passed with the official version-matched template;
the debug app was launched and exercised. iOS Xcode export, unsigned Intel
Simulator compilation, and unsigned ARM64 device compilation passed. The official
template's Simulator binary is Intel-only despite its advertised ARM64 entry,
so that binary cannot install on the available ARM64 iOS 26.5 Simulator.

A matching ARM64 debug Simulator library was built from official 4.7.2 source
and combined with the original Intel library in a separate local template copy.
The corrected unsigned ARM64 Simulator build compiled, installed, launched, and
passed the real-touch checks above. Device and release libraries were unchanged.
Both platforms use `dev.ruarfff.nathaniel.godot`, separate from the Swift app.
Final local artifacts are `godot/exports/macos/NathanielGodot.app` and
`godot/exports/ios/NathanielGodot.xcodeproj`; templates and build provenance are
in ignored `test-artifacts/godot/export-templates/`.

The final macOS release, macOS debug, and iOS PCKs were inspected to confirm the
same latest UI tokens and the native effects scene. Final test logs, export
audit, and successful ARM64 Simulator build log are preserved under ignored
`test-artifacts/godot/final-validation/`. No generated export or engine template
is added to source control.

Signing, App Store distribution, notarization, and physical device input are
not established by unsigned/local builds. No credentials or real save files were
used during these checks. See [content authoring](godot-authoring.md) for the
precise template and platform commands. Physical-device touch, audible output,
and iOS performance remain release acceptance checks. Retirement of the Swift
app is a separate decision; this task preserves it and its build commands.
