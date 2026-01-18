#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

SCHEME="${SCHEME:-Nathaniel iOS}"
CONFIGURATION="${CONFIGURATION:-Debug}"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/Nathaniel.xcodeproj}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/test-artifacts/DerivedData}"
LOG_DIR="${LOG_DIR:-$ROOT_DIR/test-artifacts}"
LOG_FILE="$LOG_DIR/ios-sim-smoke.log"

BUNDLE_ID="${BUNDLE_ID:-com.ruarfff.Nathaniel}"
SMOKE_WAIT_SECONDS="${SMOKE_WAIT_SECONDS:-5}"

mkdir -p "$DERIVED_DATA_PATH" "$LOG_DIR"

{
  echo "== Nathaniel iOS simulator smoke test =="
  echo "scheme: $SCHEME"
  echo "configuration: $CONFIGURATION"
  echo "derivedData: $DERIVED_DATA_PATH"
  echo "bundleId: $BUNDLE_ID"
  echo
} | tee "$LOG_FILE"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -sdk iphonesimulator \
  -destination "${DESTINATION:-generic/platform=iOS Simulator}" \
  CODE_SIGNING_ALLOWED=NO \
  build | tee -a "$LOG_FILE"

APP_PATH="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-iphonesimulator/Nathaniel.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "error: built iOS .app not found at: $APP_PATH" | tee -a "$LOG_FILE" >&2
  exit 2
fi

pick_sim_udid() {
  python3 -c 'import json, re, sys
data = json.load(sys.stdin)
devices = data.get("devices", {})

def parse_ios_version(runtime_id: str):
    m = re.search(r"iOS-(\d+)(?:-(\d+))?(?:-(\d+))?$", runtime_id or "")
    if not m:
        return ()
    parts = [p for p in m.groups() if p is not None]
    return tuple(int(p) for p in parts)

def iter_iphones():
    for runtime_id, devs in devices.items():
        for dev in devs:
            if not dev.get("isAvailable", False):
                continue
            name = (dev.get("name") or "").lower()
            if "iphone" not in name:
                continue
            yield (parse_ios_version(runtime_id), dev)

iphones = list(iter_iphones())
iphones.sort(key=lambda t: t[0], reverse=True)
if iphones:
    best_version = iphones[0][0]
    for version, dev in iphones:
        if version == best_version and dev.get("state") == "Booted":
            print(dev["udid"])
            raise SystemExit(0)

    print(iphones[0][1]["udid"])
    raise SystemExit(0)

raise SystemExit(1)
'
}

SIMULATOR_UDID="${SIMULATOR_UDID:-}"
if [[ -z "$SIMULATOR_UDID" ]]; then
  SIMULATOR_UDID="$(xcrun simctl list devices available -j | pick_sim_udid)"
fi

if [[ -z "$SIMULATOR_UDID" ]]; then
  echo "error: could not find an available iPhone simulator (set SIMULATOR_UDID=...)" | tee -a "$LOG_FILE" >&2
  exit 2
fi

echo | tee -a "$LOG_FILE"
echo "Using simulator: $SIMULATOR_UDID" | tee -a "$LOG_FILE"

xcrun simctl boot "$SIMULATOR_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIMULATOR_UDID" -b | tee -a "$LOG_FILE"

xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH" | tee -a "$LOG_FILE"

echo "Launching (smoke mode)..." | tee -a "$LOG_FILE"
xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID" --args --smoke-test | tee -a "$LOG_FILE"

echo "Waiting ${SMOKE_WAIT_SECONDS}s..." | tee -a "$LOG_FILE"
sleep "$SMOKE_WAIT_SECONDS"

SCREENSHOT_PATH="$LOG_DIR/ios-sim-smoke.png"
xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" | tee -a "$LOG_FILE"
echo "Screenshot: $SCREENSHOT_PATH" | tee -a "$LOG_FILE"

xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
