class_name GameUI
extends Control

signal command(name: String, value: Variant)
signal tower_drag(kind: String)

var menu := "main"
var previous_menu := "main"
var notice_time := 0.0
var build_kind := ""
var build_open := false
var buttons: Dictionary = {}


func _ready() -> void:
	theme = _make_theme()
	resized.connect(_fit_menu)
	%Content.minimum_size_changed.connect(func() -> void: _fit_menu.call_deferred())
	%Nathaniel.pressed.connect(func() -> void: command.emit("focus", "nathaniel"))
	%Hermes.pressed.connect(func() -> void: command.emit("focus", "hermes"))
	%Pause.pressed.connect(func() -> void: command.emit("pause", null))
	%Modal.gui_input.connect(func(event: InputEvent) -> void:
		if menu in ["victory", "gameOver"] and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			command.emit("continue_result", null)
	)
	for item: Array in [["Fire", "fire"], ["Stop [S]", "stop"], ["Follow [R]", "follow"], ["Hermes Stop", "hermes_stop"], ["Build", "build"], ["Gun · 5", "gun_tower"], ["Laser · 10", "laser_tower"], ["Heal · 15", "heal_tower"], ["−", "zoom_out"], ["+", "zoom_in"]]:
		var button := _button(item[0], %Commands)
		buttons[item[1]] = button
		button.pressed.connect(func() -> void: command.emit(item[1], null))
		if String(item[1]).ends_with("_tower"):
			button.button_down.connect(func() -> void: tower_drag.emit(item[1]))


func _process(delta: float) -> void:
	if notice_time > 0:
		notice_time -= delta
		if notice_time <= 0:
			%Notice.text = ""


func update_game(sim: GameSimulation) -> void:
	var separator := "\n" if OS.has_feature("mobile") else "  "
	%Nathaniel.text = ("Nathaniel%s%d/%d" % [separator, sim.nathaniel.get("hp", 0), sim.nathaniel.get("max_hp", 8000)])
	%Hermes.text = ("Hermes%s%d/%d" % [separator, sim.hermes.get("hp", 0), sim.hermes.get("max_hp", 2000)])
	%Stats.text = "RESOURCES %d   ·   LIVES %d   ·   SCORE %d\n%s  %02d:%02d" % [sim.resources, sim.lives, sim.score, "SURVIVAL" if sim.config.get("number", 0) == 0 else "LEVEL %d" % sim.config.get("number", 1), int(sim.elapsed_time) / 60, int(sim.elapsed_time) % 60]
	%Status.text = "Hermes: %s  ·  Focus: %s  ·  %s" % [sim.hermes_mode.capitalize(), sim.focused_character.capitalize(), "Place %s on clear ground" % build_kind.replace("_", " ") if not build_kind.is_empty() else "Click terrain to move • Select enemies to attack"]
	for kind: String in ["gun_tower", "laser_tower", "heal_tower"]:
		buttons[kind].disabled = sim.hermes_mode != "building"
		buttons[kind].visible = build_open and sim.hermes_mode == "building" and sim.focused_character == "hermes"
	buttons.build.visible = sim.hermes_mode == "building" and sim.focused_character == "hermes"
	buttons.build.text = "Close Build" if build_open else "Build"


func show_notice(message: String) -> void:
	%Notice.text = message
	notice_time = 5.0


