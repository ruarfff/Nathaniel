class_name GameApp
extends Node2D
## Composes input, scenes, storage, and audio around the gameplay domain.

const CAMERA_FOCUS_DURATION := 0.28

var sim: GameSimulation
var level: GameLevel
var views: Dictionary = {}
var pickup_views: Dictionary = {}
var tech_views: Dictionary = {}
var _retiring_centers: Array[ResearchCenterView] = []
var _tech_collection := TechCollectionView.new()
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
var demo_mode := OS.has_feature("demo")
var map_selection_override := ""
var map_selection_rng := RandomNumberGenerator.new()
var _displayed_result := "playing"
var _scene_cache: Dictionary = {}
var _debug: Node
var _debug_bridge: RefCounted
var _scenery: Node2D
var _camera_focus_from := Vector2.ZERO
var _camera_focus_zoom := 1.0
var _camera_focus_elapsed := CAMERA_FOCUS_DURATION
@onready var ui: GameUI = $Interface/GameUI
@onready var camera: Camera2D = $Camera


func _init() -> void:
	map_selection_rng.randomize()


func _ready() -> void:
	if OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android"):
		get_tree().root.content_scale_size = Vector2i(960, 540)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--storage-dir="):
			storage_root = argument.trim_prefix("--storage-dir=").trim_suffix("/") + "/"
		elif argument == "--demo":
			demo_mode = true
		elif argument.begins_with("--survival-map="):
			map_selection_override = argument.trim_prefix("--survival-map=")
	if demo_mode:
		storage_root = storage_root.path_join("demo") + "/"
	ui.demo_mode = demo_mode
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
	effects.actor_layer = $World/Actors
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
		elif argument.begins_with("--survival-map="):
			start_survival_run()
		if argument == "--debug-server" or argument.begins_with("--debug-port="):
			_start_debug(int(argument.trim_prefix("--debug-port=")) if argument.begins_with("--debug-port=") else 8766)


func load_level(number: int) -> bool:
	if demo_mode and number != 0:
		ui.show_notice("Demo mode includes Survival only.")
		return false
	if number < 0 or number > 5:
		return false
	var packed := load("res://levels/level_%d.tscn" % number) as PackedScene
	if packed == null:
		ui.show_notice("Could not load level %d" % number)
		return false
	start_level_scene(packed.instantiate() as GameLevel)
	return true


func start_survival_run() -> bool:
	var map_id := map_selection_override
	if not map_id.is_empty() and map_id not in SurvivalMapCatalog.NEW_RUN_IDS:
		ui.show_notice("Unknown new-run survival map identifier: " + map_id)
		return false
	if map_id.is_empty():
		map_id = SurvivalMapCatalog.choose(map_selection_rng)
	return load_survival_map(map_id)


func load_survival_map(map_id: String) -> bool:
	var path := SurvivalMapCatalog.scene_path(map_id)
	if path.is_empty():
		ui.show_notice("Unknown survival map identifier: " + map_id)
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		ui.show_notice("Could not load survival map: " + map_id)
		return false
	var new_level := packed.instantiate() as GameLevel
	if new_level == null:
		ui.show_notice("Invalid survival map scene: " + map_id)
		return false
	start_level_scene(new_level)
	return true


func retry_level() -> bool:
	if sim == null:
		return false
	if sim.level_number == 0:
		return load_survival_map(sim.survival_map_id)
	return load_level(sim.level_number)


