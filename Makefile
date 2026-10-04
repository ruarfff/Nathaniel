# Nathaniel development commands. Open project.godot or use make editor.
.DEFAULT_GOAL := run
GODOT ?= godot
LEVEL ?= 1
DEBUG_PORT ?= 8766
WEB_PORT ?= 8060
TEST_STORAGE := $(CURDIR)/test-artifacts/test-session
ASSET ?= placeholder_prop
GENERATOR ?= tools/blender/generate_placeholder.py
PROFILE ?= default

.PHONY: help version run editor level debug import test test-tooling test-mcp format format-check profile profile-rendered export-macos export-ios export-web serve-web health clean
.PHONY: art-doctor art-generate art-render art-regenerate art-preview art-review art-characters test-art test-hd-art test-animated-art test-static-art
.PHONY: art-environment art-environment-regenerate test-environment-art
.PHONY: art-gun-turret art-gun-turret-preview test-gun-turret
.PHONY: test-healing-tower
.PHONY: test-nathaniel-weapons
.PHONY: art-nathaniel-weapons
.PHONY: test-content test-gameplay test-services test-presentation
.PHONY: test-hermes-base art-hermes-base

help:
	@echo "Development and platform exports"
	@echo "make / make run       Run Nathaniel"
	@echo "make editor           Open the project in Godot"
	@echo "make level LEVEL=1    Run campaign 1–5 or survival 0"
	@echo "make debug            Run with the local debug interface"
	@echo "make test             Run content, gameplay, UI, storage, and MCP checks"
	@echo "make test-tooling     Run Python tooling checks"
	@echo "make test-mcp         Run adapter and live game integration checks"
	@echo "make test-content     Check native levels, scenes, and resources"
	@echo "make test-gameplay    Check simulation and weapon rules"
	@echo "make test-services    Check storage and save compatibility"
	@echo "make test-presentation Check input, HUD, and weapon controls"
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
	@echo ""
	@echo "Blender source authoring (saved .blend files live in art/blender/sources/)"
	@echo "make art-doctor       Check Blender and its bundled Python"
	@echo "make art-generate     Create a new .blend (ASSET, GENERATOR)"
	@echo "make art-render       Render a saved .blend (ASSET)"
	@echo "make art-regenerate   Render all saved Blender sources"
	@echo "make art-environment-regenerate Render saved environment sources only"
	@echo ""
	@echo "Godot previews and captures (review output goes to test-artifacts/)"
	@echo "make art-preview      Run the isolated asset comparison scene"
	@echo "make art-review       Capture the tower review board and native 4K view"
	@echo "make art-characters   Capture the animated character review board"
	@echo "make art-environment  Capture terrain, building, and scenery review boards"
	@echo "make art-gun-turret   Capture the live turret and measure a 30-tower view"
	@echo "make art-gun-turret-preview Open the isolated live turret test scene"
	@echo "make art-nathaniel-weapons Capture both guns in the normal game at 4K"
	@echo "make art-hermes-base Capture Hermes mobile, base, and reclaimed states"
	@echo ""
	@echo "Asset checks (these include graphical checks; make test stays headless)"
	@echo "make test-environment-art Check terrain seams, grid, scenery, and unchanged level data"
	@echo "make test-art         Check Blender source safety and rendered Godot sorting"
	@echo "make test-hd-art      Check high-resolution tower imports, anchors, and sorting"
	@echo "make test-animated-art Check character clips, facing, playback, and anchors"
	@echo "make test-static-art  Check the spawner and spent-body art contracts"
	@echo "make test-gun-turret  Check continuous aim, muzzle effects, and rendered sorting"
	@echo "make test-healing-tower Check healing pulses, event routing, and rendered lights"
	@echo "make test-nathaniel-weapons Check loadout, controls, aiming, recoil, and saves"
	@echo "make test-hermes-base Check Hermes transformation, build range, and cables"
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
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_blender_asset.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_hd_art.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_gun_turret.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_weapon_effects.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_weapons.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_weapon_controls.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_nathaniel_weapons.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_healing_tower.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_hermes_actor.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_hermes_base_effects.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_animated_art.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_static_art.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_environment_art.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_gameplay.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_services.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_presentation.gd -- --storage-dir="$(TEST_STORAGE)"
	$(MAKE) test-mcp

