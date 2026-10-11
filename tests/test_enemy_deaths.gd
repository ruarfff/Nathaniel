extends SceneTree
## Death identity, retained matter, transient shells and campaign boundaries.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func game() -> GameSimulation:
	var sim := GameSimulation.new()
	sim.configure({"number": 0, "width": 64, "height": 64, "tile_size": 32, "blocked": [],
		"player_start": Vector2(300, 300), "hermes_start": Vector2(600, 300), "enemies": [], "wave_based": false})
	sim.set_hermes_mode("building")
	sim.take_events()
	return sim


func kill_boss(sim: GameSimulation, offset: Vector2 = Vector2.ZERO) -> Dictionary:
	var boss: Dictionary = sim.spawn_enemy("boss", sim.nathaniel.position + offset)
	boss.firing = true
	sim.damage_entity(boss.id, 1000)
	sim.damage_entity(boss.id, 1000)
	expect(not boss.active and not boss.firing and boss.target_id == -1, "Boss death stops its weapon immediately")
	return sim.corpses.back()


func round_trip(sim: GameSimulation, label: String) -> GameSimulation:
	var directory: String = "/private/tmp/nathaniel-enemy-deaths-%d" % Time.get_ticks_usec()
	var store := GameSaveStore.new(directory)
	expect(store.save_slot(1, sim.snapshot()).success, label + " passes file validation")
	var saved: Dictionary = store.load_slot(1)
	var restored := GameSimulation.new()
	expect(saved.success and restored.restore(saved.get("state", {})), label + " restores from an actual slot")
	expect(restored.corpses.size() == sim.corpses.size(), label + " keeps every body")
	for index: int in mini(restored.corpses.size(), sim.corpses.size()):
		var before: Dictionary = sim.corpses[index]
		var after: Dictionary = restored.corpses[index]
		for field: String in ["id", "amount", "source_kind", "carried", "disarmed", "phase", "cargo_slot"]:
			expect(before[field] == after[field], label + " keeps " + field)
		for field: String in ["expiration", "phase_elapsed"]:
			expect(is_equal_approx(float(before[field]), float(after[field])), label + " keeps " + field)
		for field: String in ["position", "pickup_position"]:
			expect(Vector2(before[field]).is_equal_approx(Vector2(after[field])), label + " keeps " + field)
	store.delete_slot(1)
	DirAccess.remove_absolute(directory)
	return restored


func _boss_collection() -> void:
	for anchored: bool in [false, true]:
		var sim: GameSimulation = game()
		var body: Dictionary = kill_boss(sim, Vector2(45, 0))
		expect(sim.result == "playing" and sim.corpses.size() == 1 and sim.score == 100, "One survival death creates one boss body and the run continues")
		expect(body.source_kind == "boss" and body.amount == GameBalance.RESOURCE_VALUES.boss and body.expiration == 10.0, "Boss value is tunable and its deadline begins at death")
		sim.step(0.1)
		expect(body.phase == "loose", "Starter reach excludes a boss at 45 points")
		sim.nathaniel.position.x += 1
		sim.step(0.1)
		expect(body.phase == "grab" and not body.disarmed, "Boss grab starts at 44 points without disarming")
		sim.nathaniel.position.x -= 2
		sim.step(0.1)
		expect(body.phase == "loose" and is_equal_approx(body.expiration, 9.7), "Interrupted grip retains the original boss deadline")
		sim.nathaniel.position = body.position
		sim.step(0.6)
		expect(body.phase == "carry" and body.disarmed and body.cargo_slot == 0 and sim.resources == 30, "Starter tool compresses one boss into one slot without credit")
		var other: Dictionary = sim.spawn_resource(10, sim.nathaniel.position, 0.5, false, "boss")
		sim.step(0.5)
		expect(sim.corpses.size() == 1 and not sim.corpses.has(other), "Full starter rack cannot disarm another boss")
		sim.set_hermes_mode("building" if anchored else "following")
		sim.nathaniel.position = sim.hermes.position + Vector2(48, 0)
		sim.step(0.3)
		expect(body.phase == "feed" and sim.resources == 30, "Both Hermes forms accept boss matter through the normal timed intake")
		sim.nathaniel.position.x += 1
		sim.step(0)
		expect(body.phase == "carry" and body.disarmed and sim.resources == 30, "Interrupted boss delivery keeps safe cargo without credit")
		sim.nathaniel.position.x -= 1
		sim.step(0.6)
		sim.step(3.0)
		var deliveries: int = 0
		for event: Dictionary in sim.take_events():
			if event.type == "delivery":
				deliveries += 1
		expect(deliveries == 1 and sim.resources == 40 and sim.corpses.is_empty(), "Hermes credits the boss exactly once")