func start_level_scene(new_level: GameLevel) -> void:
	if demo_mode and new_level.definition.number != 0:
		ui.show_notice("Demo mode includes Survival only.")
		new_level.queue_free()
		return
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
	effects.delivery_pulse_time = 0.0
	fog.simulation = sim
	_displayed_result = "playing"
	ui.build_open = false
	ui.close_ring()
	effects.build_open = false
	game_input.cancel_tower_drag()
	ui.show_notice(SurvivalMapCatalog.title(sim.survival_map_id) if sim.level_number == 0 else "")
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
	for event: Dictionary in events:
		if event.get("type", "") in ["death", "recycle"]:
			var removed_id := int(event.get("owner_id", event.get("entity_id", event.get("target_id", -1))))
			if views.get(removed_id) is ResearchCenterView:
				var retired: ResearchCenterView = views[removed_id]
				retired.begin_removal("recycled" if event.type == "recycle" else "destroyed")
				_retiring_centers.append(retired)
				views.erase(removed_id)
		elif event.get("type", "") == "research_purchased":
			var center_view: ActorView = views.get(int(event.get("center_id", -1)))
			if center_view is ResearchCenterView:
				center_view.notify_research()
		if event.get("type", "") == "sound":
			audio.play_effect(event.get("name", "gunShot"))
		elif event.get("type", "") == "shot":
			audio.play_effect("arrowShot" if event.get("kind") == "arrow" else "gunShot")
		elif event.get("type", "") == "laser":
			audio.play_effect("laserFire")
		elif event.get("type", "") == "death":
			audio.play_effect("explosion")
			if event.get("target_kind", event.get("kind", "")) in ["nathaniel", "hermes"] or not CombatRules.alive(sim.nathaniel) or not CombatRules.alive(sim.hermes):
				game_input.cancel_world_tap()
				_set_build_open(false)
		elif event.get("type", "") == "weapon_collected":
			var weapon_name := "Heavy rifle" if event.weapon_id == "heavy_rifle" else "Rifle"
			ui.show_notice("%s collected · choose its weapon button to equip." % weapon_name)
		elif event.get("type", "") == "tech_collected":
			ui.show_notice("+%d Tech" % int(event.get("amount", 1)))
		elif event.get("type", "") == "respawn" and sim.result == "playing":
			ui.show_notice("Life lost · %d spare lives remain" % sim.lives)
	if ui.menu == "research" and not bool(sim.research_state().get("active", false)):
		_close_research()
	_sync_views()
	var pulsed_healers: Dictionary = {}
	for event: Dictionary in events:
		if event.get("type", "") == "respawn" and views.has(int(sim.nathaniel.id)):
			(views[int(sim.nathaniel.id)] as ActorView).notify_respawn()
		elif event.get("type", "") in ["shot", "laser"]:
			var owner_id: int = int(event.get("owner_id", -1))
			if views.has(owner_id):
				(views[owner_id] as ActorView).notify_attack(event.get("direction", Vector2.ZERO), event.get("weapon_id", ""))
		elif event.get("type", "") == "heal":
			var owner_id: int = int(event.get("owner_id", -1))
			if views.has(owner_id) and not pulsed_healers.has(owner_id):
				(views[owner_id] as ActorView).notify_heal()
				pulsed_healers[owner_id] = true
	effects.add_events(events, views)
	ui.update_game(sim, fog.enabled)
	effects.build_open = ui.build_open and ui.menu.is_empty()
	if not sim.paused:
		_update_camera(delta)
	_update_character_hud()
	effects.placement = not ui.build_kind.is_empty() and ui.menu.is_empty() and not ui.blocks_world_input(game_input.pointer_position)
	effects.cursor_world = screen_to_world(game_input.pointer_position)
	if effects.placement:
		effects.placement_valid = sim.resources >= int(GameBalance.COSTS.get(GameBalance.canonical_kind(ui.build_kind), 0)) and sim.placement_error(effects.cursor_world) == "valid"
	if sim.result != "playing" and sim.result != "paused" and _displayed_result != sim.result:
		_displayed_result = sim.result
		if sim.result == "victory":
			progress.record_completion(level.definition.number, sim.score, sim.elapsed_time)
		ui.show_notice("")
		ui.show_menu(sim.result, {"level": level.definition.number, "next_level": level.definition.next_level, "score": sim.score, "elapsed": sim.elapsed_time})


