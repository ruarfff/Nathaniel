FROM debian:bookworm-slim AS builder

ARG TARGETARCH
ENV GODOT_VERSION=4.7.2
ENV GODOT_SILENCE_ROOT_WARNING=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip make python3 nodejs npm libfontconfig1 libx11-6 \
    libxcursor1 libxinerama1 libxi6 libxrandr2 libgl1 libasound2 libpulse0 \
    && rm -rf /var/lib/apt/lists/*

# Use the same verified Godot release for the editor and web templates.
RUN set -eu; \
    case "$TARGETARCH" in \
      amd64) godot_arch=x86_64; editor_sha=cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4 ;; \
      arm64) godot_arch=arm64; editor_sha=5dd0d86405cf7e8adf79fb6377b38ba682a2846cb378ffe5364f38c01ad29b9d ;; \
      *) echo "Unsupported build architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    release_url="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable"; \
    curl -fL --retry 3 "$release_url/Godot_v${GODOT_VERSION}-stable_linux.${godot_arch}.zip" -o /tmp/editor.zip; \
    echo "$editor_sha  /tmp/editor.zip" | sha256sum -c -; \
    unzip -q /tmp/editor.zip -d /tmp/editor; \
    mv "/tmp/editor/Godot_v${GODOT_VERSION}-stable_linux.${godot_arch}" /usr/local/bin/godot; \
    chmod +x /usr/local/bin/godot; \
    curl -fL --retry 3 "$release_url/Godot_v${GODOT_VERSION}-stable_export_templates.tpz" -o /tmp/templates.tpz; \
    echo "f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011  /tmp/templates.tpz" | sha256sum -c -; \
    mkdir -p "/root/.local/share/godot/export_templates/${GODOT_VERSION}.stable"; \
    unzip -q -j /tmp/templates.tpz 'templates/web*.zip' -d "/root/.local/share/godot/export_templates/${GODOT_VERSION}.stable"; \
    rm -rf /tmp/editor.zip /tmp/editor /tmp/templates.tpz

WORKDIR /project
COPY game-mcp-server/package.json game-mcp-server/package-lock.json game-mcp-server/
RUN npm --prefix game-mcp-server ci
COPY .godot-version project.godot export_presets.cfg Makefile ./
COPY assets/ assets/
COPY levels/ levels/
COPY resources/ resources/
COPY scenes/ scenes/
COPY scripts/ scripts/
COPY tests/ tests/
COPY tools/ tools/
COPY art/ art/
COPY game-mcp-server/ game-mcp-server/
RUN make test export-web-demo

FROM caddy:2.10.2-alpine AS runtime
COPY web/Caddyfile /etc/caddy/Caddyfile
RUN caddy validate --config /etc/caddy/Caddyfile
COPY --from=builder /project/exports/web-demo/ /srv/
ENV PORT=8080
EXPOSE 8080
