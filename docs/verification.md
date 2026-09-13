# Verification record

Test host: Apple M4 Pro (12 CPU cores), arm64 macOS, Xcode 26.6 (17F113),
Godot 4.7.2 stable. Results are local measurements, not guarantees for other hardware.

## Desktop browser preview — 2026-09-13

`make export-web` passed with the matching official single-thread release
template. An initial sandboxed attempt reported denial of the macOS certificate
service; the export passed with normal system access. `make serve-web` serves
only the generated site at `http://127.0.0.1:8060/`. Local socket binding also
required normal system access on this host.

In the Codex in-app browser at 1280×720, real computer input verified Survival
start, terrain movement, Space focus, R follow, Escape pause/resume, and wheel
zoom. A gun-tower drag changed resources from 30 to 25; follow removed it and
refunded one resource (26). Terrain, actors, combat, fog, and the HUD rendered.
The main menu omitted Quit. The browser console capture reported no warnings
or errors during this session.

All three slots were initially empty in the new localhost browser origin.
Saving slot 1, reloading the page, and loading slot 1 retained the saved Survival
state, 30 resources, Hermes focus, and Following mode. This test used browser
storage separate from native user files. It establishes normal same-origin
reload persistence, not immediate durable writes, private-mode support, or
browser-restart persistence.

The static payload has nine files totaling 52,225,759 bytes (52.2 MB decimal).
Compressing each file with Python gzip totals 21,054,414 bytes (21.1 MB); this is
an offline size measurement, not a measured network transfer or load time. The
local server does not enable response compression. The PCK has 464 entries and
excludes repository tooling, tests, dependencies, and artifacts. Its generated
HTML disables threads and requires no cross-origin isolation headers.

All 11 Python tooling tests, formatting, and diff whitespace checks passed.
The native presentation suite passed 135 checks with a 60 FPS cap. An initial
uncapped run passed its assertions but failed teardown with an audio resource
leak; that first run was not clean. Native macOS/iOS exports and the full native
suite were not rerun for these export and web-only guard changes.

Screenshot and payload hashes are in ignored `test-artifacts/web-preview/`;
export logs are `exports/web-export.log` and `exports/web-export.stdout.log`.
Template hashes are in `test-artifacts/export-templates/MANIFEST.json`.

This is a desktop feasibility preview. Other browsers, mobile browser layout
and touch, audible playback, performance/load-time profiling, blocked storage,
offline operation, and public hosting remain unverified. Phone browsers still
use desktop control sizing; see [browser behavior and hosting](web.md).

## Root project cleanup

The active project is at the repository root. Swift/SpriteKit, Windows Phone,
and source-map conversion are retired. Native save formats, slot filenames,
and app storage identifiers are preserved; explicit Swift-save import remains.

The root project passed `make test`: 171 native content checks, 229 gameplay
assertions, 188 storage/HTTP checks, 135 presentation checks, 133 live MCP checks,
eight Python tests, and six MCP adapter tests. Formatting, hook configuration,
resource paths and documentation links passed. A separate audit confirmed that
all 170 copied asset files retain their original bytes. Direct level-scene launch
and actual CLI Swift-save import passed after the move, including source-file
preservation and correct level/slot restoration.

`make export-macos` and `make export-ios` passed. The unsigned ARM64 Simulator
Xcode build passed. Both packages contain only game resources and runtime script
paths; tools, tests, MCP dependencies, artifacts and retired code are excluded.
The macOS release received a real Survival click, Space focus, R follow and Escape
pause; the resulting HUD and menu were inspected. On iPhone 17 Pro / iOS 26.5,
real taps started Survival, moved Nathaniel, selected Hermes and paused. State
and rendered viewport PNGs confirmed those results. These are smoke checks;
the older comprehensive playtest and its limits are separate below.

Initial export attempts encountered sandbox denial of macOS certificate services;
reruns with normal system access passed. Initial app launches omitted Godot's
`--` user-argument separator; the smoke checks were repeated with explicit isolated
storage. Those first launches performed no save/load operation or settings change.
Simulator window capture remained intermittently blank; resizing restored one
native view, while the final viewport PNGs and state were captured through the
read-only debug interface. Failed window-target attempts are not counted as input.

Current logs, Simulator screenshots/state, and package inventories/hashes are in
ignored `test-artifacts/cleanup/`. Focused direct-scene and CLI-import logs are
`test-artifacts/runtime-reorganization-*.log`. Performance, device signing and
multi-touch acceptance were not rerun for this structural cleanup.

## Prior verification

