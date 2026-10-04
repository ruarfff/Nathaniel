#!/bin/sh
# Run asset tools with Blender's bundled Python, without a separate environment.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ -n "${BLENDER:-}" ]; then
    BIN=$BLENDER
elif command -v blender >/dev/null 2>&1; then
    BIN=$(command -v blender)
elif [ -x /Applications/Blender.app/Contents/MacOS/Blender ]; then
    BIN=/Applications/Blender.app/Contents/MacOS/Blender
elif [ -x "$HOME/Applications/Home Manager Apps/Blender.app/Contents/MacOS/Blender" ]; then
    BIN="$HOME/Applications/Home Manager Apps/Blender.app/Contents/MacOS/Blender"
else
    echo 'Blender not found. Install the pinned version or set BLENDER to its executable.' >&2
    exit 1
fi
if ! command -v "$BIN" >/dev/null 2>&1; then
    echo "Blender executable not found: $BIN" >&2
    exit 1
fi
exec "$BIN" --background --factory-startup --disable-autoexec --python-exit-code 1 \
    --python "$ROOT/tools/blender/pipeline.py" -- "$@"
