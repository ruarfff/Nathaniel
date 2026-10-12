# Browser version

The Web preset exports the same game, scenes, and GDScript used by the native
apps. It uses the existing Compatibility renderer (WebGL 2.0), a single-thread
WebAssembly runtime, and Godot's standard HTML shell. No game server is needed.

## Survival demo

The `Web Demo` preset offers Survival only. Its main menu says
`DEMO MODE · SURVIVAL ONLY`; the gameplay HUD and pause menu also identify the
demo. Settings, Survival save/load, and retry remain available. Campaign menus,
campaign loads, and Swift-save import are unavailable. Campaign level scenes
are excluded from the demo pack.

```sh
rtk make                  # Run demo mode with the local Godot editor binary
rtk make test-demo        # Check demo startup, access rules, and saves
rtk make export-web-demo  # Build exports/web-demo/index.html and companion files
rtk make serve-web-demo   # Preview at http://127.0.0.1:8060/
```

The export helper also accepts `Web --release --demo`. In the Godot editor,
select `Web Demo` in the export dialog. The preset supplies the `demo`
[custom feature tag](https://docs.godotengine.org/en/stable/tutorials/export/feature_tags.html#custom-features),
which applies to exported builds. Local editor runs use the `--demo` user
argument, as `make` and `make demo` do. Use `make run` to launch the full game.
The regular `Web`, macOS, and iOS presets still provide the full game.

Demo saves, settings, and records use `user://demo/`. An explicit
`--storage-dir=PATH` uses `PATH/demo/`. The full game's storage identity and save
format stay unchanged. A campaign save copied into demo storage is rejected
without replacing the current session.

Use the [Railway deployment setup](railway.md) for a tested Docker image and
GitHub workflow based on the CorpWorld deployment.

Deploy the complete `exports/web-demo/` directory when hosting is ready. It has
the same static hosting requirements as the full web build below. This command
prepares local files and does not publish them.

## Run locally

Use Godot 4.7.2 stable and its matching export templates. The export helper
looks in `test-artifacts/export-templates/` and the standard installed template
directory. Set `GODOT_TEMPLATE_DIR` for another location. Web exports need
`web_nothreads_release.zip`; debug exports need `web_nothreads_debug.zip`.
The [official release archive](https://godotengine.org/download/archive/4.7.2-stable/)
contains both in its export-template download. Keep local copies outside source
control; the helper does not install or download tools.

```sh
make export-web
make serve-web
```

Open <http://127.0.0.1:8060/>. The server binds only to the local computer and
serves `exports/web/`. Stop it with Ctrl+C. Use `WEB_PORT=8061` to select another
port. Rebuild with `make export-web` after changing the game, then reload the
page. `make clean` removes generated web exports as well as native exports.

The HTML, JavaScript, WebAssembly, pack, and icons in `exports/web/` form the
static site. The pack name includes a content hash, such as
`index-0123456789abcdef.pck`, so a changed export cannot reuse an old cached game.
The export updates the HTML reference and removes older generated packs. Keep
these names and relative paths together. Opening `index.html` as a local file
does not work; it must be served over HTTP or HTTPS.

## Browser behavior

- Click the game to give it keyboard focus. Existing mouse, keyboard, and HUD
  controls apply. Browsers can require an initial click before audio starts.
- The browser menu omits Quit; close the tab to leave the game.
- Saves, settings, and campaign progress use the browser's IndexedDB-backed
  `user://` storage. They are separate from native app saves and belong to the
  site's origin. Keep the scheme, host, and port stable to retain access to them.
  Clearing site data removes them; blocked storage or private browsing can
  prevent durable persistence. These saves are local, with no account sync.
- The native debug HTTP/MCP server cannot run in a browser because it requires
  a TCP listener. Swift-save import remains a native command-line workflow;
  browser file upload and save download are not implemented.
- Browser tabs can suspend game processing while hidden. Mobile browsers use
  the touch layout through `web_ios` and `web_android`, as native apps do through
  `mobile`. Mobile browser input and performance still need separate checks;
  native iOS acceptance does not prove browser acceptance.

## Character controls

Nathaniel is always the controlled character. His card focuses the camera on
him and closes Build. Hermes's card focuses Hermes and opens Build; repeated
clicks keep it open. The target portrait is part of the same button. Card taps
do not issue gameplay orders.
The friendly face stays visible; an off-screen arrow points to that friendly
unit. Hidden enemy targets use “Out of sight” with no enemy image or health.
The target portrait remains the main cue. Visible enemies have a subtle amber
body tint for Nathaniel's target or cyan for Hermes's, with matching HUD
crosshairs. A shared target blends both tints. Each character's tint clears on
retarget, death, or fog. Enemy targeting uses no ring, letter, or click pulse.

Tap Nathaniel in the world to focus him and close Build; he has no tap ring.
Click away from Hermes's build ring to close it and return the camera and
manual controls to Nathaniel. The closing world click is consumed; the next
world click controls Nathaniel. Tapping Hermes in the world never selects him
or opens Build. With Build closed and cargo loaded, it orders delivery;
without cargo, it does nothing.

Taps act on release with no double-tap timer. Repeated taps keep the same
meaning. Drag, pinch, another control, pause, death, and scene changes cancel
a held world tap. Pressed feedback clears on release or cancellation.
If the world target changes under a stationary press, release cancels the tap.
Opening or closing Build preserves existing orders and automatic combat.

Hermes has six fixed positions: Gun, Laser, Heal, Research in Survival,
Pack up & move, and disabled Settings. Campaign keeps the fourth slot empty.
Tower slots show their cost and explain
insufficient matter. Select a tower to replace the ring with placement and a
Cancel button, then tap clear ground inside the amber range or drag the tower
there. A valid placement pays once, deploys Hermes, connects the tower, and
returns to Build with Hermes still framed so you can place another tower.
A rejected placement keeps the preview. Cancel or Escape returns to Build.
Tapping Nathaniel's card or body, or pressing Space, discards the preview and
closes Build; tapping Hermes's card returns to his build ring. Campaign backpack
upgrades remain in the command tray. Survival backpack upgrades use Research.

In Survival, tap tech to approach it. Nearby tech also collects automatically,
including with a full matter rack. The tech counter updates at pickup acceptance.
Tap the ready research center from either character focus to open Research;
this replaces an open build ring. Active tower placement keeps input priority.
The menu pauses all world activity. Select Nathaniel, Hermes, or Defenses, then
select a track and press Research to buy one rank with tech. Selecting a row
does not spend anything. Insufficient-tech and maximum-rank reasons stay visible.
On a narrow screen, Back or Escape first returns from details to the list.
Resume, or Back from the list, closes Research. Background taps are consumed.

Pack up & move shows the connected tower types, their counts, and the actual
refund before activation. Existing ground cables show the connections;
the control tooltip also lists individual IDs. Packing reclaims surviving
connected towers and refunds 25% of each paid cost, rounded down. Hermes then
follows Nathaniel; Build closes and the camera returns to Nathaniel. Mobile
Hermes keeps the same disabled position. His death
removes connected towers without a refund.

Nathaniel uses the named weapon controls in the command tray. He has no tap
ring. Settings in Hermes's ring remains a disabled placeholder; the pause menu
retains its existing settings screen.

Ground, enemy, fire, stop, weapon, and delivery commands control Nathaniel.
His manual controls are disabled while Build or tower placement is open.
S stops him; automatic combat continues. Right-click or F fires toward the
pointer. Fire, Stop, zoom, Pause and the named weapon controls retain touch
access. R retains the existing deploy/follow shortcut.
B opens or closes Hermes's commands; Space closes them and focuses Nathaniel.
Escape returns from placement to Build first, then closes commands, then pauses.
Focus changes use a 280 ms camera move with easing in and out. Closing Build
restores Nathaniel's manual controls immediately. Combat continues while a
ring is open.

## Hosting

Serve this directory from a static HTTPS host with the `.wasm` MIME type
`application/wasm`. Enable gzip or Brotli delivery for the `.wasm` and `.pck`
payloads. The local Python server is for development and does not compress
responses.

This preset disables threads, GDExtensions, and the progressive web app service
worker. It does not require COOP/COEP headers or a backend. Offline installation,
custom loading UI, cloud saves, and public deployment are outside this preview.

See Godot's [web export guide](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html)
and [Web preset options](https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformweb.html)
for browser restrictions.