The [full record at commit 824c8f1](https://github.com/ruarfff/Nathaniel/blob/824c8f1/docs/godot-verification.md)
contains the retired app baseline, migration tests, platform logs, and detailed
input results. Prior native content, gameplay, persistence, UI, and live MCP
checks passed. The removed converter tests are historical, not current coverage.

Real computer input verified these controls before the root move:

| Platform | Verified input and result |
| --- | --- |
| macOS debug export | Ground movement; Space focus; R follow; Hermes Stop; Escape pause/resume; wheel zoom 1.0→1.1; gun-tower drag 30→25 resources; follow dismantling/refund 25→26 |
| ARM64 iPhone 17 Pro / iOS 26.5 Simulator | Survival start; terrain movement; Hermes focus/build; tower placement and rejection; follow/refund; zoom button; pause/settings/back/exit; isolated slot 1 save/load; scrollbar-track navigation and Credits tap |

All three save slots have native automated coverage; the real iOS save/load
check used slot 1. Rendered scenes showed combat, fog, upright scenery, actor
feet, HUD, and mobile menu layouts. Tests used isolated storage, not real saves.
Native-window captures were intermittently blank while viewport PNGs remained
correct; reselecting or fitting the window restored computer-use captures.

The menu swipe test found buttons blocking drag propagation. Menu buttons and
settings toggles now pass events to ScrollContainer. A native event regression
verifies scroll start, offset change, cancelled activation, and ordinary taps.
The final Simulator drag still activated its starting button. This is consistent
with missing motion, but does not prove the cause. Real menu swipe scrolling
and multi-touch pinch remain unverified; scrollbar-track navigation is verified.

## Prior performance

Simulation workload: 200 enemies, 30 towers, two players, health raised to retain
the population, 600 measured 60 Hz steps. Median **4.131 ms**, p95 **5.230 ms**,
maximum **6.241 ms**. Indexing repeated combat/owner scans reduced the earlier
9.291 ms median / 12.440 ms p95. No Swift frame-time comparison is claimed.

Rendered workload: the same 232 actors on survival, fog/waves off, audio muted,
zoom 0.55; 60 warmup draw frames, then 600 draw frames and 600 physics ticks.
Frame cap and physics rate were 60 Hz, VSync off, display reported 100 Hz.
The renderer was OpenGL/Metal Compatibility on the host above.

| Measurement | Median | p95 | Maximum |
| --- | ---: | ---: | ---: |
| Wall frame interval | 17.758 ms | 20.278 ms | 35.490 ms |
| Engine process time | 11.598 ms | 14.827 ms | 19.626 ms |
| Engine physics process time | 7.077 ms | 10.082 ms | 77.379 ms |

Mean wall interval was 16.669 ms. Frame pacing varied; constant 60 FPS is not
established. Engine monitor values are not additive wall-frame samples. The
physics maximum remains an unattributed spike. Peaks: 128 projectiles, 805 draw
calls, 2,876 rendered objects, 517 nodes. The logical viewport was 1280×800;
capture was 1708×1067. The game retained all actors and stayed in `playing` state.

Raw historical results and image remain under ignored
`test-artifacts/godot-rendered-profile/`; the run log is
`test-artifacts/godot-rendered-profile-final.log`. These names reflect the older
layout. No iOS performance measurement is claimed.

## Export provenance and remaining acceptance

Prior macOS release/debug exports passed, with a debug launch and real input.
iOS project export and unsigned Intel Simulator/ARM64 device builds passed.
The official template lacked its advertised ARM64 Simulator binary; its Intel
build could not install on the available runtime. A separate template copy
added an ARM64 debug library from official 4.7.2 source, then compiled, installed,
launched and passed the Simulator checks above. Device/release libraries stayed intact.

The corrected templates and `MANIFEST.json` are in ignored
`test-artifacts/export-templates/`. The manifest records source/archive hashes,
build flags, and output hashes. The official template archive SHA-256 is
`f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011`.
The source archive SHA-256 is
`e954996374cbd1cb5d72e0e3781cc537408e6ce73b010b12c6c2f308a820690a`.

The source is the [4.7.2-stable tag](https://github.com/godotengine/godot/tree/4.7.2-stable).
Build with `scons platform=ios arch=arm64 simulator=yes target=template_debug
debug_symbols=no optimize=none disable_3d=yes vulkan=no metal=no
module_csg_enabled=no module_gltf_enabled=no module_gridmap_enabled=no
module_openxr_enabled=no -j12`. Combine its ARM64 library with the original Intel
library using `lipo -create`; replace only the debug Simulator library in a copy
of `ios.zip`. The managed engine installation and original archive stay intact.

Retirement does not resolve release acceptance: physical-device touch, real menu
swipe, pinch, audible output, iOS performance, signing, App Store distribution,
and notarization remain unverified. Unsigned builds do not establish these results.
