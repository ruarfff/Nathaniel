class_name GameUI
extends Control

signal command(name: String, value: Variant)
signal tower_drag(kind: String)

var menu := "main"
var notice_time := 0.0
var build_kind := ""
var build_open := false
var demo_mode := false
var buttons: Dictionary = {}
var ring_character := ""
var ring_center := Vector2.ZERO
var ring_actor_position := Vector2.ZERO
var pressed_actor_position := Vector2.ZERO
var character_pressed := false
var ring_buttons: Dictionary = {}
var _ring: Control
var _placement: HBoxContainer
var _placement_label: Label
var _ring_layout_size := Vector2.ZERO


func _ready() -> void:
	theme = _make_theme()
	%Modal.theme = _make_theme(false)
	resized.connect(_fit_menu)
	$Bottom.minimum_size_changed.connect(func() -> void: _fit_hud.call_deferred())
	resized.connect(func() -> void: _fit_hud.call_deferred())
	%Content.minimum_size_changed.connect(func() -> void: _fit_menu.call_deferred())
	%Nathaniel.pressed.connect(func() -> void: command.emit("focus", "nathaniel"))
	%Hermes.pressed.connect(func() -> void: command.emit("open_build"))
	%Pause.pressed.connect(func() -> void: command.emit("pause", null))
	%Modal.gui_input.connect(func(event: InputEvent) -> void:
		if menu in ["victory", "gameOver"] and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			command.emit("continue_result", null)
	)
	for item: Array in [["Fire", "fire"], ["Stop [S]", "stop"], ["Hermes [B]", "build"], ["−", "zoom_out"], ["+", "zoom_in"]]:
		var button := _button(item[0], %Commands)
		buttons[item[1]] = button
		button.pressed.connect(func() -> void: command.emit(item[1], null))
	buttons.build.toggle_mode = true
	buttons.fire.tooltip_text = "Nathaniel fires at his current enemy target. F fires toward the pointer."
	buttons.stop.tooltip_text = "Stop Nathaniel's movement. Automatic combat continues."
	buttons.zoom_out.tooltip_text = "Zoom out"
	buttons.zoom_in.tooltip_text = "Zoom in"
	for weapon_id: String in ["rifle", "heavy_rifle"]:
		var button := _button("Rifle [1]" if weapon_id == "rifle" else "Heavy rifle [2]", %Weapons)
		button.toggle_mode = true
		button.pressed.connect(func() -> void: command.emit("equip_weapon", weapon_id))
		buttons[weapon_id] = button
	for upgrade: String in ["capacity", "reach"]:
		var button := _button("", %Towers)
		button.pressed.connect(func() -> void: command.emit("upgrade_gathering", upgrade))
		buttons["upgrade_" + upgrade] = button
	_make_ring()
	_fit_hud.call_deferred()


func _process(delta: float) -> void:
	if notice_time > 0:
		notice_time -= delta
		if notice_time <= 0:
			%Notice.text = ""


