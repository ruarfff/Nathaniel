# Verification record

This file records completed checks by change and date. Use [testing](testing.md)
for current commands and [authoring](authoring.md#export-and-platform-checks)
for current platform requirements. Earlier results do not establish acceptance
of later code or assets.

Test host: Apple M4 Pro (12 CPU cores), arm64 macOS, Xcode 26.6 (17F113),
Godot 4.7.2 stable. Results are local measurements, not guarantees for other hardware.

## Hermes shoulder laser — 2026-10-04

Mobile Hermes uses a live shoulder pod with independent yaw and tilt. The amber
beam starts at its current muzzle and ends at the target's authored contact
height. A shared laser resource controls the beam and brief contact sparks.
Positive damage also emits a transient hit record, so bullets and lethal hits
can show compact impacts after an enemy view disappears. Damage, targeting,
range, cadence and saved state retain their existing rules.

The first tall support was rejected after visual inspection. The final angled
bracket sits on the reference shoulder and moves the upper pivot inward. The
saved mobile source retains its body geometry and walk actions. Blender checks
cover migration idempotence, preservation of an edited mesh, invalid rigs,
repeatable GLB output, and 10,368 padded head-clearance segments through walking
poses and close targets. The original deployed cannon source is unchanged.

`make test` passed the complete headless regression suite, Python tooling and
live MCP checks. Focused checks passed 45 laser assertions, 10 impact assertions,
1,035 headless Hermes assertions and 1,055 rendered Hermes assertions. Existing
weapon effects passed 73 checks, and healing passed 41 headless and 52 rendered
checks. The Hermes checks include eight body and aim directions, target distances
of 60, 90 and 180 world points, walking, pause, loading, deployment, death, and
projection at densities from 1 to 8.

Scripted captures of the actual Survival level were inspected at normal zoom
and in detail. They show a connected mobile beam, a close shot across the body,
walking fire, and the deployed cannon with its existing base and cables.
Regenerate them with `make art-hermes-laser` and `make art-hermes-base`.
The eight-direction model sheet is `test-artifacts/hermes-shoulder-angles.png`.
All capture scenes use isolated storage. These captures establish rendered
behavior, not real mouse or touch input.

After the final source export and import, `make test-hermes-base` passed again:
1,035 headless and 1,055 rendered actor checks, plus 28 headless and 32 rendered
base-effect checks. Animated art passed 1,111 checks. Formatting and diff
whitespace checks passed.

macOS release and unsigned iOS project exports passed. Real mouse and keyboard
input in the macOS release verified Nathaniel movement, Hermes following,
B opening Build, R deploying the cannon, R restoring the mobile form and closing
Build, and Escape opening Pause. A native screenshot showed the shoulder beam
connected to an enemy after the return to mobile form. This run used a separate
temporary storage directory and exited without engine or script errors.

iOS runtime and physical touch/pinch remain unverified. The available custom
Simulator template has 3D disabled. No performance measurements were taken.

## Hermes anchor base — 2026-10-03

Hermes now deploys as a stationary cannon when a tower is placed. New builds
must be inside his 240-point range. All towers depend on Hermes; Follow reclaims
them and refunds only paid owned costs, while his death removes them without a
refund. His live base retains the mobile model's head, intake and armour, with
folding limbs, four stabilizers and an independently aimed cannon. Ground cables
and the amber range use the same simulation state as construction.

`make test` passed, including 334 gameplay assertions, 102 weapon checks,
236 presentation checks, the save and live MCP suites, and the new Hermes
checks. The separate graphical suites passed 21 actor checks and 32 ground-effect
checks. These cover pose transitions, pause, saved deployed state, cannon aim,
muzzle/recoil, exact range projection, actor occlusion and cable cleanup.
Formatting and diff whitespace checks passed. Blender 5.2.2 LTS generated and
exported the saved `hermes_anchor.blend`; the existing mobile source was unchanged.

`make art-hermes-base` produced inspected mobile, deployed and reclaimed captures
in the actual Survival level. The deployed capture shows three linked towers and
Hermes firing from his barrel. These are scripted setups in isolated storage,
not real-input evidence. Images are under `test-artifacts/hermes-*-gameplay.png`.

macOS release, unsigned iOS project, and Web exports passed. The macOS release
opened, but native mouse control repeatedly failed with `noWindowsAvailable`;
a later native capture was blank. Native input acceptance is therefore unverified.
The isolated native test processes were closed after inspection.

Real mouse and keyboard input in the local browser verified Survival start,
B opening Build while Hermes followed, out-of-range rejection without charging,
valid placement and deployment, a visible ground link, Nathaniel movement while
Hermes stayed anchored, Space closing Build without reclaiming, and R reclaiming
the tower and restoring the mobile form. Resources changed 30 → 25 → 26.
The cable and range disappeared after Follow. Browser logs had no warnings or
errors. The test used port 18917 and a separate `user://playtests/` directory.

iOS runtime, physical touch/pinch, and performance were not tested. The available
custom Simulator template still has 3D disabled. Tower pedestal/head assembly
animation remains a visual follow-up; the current transition is Hermes's fold
plus brief transfer pulses, with immediate gameplay placement and reclamation.

## Repository gardening — 2026-10-03

Reviewed ten recent coding sessions, including three for Nathaniel. Repeated
broad source searches and reads of historical verification notes showed a need
for task-specific entry points. The README now maps tasks to source files and
focused Make checks. Authoring guides link to dated results here and state the
current live-model and Simulator requirements. No time saving was measured.

Removed unused capture scripts, the completed environment migration script,
an unused movement helper and actor ID field, and duplicate projectile syncing.
The rifle catalog now supplies starting weapon stats. Shared save validation
rejects invalid or duplicate object IDs before restoration changes active state.
Regression tests first reproduced two rifle-setting failures and 24 save-ID
failures, then passed after the fixes.

The final `make test` passed all suites, including 102 weapon-rule checks,
323 service checks, 311 gameplay assertions, 231 presentation checks, and
145 live MCP checks. `make format-check` and `git diff --check` passed. All
71 local documentation links and all task-map source paths resolved. Focused
Make recipes were checked against the same commands used by the full suite.

This gardening pass did not rerun graphical playtests or platform exports.
The preceding art and weapon verification below records those separate checks
and their remaining platform limits.

## Nathaniel's modular weapons — 2026-10-03

Nathaniel now starts with the rifle and can collect a heavy rifle near the start
of each level. Keys 1/2 and named buttons switch weapons in 0.35 seconds. The
simulation owns aim and firing readiness. The live model uses independent leg
motion, a stable upper-body aim, modular weapons and hand recoil. Bullets keep
their original weapon identity across a switch and save/load.

The final `make test` passed: 94 weapon-rule checks, 62 weapon-control checks,
48 character-model checks, 311 gameplay assertions, 191 service checks,
231 presentation checks, 145 live MCP checks, and all content, art, healing,
Python and MCP-adapter suites. The terrain migration check was updated to keep
its original level fingerprint separate from the newly authored pickups.
The graphical character suite passed 58 checks; turret and animation rendering
regressions also passed. Formatting and diff checks passed.

Blender 5.2.2 LTS and bundled Python 3.13.15 passed the full asset verifier.
The migration preserved all 67 original character mesh transforms. Saved mesh
and walk-keyframe edits reached the exports. Repeated PNG/GLB exports were
identical, source hashes stayed unchanged, and a second migration left existing
character and weapon sources unchanged. Invalid animated upper-body mounts and
weapons saved mid-recoil are rejected.

Actual 3840×2160 GameApp captures and a 4K forward/strafe/backpedal sheet were
inspected. They show both guns, barrel-tip flashes, clean transparency, ground
alignment and stable upper-body aim. Graphical assertions also check the
retained actor sorting, grip motion and pause/respawn behavior. Captures are
under `test-artifacts/nathaniel-*`; regenerate with `make art-nathaniel-weapons`
and `make test-nathaniel-weapons`.

macOS release, unsigned iOS project, and web exports passed. The macOS release
ran with isolated storage. Real mouse and keyboard input verified walking to a
crate, collection without automatic equip, key 2, the named rifle button, and
movement while aiming at enemies. The release exited without engine errors.
The local web release also ran: browser input collected the pickup and equipped
the heavy rifle; the live model and firing rendered without console errors.

iOS runtime, physical touch/pinch, physical 4K display acceptance and mobile
performance were not tested. The existing custom iOS Simulator template still
has 3D disabled, so it must be rebuilt with 3D support before this live model can
run there. No new full-game frame-time claim is made for this change.

## Healing tower range and shared healing — 2026-10-03

Each one-second healing tick now restores up to 5 HP to both Nathaniel and Hermes
when they are alive, injured, and inside the tower's actual range. Full-health,
dead, and out-of-range characters produce no healing event. Clicking a healing
tower shows a cyan outline projected from that same logical radius. Selection
does not change Nathaniel's orders or camera focus.

`make test` passed, including 311 gameplay assertions, 73 weapon-effect checks,
and 41 healing-tower checks. The graphical healing suite passed 52 checks,
including rendered light and range boundaries. It checks selection at 0.5x, 1x,
and 2x zoom, clearing and lifecycle cases, and both healing recipients. Formatting
and diff checks passed. `test-artifacts/healing-range-review.png` is a scripted
capture of the actual level with the selected tower's range.

macOS release and unsigned iOS project exports passed. Real mouse and keyboard
input in the macOS release build verified building a healing tower, selecting
its upper panels, and clearing the range with Escape without pausing. The build
ran with isolated storage and exited without engine errors. The iOS runtime,
touch, and pinch were not tested; the existing custom Simulator template's
missing 3D support remains the limitation recorded below.

## Live gun turret — 2026-10-03

The gun tower now uses an editable Blender model with a fixed pedestal, rotating
turret, sliding recoil, and barrel-tip marker. Its transparent Godot image uses
the existing 64×32 projection, ground anchor, and actor sorting. Shot events keep
the actual firing direction; the presentation captures each muzzle offset once.
Gameplay footprints, collision rules, and saved projectile fields stay unchanged.

`make test` passed, including 171 content checks, 296 gameplay assertions,
188 service checks, 231 presentation checks, 14 Python tests, six MCP adapter
tests, and 145 live MCP checks. It also passed the Blender/HD/animated/static/
terrain resource suites and the new turret and weapon-effect suites. After the
display-density fix, `make test-gun-turret` passed again: 61 headless turret
checks, 28 weapon-effect checks, and 73 graphical turret checks. Formatting and
diff checks passed.

`sh tools/blender.sh verify` passed with Blender 5.2.2 LTS and its bundled Python.
It covers saved manual edits, unchanged source hashes, invalid-rig rejection,
and identical PNG/GLB output from separate Blender processes. The source was
opened and inspected with Computer Use. Godot captures show the gun firing in
Level 2 and front/rear fixture views. Graphical assertions verify transparency,
overlap sorting, camera projection, and muzzle alignment. These are scripted
gameplay checks; real mouse/keyboard playtesting was not repeated for this change.

The first 4K window capture was clamped by macOS and is not acceptance evidence.
The final capture is an exact offscreen 3840×2160 image. A regression test checks
that 4K at close zoom selects a 768×768 model texture, resizes down correctly,
and keeps the same ground and muzzle anchors.

`make art-gun-turret` measured 30 visible, continuously turning towers with
staggered recoil and logical scale 2. Compatibility renderer, VSync off, no FPS
cap, 60 warmup frames, and 120 measured frames; no terrain or other units:

| Offscreen output | Median frame interval | p95 | Model render pixels |
| --- | ---: | ---: | ---: |
| 1280×800 | 12.82 ms | 17.50 ms | 1,966,080 |
| 3840×2160 | 13.43 ms | 17.51 ms | 17,694,720 |

The 4K renderer texture-memory monitor reported about 839 MiB for the process,
including retained resources from the earlier gameplay capture. It is not a
per-tower or total GPU-memory measurement. This workload does not establish
full-game 4K performance. Raw JSON and images are in `test-artifacts/gun-turret-*`.

macOS release, web, and iOS exports were not rerun. Physical 4K display acceptance,
mobile performance, and touch remain unverified. The earlier custom iOS Simulator
template below was built with `disable_3d=yes`; it must be replaced by a template
with 3D support before this live model can run there. Native lighting approximates
the Blender palette but does not match Cycles indirect light or soft shadows.

## Base Blender pipeline — 2026-10-03

Validated on macOS with Blender 5.2.2 LTS, its bundled Python 3.13.15, and Godot
4.7.2. `make test`, `make test-art`, and `make format-check` passed. The Godot
asset suite passed 25 structure/import checks and 29 checks with rendering;
pixel comparisons confirmed both front and behind occlusion. The PNG and
viewport capture confirmed scale, ground alignment, and transparency.

Opened the source through Computer Use in Blender, renamed the mesh to
`PlaceholderProp_HandEdited`, saved it, and re-exported it. The source hash
remained unchanged by rendering. The temporary Blender test also saved geometry
and material edits, then confirmed identical PNGs from two exports and retained
source contents. The existing-source and missing-executable errors were checked.

Computer Use could not attach to the unbundled Nix Godot executable. Godot visual
checks used its rendered viewport capture; the preview's physical Space-key
toggle was not verified. macOS/iOS application exports and device input were not
rerun for this isolated tooling change. Blender needs normal macOS access on
this host; command-sandbox startup crashed before the script ran.

Camera API reference: [Blender Camera](https://docs.blender.org/api/4.5/bpy.types.Camera.html).
The local projection assertions verify the installed Blender version directly.

## Environment assets — 2026-10-03

Verified with Blender 5.2.2 LTS, bundled Python 3.13.15, and Godot 4.7.2 on
Apple M4 Pro macOS. The complete game regression suite passed after the final
asset import. Environment checks passed 359 headless and 389 rendered assertions.
They compare exact level data, all 119 original scenery origins, the 12 prop
exports, and terrain minification from 0.5 through 5.4 screen pixels per world
pixel, including subpixel camera movement. Rendered checks also compare colors
at tile edges and interiors to detect dark mipmap joins.

Repeated terrain exports produced identical atlas PNG bytes and left the source
unchanged. Tests also saved material edits and viewport visibility choices,
re-exported twice, and confirmed both remained in the source. All 13 environment
export records match their saved Blender source hashes.

The building gallery, four native-level sections, and scripted GameApp garage
capture were inspected. The house source was opened through Computer Use in
Blender. The GameApp capture used temporary storage and reported about 722 MiB
of renderer texture memory; that value is not total GPU memory or a frame-rate
measurement. Physical 4K hardware, real player input, mobile performance, and
platform exports were not tested for this art pass.

## Iron & Ink sprite batches — 2026-10-03

Verified locally on 2026-10-03 with Blender 5.2.2 LTS, its bundled Python 3.13.15,
and Godot 4.7.2 on Apple M4 Pro macOS. The full `make test` suite passed. The final
focused runs passed `test-art`, 68 headless HD checks, 74 rendered HD checks, and
format checks. Repeated exports at densities 1 and 8 produced identical PNG bytes
and preserved saved source edits. Exported PNGs omit timestamps, render timings,
and local source paths; the JSON records retain version and hash provenance.

The comparison board, native 3840×2160 asset capture, and a scripted GameApp
capture were inspected for scale, ground alignment, alpha edges, and sorting.
These checks did not test real player input, physical 4K display performance,
or mobile rendering. Platform exports were not rerun for this asset batch.

For the animated batch, the final full `make test` passed: 171 content checks,
25 original pipeline checks, 50 HD checks, 1,111 animation checks, 39 static-art
checks, 272 gameplay assertions, 188 service checks, 231 presentation checks,
14 Python tests, six MCP adapter tests, and 145 live MCP checks. Separate final
graphical runs passed 29 original pipeline checks, 56 HD checks, 1,121 animation
checks, and 42 static-art checks. Formatting and whitespace checks passed.

The Blender checks also verify exact RGBA preservation, a shifted pose's atlas
region and margins against its original render, repeat-export byte identity,
saved keyframe preservation, and clear errors for unsupported clip loops or
geometry outside the facing root. All seven new export records match their
saved Blender source hashes. The in-game capture uses scripted placement and
temporary storage; it does not establish real-input or platform acceptance.

## Controls cleanup review — 2026-09-15

Reviewed the pending controls, feedback, domain/save, and export/debug changes
with the ponytail skill. Removed unused HUD state, redundant child visibility
and placement resets, and reused the existing clock formatter. World clicks
now share the paused/result/living-player guard. Two regression checks failed
before this fix because paused movement and delivery still showed acceptance
feedback without a modal; both pass after the fix.

`make test` passed cleanly: 14 Python tests, 171 content checks, 272 gameplay
assertions, 188 service checks, 231 presentation checks, six MCP adapter tests,
and 145 live MCP checks. Formatting and diff checks passed. An earlier focused
presentation run passed assertions but hit the previously recorded engine
resource-cleanup error at exit; the final full run did not reproduce it.

`make export-web` passed. Real browser mouse and keyboard input at 1280×720
verified Survival, B Build, gun-tower drag, R Follow/refund (30→25→26), and
Escape pause. No browser warnings or errors were captured. The preview server
was restarted after confirming port 8060 was free; isolated storage was kept.
Native exports and touch were not rerun for this presentation cleanup.

One pre-existing rendering issue remains outside the pending changes:
`WorldEffects._draw()` always checks fog visibility for corpses, projectiles,
and laser beams, even when the fog display setting is disabled. The new target
markers already honor that setting. This was identified by code review only.

## Hermes follows on level start — 2026-09-14

Fresh levels and restarts now start Hermes following Nathaniel. Saved modes
and the legacy missing-mode fallback remain unchanged. Gameplay passed 272
assertions, presentation passed 229 checks, and services passed 188 checks with
temporary storage and normal system access. Coverage includes all six level
starts, follow movement, restart, and stopped/following save restoration.
Formatting and diff whitespace checks passed. The initial sandboxed gameplay
run passed assertions but failed on log/certificate access; the normal-access
rerun exited cleanly.

`make export-web` passed. The refreshed browser showed Following immediately
after real mouse starts of campaign and survival, and R changed it to Stopped.
The existing server and isolated preview storage were reused. Native exports,
native input, touch, and the full suite were not rerun for this default change.

## Hermes Build controls — 2026-09-14

Hermes is no longer selectable. Build opens the tower tray and focuses the
camera on Hermes without changing his movement mode. A valid placement stops
him; invalid placement preserves his mode. Build stays open for more towers.
Space or Close Build returns to Nathaniel. Follow closes Build, removes towers,
and applies the existing refund. Old saves retain their format and Hermes mode;
saved Hermes camera focus reopens Build.

The suites passed 171 content checks, 267 gameplay assertions, 188 service
checks, 14 Python tests, six MCP adapter tests, and 145 live MCP checks.
The final presentation suite passed 223 checks with temporary storage.
An initial live check found a one-frame stale Build tray after Follow; the
controller now refreshes it immediately. One earlier presentation run passed
assertions but logged an engine resource-cleanup error at exit; separate
reruns exited cleanly. Its cause remains unconfirmed.

Web, macOS, and iOS exports passed with normal system access. Real browser
mouse and keyboard input verified Build while following, blocked placement,
click and drag placement, retained Build after placement, Space, and R Follow.
The final web and macOS reruns both verified B, tower drag, and R with resources
30→25→26. Both showed the updated Follow notice. The macOS app exited cleanly;
the browser reported no warnings or errors. All playtests used isolated saves.
The existing web server was reused and the main preview was refreshed.

The ARM64 iOS Simulator Debug build ran on iPhone 17 Pro / iOS 26.5. Debug
commands and viewport images verified Build, placement, and Follow/refund.
Mouse polling in game scripts was replaced with cached mouse/touch event
positions, covered by regression tests. One unsupported `mouse_get_position()`
engine error still occurred at Simulator startup; no script errors or repeated
engine errors appeared during the checks. The remaining caller is unknown.
Real touch, pinch, mobile browser input, and physical devices were not tested.

## Combat target feedback — 2026-09-14

The native presentation suite passed 198 checks and the content suite passed
171 checks with normal system access and temporary storage. New coverage
includes accepted/rejected target clicks, pulse expiry, selected/automatic
targets, range, health, fog, dead/removed targets, shared markers, HUD input
capture, and layout at 960×540. Formatting and diff whitespace checks passed.

`make export-web` passed. In the rebuilt browser at 1280×720, real mouse and
keyboard input verified click pulses, separate and shared N/H target markers,
live health readouts, Selected/Auto labels, and Space camera switching after
HUD input. Clicking an enemy with Hermes focused still commanded Nathaniel
and retained Hermes's automatic target. The browser reported no warnings or
errors. Setup used a disposable save with stationary harmless enemies, loaded
through the visible menu. The existing server and preview storage were reused.

Native exports, physical touch, mobile browser input, and the full suite were
not rerun for this presentation-only change. Mobile layout has automated
coverage; this does not establish touch behavior.

## Resource delivery feedback — 2026-09-14

The presentation suite passed 175 checks with temporary storage and normal
system access. Ten new checks cover delivery acknowledgement, retained focus,
pending resource credit, pulse restart/expiry, pause, and ordinary Hermes
selection. Formatting passed. An initial sandboxed run passed assertions but
failed on certificate/log access and engine cleanup; the normal-access run
exited cleanly.

`make export-web` passed. A temporary save with Nathaniel carrying resources
was loaded through the browser menu at 1280×720. A real mouse click on stopped
Hermes showed a cyan pulse and the delivery message, kept Nathaniel selected,
and sent him to Hermes. Resources changed from 30 to 40 on arrival. The pulse
expired. This used a separate temporary browser filesystem; existing saves
were preserved. Native exports, touch, and the full suite were not rerun for
this presentation-only change.

## Character controls — 2026-09-14

This run used the same Apple M4 Pro host, Godot 4.7.2, and Xcode 27.0
(27A266a). `make test` passed: 171 content checks, 237 gameplay assertions,
188 storage/HTTP checks, 165 presentation checks, 14 Python tests, six MCP
adapter tests, and 133 live MCP checks. Formatting and diff whitespace checks
passed. New regressions cover small destination corrections, blocked movement,
keyboard press/release after HUD clicks, tower cancellation/retry, HUD input
capture, pinch-start cancellation, and debug input parity.

An initial uncapped presentation run passed its assertions but failed at audio
resource cleanup. Separate uncapped reruns did not reproduce it. The suite now
uses the previously verified 60 FPS timing limit; the final full run exited
cleanly. This does not establish the cause of the intermittent engine cleanup
error or change production audio behavior.

`make export-web` passed with normal macOS service access. Real mouse and
keyboard input in the Codex browser at 1280×800 verified HUD selection, Space
switching after a character click, terrain commands while Hermes has camera
focus, enemy targeting with Hermes focused, valid/blocked destination feedback,
S stop, R follow, Stop + Build,
tower drag placement, HUD drop rejection, blocked-drop retry, and Escape
pause/resume. Two gun towers changed resources 30→25→20; Follow removed them
and refunded two resources, reaching 22. Wheel zoom retained usable HUD input.
Terrain, characters, combat, placement previews, and selection states rendered.
Saving slot 1 in the isolated browser directory, refreshing, and loading it
restored 30 resources, Hermes camera focus, and Following mode. This checks a
normal reload, not immediate durable writes or browser-restart persistence.

The browser initially retained the old PCK despite refreshing the newly
exported HTML. Package inspection confirmed the export contained current code.
Web exports now give the PCK a content-hashed filename and update the shell's
`mainPack` reference. A normal refresh then loaded the current HUD. The existing
server on port 8060 was reused. The generated preview shell uses an isolated
`user://playtests/controls-01a0a275` storage directory; a new export restores the
standard shell arguments. Early checks used a disposable browser `/tmp` path.

`make export-macos` and `make export-ios` passed. The macOS release ran with
temporary storage and real mouse/keyboard input: Survival, HUD selection,
Space, movement, S stop, R follow, Stop + Build, tower drag, refund 30→25→26,
and Escape pause. It exited successfully. The ARM64 Simulator Debug build
passed and ran on iPhone 17 Pro / iOS 26.5 with a fresh container temporary
directory. Debug setup and viewport PNGs established native mobile rendering;
they are not real touch checks. Simulator could not be selected by the
available computer-input tool in this run.

Real touch, pinch, mobile browser input, physical-device behavior, audio output,
and performance were not verified in this run. Touch cancellation has synthetic
event coverage only. Simulator images are in ignored `test-artifacts/controls/`.

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