func _sync_views() -> void:
	effects.fog_enabled = fog.enabled
	var target_highlights := effects.target_highlights()
	var selected_tower: Dictionary = sim.entity(effects.selected_healing_tower_id)
	if not CombatRules.alive(selected_tower) or selected_tower.get("kind") != "healTower" or (fog.enabled and sim.visibility_at(selected_tower.position) != 2):
		effects.selected_healing_tower_id = -1
	var live: Dictionary = {}
	for entity: Dictionary in sim.entities:
		if float(entity.get("hp", 0)) <= 0:
			continue
		var id: int = entity.id
		live[id] = true
		if not views.has(id):
			var kind: String = {"gunTower": "gun_tower", "laserTower": "laser_tower", "healTower": "heal_tower", "researchCenter": "research_center", "gunSoldier": "gun_soldier"}.get(entity.kind, entity.kind)
			var path := "res://scenes/actors/%s.tscn" % kind
			if not ResourceLoader.exists(path):
				continue
			if not _scene_cache.has(kind):
				_scene_cache[kind] = load(path)
			var view: ActorView = _scene_cache[kind].instantiate()
			$World/Actors.add_child(view)
			views[id] = view
		var actor: ActorView = views[id]
		actor.apply_state(entity, entity.kind == "nathaniel" or (entity.kind == "hermes" and ui.build_open) or id == effects.selected_healing_tower_id, sim.result == "playing" and not sim.paused, true)
		actor.set_target_highlight(target_highlights.get(id, Color.WHITE), effects.target_tint_strength)
		actor.visible = entity.kind in ["nathaniel", "hermes"] or not fog.enabled or sim.visibility_at(entity.position) == 2
	for id: int in views.keys():
		if not live.has(id):
			views[id].queue_free()
			views.erase(id)
	if views.has(int(sim.nathaniel.id)):
		var player_view: ActorView = views[int(sim.nathaniel.id)]
		player_view.sync_gathering(sim.corpses, sim.nathaniel, sim.hermes, views.get(int(sim.hermes.id)) as ActorView)
		_tech_collection.sync(player_view.model_view, sim.tech_pickups, sim.nathaniel, not sim.paused and sim.result == "playing")
	if views.has(int(sim.hermes.id)):
		(views[int(sim.hermes.id)] as ActorView).sync_intake(sim.corpses, sim.nathaniel, sim.hermes)
	_sync_pickup_views()
	_sync_tech_views()
	_retiring_centers = _retiring_centers.filter(func(view: ResearchCenterView) -> bool: return is_instance_valid(view))
	for view: ResearchCenterView in _retiring_centers:
		view._playback_enabled = not sim.paused and sim.result == "playing"
	effects.sync_projectiles(views)
	effects.sync_lasers(views)


func _sync_pickup_views() -> void:
	var live: Dictionary = {}
	for pickup: Dictionary in sim.weapon_pickups:
		var id: int = pickup.id
		live[id] = true
		if not pickup_views.has(id):
			var view := WeaponPickupView.new()
			$World/Actors.add_child(view)
			pickup_views[id] = view
		var view: WeaponPickupView = pickup_views[id]
		view.position = IsoProjection.project(pickup.position)
		view.visible = not fog.enabled or sim.visibility_at(pickup.position) == 2
	for id: int in pickup_views.keys():
		if not live.has(id):
			pickup_views[id].queue_free()
			pickup_views.erase(id)


func _clear_views() -> void:
	effects.selected_healing_tower_id = -1
	for view: Node in views.values():
		view.queue_free()
	views.clear()
	for view: Node in pickup_views.values():
		view.queue_free()
	pickup_views.clear()
	for view: Node in tech_views.values():
		view.queue_free()
	tech_views.clear()
	for view: ResearchCenterView in _retiring_centers:
		if is_instance_valid(view):
			view.queue_free()
	_retiring_centers.clear()


func _sync_tech_views() -> void:
	var live: Dictionary = {}
	for pickup: Dictionary in sim.tech_pickups:
		if pickup.phase == "deferred":
			continue
		var id: int = pickup.id
		live[id] = true
		if not tech_views.has(id):
			var view := TechPickupView.new()
			$World/Actors.add_child(view)
			tech_views[id] = view
		var view: TechPickupView = tech_views[id]
		view.apply_state(pickup, not sim.paused and sim.result == "playing")
		view.visible = not fog.enabled or sim.visibility_at(pickup.position) == 2
	for id: int in tech_views.keys():
		if not live.has(id):
			tech_views[id].queue_free()
			tech_views.erase(id)


func tech_at_screen(screen: Vector2) -> Dictionary:
	var nearest := 30.0
	var selected: Dictionary = {}
	for pickup: Dictionary in sim.tech_pickups:
		if pickup.phase != "loose" or (fog.enabled and sim.visibility_at(pickup.position) != 2):
			continue
		var distance := world_to_screen(pickup.position).distance_to(screen)
		if distance < nearest:
			selected = pickup
			nearest = distance
	return selected


func screen_to_world(screen: Vector2) -> Vector2:
	return IsoProjection.unproject($World.get_global_transform_with_canvas().affine_inverse() * screen)


func world_to_screen(world: Vector2) -> Vector2:
	return $World.get_global_transform_with_canvas() * IsoProjection.project(world)


