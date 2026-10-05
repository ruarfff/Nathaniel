# Railway demo deployment

Railway hosts one static web service for the Survival demo. The browser runs
the game. The runtime needs no game server, database, or volume.

## Current deployment

The public demo is [nathaniel-demo-production.up.railway.app](https://nathaniel-demo-production.up.railway.app/).
It runs as `nathaniel-demo` in the `Nathaniel` project's `production` environment.
The first release was uploaded from the local checkout with the Railway CLI.
GitHub autodeploy now follows `ruarfff/Nathaniel` on `main`, with **Wait for CI**
enabled. Push changes to `main` for the normal release flow.

To deploy a later local change, reuse this service:

```sh
rtk railway link --project fc4bf1de-8b57-43bb-b4d0-50a21ebf6dce --environment production --service nathaniel-demo
rtk railway up --service nathaniel-demo --environment production --detach
```

Check the deployment status before running
`rtk python3 tools/check_web.py https://nathaniel-demo-production.up.railway.app`.

## Build and check the image

```sh
rtk make image-demo
rtk docker run --rm --name nathaniel-demo -e PORT=8090 -p 127.0.0.1:8090:8090 nathaniel-demo:local
```

Open <http://127.0.0.1:8090/>. In another terminal, check the HTTP contract:

```sh
rtk python3 tools/check_web.py http://127.0.0.1:8090
```

The Docker build uses Godot 4.7.2 and verifies the official Linux editor and
template downloads by SHA-256. AMD64 and ARM64 builds are supported. It runs
`make test` before exporting the `Web Demo` preset. A failed check or export
fails the image build. Editable Blender sources are present for the native
content checks; Blender itself is not required.

The runtime contains Caddy and the files from `exports/web-demo/`. It listens
on Railway's `PORT` on all interfaces. Railway provides public HTTPS. Caddy
serves `/healthz`, the correct WebAssembly MIME type, gzip/zstd compression
for both WebAssembly and the game pack, and cache revalidation. Missing assets
return 404. Source files, tests, and build logs are absent from the runtime.

## Create the Railway service

Use a workspace with capacity for a project and service. These commands create
and link a dedicated Nathaniel deployment:

```sh
rtk railway init --name Nathaniel --workspace WORKSPACE_ID --json
rtk railway add --service nathaniel-demo --json
rtk railway link --project PROJECT_ID --environment production --service nathaniel-demo
rtk railway api --file web/railway-service.graphql --raw-var serviceId=SERVICE_ID --raw-var environmentId=ENVIRONMENT_ID
rtk railway up --service nathaniel-demo --environment production --detach
rtk railway domain --service nathaniel-demo --port 8080 --json
```

Replace IDs with the values returned by Railway. Check the linked project
before deploying. The API document sets Docker builds, a `/healthz` healthcheck
with a 60-second timeout, and restart on failure. Build and start commands
come from the image. This uses service settings rather than the deprecated
`railway.json` / `railway.toml` format.

`railway up` uploads the local source, including uncommitted files. It does
not connect GitHub autodeploy. Check the build and deployment status, then run
`tools/check_web.py` against the public HTTPS URL. A successful upload alone
does not establish a healthy deployment.

## GitHub autodeploy

The existing service is already connected. For a new service, connect the
source after the demo and deployment files are present on `main`:

```sh
rtk railway service source connect --repo ruarfff/Nathaniel --branch main --service nathaniel-demo
```

Enable **Wait for CI** in Railway's source settings. The prepared GitHub
workflow `.github/workflows/web-demo.yml` builds the image and checks its HTTP
server on pushes to `main`, pull requests, and manual runs. It needs no Railway
token. Railway's Docker build repeats the game checks before serving a release.

The CLI can also enable this setting for the service's deployment trigger:

```sh
rtk railway api --file web/railway-autodeploy.graphql --raw-var triggerId=TRIGGER_ID
```

Use the trigger ID for the intended service, environment, and branch. The
current production trigger is `96098f40-0c2a-440c-9f4b-519f180e8445`.

If Railway cannot list the repository, grant its GitHub app access to
`ruarfff/Nathaniel`. A free-plan provisioning error must be resolved in the
workspace before creating the deployment. Do not remove other projects or
upgrade billing as part of a deployment command.

## References

- [Railway Docker builds](https://docs.railway.com/builds/dockerfiles)
- [Railway healthchecks](https://docs.railway.com/deployments/healthchecks)
- [Railway GitHub autodeploy](https://docs.railway.com/deployments/github-autodeploys)
- [Railway Infrastructure as Code and legacy configuration](https://docs.railway.com/infrastructure-as-code)
- [Caddy response compression](https://caddyserver.com/docs/caddyfile/directives/encode)
