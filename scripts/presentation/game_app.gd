class_name GameApp
extends Node2D
## Composes input, scenes, storage, and audio around the gameplay domain.

var sim: GameSimulation
var level: GameLevel
var views: Dictionary = {}
var save_store: GameSaveStore
var settings: GameSettingsStore
var progress: GameProgressStore
var game_input: GameInput
var audio: GameAudio
var effects: WorldEffects
var fog: FogView
var camera_zoom := 1.0
var return_menu := "main"
var storage_root := "user://"
var _displayed_result := "playing"
var _scene_cache: Dictionary = {}
var _debug: Node
var _debug_bridge: RefCounted
var _scenery: Node2D
@onready var ui: GameUI = $Interface/GameUI
@onready var camera: Camera2D = $Camera


func _ready() -> void:
	if OS.has_feature("mobile"):
		get_tree().root.content_scale_size = Vector2i(960, 540)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--storage-dir="):
			storage_root = argument.trim_prefix("--storage-dir=").trim_suffix("/") + "/"
	save_store = GameSaveStore.new(storage_root.path_join("saves"))
	settings = GameSettingsStore.new(storage_root.path_join("settings.json"))
	progress = GameProgressStore.new(storage_root.path_join("progress.json"))
	game_input = GameInput.new()
	game_input.app = self
	add_child(game_input)
	audio = GameAudio.new()
	add_child(audio)
	audio.apply_settings(settings.music_enabled, settings.sound_effects_enabled)
	effects = preload("res://scenes/effects/world_effects.tscn").instantiate() as WorldEffects
	$World.add_child(effects)
	fog = FogView.new()
	fog.z_index = 10
	fog.enabled = settings.fog_enabled
	$World.add_child(fog)
	ui.command.connect(command)
	ui.tower_drag.connect(game_input.begin_tower_drag)
	show_main()
	_import_cli_file()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			load_level(int(argument.trim_prefix("--level=")))
		if argument == "--debug-server" or argument.begins_with("--debug-port="):
			_start_debug(int(argument.trim_prefix("--debug-port=")) if argument.begins_with("--debug-port=") else 8766)


func load_level(number: int) -> bool:
	if number < 0 or number > 5:
		return false
	var packed := load("res://levels/level_%d.tscn" % number) as PackedScene
	if packed == null:
		ui.show_notice("Could not load level %d" % number)
		return false
	start_level_scene(packed.instantiate() as GameLevel)
	return true


func start_level_scene(new_level: GameLevel) -> void:
	if _scenery != null:
		_scenery.get_parent().remove_child(_scenery)
		_scenery.queue_free()
		_scenery = null
	if level != null and level != new_level:
		$World.remove_child(level)
		level.queue_free()
	_clear_views()
	level = new_level
	if level.get_parent() != null:
		level.reparent($World)
	else:
		$World.add_child(level)
	$World.move_child(level, 0)
	level.position = Vector2.ZERO
	_scenery = level.get_node_or_null("Scenery") as Node2D
	if _scenery != null:
		_scenery.reparent($World/Actors)
		_scenery.y_sort_enabled = true
	sim = GameSimulation.new()
	sim.configure(level.data())
	effects.simulation = sim
	fog.simulation = sim
	_displayed_result = "playing"
	ui.build_kind = ""
	ui.build_open = false
	game_input.drag_kind = ""
	ui.show_menu("")
	return_menu = "pause"
	camera.position = IsoProjection.project(sim.nathaniel.position)
	_update_camera(1.0, true)
	var track := "gameMusic"
	if level.definition.number == 2:
		track = "gameMusic2"
	elif level.definition.number == 3:
		track = "gameMusic3"
	audio.play_music(track)
	_sync_views()