func world_click(screen: Vector2) -> void:
	if sim == null or not ui.menu.is_empty() or sim.paused or sim.result != "playing" or not CombatRules.alive(sim.nathaniel):
		game_input.cancel_world_tap()
		return
	if ui.blocks_world_input(screen):
		game_input.cancel_world_tap()
		return
	game_input.cancel_world_tap()
	var selected := world_entity_at(screen)
	var target_id: int = int(selected.get("id", -1))
	if not ui.build_kind.is_empty():
		place_at(ui.build_kind, screen)
		return
	if selected.get("kind", "") == "researchCenter":
		_open_research(target_id)
		return
	if selected.get("kind", "") == "nathaniel":
		command("focus", "nathaniel")
		return
	if not ui.ring_character.is_empty():
		_set_build_open(false)
		return
	if selected.get("kind", "") == "hermes":
		if not ui.build_open and sim.carried_resource_count() > 0:
			command("deliver")
		return
	_select_healing_tower(target_id if selected.get("kind") == "healTower" else -1)
	if target_id >= 0:
		var entity: Dictionary = sim.entity(target_id)
		if entity.kind == "healTower":
			ui.show_notice("Healing range shown. Heals injured Nathaniel and Hermes.")
		elif entity.kind in GameBalance.ENEMIES and not ui.build_open:
			if sim.visibility_at(entity.position) != 2:
				ui.show_notice("Target is out of sight.")
				return
			sim.target_enemy(target_id)
			ui.show_notice("Nathaniel targeting %s." % String(entity.kind).capitalize())
	elif not ui.build_open:
		var corpse := effects.corpse_at_screen(screen)
		if corpse.is_empty():
			var tech := tech_at_screen(screen)
			if not tech.is_empty():
				ui.show_notice("Collecting Tech." if sim.approach_tech(int(tech.id)) else "Cannot collect Tech now. Clear a route or finish the current collection.")
			else:
				_move_nathaniel(screen_to_world(screen))
		else:
			if sim.carried_resource_count() >= int(sim.nathaniel.resource_capacity):
				_move_nathaniel(corpse.position)
				ui.show_notice("Cargo full. Deliver to Hermes first.")
			elif sim.approach_corpse(int(corpse.id)):
				effects.pickup_target_id = int(corpse.id)
				ui.show_notice("No clear route to the corpse. Nathaniel will move as far as possible." if sim.nathaniel.direct_movement else "Collecting corpse.")


func world_entity_at(screen: Vector2) -> Dictionary:
	var target_id := -1
	var nearest := 42.0
	var friendly_hit_id := -1
	var friendly_hit_y := -INF
	var tower_hit_id: int = -1
	var tower_hit_y: float = -INF
	for entity: Dictionary in sim.entities:
		if not CombatRules.alive(entity) or (entity.kind not in ["nathaniel", "hermes"] and sim.visibility_at(entity.position) != 2 and fog.enabled):
			continue
		if entity.kind in ["nathaniel", "hermes"]:
			var dimensions := Vector2(48, 74) if entity.kind == "nathaniel" else Vector2(80, 104)
			if views.has(int(entity.id)):
				dimensions = views[int(entity.id)].visual.display_size
			dimensions *= camera_zoom
			var feet := world_to_screen(entity.position)
			var bounds := Rect2(feet - Vector2(dimensions.x / 2, dimensions.y), dimensions).grow(6)
			var depth: float = IsoProjection.project(entity.position).y
			if bounds.has_point(screen) and depth >= friendly_hit_y:
				friendly_hit_id = int(entity.id)
				friendly_hit_y = depth
		if entity.kind in ["healTower", "researchCenter"] and views.has(int(entity.id)):
			var actor: ActorView = views[int(entity.id)]
			var depth: float = IsoProjection.project(entity.position).y
			if depth >= tower_hit_y and actor.sprite_contains_screen_point(screen):
				tower_hit_id = int(entity.id)
				tower_hit_y = depth
		var distance := (world_to_screen(entity.position) - Vector2(0, 20 * camera_zoom)).distance_to(screen)
		if distance < nearest:
			target_id = entity.id
			nearest = distance
	if friendly_hit_id >= 0:
		var nearby: Dictionary = sim.entity(target_id)
		if nearby.is_empty() or IsoProjection.project(nearby.position).y <= friendly_hit_y:
			target_id = friendly_hit_id
	if tower_hit_id >= 0:
		var nearby: Dictionary = sim.entity(target_id)
		if nearby.is_empty() or nearby.kind in ["healTower", "researchCenter"] or IsoProjection.project(nearby.position).y <= tower_hit_y:
			target_id = tower_hit_id
	return sim.entity(target_id)


