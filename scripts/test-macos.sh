#!/bin/bash
#
# macOS Smoke Test Runner for Nathaniel
#
# Builds and runs the macOS version of the game, then executes a series
# of smoke tests using the GameCommandServer HTTP API.
#
# Usage: ./scripts/test-macos.sh [--skip-build] [--screenshots-dir DIR]
#

set -e

# Configuration
GAME_SERVER_URL="http://localhost:8765"
SCREENSHOTS_DIR="${SCREENSHOTS_DIR:-/tmp/nathaniel-macos-test}"
SKIP_BUILD=false
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --screenshots-dir)
            SCREENSHOTS_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--skip-build] [--screenshots-dir DIR]"
            exit 1
            ;;
    esac
done

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

wait_for_server() {
    local max_attempts=30
    local attempt=0

    log_info "Waiting for GameCommandServer..."
    while [ $attempt -lt $max_attempts ]; do
        if curl -sf "$GAME_SERVER_URL/health" > /dev/null 2>&1; then
            log_success "GameCommandServer is ready"
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done

    log_error "GameCommandServer did not start within ${max_attempts}s"
    return 1
}

get_state() {
    curl -sf "$GAME_SERVER_URL/state" 2>/dev/null
}

get_scene() {
    get_state | python3 -c "import sys,json; print(json.load(sys.stdin).get('scene', 'unknown'))" 2>/dev/null
}

execute_action() {
    local action="$1"
    local params="${2:-}"

    if [ -n "$params" ]; then
        curl -sf "$GAME_SERVER_URL/action" -X POST \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"$action\",\"params\":$params}" 2>/dev/null
    else
        curl -sf "$GAME_SERVER_URL/action" -X POST \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"$action\"}" 2>/dev/null
    fi
}

take_screenshot() {
    local name="$1"
    local filepath="$SCREENSHOTS_DIR/${name}.png"

    curl -sf "$GAME_SERVER_URL/screenshot" | \
        python3 -c "import sys,json,base64; d=json.load(sys.stdin); open('$filepath','wb').write(base64.b64decode(d['data']))" 2>/dev/null

    if [ -f "$filepath" ]; then
        log_info "Screenshot saved: $filepath"
    fi
}

take_annotated_screenshot() {
    local name="$1"
    local filepath="$SCREENSHOTS_DIR/${name}_annotated.png"

    curl -sf "$GAME_SERVER_URL/screenshot/annotated" | \
        python3 -c "import sys,json,base64; d=json.load(sys.stdin); open('$filepath','wb').write(base64.b64decode(d['data']))" 2>/dev/null

    if [ -f "$filepath" ]; then
        log_info "Annotated screenshot saved: $filepath"
    fi
}

get_description() {
    curl -sf "$GAME_SERVER_URL/describe" 2>/dev/null | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin), indent=2))"
}

cleanup() {
    log_info "Cleaning up..."
    pkill -f "Nathaniel.app" 2>/dev/null || true
}