func _physics_process(delta: float) -> void:
	if sim == null:
		return
	sim.step(delta)
	var events := sim.take_events()
	effects.add_events(events)
	for event: Dictionary in events:
		if event.get("type", "") == "sound":
			audio.play_effect(event.get("name", "gunShot"))
		elif event.get("type", "") == "shot":
			audio.play_effect("arrowShot" if event.get("kind") == "arrow" else "gunShot")
		elif event.get("type", "") == "laser":
			audio.play_effect("laserFire")
		elif event.get("type", "") == "death":
			audio.play_effect("explosion")
		elif event.get("type", "") == "respawn" and sim.result == "playing":
			ui.show_notice("Life lost · %d spare lives remain" % sim.lives)
	_sync_views()
	ui.update_game(sim)
	_update_camera(delta)
	effects.placement = not ui.build_kind.is_empty() and ui.menu.is_empty()
	effects.cursor_world = screen_to_world(get_viewport().get_mouse_position())
	if effects.placement:
		effects.placement_valid = sim.placement_error(effects.cursor_world) == "valid"
	if sim.result != "playing" and sim.result != "paused" and _displayed_result != sim.result:
		_displayed_result = sim.result
		if sim.result == "victory":
			progress.record_completion(level.definition.number, sim.score, sim.elapsed_time)
		ui.show_notice("")
		ui.show_menu(sim.result, {"level": level.definition.number, "next_level": level.definition.next_level, "score": sim.score, "elapsed": sim.elapsed_time})


func _sync_views() -> void:
	var live: Dictionary = {}
	for entity: Dictionary in sim.entities:
		if float(entity.get("hp", 0)) <= 0:
			continue
		var id: int = entity.id
		live[id] = true
		if not views.has(id):
			var kind: String = {"gunTower": "gun_tower", "laserTower": "laser_tower", "healTower": "heal_tower"}.get(entity.kind, entity.kind)
			var path := "res://scenes/actors/%s.tscn" % kind
			if not ResourceLoader.exists(path):
				continue
			if not _scene_cache.has(kind):
				_scene_cache[kind] = load(path)
			var view: ActorView = _scene_cache[kind].instantiate()
			$World/Actors.add_child(view)
			views[id] = view
		var actor: ActorView = views[id]
		actor.apply_state(entity, entity.kind == sim.focused_character)
		actor.visible = entity.kind in ["nathaniel", "hermes"] or not fog.enabled or sim.visibility_at(entity.position) == 2
	for id: int in views.keys():
		if not live.has(id):
			views[id].queue_free()
			views.erase(id)


func _clear_views() -> void:
	for view: Node in views.values():
		view.queue_free()
	views.clear()


func screen_to_world(screen: Vector2) -> Vector2:
	return IsoProjection.unproject($World.get_global_transform_with_canvas().affine_inverse() * screen)


func world_to_screen(world: Vector2) -> Vector2:
	return $World.get_global_transform_with_canvas() * IsoProjection.project(world)


func world_click(screen: Vector2) -> void:
	if sim == null or not ui.menu.is_empty():
		return
	if not ui.build_kind.is_empty():
		if place_at(ui.build_kind, screen):
			ui.build_kind = ""
		return
	var target_id := -1
	var nearest := 42.0
	for entity: Dictionary in sim.entities:
		if entity.get("hp", 0) <= 0 or (sim.visibility_at(entity.position) != 2 and fog.enabled):
			continue
		var distance := (world_to_screen(entity.position) - Vector2(0, 20 * camera_zoom)).distance_to(screen)
		if distance < nearest:
			target_id = entity.id
			nearest = distance
	if target_id >= 0:
		var entity: Dictionary = sim.entity(target_id)
		if entity.kind == "nathaniel":
			sim.focused_character = "nathaniel"
		elif entity.kind == "hermes":
			if sim.focused_character == "nathaniel" and sim.nathaniel.get("has_corpse", false) and sim.hermes_mode == "building":
				sim.move_to(entity.position)
			else:
				sim.focused_character = "hermes"
		elif entity.kind in ["grunt", "soldier", "boss", "spawner"]:
			sim.target_enemy(target_id)
	else:
		sim.move_to(screen_to_world(screen))


func place_at(kind: String, screen: Vector2) -> bool:
	if sim == null or not ui.menu.is_empty():
		return false
	var world := screen_to_world(screen)
	var error := sim.placement_error(world)
	if error != "valid":
		ui.show_notice({"blockedByTerrain": "Choose clear ground away from the map edge.", "overlapsStructure": "A tower is already here.", "overlapsEnemy": "An enemy blocks this location.", "overlapsCharacter": "A character blocks this location.", "overlapsResource": "Collect the corpse before building here."}.get(error, error))
		return false
	var placed := sim.place_tower(kind, world)
	if not placed:
		ui.show_notice("Not enough resources, or Hermes is not in build mode.")
	return placed


func change_zoom(factor: float) -> void:
	if sim == null or not ui.menu.is_empty():
		return
	camera_zoom = clampf(camera_zoom * factor, 0.5, 2.0)
	camera.zoom = Vector2.ONE * camera_zoom
	_update_camera(1.0, true)