func _select_healing_tower(id: int) -> void:
	if effects.selected_healing_tower_id == id:
		return
	effects.selected_healing_tower_id = id
	effects.queue_redraw()
	if sim != null:
		_sync_views()


func _move_nathaniel(world: Vector2) -> void:
	effects.pickup_target_id = -1
	sim.move_to(world)
	ui.show_notice("No clear route. Nathaniel will move as far as possible." if sim.nathaniel.direct_movement else "Moving Nathaniel.")


func place_at(kind: String, screen: Vector2) -> bool:
	if sim == null or not ui.menu.is_empty() or not ui.build_open or sim.paused or sim.result != "playing":
		return false
	var cost := int(GameBalance.COSTS.get(GameBalance.canonical_kind(kind), 0))
	if sim.resources < cost:
		ui.show_notice("Need %d resources to build this tower; you have %d." % [cost, sim.resources])
		return false
	var world := screen_to_world(screen)
	var error := sim.placement_error(world)
	if error != "valid":
		ui.show_notice({"outOfBuildRange": "Outside Hermes's build range. Choose ground inside the amber ring.", "noHermes": "Hermes must be alive to support a tower.", "blockedByTerrain": "Choose clear ground away from the map edge.", "overlapsStructure": "A tower is already here.", "overlapsEnemy": "An enemy blocks this location.", "overlapsCharacter": "A character blocks this location.", "overlapsResource": "Collect the corpse before building here.", "blocksEntryRoute": "Keep a route open from every enemy entry sector. Choose another tower position."}.get(error, error))
		return false
	var placed := sim.place_tower(kind, world)
	if placed:
		ui.show_notice("Tower linked. Hermes anchored and cannon active. Follow reclaims the base.")
		open_context_ring()
	else:
		ui.show_notice("Could not place this tower.")
	return placed


func change_zoom(factor: float) -> void:
	if sim == null or not ui.menu.is_empty():
		return
	game_input.cancel_world_tap()
	camera_zoom = clampf(camera_zoom * factor, 0.5, 2.0)
	camera.zoom = Vector2.ONE * camera_zoom
	if _camera_focus_elapsed < CAMERA_FOCUS_DURATION:
		_begin_camera_focus()
	else:
		_update_camera(1.0, true)


func _begin_camera_focus() -> void:
	_camera_focus_from = camera.position
	_camera_focus_zoom = camera_zoom
	_camera_focus_elapsed = 0.0


func _update_camera(delta: float, immediate: bool = false) -> void:
	if sim == null:
		return
	var target: Dictionary = sim.hermes if ui.build_open else sim.nathaniel
	var zoom_target := camera_zoom
	var dimensions := _character_display_size(target)
	if ui.build_open:
		zoom_target = minf(zoom_target, minf(136.0 / dimensions.y, 156.0 / dimensions.x))
	var focusing := _camera_focus_elapsed < CAMERA_FOCUS_DURATION
	_camera_focus_elapsed = CAMERA_FOCUS_DURATION if immediate else minf(_camera_focus_elapsed + delta, CAMERA_FOCUS_DURATION)
	var focus_weight := smoothstep(0.0, CAMERA_FOCUS_DURATION, _camera_focus_elapsed)
	camera_zoom = zoom_target if immediate else lerpf(_camera_focus_zoom, zoom_target, focus_weight)
	camera.zoom = Vector2.ONE * camera_zoom
	var world_size := Vector2(sim.config.width, sim.config.height) * float(sim.config.tile_size)
	var point := IsoProjection.clamp_camera(IsoProjection.project(target.position), world_size, get_viewport_rect().size, camera_zoom)
	if ui.build_open:
		point = IsoProjection.project(target.position) - Vector2(0, dimensions.y / 2) + (get_viewport_rect().size / 2 - ui.play_rect().get_center()) / camera_zoom
	if immediate:
		camera.position = point
	elif focusing:
		camera.position = _camera_focus_from.lerp(point, focus_weight)
	else:
		camera.position = camera.position.lerp(point, 1.0 - exp(-8.0 * delta))
	camera.force_update_scroll()