test-tooling:
	python3 -m unittest discover -s tests -p 'test_*.py'

test-content: import
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_content.gd

test-gameplay: import
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_gameplay.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_weapons.gd

test-services: import
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_services.gd

test-presentation: import
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_presentation.gd -- --storage-dir="$(TEST_STORAGE)"
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_weapon_controls.gd

test-nathaniel-weapons: import
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_weapons.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_weapon_controls.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_nathaniel_weapons.gd
	python3 tools/run_checked.py "$(GODOT)" --path . --script res://tests/test_nathaniel_weapons.gd -- --render

art-nathaniel-weapons: import
	python3 tools/run_checked.py "$(GODOT)" --path . --script res://tools/render_nathaniel_weapons.gd

test-hermes-base: import
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_hermes_actor.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_hermes_base_effects.gd
	python3 tools/run_checked.py "$(GODOT)" --path . --script res://tests/test_hermes_actor.gd -- --render
	python3 tools/run_checked.py "$(GODOT)" --path . --script res://tests/test_hermes_base_effects.gd -- --render

art-hermes-base: import
	python3 tools/run_checked.py "$(GODOT)" --path . --script res://tools/render_hermes_base.gd

test-mcp: import
	npm --prefix game-mcp-server test
	python3 tools/run_live_mcp.py "$(GODOT)"

format:
	python3 tools/format_sources.py

format-check:
	python3 tools/format_sources.py --check

art-doctor:
	sh tools/blender.sh doctor

art-generate:
	sh tools/blender.sh generate "$(ASSET)" --generator "$(GENERATOR)" --profile "$(PROFILE)"

art-render:
	sh tools/blender.sh render "$(ASSET)"

art-regenerate:
	sh tools/blender.sh regenerate

art-preview: import
	python3 tools/run_checked.py "$(GODOT)" --path . res://scenes/tests/blender_asset_preview.tscn

art-review: import
	python3 tools/run_checked.py "$(GODOT)" --path . --script res://tools/render_hd_art.gd

art-characters: import
	python3 tools/run_checked.py "$(GODOT)" --path . --script res://tools/render_character_art.gd

art-gun-turret: import
	python3 tools/run_checked.py "$(GODOT)" --path . --script res://tools/render_gun_turret.gd

art-gun-turret-preview: import
	python3 tools/run_checked.py "$(GODOT)" --path . res://scenes/tests/gun_turret_preview.tscn

test-gun-turret: import
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_gun_turret.gd
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_weapon_effects.gd
	python3 tools/run_checked.py "$(GODOT)" --path . --script res://tests/test_gun_turret.gd -- --render

art-environment: import
	python3 tools/run_checked.py "$(GODOT)" --path . --script res://tools/render_environment_art.gd

art-environment-regenerate:
	sh tools/blender.sh regenerate --prefix environment_

test-environment-art: import
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_environment_art.gd
	python3 tools/run_checked.py "$(GODOT)" --path . --script res://tests/test_environment_art.gd -- --render

test-healing-tower: import
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_healing_tower.gd
	python3 tools/run_checked.py "$(GODOT)" --path . --script res://tests/test_healing_tower.gd -- --render

test-animated-art: import
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_animated_art.gd
	python3 tools/run_checked.py "$(GODOT)" --path . --script res://tests/test_animated_art.gd -- --render

test-static-art: import
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_static_art.gd
	python3 tools/run_checked.py "$(GODOT)" --path . --script res://tests/test_static_art.gd -- --render

test-hd-art: import
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_hd_art.gd
	python3 tools/run_checked.py "$(GODOT)" --path . --script res://tests/test_hd_art.gd -- --render

test-art:
	sh tools/blender.sh verify
	$(MAKE) import
	python3 tools/run_checked.py "$(GODOT)" --headless --path . --script res://tests/test_blender_asset.gd
	python3 tools/run_checked.py "$(GODOT)" --path . --script res://tests/test_blender_asset.gd -- --render

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