func _update_camera(delta: float, immediate: bool = false) -> void:
	if sim == null:
		return
	var target: Dictionary = sim.hermes if sim.focused_character == "hermes" else sim.nathaniel
	var world_size := Vector2(sim.config.width, sim.config.height) * float(sim.config.tile_size)
	var point := IsoProjection.clamp_camera(IsoProjection.project(target.position), world_size, get_viewport_rect().size, camera_zoom)
	camera.position = point if immediate else camera.position.lerp(point, 1.0 - exp(-8.0 * delta))


func show_main() -> void:
	_clear_views()
	if level != null:
		level.get_parent().remove_child(level)
		level.queue_free()
		level = null
	if _scenery != null:
		_scenery.get_parent().remove_child(_scenery)
		_scenery.queue_free()
		_scenery = null
	sim = null
	effects.simulation = null
	fog.simulation = null
	effects.placement = false
	ui.build_kind = ""
	ui.build_open = false
	game_input.drag_kind = ""
	ui.show_menu("main", {"in_game": false, "continue_level": progress.continue_level(), "has_progress": int(progress.data.highest_level_completed) > 0})
	audio.play_music("menuMusic")
	return_menu = "main"


func command(action: String, value: Variant = null) -> void:
	if sim != null and sim.result in ["victory", "gameOver"] and action not in ["main", "level", "quit", "continue_result"]:
		return
	if action in ["pause", "settings", "credits", "save_menu", "load_menu", "resume", "exit_menu"]:
		ui.build_kind = ""
		ui.build_open = false
		game_input.drag_kind = ""
	match action:
		"main":
			show_main()
		"exit_menu":
			if sim != null:
				sim.set_paused(true)
				return_menu = "pause"
				ui.show_menu("confirm_exit")
		"level":
			load_level(int(value))
		"continue_result":
			if sim == null:
				return
			if sim.result == "gameOver":
				load_level(sim.level_number)
			elif sim.result == "victory":
				if level.definition.next_level < 0:
					show_main()
				else:
					load_level(level.definition.next_level)
		"levels":
			var completed: Array[int] = []
			for number in range(1, 6):
				if progress.is_level_completed(number):
					completed.append(number)
			ui.show_menu("levels", {"completed": completed, "high_scores": progress.data.level_high_scores, "in_game": false})
		"settings", "credits":
			return_menu = "pause" if sim != null else "main"
			if sim != null:
				sim.set_paused(true)
			ui.show_menu(action, {"music_enabled": settings.music_enabled, "sound_effects_enabled": settings.sound_effects_enabled, "fog_enabled": fog.enabled, "in_game": return_menu == "pause"})
		"setting":
			if value.has("music_enabled"):
				settings.music_enabled = value.music_enabled
			if value.has("sound_effects_enabled"):
				settings.sound_effects_enabled = value.sound_effects_enabled
			if value.has("fog_enabled"):
				fog.enabled = value.fog_enabled
				settings.fog_enabled = value.fog_enabled
			var saved_settings := settings.save()
			if not saved_settings.success:
				ui.show_notice("Could not save settings: " + saved_settings.error)
			audio.apply_settings(settings.music_enabled, settings.sound_effects_enabled)
		"save_menu", "load_menu":
			return_menu = "main" if sim == null else "pause"
			if sim != null:
				sim.set_paused(true)
			ui.show_menu("save" if action == "save_menu" else "load", {"slots": save_store.list_slots(), "in_game": return_menu == "pause"})
		"save_slot":
			if FileAccess.file_exists(save_store.slot_path(int(value))):
				ui.show_menu("confirm_save", {"slot": value})
			else:
				_save(int(value))
		"confirm_save":
			_save(int(value))
		"load_slot":
			_load(int(value))
		"back":
			if return_menu == "main":
				show_main()
			else:
				ui.show_menu(return_menu)
		"quit":
			get_tree().quit()
		"escape":
			if not ui.build_kind.is_empty():
				ui.build_kind = ""
			elif ui.menu.is_empty():
				command("pause")
			elif ui.menu == "pause":
				command("resume")
			elif ui.menu not in ["main", "victory", "gameOver"]:
				command("back")
		"pause":
			if sim != null and sim.result == "playing":
				sim.set_paused(true)
				ui.show_menu("pause")
		"resume":
			if sim != null:
				sim.set_paused(false)
				ui.show_menu("")
		_:
			_game_command(action, value)