func show_menu(which: String, context: Dictionary = {}) -> void:
	menu = which
	%Scroll.scroll_vertical = 0
	_fit_menu.call_deferred()
	%Modal.visible = not which.is_empty()
	$Top.visible = which != "main" and which != "levels" and context.get("in_game", true)
	$Bottom.visible = $Top.visible
	for child in %Content.get_children():
		%Content.remove_child(child)
		child.queue_free()
	match which:
		"main":
			_heading("NATHANIEL", "EARTH NEEDS YOU")
			if context.get("has_progress", false):
				_menu_button("Continue · Level %d" % context.get("continue_level", 1), "level", context.get("continue_level", 1))
			_menu_button("New campaign", "level", 1)
			_menu_button("Select level", "levels")
			_menu_button("Survival", "level", 0)
			_menu_button("Load game", "load_menu")
			_menu_button("Settings", "settings")
			_menu_button("Credits", "credits")
			_menu_button("Quit", "quit")
		"levels":
			_heading("CAMPAIGN", "Choose an encounter")
			for number in range(1, 6):
				var best: Variant = context.get("high_scores", {}).get(str(number))
				var score_text := " · Best %d" % int(best) if best != null else ""
				_menu_button("Level %d%s%s" % [number, "  ✓" if number in context.get("completed", []) else "", score_text], "level", number)
			_menu_button("Back", "main")
		"pause":
			_heading("PAUSED", "Your orders can wait")
			_menu_button("Resume", "resume")
			_menu_button("Save game", "save_menu")
			_menu_button("Load game", "load_menu")
			_menu_button("Settings", "settings")
			_menu_button("Main menu", "exit_menu")
		"confirm_exit":
			_heading("EXIT TO MAIN MENU?", "Unsaved progress will be lost.")
			_menu_button("Exit to main menu", "main")
			_menu_button("Cancel", "back")
		"settings":
			_heading("SETTINGS", "Audio and visibility")
			for option: Array in [["Music", "music_enabled"], ["Sound effects", "sound_effects_enabled"], ["Fog of war", "fog_enabled"]]:
				var toggle := CheckButton.new()
				toggle.text = option[0]
				toggle.mouse_filter = Control.MOUSE_FILTER_PASS
				toggle.button_pressed = context.get(option[1], true)
				%Content.add_child(toggle)
				toggle.toggled.connect(func(value: bool) -> void: command.emit("setting", {option[1]: value}))
			_menu_button("Back", "back")
		"save", "load":
			_heading("SAVE GAME" if which == "save" else "LOAD GAME", "Three independent slots")
			for slot in range(1, 4):
				var slots: Array = context.get("slots", [])
				var entry: Dictionary = slots[slot - 1] if slots.size() >= slot else {}
				var label: String = entry.get("display_name", "Empty" if str(entry.get("error", "")).is_empty() else "Cannot read save")
				var button := _menu_button("Slot %d · %s" % [slot, label], "save_slot" if which == "save" else "load_slot", slot)
				button.disabled = which == "load" and not entry.get("has_save", false)
				button.tooltip_text = entry.get("error", "")
			_menu_button("Cancel", "back")
		"confirm_save":
			_heading("REPLACE SAVE?", "Slot %d already contains a saved game." % context.get("slot", 1))
			_menu_button("Replace slot %d" % context.get("slot", 1), "confirm_save", context.get("slot", 1))
			_menu_button("Cancel", "save_menu")
		"victory":
			_heading("CAMPAIGN COMPLETE" if context.get("next_level", -1) < 0 else "LEVEL COMPLETE", "Score %d · Time %s" % [context.get("score", 0), _time_text(context.get("elapsed", 0.0))])
			if context.get("next_level", -1) >= 0:
				_menu_button("Next level", "level", context.next_level)
			_menu_button("Main menu", "main")
		"gameOver":
			_heading("EARTH HAS FALLEN", "Score %d · Time %s" % [context.get("score", 0), _time_text(context.get("elapsed", 0.0))])
			_menu_button("Try again", "level", context.get("level", 1))
			_menu_button("Main menu", "main")
		"credits":
			_heading("NATHANIEL", "Defender of Earth\n\nOriginal game · Ruairi O'Brien\nSpriteKit port · Ruairi O'Brien\nOriginal platform · Windows Phone 7 / XNA\nSwift & SpriteKit · Godot 4.7.2\n\nSpecial thanks\nThe XNA Community\nApple Developer Tools")
			_menu_button("Back", "back")


func _heading(title: String, subtitle: String) -> void:
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color("b4e69b"))
	%Content.add_child(label)
	var description := Label.new()
	description.text = subtitle
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_color_override("font_color", Color("99adaa"))
	%Content.add_child(description)


func _time_text(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func _menu_button(label: String, action: String, value: Variant = null) -> Button:
	var button := _button(label, %Content)
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(func() -> void: command.emit(action, value))
	return button


func _button(label: String, parent: Node) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(60, 60) if OS.has_feature("mobile") else Vector2(52, 44)
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button


func _make_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 20 if OS.has_feature("mobile") else 16
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("142628")
	panel.border_color = Color("3d5750")
	panel.set_border_width_all(1)
	panel.content_margin_left = 16
	panel.content_margin_right = 16
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	result.set_stylebox("panel", "PanelContainer", panel)
	var normal := panel.duplicate() as StyleBoxFlat
	normal.bg_color = Color("233b37")
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	result.set_stylebox("normal", "Button", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("395d48")
	result.set_stylebox("hover", "Button", hover)
	result.set_stylebox("pressed", "Button", hover)
	return result


func _fit_menu() -> void:
	if not is_node_ready() or size.y <= 0:
		return
	var panel := $Modal/Center/Panel as PanelContainer
	panel.custom_minimum_size.x = minf(520.0 if OS.has_feature("mobile") else 480.0, size.x - 32.0)
	%Scroll.custom_minimum_size.y = minf(%Content.get_combined_minimum_size().y, maxf(100.0, size.y - 80.0))