func _boss_saves_and_deadlines() -> void:
	var sim: GameSimulation = game()
	var body: Dictionary = kill_boss(sim, Vector2(100, 0))
	sim.step(7.125)
	sim = round_trip(sim, "Armed warning boss")
	body = sim.corpses[0]
	var effects: WorldEffects = load("res://scenes/effects/world_effects.tscn").instantiate()
	expect(effects.corpse_warning_strength(body) > 0.99, "Boss warning uses the final three seconds")
	sim.set_paused(true)
	sim.step(4)
	expect(is_equal_approx(body.expiration, 2.875), "Pause freezes a boss deadline")
	sim.set_paused(false)
	sim.nathaniel.position = body.position
	body.expiration = GameBalance.RESOURCE_GRAB_SECONDS
	sim.step(GameBalance.RESOURCE_GRAB_SECONDS)
	expect(sim.corpses.is_empty() and sim.resources == 30, "Exact boss expiry wins over grip")
	var events: Array = sim.take_events()
	expect(events.filter(func(event: Dictionary) -> bool: return event.type == "corpse_expired").size() == 1, "Boss expiry emits one dissolve and no reward")
	sim = game()
	body = kill_boss(sim)
	sim.step(0.1)
	sim = round_trip(sim, "Armed boss during grab")
	sim.step(0.2)
	sim = round_trip(sim, "Disarmed boss during crush")
	sim.step(0.3)
	sim = round_trip(sim, "Carried boss")
	sim.nathaniel.position = sim.hermes.position
	sim.step(0.3)
	sim = round_trip(sim, "Boss during feed")
	sim.damage_entity(sim.hermes.id, 100000)
	expect(sim.corpses[0].phase == "carry" and sim.corpses[0].disarmed and sim.resources == 30, "Hermes death cancels boss delivery without credit")
	sim = game()
	body = kill_boss(sim)
	sim.step(0.6)
	sim.damage_entity(sim.nathaniel.id, 100000)
	expect(not body.carried and body.disarmed and body.phase == "loose" and body.cargo_slot == -1, "Death drops the boss body permanently safe")
	sim = round_trip(sim, "Disarmed dropped boss")
	BattlefieldRules.update_corpses(sim, 30.0)
	expect(sim.corpses.size() == 1 and effects.corpse_warning_strength(sim.corpses[0]) == 0.0, "Dropped boss matter never warns or expires")
	var old: GameSimulation = game()
	old.spawn_resource(10, Vector2(500, 500))
	old.spawn_resource(10, Vector2(600, 500), 10, false, "gunSoldier")
	var saved: Dictionary = old.snapshot()
	saved.corpses[0].erase("source_kind")
	expect(GameSaveStore.validate_state(saved).is_empty() and old.restore(saved), "Older soldier saves still load")
	expect(old.corpses[0].source_kind == "soldier" and old.corpses[1].source_kind == "gunSoldier", "Old and explicit soldier identities stay intact")
	saved.corpses[0].source_kind = "spawner"
	expect(not GameSaveStore.validate_state(saved).is_empty() and not old.restore(saved), "Both validators reject noncollectible kinds")
	effects.free()


