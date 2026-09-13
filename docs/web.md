# Browser version

The Web preset exports the same game, scenes, and GDScript used by the native
apps. It uses the existing Compatibility renderer (WebGL 2.0), a single-thread
WebAssembly runtime, and Godot's standard HTML shell. No game server is needed.

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
static site. Keep their names and relative paths together. Opening `index.html`
as a local file does not work; it must be served over HTTP or HTTPS.

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
- Browser tabs can suspend game processing while hidden. Mobile browsers need
  separate input and performance checks; native iOS acceptance does not prove
  browser acceptance. The current layout checks the native `mobile` feature,
  which is false in web exports; phone browsers currently get desktop control
  sizes. A mobile browser pass must handle `web_ios` and `web_android` as well.

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
for browser restrictions. Local results are recorded in
[verification](verification.md).
