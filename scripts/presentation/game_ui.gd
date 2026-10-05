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


func _ready() -> void:
	theme = _make_theme()
	resized.connect(_fit_menu)
	$Bottom.minimum_size_changed.connect(func() -> void: _fit_hud.call_deferred())
	resized.connect(func() -> void: _fit_hud.call_deferred())
	%Content.minimum_size_changed.connect(func() -> void: _fit_menu.call_deferred())
	%Nathaniel.pressed.connect(func() -> void: command.emit("focus", "nathaniel"))
	%Pause.pressed.connect(func() -> void: command.emit("pause", null))
	%Nathaniel.tooltip_text = "Return the camera to Nathaniel and close Build. Space also returns to Nathaniel."
	%Modal.gui_input.connect(func(event: InputEvent) -> void:
		if menu in ["victory", "gameOver"] and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			command.emit("continue_result", null)
	)
	for item: Array in [["Fire Nathaniel", "fire"], ["Stop Nathaniel [S]", "stop"], ["Deliver cargo", "deliver"], ["Follow [R]", "follow"], ["Stop Hermes [R]", "hermes_stop"], ["Build [B]", "build"], ["Gun · 5", "gun_tower"], ["Laser · 10", "laser_tower"], ["Heal · 15", "heal_tower"], ["−", "zoom_out"], ["+", "zoom_in"]]:
		var is_tower := String(item[1]).ends_with("_tower")
		var button := _button(item[0], %Towers if is_tower else %Commands)
		buttons[item[1]] = button
		if is_tower:
			button.toggle_mode = true
			button.button_down.connect(func() -> void: tower_drag.emit(item[1]))
		else:
			button.pressed.connect(func() -> void: command.emit(item[1], null))
	buttons.build.toggle_mode = true
	buttons.fire.tooltip_text = "Nathaniel fires at his current enemy target. F fires toward the pointer."
	buttons.stop.tooltip_text = "Stop Nathaniel's movement. Automatic combat continues."
	buttons.deliver.tooltip_text = "Return to Hermes to feed carried bundles into his furnace. Each body supplies 10 resources."
	buttons.hermes_stop.tooltip_text = "Deploy Hermes as a stationary cannon base. Follow packs the base away."
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
	_fit_hud.call_deferred()


func _process(delta: float) -> void:
	if notice_time > 0:
		notice_time -= delta
		if notice_time <= 0:
			%Notice.text = ""


func update_game(sim: GameSimulation, fog_enabled: bool = true) -> void:
	%Nathaniel.text = "Nathaniel\n%d / %d" % [sim.nathaniel.get("hp", 0), sim.nathaniel.get("max_hp", 8000)]
	%Hermes.text = "Hermes\n%d / %d" % [sim.hermes.get("hp", 0), sim.hermes.get("max_hp", 2000)]
	%NathanielTarget.text = _target_text(sim, sim.nathaniel, fog_enabled)
	%HermesTarget.text = _target_text(sim, sim.hermes, fog_enabled)
	%Nathaniel.set_pressed_no_signal(sim.focused_character == "nathaniel")
	var mode_label := "DEMO · SURVIVAL" if demo_mode else ("SURVIVAL" if sim.config.get("number", 0) == 0 else "LEVEL %d" % sim.config.get("number", 1))
	%Stats.text = "Resources %d · Lives %d · Score %d\n%s\n%s  %s" % [sim.resources, sim.lives, sim.score, _cargo_text(sim), mode_label, _time_text(sim.elapsed_time)]
	var following := sim.hermes_mode == "following"
	var tower_count := 0
	var refund := 0
	for entity: Dictionary in sim.entities:
		if entity.tower and entity.hp > 0:
			tower_count += 1
			if entity.owned:
				refund += int(entity.construction_cost) / 4
	var instruction := "Ground moves Nathaniel. Select an enemy to attack. Space returns to Nathaniel."
	if build_open:
		instruction = "Build inside the amber ring. " + ("The first tower deploys Hermes." if following else "Towers need Hermes's base.")
	if not build_kind.is_empty():
		instruction = "Place %s inside the amber ring. Escape cancels." % build_kind.replace("_", " ")
	if tower_count > 0:
		var follow_instruction := "Follow reclaims %d linked tower%s; refund: %d." % [tower_count, "" if tower_count == 1 else "s", refund]
		instruction = instruction + " " + follow_instruction if build_open else follow_instruction
	var hermes_state := "Following" if following else "Anchored · Cannon active"
	if not CombatRules.alive(sim.hermes):
		hermes_state = "Destroyed"
	%Status.text = "Nathaniel: %s · Hermes: %s · Camera: %s\n%s" % [_nathaniel_state(sim), hermes_state, sim.focused_character.capitalize(), instruction]
	%Towers.visible = build_open
	buttons.deliver.disabled = not sim.nathaniel.get("has_corpse", false) or not CombatRules.alive(sim.hermes) or not CombatRules.alive(sim.nathaniel)
	for upgrade: String in ["capacity", "reach"]:
		var cost: int = sim.gathering_upgrade_cost(upgrade)
		var button: Button = buttons["upgrade_" + upgrade]
		var label := "Cargo slot" if upgrade == "capacity" else "Arm reach"
		button.text = "%s · %d" % [label, cost] if cost >= 0 else "%s · Max" % label
		button.disabled = cost < 0 or sim.resources < cost or not CombatRules.alive(sim.nathaniel) or not CombatRules.alive(sim.hermes)
		button.tooltip_text = "All upgrades fitted." if cost < 0 else "Costs %d resources. %s" % [cost, "Add one visible cargo clamp." if upgrade == "capacity" else "Reach more distant bodies with the same two arms."]
	for kind: String in ["gun_tower", "laser_tower", "heal_tower"]:
		var cost := int(GameBalance.COSTS[GameBalance.canonical_kind(kind)])
		buttons[kind].disabled = sim.resources < cost or not CombatRules.alive(sim.hermes)
		buttons[kind].set_pressed_no_signal(build_kind == kind)
		buttons[kind].tooltip_text = "Costs %d resources. %s" % [cost, "Need %d more resources." % (cost - sim.resources) if sim.resources < cost else "Place inside Hermes's amber build ring. Towers need his base to survive."]
	buttons.follow.visible = not following
	buttons.follow.text = "Follow · +%d [R]" % refund if tower_count > 0 else "Follow [R]"
	buttons.follow.tooltip_text = "Pack the base and follow Nathaniel. " + ("Reclaims %d linked towers and refunds %d resources." % [tower_count, refund] if tower_count > 0 else "")
	buttons.hermes_stop.visible = following
	buttons.hermes_stop.text = "Deploy Hermes [R]"
	buttons.build.text = "Close Build [B]" if build_open else "Build [B]"
	buttons.build.set_pressed_no_signal(build_open)
	buttons.build.tooltip_text = "Close tower choices and return to Nathaniel." if build_open else "Show Hermes's build range and tower choices. A valid build deploys his cannon base."
	var equipped: String = sim.nathaniel.get("equipped_weapon_id", "rifle")
	var switching: float = sim.nathaniel.get("equip_ready_remaining", 0.0)
	for weapon_id: String in ["rifle", "heavy_rifle"]:
		var owned: bool = weapon_id in sim.nathaniel.get("owned_weapon_ids", ["rifle"])
		var button: Button = buttons[weapon_id]
		button.disabled = not owned or not CombatRules.alive(sim.nathaniel)
		button.set_pressed_no_signal(weapon_id == equipped)
		button.tooltip_text = "Switch in 0.35 seconds. Movement and targeting continue." if owned else "Walk over a heavy rifle crate to unlock this gun."
	var weapon_name := "Heavy rifle" if equipped == "heavy_rifle" else "Rifle"
	var weapon_state := "Ready"
	if not CombatRules.ready_to_shoot(sim.nathaniel):
		weapon_state = "Recovering"
	if switching > 0.0:
		weapon_state = "Equipping…"
	%WeaponStatus.text = "%s · %s" % [weapon_name, weapon_state]