func open_context_ring() -> void:
	if sim == null or sim.paused or sim.result != "playing" or not ui.menu.is_empty():
		return
	var actor: Dictionary = sim.hermes
	if not CombatRules.alive(actor):
		return
	if ui.ring_character == "hermes":
		ui.update_game(sim, fog.enabled)
		return
	_set_build_open(true)
	ui.ring_character = "hermes"
	ui._fit_hud()
	ui.open_ring(ui.play_rect().get_center())
	ui.update_game(sim, fog.enabled)
	_sync_views()


func _character_display_size(actor: Dictionary) -> Vector2:
	if views.has(int(actor.id)):
		return views[int(actor.id)].visual.display_size
	return Vector2(80, 104) if actor.kind == "hermes" else Vector2(48, 74)


func _update_character_hud() -> void:
	var viewport := Rect2(Vector2.ZERO, get_viewport_rect().size)
	for character: String in ["nathaniel", "hermes"]:
		var actor: Dictionary = sim.hermes if character == "hermes" else sim.nathaniel
		var point := world_to_screen(actor.position)
		var card := ui.get_node("%" + character.capitalize()) as CharacterControl
		card.target_color = effects.nathaniel_target_color if character == "nathaniel" else effects.hermes_target_color
		card.offscreen_direction = Vector2.ZERO if viewport.has_point(point) else point - viewport.get_center()
		card.queue_redraw()
		if ui.ring_character == character:
			if not CombatRules.alive(actor):
				ui.close_ring()
			else:
				ui.ring_actor_position = point - Vector2(0, _character_display_size(actor).y * camera_zoom / 2)
	ui.queue_redraw()


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
	ui.build_open = false
	ui.close_ring()
	game_input.cancel_tower_drag()
	ui.show_menu("main", {"in_game": false, "continue_level": progress.continue_level(), "has_progress": int(progress.data.highest_level_completed) > 0})
	audio.play_music("menuMusic")
	return_menu = "main"


func command(action: String, value: Variant = null) -> void:
	game_input.cancel_world_tap()
	if ui.menu == "research":
		match action:
			"research_purchase":
				if value is Dictionary:
					var accepted := sim.purchase_research(str(value.get("track", "")), int(value.get("expected_rank", -1)), int(value.get("session_id", -1)))
					ui.research.update_state(sim.research_state())
					ui.research.acknowledge(accepted)
					if accepted:
						audio.play_effect("zap", -24)
			"escape", "back":
				if not ui.research.back():
					_close_research()
			"research_resume", "resume":
				_close_research()
		return
	if sim != null and sim.result in ["victory", "gameOver"] and action not in ["main", "level", "quit", "continue_result"]:
		return
	if action in ["pause", "settings", "credits", "save_menu", "load_menu", "resume", "exit_menu"]:
		_set_build_open(false)
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
		"survival":
			start_survival_run()
		"continue_result":
			if sim == null:
				return
			if sim.result == "gameOver":
				retry_level()
			elif sim.result == "victory":
				if level.definition.next_level < 0:
					show_main()
				else:
					load_level(level.definition.next_level)
		"levels":
			if demo_mode:
				ui.show_notice("Demo mode includes Survival only.")
				return
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
			if not ui.build_kind.is_empty() or not game_input.drag_kind.is_empty():
				command("cancel_placement")
			elif not ui.ring_character.is_empty():
				_set_build_open(false)
			elif ui.build_open:
				_set_build_open(false)
			elif ui.menu.is_empty() and effects.selected_healing_tower_id >= 0:
				_select_healing_tower(-1)
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


func _set_build_open(open: bool) -> void:
	var changed := ui.build_open != open
	if open:
		_select_healing_tower(-1)
	ui.build_open = open
	effects.build_open = open
	game_input.cancel_tower_drag()
	if not open:
		ui.close_ring()
	if sim != null:
		sim.focused_character = "nathaniel"
		if changed:
			_begin_camera_focus()
		ui.update_game(sim, fog.enabled)
		_sync_views()