func update_game(sim: GameSimulation, fog_enabled: bool = true) -> void:
	%Nathaniel.update_unit(sim, sim.nathaniel, fog_enabled, true)
	%Hermes.update_unit(sim, sim.hermes, fog_enabled, build_open)
	var mode_label := "DEMO · SURVIVAL" if demo_mode else ("SURVIVAL" if sim.config.get("number", 0) == 0 else "LEVEL %d" % sim.config.get("number", 1))
	%Stats.text = "MATTER %d   ·   %s\n%d lives · %d score · %s" % [sim.resources, _time_text(sim.elapsed_time), sim.lives, sim.score, mode_label]
	buttons.fire.disabled = build_open or not CombatRules.alive(sim.nathaniel)
	buttons.stop.disabled = buttons.fire.disabled
	var following := sim.hermes_mode == "following"
	var tower_counts := {"gunTower": 0, "laserTower": 0, "healTower": 0}
	var refund := 0
	for entity: Dictionary in sim.entities:
		if entity.tower and entity.hp > 0:
			tower_counts[entity.kind] += 1
			if entity.owned:
				refund += int(entity.construction_cost) / 4
	%Towers.visible = build_open
	%Weapons.visible = not build_open
	for upgrade: String in ["capacity", "reach"]:
		var cost: int = sim.gathering_upgrade_cost(upgrade)
		var button: Button = buttons["upgrade_" + upgrade]
		var label := "Cargo slot" if upgrade == "capacity" else "Arm reach"
		button.text = "%s · %d" % [label, cost] if cost >= 0 else "%s · Max" % label
		button.disabled = cost < 0 or sim.resources < cost or not CombatRules.alive(sim.nathaniel) or not CombatRules.alive(sim.hermes)
		button.tooltip_text = "All upgrades fitted." if cost < 0 else "Costs %d resources. %s" % [cost, "Add one visible cargo clamp." if upgrade == "capacity" else "Reach more distant bodies with the same two arms."]
	for kind: String in ["gun_tower", "laser_tower", "heal_tower"]:
		var cost := int(GameBalance.COSTS[GameBalance.canonical_kind(kind)])
		var button: Button = ring_buttons[kind]
		button.disabled = sim.resources < cost or not CombatRules.alive(sim.hermes)
		button.text = "%s · %d\n%s" % [kind.trim_suffix("_tower").capitalize(), cost, "Need more matter" if sim.resources < cost else "Place tower"]
		button.tooltip_text = "Costs %d matter. Place inside Hermes's build range." % cost
	ring_buttons.pack.disabled = following or not CombatRules.alive(sim.hermes)
	var tower_summary: PackedStringArray = []
	for kind: String in tower_counts:
		if tower_counts[kind] > 0:
			tower_summary.append("%s %d" % [{"gunTower": "Gun", "laserTower": "Laser", "healTower": "Heal"}[kind], tower_counts[kind]])
	var pack_detail := "No linked towers" if tower_summary.is_empty() else " · ".join(tower_summary.slice(0, 2))
	pack_detail += "\n%s+%d matter" % [(tower_summary[2] + " · ") if tower_summary.size() > 2 else "", refund]
	ring_buttons.pack.text = "Pack up & move\n%s" % ("Already mobile" if following else pack_detail)
	var structures: PackedStringArray = []
	for entity: Dictionary in sim.entities:
		if entity.tower and entity.hp > 0:
			structures.append("%s #%d" % [String(entity.kind), int(entity.id)])
	ring_buttons.pack.tooltip_text = "Reclaim: %s. Refund %d matter. Resume following Nathaniel." % [", ".join(structures) if not structures.is_empty() else "no structures", refund]
	buttons.build.text = "Close [B]" if build_open else "Hermes [B]"
	buttons.build.set_pressed_no_signal(build_open)
	buttons.build.tooltip_text = "Close Build and return to Nathaniel." if build_open else "Focus Hermes and open Build. A valid build deploys his cannon base."
	var equipped: String = sim.nathaniel.get("equipped_weapon_id", "rifle")
	var switching: float = sim.nathaniel.get("equip_ready_remaining", 0.0)
	for weapon_id: String in ["rifle", "heavy_rifle"]:
		var owned: bool = weapon_id in sim.nathaniel.get("owned_weapon_ids", ["rifle"])
		var button: Button = buttons[weapon_id]
		button.disabled = build_open or not owned or not CombatRules.alive(sim.nathaniel)
		button.set_pressed_no_signal(weapon_id == equipped)
		button.tooltip_text = "Switch in 0.35 seconds. Movement and targeting continue." if owned else "Walk over a heavy rifle crate to unlock this gun."
	var weapon_name := "Heavy rifle" if equipped == "heavy_rifle" else "Rifle"
	var weapon_state := "Ready"
	if not CombatRules.ready_to_shoot(sim.nathaniel):
		weapon_state = "Recovering"
	if switching > 0.0:
		weapon_state = "Equipping…"
	%WeaponStatus.text = "%s · %s" % [weapon_name, weapon_state]
	_ring.visible = not ring_character.is_empty() and menu.is_empty()
	_placement.visible = not build_kind.is_empty() and menu.is_empty()
	if _placement.visible:
		_placement_label.text = "%s · %d matter · Range %d" % [build_kind.trim_suffix("_tower").capitalize(), GameBalance.COSTS[GameBalance.canonical_kind(build_kind)], sim.hermes_build_range()]
	_layout_ring()
	queue_redraw()


func _fit_hud() -> void:
	if not is_node_ready():
		return
	var safe := safe_rect()
	var bottom := $Bottom as PanelContainer
	var narrow := safe.size.x < 900
	bottom.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bottom.position.x = safe.position.x + (0 if narrow else 472)
	bottom.size.x = safe.size.x - (0 if narrow else 472)
	bottom.size.y = bottom.get_combined_minimum_size().y
	bottom.position.y = safe.end.y - bottom.size.y
	$Characters.set_anchors_preset(Control.PRESET_TOP_LEFT)
	$Characters.position = Vector2(safe.position.x, bottom.position.y - 124 if narrow else safe.end.y - 116)
	$Characters.size = Vector2(456, 116)
	$Top.position = safe.position
	%Pause.set_anchors_preset(Control.PRESET_TOP_LEFT)
	%Pause.position = Vector2(safe.end.x - %Pause.size.x, safe.position.y)
	%Notice.position.y = safe.position.y + 68
	%Notice.offset_bottom = %Notice.offset_top + 48
	if _placement != null:
		_placement.position = Vector2(safe.get_center().x - _placement.size.x / 2, safe.position.y + 68)
	_layout_ring()