func _shell_effects() -> void:
	var sim: GameSimulation = game()
	var effects: WorldEffects = load("res://scenes/effects/world_effects.tscn").instantiate()
	effects.simulation = sim
	effects.fog_enabled = false
	root.add_child(effects)
	effects.set_process(false)
	var hp: int = sim.nathaniel.hp
	var ids: Array[int] = []
	for kind: String in ["grunt", "spawner", "grunt"]:
		var unit: Dictionary = sim.spawn_enemy(kind, Vector2(800, 800))
		unit.facing = Vector2.UP
		unit.firing = true
		unit.target_id = sim.nathaniel.id
		unit.spawn_countdown = 0.0
		ids.append(unit.id)
		sim.damage_entity(unit.id, 100000)
		sim.damage_entity(unit.id, 100000)
		expect(not unit.firing and not unit.active and unit.target_id == -1, kind + " stops attacks at death")
	var events: Array = sim.take_events()
	var deaths: Array = events.filter(func(event: Dictionary) -> bool: return event.type == "death")
	expect(deaths.size() == 3 and deaths[0].position == Vector2(800, 800) and deaths[0].facing == Vector2.UP, "Each death retains its ground position and facing once")
	sim.step(0.01)
	expect(sim.corpses.is_empty() and sim.resources == 30 and sim.nathaniel.hp == hp and sim.projectiles.is_empty(), "Shell deaths leave no loot, blast damage or new shots")
	expect(sim.entities.size() == 2, "Dead spawners cannot create children and all dead actors are removed")
	effects.add_events(events)
	expect(effects.shell_deaths.size() == 3 and effects.transients.filter(func(effect: Dictionary) -> bool: return effect.kind == "death").is_empty(), "Simultaneous shells replace the death ring without duplicate effects")
	expect(effects.shell_deaths[0].clip == &"death_6" and effects.shell_deaths[0].sprite.position == IsoProjection.project(Vector2(800, 800)), "Directional effect keeps the removed grunt's heading and ground anchor")
	sim.set_paused(true)
	effects._process(0.5)
	expect(effects.shell_deaths[0].age == 0.0, "Pause freezes the explosion sequence")
	sim.set_paused(false)
	effects._process(0.4)
	expect(effects.shell_deaths.size() == 1 and is_equal_approx(effects.shell_deaths[0].duration, 0.8), "Grunts clear after 0.4 seconds; the spawner continues")
	effects._process(0.4)
	expect(effects.shell_deaths.is_empty(), "Spawner clears after 0.8 seconds")
	effects.add_events(sim.take_events())
	expect(effects.shell_deaths.is_empty(), "Consumed death events cannot replay effects")
	effects.add_events(deaths)
	effects.simulation = game()
	expect(effects.shell_deaths.is_empty(), "Level reset clears unfinished shell effects")
	effects.free()


func _campaign() -> void:
	var app: GameApp = load("res://scenes/main.tscn").instantiate()
	app.storage_root = "/private/tmp/nathaniel-death-campaign-%d/" % Time.get_ticks_usec()
	root.add_child(app)
	app.set_physics_process(false)
	app.load_level(1)
	var grunt: Dictionary = app.sim.spawn_enemy("grunt", app.sim.nathaniel.position - Vector2(100, 100))
	app.sim.damage_entity(grunt.id, 1000)
	app._physics_process(0)
	var shell: Sprite2D = app.effects.shell_deaths[0].sprite
	expect(shell.get_parent() == app.get_node("World/Actors") and shell.get_parent().y_sort_enabled, "Shells sort with nearby actors at their ground position")
	var boss: Dictionary = app.sim.spawn_enemy("boss", app.sim.nathaniel.position)
	app.sim.damage_entity(boss.id, 1000)
	expect(app.sim.result == "victory" and app.sim.corpses.size() == 1, "Campaign boss still wins immediately")
	app._physics_process(0)
	var corpse: Dictionary = app.sim.corpses[0].duplicate(true)
	app.sim.step(2)
	expect(app.sim.corpses[0] == corpse and app.sim.resources == 30, "Campaign victory does not add a collection phase or credit")
	app.command("continue_result")
	expect(app.sim.level_number == 2 and app.sim.corpses.is_empty() and app.sim.resources == 30, "Continue resets resources and cargo as before")
	expect(app.effects.shell_deaths.is_empty() and shell.is_queued_for_deletion(), "Level transition removes shells from the actor sorting layer")
	app.free()


