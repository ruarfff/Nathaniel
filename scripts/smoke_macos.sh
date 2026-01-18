#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

SCHEME="${SCHEME:-Nathaniel macOS}"
CONFIGURATION="${CONFIGURATION:-Debug}"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/Nathaniel.xcodeproj}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/test-artifacts/DerivedData}"
LOG_DIR="${LOG_DIR:-$ROOT_DIR/test-artifacts}"
LOG_FILE="$LOG_DIR/macos-smoke.log"

mkdir -p "$DERIVED_DATA_PATH" "$LOG_DIR"

{
  echo "== Nathaniel macOS smoke test =="
  echo "scheme: $SCHEME"
  echo "configuration: $CONFIGURATION"
  echo "derivedData: $DERIVED_DATA_PATH"
  echo
} | tee "$LOG_FILE"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  build | tee -a "$LOG_FILE"

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/Nathaniel.app"
BIN_PATH="$APP_PATH/Contents/MacOS/Nathaniel"

if [[ ! -x "$BIN_PATH" ]]; then
  echo "error: built macOS binary not found at: $BIN_PATH" | tee -a "$LOG_FILE" >&2
  exit 2
fi

echo | tee -a "$LOG_FILE"
echo "Running: $BIN_PATH --smoke-test" | tee -a "$LOG_FILE"
"$BIN_PATH" --smoke-test 2>&1 | tee -a "$LOG_FILE"