func safe_rect() -> Rect2:
	var safe := Rect2(Vector2.ZERO, size)
	if OS.has_feature("mobile"):
		var display := Rect2(DisplayServer.get_display_safe_area())
		var window := Vector2(DisplayServer.window_get_size())
		if window.x > 0 and window.y > 0 and display.has_area():
			safe = safe.intersection(Rect2(display.position * size / window, display.size * size / window))
	return safe.grow(-16)


func play_rect() -> Rect2:
	var safe := safe_rect()
	var bottom: float = minf($Characters.position.y, $Bottom.position.y) - 12
	return Rect2(Vector2(safe.position.x, safe.position.y + 64), Vector2(safe.size.x, maxf(300, bottom - safe.position.y - 64)))


func _make_ring() -> void:
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)
	move_child(_ring, get_node("Modal").get_index())
	for key: String in ["gun_tower", "laser_tower", "heal_tower", "empty", "pack", "settings"]:
		var button := _button("", _ring)
		button.add_theme_font_size_override("font_size", 12)
		var face := get_theme_stylebox("normal", "Button").duplicate() as StyleBoxFlat
		face.border_color = Color("e6ad50") if key not in ["empty", "settings"] else Color("70858a")
		face.set_corner_radius_all(6)
		face.set_border_width_all(2)
		button.add_theme_stylebox_override("normal", face)
		var unavailable := face.duplicate() as StyleBoxFlat
		unavailable.bg_color = Color("26353a")
		unavailable.border_color = Color("70858a")
		button.add_theme_stylebox_override("disabled", unavailable)
		button.custom_minimum_size = Vector2.ZERO
		button.size = Vector2(136, 72)
		button.disabled = key in ["empty", "settings"]
		if key == "settings":
			button.text = "Settings\nNot yet available"
		elif key == "empty":
			button.text = "Empty\nUnassigned"
		elif key.ends_with("_tower"):
			button.icon = CharacterControl.portrait(GameBalance.canonical_kind(key))
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			button.add_theme_constant_override("icon_max_width", 24)
			button.button_down.connect(func() -> void: tower_drag.emit(key))
		else:
			button.pressed.connect(func() -> void: command.emit(key, null))
		ring_buttons[key] = button
	_placement = HBoxContainer.new()
	_placement.add_theme_constant_override("separation", 12)
	_placement.minimum_size_changed.connect(func() -> void: _fit_hud.call_deferred())
	add_child(_placement)
	move_child(_placement, get_node("Modal").get_index())
	_placement_label = Label.new()
	_placement.add_child(_placement_label)
	var cancel := _button("Cancel", _placement)
	cancel.pressed.connect(func() -> void: command.emit("cancel_placement", null))
	_placement.visible = false
	_ring.visible = false


func open_ring(screen: Vector2) -> void:
	ring_character = "hermes"
	ring_actor_position = screen
	_ring_layout_size = Vector2.ZERO
	_layout_ring()
	_ring.show()


func close_ring() -> void:
	ring_character = ""
	if _ring != null:
		_ring.hide()
	queue_redraw()


func _layout_ring() -> void:
	if _ring == null or ring_character.is_empty():
		return
	var offsets := {"gun_tower": Vector2(-142, -56), "laser_tower": Vector2(0, -112), "heal_tower": Vector2(142, -56), "empty": Vector2(142, 56), "pack": Vector2(0, 112), "settings": Vector2(-142, 56)}
	if _ring_layout_size != size:
		var safe := play_rect()
		var half := Vector2(210, 148)
		ring_center = Vector2(clampf(ring_actor_position.x, safe.position.x + half.x, safe.end.x - half.x), clampf(ring_actor_position.y, safe.position.y + half.y, safe.end.y - half.y))
		_ring_layout_size = size
	for key: String in ring_buttons:
		var button: Button = ring_buttons[key]
		button.visible = offsets.has(key)
		if button.visible:
			button.size = Vector2(156 if key == "pack" else (128 if key == "settings" else 112), 72)
			button.position = ring_center + offsets[key] - button.size / 2