func _game_command(action: String, value: Variant) -> void:
	if sim == null or not ui.menu.is_empty() or sim.paused:
		return
	if action in ["deliver", "equip_weapon", "fire", "fire_at_pointer", "stop"] and ui.build_open:
		return
	match action:
		"deliver":
			if sim.return_to_hermes():
				_set_build_open(false)
				effects.pulse_delivery(sim.hermes.position)
				ui.show_notice("No clear route to Hermes. Clear a path, then deliver again." if sim.nathaniel.direct_movement else "Returning cargo to Hermes.")
		"upgrade_gathering":
			if sim.upgrade_gathering(String(value)):
				ui.show_notice("Backpack holds %d bodies." % sim.nathaniel.resource_capacity if value == "capacity" else "Backpack arms now reach farther.")
				ui.update_game(sim, fog.enabled)
		"equip_weapon":
			if sim.equip_weapon(String(value)):
				ui.update_game(sim, fog.enabled)
			elif String(value) not in sim.nathaniel.get("owned_weapon_ids", []):
				ui.show_notice("Find the heavy rifle crate, then walk over it to collect it.")
		"focus":
			var character: String = "nathaniel" if value == null else String(value)
			if character == "hermes":
				open_context_ring()
			elif character == "nathaniel":
				_select_healing_tower(-1)
				_set_build_open(false)
		"cancel_placement":
			game_input.cancel_tower_drag()
			open_context_ring()
		"pack":
			if sim.hermes_mode != "following" and ui.ring_character == "hermes":
				sim.set_hermes_mode("following")
				_set_build_open(false)
				ui.show_notice("Base reclaimed. Hermes follows Nathaniel.")
		"fire":
			if int(sim.nathaniel.target_id) < 0:
				ui.show_notice("Select an enemy for Nathaniel, or aim with right-click / F.")
			sim.fire()
		"fire_at_pointer":
			if not ui.blocks_world_input(game_input.pointer_position):
				sim.fire_at(screen_to_world(game_input.pointer_position))
		"stop":
			sim.stop_player()
			ui.show_notice("Nathaniel stopped.")
		"follow":
			sim.set_hermes_mode("following")
			_set_build_open(false)
			ui.show_notice("Hermes following.")
		"hermes_stop":
			sim.set_hermes_mode("stopped")
			game_input.cancel_tower_drag()
			if ui.build_open:
				open_context_ring()
			ui.show_notice("Hermes anchored. Cannon active; build inside his range.")
		"open_build":
			open_context_ring()
		"build":
			if ui.build_open:
				_set_build_open(false)
			else:
				open_context_ring()
		"toggle_hermes":
			command("hermes_stop" if sim.hermes_mode == "following" else "follow")
		"gun_tower", "laser_tower", "heal_tower", "research_center":
			if action == "research_center" and (sim.level_number != 0 or not sim.research_center().is_empty()):
				return
			if ui.build_open and sim.resources >= int(GameBalance.COSTS[GameBalance.canonical_kind(action)]) and CombatRules.alive(sim.hermes):
				ui.build_kind = action
				ui.close_ring()
				ui.update_game(sim, fog.enabled)
		"zoom_in":
			change_zoom(1.15)
		"zoom_out":
			change_zoom(1.0 / 1.15)


func _open_research(center_id: int) -> bool:
	if sim == null or not sim.begin_research(center_id):
		return false
	game_input.cancel_tower_drag()
	_set_build_open(false)
	ui.show_menu("research", sim.research_state())
	_sync_views()
	return true


func _close_research() -> void:
	if sim == null:
		return
	sim.end_research()
	ui.show_menu("pause" if sim.external_pause_active() and sim.result == "playing" else "")
	_sync_views()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		command("escape")
	elif what == NOTIFICATION_APPLICATION_PAUSED and sim != null:
		sim.set_application_suspended(true)
		game_input.cancel_world_tap()
		ui.research.cancel_purchase_input()
	elif what == NOTIFICATION_APPLICATION_RESUMED and sim != null:
		sim.set_application_suspended(false)


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
	var loaded := load_survival_map(snapshot.level.get("survival_map_id", SurvivalMapCatalog.LEGACY_ID)) if number == 0 else load_level(number)
	if not loaded:
		return
	if number == 0:
		# The catalog scene supplies terrain and entries; the save supplies run state.
		snapshot.level = level.data()
	if not sim.restore(snapshot):
		ui.show_notice("Save could not be restored")
		return
	_set_build_open(false)
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
	if demo_mode:
		return {"success": false, "error": "Swift save import is unavailable in demo mode."}
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
