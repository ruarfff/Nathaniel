# Nathaniel development commands. Open project.godot or use make editor.
.DEFAULT_GOAL := run
GODOT ?= godot
LEVEL ?= 1
DEBUG_PORT ?= 8766
WEB_PORT ?= 8060
TEST_STORAGE := $(CURDIR)/test-artifacts/test-session

.PHONY: help version run editor level debug import test test-tooling test-mcp format format-check profile profile-rendered export-macos export-ios export-web serve-web health clean

help:
	@echo "make / make run       Run Nathaniel"
	@echo "make editor           Open the project in Godot"
	@echo "make level LEVEL=1    Run campaign 1–5 or survival 0"
	@echo "make debug            Run with the local debug interface"
	@echo "make test             Run content, gameplay, UI, storage, and MCP checks"
	@echo "make test-tooling     Run Python tooling checks"
	@echo "make test-mcp         Run adapter and live game integration checks"
	@echo "make format           Normalize project source whitespace"
	@echo "make format-check     Check project source whitespace"
	@echo "make profile          Measure simulation performance"
	@echo "make profile-rendered Measure a rendered battle"
	@echo "make export-macos     Export the macOS release app"
	@echo "make export-ios       Export an unsigned iOS Xcode project"
	@echo "make export-web       Export the browser release build"
	@echo "make serve-web        Serve exports/web on http://127.0.0.1:$(WEB_PORT)"
	@echo "make health           Check the running debug interface"
	@echo "make clean            Remove generated imports and exports"
	@echo "Override GODOT, LEVEL, DEBUG_PORT, WEB_PORT, or GODOT_TEMPLATE_DIR as needed."

version:
	python3 tools/check_version.py "$(GODOT)"

run: import
	"$(GODOT)" --path .

editor: version
	"$(GODOT)" --editor --path .

level: import
	"$(GODOT)" --path . -- --level=$(LEVEL)

debug: import
	"$(GODOT)" --path . -- --debug-port=$(DEBUG_PORT)

import: version
	python3 tools/run_checked.py "$(GODOT)" --headless --editor --path . --import --quit

test: import format-check test-tooling
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_content.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_gameplay.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_services.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_presentation.gd -- --storage-dir="$(TEST_STORAGE)"
	$(MAKE) test-mcp

test-tooling:
	python3 -m unittest discover -s tests -p 'test_*.py'

test-mcp: import
	npm --prefix game-mcp-server test
	python3 tools/run_live_mcp.py "$(GODOT)"

format:
	python3 tools/format_sources.py

format-check:
	python3 tools/format_sources.py --check

profile: import
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/profile_gameplay.gd

profile-rendered: import
	python3 tools/run_checked.py "$(GODOT)" --path . --script res://tests/profile_rendered.gd

export-macos: version
	python3 tools/export_project.py macOS --godot "$(GODOT)" --release

export-ios: version
	python3 tools/export_project.py iOS --godot "$(GODOT)" --unsigned-ios

export-web: version
	python3 tools/export_project.py Web --godot "$(GODOT)" --release

serve-web:
	test -f exports/web/index.html
	python3 -m http.server "$(WEB_PORT)" --bind 127.0.0.1 --directory exports/web

health:
	curl --fail --silent --show-error http://127.0.0.1:$(DEBUG_PORT)/health

clean:
	rm -rf .godot exports/macos exports/ios exports/web exports/web-export.log exports/web-export.stdout.log