func _draw() -> void:
	if character_pressed and menu.is_empty():
		draw_arc(pressed_actor_position, 24, 0, TAU, 48, Color("f0e8d6"), 2, true)
	if ring_character.is_empty() or not menu.is_empty():
		return
	var ochre := Color("e6ad50")
	if ring_center.distance_to(ring_actor_position) > 28:
		draw_line(ring_center, ring_actor_position, ochre, 2, true)
	for index: int in range(6):
		var angle := index * TAU / 6.0
		draw_arc(ring_center, 130, angle - 0.1, angle + 0.1, 12, ochre, 3, true)


func blocks_world_input(screen: Vector2) -> bool:
	for panel: Control in [$Top, $Bottom, $Characters, %Pause, %Modal, _placement]:
		if panel.is_visible_in_tree() and panel.get_global_rect().has_point(screen):
			return true
	if _ring.visible:
		for button: Button in ring_buttons.values():
			if button.visible and button.get_global_rect().has_point(screen):
				return true
	return false


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
	$Characters.visible = $Top.visible
	%Pause.visible = $Top.visible
	if not which.is_empty():
		close_ring()
		_placement.hide()
	for child in %Content.get_children():
		%Content.remove_child(child)
		child.queue_free()
	match which:
		"main":
			_heading("NATHANIEL", "DEMO MODE · SURVIVAL ONLY\nEARTH NEEDS YOU" if demo_mode else "EARTH NEEDS YOU")
			if not demo_mode:
				if context.get("has_progress", false):
					_menu_button("Continue · Level %d" % context.get("continue_level", 1), "level", context.get("continue_level", 1))
				_menu_button("New campaign", "level", 1)
				_menu_button("Select level", "levels")
			_menu_button("Survival", "level", 0)
			_menu_button("Load game", "load_menu")
			_menu_button("Settings", "settings")
			_menu_button("Credits", "credits")
			if not OS.has_feature("web"):
				_menu_button("Quit", "quit")
		"levels":
			_heading("CAMPAIGN", "Choose an encounter")
			for number in range(1, 6):
				var best: Variant = context.get("high_scores", {}).get(str(number))
				var score_text := " · Best %d" % int(best) if best != null else ""
				_menu_button("Level %d%s%s" % [number, "  ✓" if number in context.get("completed", []) else "", score_text], "level", number)
			_menu_button("Back", "main")
		"pause":
			_heading("PAUSED", "Demo mode · Survival only" if demo_mode else "Your orders can wait")
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
			if not demo_mode and context.get("next_level", -1) >= 0:
				_menu_button("Next level", "level", context.next_level)
			_menu_button("Main menu", "main")
		"gameOver":
			_heading("EARTH HAS FALLEN", "Score %d · Time %s" % [context.get("score", 0), _time_text(context.get("elapsed", 0.0))])
			_menu_button("Try again", "level", context.get("level", 1))
			_menu_button("Main menu", "main")
		"credits":
			_heading("NATHANIEL", "Defender of Earth\n\nOriginal game · Ruairi O'Brien\nSpriteKit port · Ruairi O'Brien\nOriginal platform · Windows Phone 7 / XNA\nCurrent engine · Godot 4.7.2\n\nSpecial thanks\nThe XNA Community\nApple Developer Tools")
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
	button.custom_minimum_size = Vector2(52, 48)
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button


func _make_theme(hud: bool = true) -> Theme:
	var result := Theme.new()
	result.default_font_size = 18 if _mobile_controls() else 16
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("102b33" if hud else "142628")
	panel.border_color = Color("507781" if hud else "3d5750")
	panel.set_border_width_all(1)
	panel.content_margin_left = 16
	panel.content_margin_right = 16
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	result.set_stylebox("panel", "PanelContainer", panel)
	var normal := panel.duplicate() as StyleBoxFlat
	normal.bg_color = Color("102b33" if hud else "233b37")
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	result.set_stylebox("normal", "Button", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("234651" if hud else "395d48")
	result.set_stylebox("hover", "Button", hover)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.border_color = Color("e6ad50" if hud else "b4e69b")
	pressed.set_border_width_all(2)
	result.set_stylebox("pressed", "Button", pressed)
	result.set_stylebox("hover_pressed", "Button", pressed)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("26353a" if hud else "192d2a")
	result.set_stylebox("disabled", "Button", disabled)
	result.set_color("font_disabled_color", "Button", Color("9aaaa4"))
	return result


func _mobile_controls() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _fit_menu() -> void:
	if not is_node_ready() or size.y <= 0:
		return
	var panel := $Modal/Center/Panel as PanelContainer
	panel.custom_minimum_size.x = minf(520.0 if _mobile_controls() else 480.0, size.x - 32.0)
	%Scroll.custom_minimum_size.y = minf(%Content.get_combined_minimum_size().y, maxf(100.0, size.y - 80.0))