func _cargo_text(sim: GameSimulation) -> String:
	var count: int = sim.carried_resource_count()
	var phase: String = sim.gathering_state().phase
	var capacity: int = int(sim.nathaniel.get("resource_capacity", 1))
	var status: String = {"grab": "Grabbing", "crush": "Crushing", "present": "Presenting", "feed": "Feeding Hermes"}.get(phase, "")
	if status.is_empty() and count >= capacity:
		status = "Full · Deliver to Hermes"
	elif status.is_empty():
		status = "Approach a body to collect" if count == 0 else "Ready to deliver"
	return "Cargo %d / %d · %s" % [count, capacity, status]


func _fit_hud() -> void:
	if not is_node_ready():
		return
	var bottom := $Bottom as PanelContainer
	bottom.offset_top = -16.0 - bottom.get_combined_minimum_size().y


func _nathaniel_state(sim: GameSimulation) -> String:
	var player := sim.nathaniel
	if player.get("hp", 0) <= 0:
		return "Down"
	var moving: bool = player.get("moving", false)
	var target := sim.entity(int(player.get("target_id", -1)))
	var targeting := CombatRules.alive(target)
	var attacking := targeting and CombatRules.distance(player, target) <= float(player.range)
	if not moving and player.get("destination") != null:
		return "Blocked"
	if moving:
		return "Moving / attacking" if attacking else ("Moving / targeting" if targeting else "Moving")
	return "Attacking" if attacking else ("Targeting" if targeting else "Idle")


func _target_text(sim: GameSimulation, unit: Dictionary, fog_enabled: bool) -> String:
	if not CombatRules.alive(unit):
		return "Target: None\nDown"
	var target := sim.entity(int(unit.get("target_id", -1)))
	if not CombatRules.alive(target):
		return "Target: None\nAutomatic targeting"
	var source := "Selected" if int(unit.get("manual_target_id", -1)) == int(target.id) else "Auto"
	if fog_enabled and sim.visibility_at(target.position) < 2:
		return "Target: Out of sight\n%s" % source
	var reach := "In range" if CombatRules.distance(unit, target) <= float(unit.range) else "Out of range"
	return "Target: %s · %d HP\n%s · %s" % [String(target.kind).capitalize(), int(target.hp), source, reach]


func blocks_world_input(screen: Vector2) -> bool:
	for panel: Control in [$Top, $Bottom, %Modal]:
		if panel.is_visible_in_tree() and panel.get_global_rect().has_point(screen):
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
	button.custom_minimum_size = Vector2(60, 48) if _mobile_controls() else Vector2(52, 44)
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button


func _make_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 18 if _mobile_controls() else 16
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
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	result.set_stylebox("normal", "Button", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("395d48")
	result.set_stylebox("hover", "Button", hover)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.border_color = Color("b4e69b")
	pressed.set_border_width_all(2)
	result.set_stylebox("pressed", "Button", pressed)
	result.set_stylebox("hover_pressed", "Button", pressed)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("192d2a")
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