func _boss_views() -> void:
	var player: ActorView = load("res://scenes/actors/nathaniel.tscn").instantiate()
	var hermes: HermesView = load("res://scenes/actors/hermes.tscn").instantiate()
	root.add_child(player)
	root.add_child(hermes)
	var sim: GameSimulation = game()
	var body: Dictionary = kill_boss(sim)
	player.apply_state(sim.nathaniel, false, false)
	hermes.apply_state(sim.hermes, false, false)
	var rig: ResourceGatheringView = player.model_view.gathering_view
	for phase: String in ["grab", "crush", "carry", "present", "feed"]:
		body.phase = phase
		body.phase_elapsed = BattlefieldRules.phase_seconds(phase) * 0.5
		body.carried = phase != "grab"
		body.cargo_slot = 0
		player.sync_gathering(sim.corpses, sim.nathaniel, sim.hermes, hermes)
		expect(ResourceGatheringView.ground_visible(body) == (phase == "grab"), "Boss ground view ends at grip in " + phase)
		var bundle: Node3D = rig._bundles[0] if phase == "carry" else rig.active_bundle
		if phase != "grab":
			expect(bundle.visible and rig._boss_bundles[bundle].visible, "Boss keeps its own bundle through " + phase)
			for child: Node in bundle.get_children():
				if child is Node3D and child != rig._boss_bundles[bundle]:
					expect(not child.visible, "Soldier shell does not stack with boss matter")
	body.phase = "crush"
	body.phase_elapsed = 0.0
	player.sync_gathering(sim.corpses, sim.nathaniel, sim.hermes, hermes)
	var large: float = rig.active_bundle.global_basis.get_scale().x
	body.phase_elapsed = GameBalance.RESOURCE_CRUSH_SECONDS * 0.9
	player.sync_gathering(sim.corpses, sim.nathaniel, sim.hermes, hermes)
	expect(is_equal_approx(large / rig.active_bundle.global_basis.get_scale().x, 4.0), "Boss compression ends at the standard one-slot size")
	for anchored: bool in [false, true]:
		sim.hermes.anchored = anchored
		hermes.apply_state(sim.hermes, false, false)
		body.phase = "feed"
		body.phase_elapsed = GameBalance.RESOURCE_FEED_SECONDS * 0.84
		player.sync_gathering(sim.corpses, sim.nathaniel, sim.hermes, hermes)
		hermes.sync_intake(sim.corpses, sim.nathaniel, sim.hermes)
		var intake: ResourceGatheringView = hermes.gathering_model().gathering_view
		expect(not rig.active_bundle.visible and intake.intake_bundle.visible and intake._boss_bundles[intake.intake_bundle].visible, "Both intake heights receive the identifiable boss bundle once")
	body.phase = "carry"
	body.source_kind = "soldier"
	player.sync_gathering(sim.corpses, sim.nathaniel, sim.hermes, hermes)
	expect(not rig._boss_bundles[rig._bundles[0]].visible, "A later soldier bundle restores its existing artwork")
	player.free()
	hermes.free()


func _art_contracts() -> void:
	for asset: String in ["boss_corpse", "boss_bundle", "grunt_death", "spawner_death"]:
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/%s.json" % asset))
		expect(FileAccess.get_sha256("res://" + str(manifest.source)) == manifest.source_sha256, asset + " export matches the saved editable source")
		if manifest.has("model"):
			expect(FileAccess.get_sha256("res://" + str(manifest.model.path)) == manifest.model.sha256, "Boss bundle GLB matches its export record")
		if manifest.has("animation"):
			var frames: SpriteFrames = load("res://assets/generated/%s_frames.tres" % asset)
			for clip: StringName in frames.get_animation_names():
				expect(not frames.get_animation_loop(clip), "Shell clips finish instead of looping")
				for frame: int in range(frames.get_frame_count(clip)):
					var texture: Texture2D = frames.get_frame_texture(clip, frame)
					expect(texture.get_size() == Vector2(manifest.canvas[0], manifest.canvas[1]), "Every shell pose preserves the shared canvas and ground anchor")


func _run() -> void:
	_boss_collection()
	_boss_saves_and_deadlines()
	_shell_effects()
	_boss_views()
	_art_contracts()
	_campaign()
	print("%s enemy deaths: %d assertions" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