# Main test sequence
main() {
    local tests_passed=0
    local tests_failed=0

    echo ""
    echo "========================================"
    echo "  Nathaniel macOS Smoke Test"
    echo "========================================"
    echo ""

    # Create screenshots directory
    mkdir -p "$SCREENSHOTS_DIR"
    log_info "Screenshots will be saved to: $SCREENSHOTS_DIR"

    # Stop any existing instance
    pkill -f "Nathaniel.app" 2>/dev/null || true
    sleep 1

    # Build if needed
    if [ "$SKIP_BUILD" = false ]; then
        log_info "Building macOS app..."
        cd "$PROJECT_DIR"
        if xcodebuild -project Nathaniel.xcodeproj \
            -scheme "Nathaniel macOS" \
            -configuration Debug \
            build 2>&1 | tail -5; then
            log_success "Build succeeded"
        else
            log_error "Build failed"
            exit 1
        fi
    else
        log_info "Skipping build (--skip-build)"
    fi

    # Find and launch the app (macOS app is in Debug/, not Debug-iphonesimulator/)
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Nathaniel.app" -path "*Products/Debug/*" ! -path "*-iphonesimulator*" ! -path "*-iphoneos*" 2>/dev/null | head -1)

    if [ -z "$APP_PATH" ]; then
        log_error "Could not find built Nathaniel.app"
        exit 1
    fi

    log_info "Launching: $APP_PATH"
    open "$APP_PATH"

    # Wait for server
    if ! wait_for_server; then
        exit 1
    fi

    # Set trap for cleanup
    trap cleanup EXIT

    echo ""
    echo "========================================"
    echo "  Running Tests"
    echo "========================================"
    echo ""

    # Test 1: App launches to main menu
    log_info "Test 1: App launches to MainMenuScene"
    scene=$(get_scene)
    if [ "$scene" = "MainMenuScene" ]; then
        log_success "App launched to MainMenuScene"
        tests_passed=$((tests_passed + 1))
    else
        log_error "Expected MainMenuScene, got: $scene"
        tests_failed=$((tests_failed + 1))
    fi
    take_screenshot "01_main_menu"

    # Test 2: Navigate to level select
    log_info "Test 2: Navigate to LevelSelectScene"
    execute_action "startGame" > /dev/null
    sleep 0.5
    scene=$(get_scene)
    if [ "$scene" = "LevelSelectScene" ]; then
        log_success "Navigated to LevelSelectScene"
        tests_passed=$((tests_passed + 1))
    else
        log_error "Expected LevelSelectScene, got: $scene"
        tests_failed=$((tests_failed + 1))
    fi
    take_screenshot "02_level_select"

    # Test 3: Start level 1
    log_info "Test 3: Start Level 1"
    execute_action "level_1" > /dev/null
    sleep 2
    scene=$(get_scene)
    if [ "$scene" = "GameScene" ]; then
        log_success "Started Level 1 (GameScene)"
        tests_passed=$((tests_passed + 1))
    else
        log_error "Expected GameScene, got: $scene"
        tests_failed=$((tests_failed + 1))
    fi
    take_screenshot "03_game_start"
    take_annotated_screenshot "03_game_start"

    # Test 4: Describe endpoint works
    log_info "Test 4: /describe endpoint returns valid data"
    description=$(curl -sf "$GAME_SERVER_URL/describe" 2>/dev/null)
    if echo "$description" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if 'summary' in d and 'playerStatus' in d else 1)" 2>/dev/null; then
        log_success "/describe endpoint works"
        tests_passed=$((tests_passed + 1))
        echo "$description" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin), indent=2))"
    else
        log_error "/describe endpoint failed or returned invalid data"
        tests_failed=$((tests_failed + 1))
    fi

    # Test 5: Player can be selected
    log_info "Test 5: Select Hermes"
    result=$(execute_action "selectHermes")
    if echo "$result" | python3 -c "import sys,json; exit(0 if json.load(sys.stdin).get('success') else 1)" 2>/dev/null; then
        log_success "Selected Hermes"
        tests_passed=$((tests_passed + 1))
    else
        log_error "Failed to select Hermes"
        tests_failed=$((tests_failed + 1))
    fi
    sleep 0.5
    take_screenshot "04_hermes_selected"

    # Test 6: Toggle character
    log_info "Test 6: Toggle character"
    result=$(execute_action "toggleCharacter")
    if echo "$result" | python3 -c "import sys,json; exit(0 if json.load(sys.stdin).get('success') else 1)" 2>/dev/null; then
        log_success "Toggled character"
        tests_passed=$((tests_passed + 1))
    else
        log_error "Failed to toggle character"
        tests_failed=$((tests_failed + 1))
    fi
    sleep 0.5
    take_screenshot "05_after_toggle"

    # Test 7: Move character
    log_info "Test 7: Move Nathaniel"
    result=$(execute_action "moveNathaniel" '{"x":"500","y":"400"}')
    if echo "$result" | python3 -c "import sys,json; exit(0 if json.load(sys.stdin).get('success') else 1)" 2>/dev/null; then
        log_success "Moved Nathaniel"
        tests_passed=$((tests_passed + 1))
    else
        log_error "Failed to move Nathaniel"
        tests_failed=$((tests_failed + 1))
    fi
    sleep 1
    take_screenshot "06_nathaniel_moved"

    # Test 8: Navigate back to main menu
    log_info "Test 8: Return to main menu"
    # We need to navigate through: GameScene -> (pause?) -> LevelSelect -> MainMenu
    # For now, just check we can get game state
    state=$(get_state)
    if echo "$state" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if 'scene' in d else 1)" 2>/dev/null; then
        log_success "Game state is accessible"
        tests_passed=$((tests_passed + 1))
    else
        log_error "Could not get game state"
        tests_failed=$((tests_failed + 1))
    fi

    # Summary
    echo ""
    echo "========================================"
    echo "  Test Results"
    echo "========================================"
    echo ""
    echo -e "Passed: ${GREEN}$tests_passed${NC}"
    echo -e "Failed: ${RED}$tests_failed${NC}"
    echo ""
    echo "Screenshots saved to: $SCREENSHOTS_DIR"
    echo ""

    if [ $tests_failed -eq 0 ]; then
        log_success "All tests passed!"
        exit 0
    else
        log_error "Some tests failed"
        exit 1
    fi
}

# Run main
main "$@"