func _game_command(action: String, value: Variant) -> void:
	if sim == null or not ui.menu.is_empty():
		return
	match action:
		"focus":
			sim.focused_character = value
			if value == "nathaniel":
				ui.build_kind = ""
				ui.build_open = false
				game_input.drag_kind = ""
		"switch_focus":
			sim.focused_character = "hermes" if sim.focused_character == "nathaniel" else "nathaniel"
			ui.build_kind = ""
			ui.build_open = false
			game_input.drag_kind = ""
		"fire":
			sim.fire()
		"fire_at_pointer":
			sim.fire_at(screen_to_world(get_viewport().get_mouse_position()))
		"stop":
			sim.stop_player()
		"follow":
			sim.set_hermes_mode("following")
			ui.build_kind = ""
			ui.build_open = false
			game_input.drag_kind = ""
		"hermes_stop":
			sim.set_hermes_mode("stopped")
		"build":
			if sim.hermes_mode == "building" and sim.focused_character == "hermes":
				ui.build_open = not ui.build_open
				ui.build_kind = ""
		"toggle_hermes":
			sim.set_hermes_mode("stopped" if sim.hermes_mode == "following" else "following")
			ui.build_kind = ""
			ui.build_open = false
			game_input.drag_kind = ""
		"gun_tower", "laser_tower", "heal_tower":
			ui.build_kind = action
		"zoom_in":
			change_zoom(1.15)
		"zoom_out":
			change_zoom(1.0 / 1.15)


func _save(slot: int) -> void:
	if sim == null:
		return
	var result := save_store.save_slot(slot, sim.snapshot(), "Level %d · %d resources" % [level.definition.number, sim.resources])
	ui.show_notice("Saved to slot %d" % slot if result.success else result.error)
	ui.show_menu("pause")


func _load(slot: int) -> void:
	var result := save_store.load_slot(slot)
	if not result.success:
		ui.show_notice(result.error)
		return
	var snapshot: Dictionary = result.state
	var number: int = snapshot.get("level", {}).get("number", 1)
	if not load_level(number):
		return
	if not sim.restore(snapshot):
		ui.show_notice("Save could not be restored")
		return
	sim.set_paused(false)
	ui.show_menu("")
	_sync_views()
	_update_camera(1.0, true)


func _start_debug(port: int) -> void:
	if _debug != null or not OS.is_debug_build() or OS.has_feature("web"):
		return
	var bridge_script := load("res://scripts/presentation/debug_bridge.gd") as GDScript
	_debug_bridge = bridge_script.new(self)
	_debug = _debug_bridge.start(port)


func _import_cli_file() -> void:
	var arguments := OS.get_cmdline_user_args()
	var source: String = ""
	var slot_text: String = "1"
	for index: int in arguments.size():
		var argument: String = arguments[index]
		if argument.begins_with("--import-swift="):
			source = argument.trim_prefix("--import-swift=")
		elif argument == "--import-swift" and index + 1 < arguments.size():
			source = arguments[index + 1]
		elif argument.begins_with("--slot="):
			slot_text = argument.trim_prefix("--slot=")
		elif argument == "--slot" and index + 1 < arguments.size():
			slot_text = arguments[index + 1]
	if source.is_empty():
		return
	if not slot_text.is_valid_int() or int(slot_text) not in [1, 2, 3]:
		push_error("Swift import failed: --slot must be 1, 2, or 3")
		ui.show_notice("Swift import failed: slot must be 1, 2, or 3")
		return
	var imported := import_swift_save(source, int(slot_text))
	if not imported.success:
		push_error("Swift import failed: " + imported.error)
		ui.show_notice("Swift import failed: " + imported.error)
		return
	print("Imported Swift save into Godot slot %s" % slot_text)
	for warning: String in imported.get("warnings", []):
		print("Save import: " + warning)
	_load(int(slot_text))


func import_swift_save(path: String, slot: int) -> Dictionary:
	# Scene ownership stays here; storage validates and writes the supplied data.
	var config: Dictionary = {}
	var source := GameAtomicJSON.read_file(path)
	if source.success and GameAtomicJSON.is_integer(source.data.get("levelNumber")):
		var number := int(source.data.levelNumber)
		if number in [0, 1, 2, 3, 4, 5]:
			var packed := load("res://levels/level_%d.tscn" % number) as PackedScene
			if packed != null:
				var source_level := packed.instantiate() as GameLevel
				config = source_level.data()
				source_level.free()
	return save_store.import_swift_file(path, slot, config)
