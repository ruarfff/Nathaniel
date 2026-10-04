extends SceneTree
## Equipment, aiming and save contracts use logical coordinates without a renderer.

const SaveStore = preload("res://scripts/infrastructure/save_store.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_test_starting_weapon_balance()
	_test_pickups()
	_test_equip_recovery()
	_test_aim_and_manual_fire()
	_test_manual_cancellation()
	_test_respawn()
	_test_saves()
	_test_invalid_saves()
	print("Weapon rules: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _game() -> GameSimulation:
	var sim := GameSimulation.new()
	sim.configure({"number": 1, "width": 64, "height": 64, "tile_size": 32,
		"blocked": [], "player_start": Vector2(500, 500), "hermes_start": Vector2(1600, 1600),
		"enemies": [], "wave_based": false})
	sim.set_hermes_mode("building")
	sim.take_events()
	return sim

func _ready(sim: GameSimulation, direction: Vector2 = Vector2.RIGHT) -> void:
	sim.nathaniel.cooldown = maxf(float(sim.nathaniel.delay), float(sim.nathaniel.recovery_delay))
	sim.nathaniel.equip_ready_remaining = 0.0
	sim.nathaniel.aim_direction = direction

func _unlock(sim: GameSimulation) -> void:
	sim.spawn_weapon_pickup("heavy_rifle", sim.nathaniel.position)
	sim.step(0.0)
	sim.take_events()

func _shots(sim: GameSimulation) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event: Dictionary in sim.take_events():
		if event.type == "shot":
			found.append(event)
	return found

func _test_starting_weapon_balance() -> void:
	# Exercise a catalog-only balance edit without changing the live game constants.
	var source: String = FileAccess.get_file_as_string("res://scripts/domain/game_balance.gd")
	var rifle_entry := RegEx.new()
	rifle_entry.compile('(?m)^\\s*"rifle": \\{[^\\n]+\\},$')
	var changed_catalog: String = '\t"rifle": {"weapon": "gun", "damage": 37, "delay": 1.1, "range": 390.0, "shot_speed": 510.0},'
	var fixture := GDScript.new()
	fixture.source_code = rifle_entry.sub(source.replace("class_name GameBalance\n", ""), changed_catalog)
	_check(fixture.reload() == OK, "Alternate rifle balance fixture compiles")
	var player: Dictionary = fixture.create("nathaniel", 1, Vector2.ZERO)
	_check(player.damage == 37 and player.delay == 1.1 and player.range == 390.0 and player.shot_speed == 510.0, "Starting rifle uses catalog balance changes")
	_check(player.recovery_delay == 1.1, "Starting weapon recovery uses the selected rifle cadence")
	var sim: GameSimulation = _game()
	var starting_stats: Dictionary = {}
	for key: String in GameBalance.WEAPONS.rifle:
		starting_stats[key] = sim.nathaniel[key]
	_unlock(sim)
	sim.equip_weapon("heavy_rifle")
	sim.equip_weapon("rifle")
	for key: String in starting_stats:
		_check(sim.nathaniel[key] == starting_stats[key], "Re-equipped rifle retains its starting %s" % key)

func _test_pickups() -> void:
	var sim: GameSimulation = _game()
	_check(sim.nathaniel.equipped_weapon_id == "rifle" and sim.nathaniel.owned_weapon_ids == ["rifle"], "Fresh level owns and equips only the default rifle")
	_check(sim.nathaniel.damage == 25 and sim.nathaniel.delay == 0.8 and sim.nathaniel.range == 450.0 and sim.nathaniel.shot_speed == 450.0, "Default rifle preserves current statistics")
	_check(not sim.equip_weapon("heavy_rifle") and not sim.equip_weapon("unknown"), "Unowned and unknown equipment is rejected")
	_check(sim.spawn_weapon_pickup("unknown", Vector2.ZERO).is_empty() and sim.spawn_weapon_pickup("rifle", Vector2(NAN, 0)).is_empty(), "Invalid pickup requests add no state")
	var pickup: Dictionary = sim.spawn_weapon_pickup("heavy_rifle", Vector2(532.01, 500))
	var pickup_id: int = pickup.id
	sim.hermes.position = pickup.position
	sim.step(0.0)
	_check(sim.weapon_pickups.size() == 1 and sim.nathaniel.owned_weapon_ids == ["rifle"], "Hermes cannot collect a gun and Nathaniel must be within 32 points")
	pickup.position = Vector2(532, 500)
	sim.step(0.0)
	_check(sim.weapon_pickups.is_empty() and sim.nathaniel.owned_weapon_ids == ["rifle", "heavy_rifle"], "Nathaniel collects at the inclusive 32-point boundary")
	_check(sim.nathaniel.equipped_weapon_id == "rifle", "Collection does not auto-equip")
	var collected: Array[Dictionary] = sim.take_events()
	_check(collected.size() == 1 and collected[0].type == "weapon_collected" and collected[0].pickup_id == pickup_id and collected[0].weapon_id == "heavy_rifle" and collected[0].newly_owned, "Collection event identifies the consumed pickup and newly owned gun")
	var duplicate: Dictionary = sim.spawn_weapon_pickup("heavy_rifle", sim.nathaniel.position)
	_check(int(duplicate.id) > pickup_id, "Pickup identities are not reused after collection")
	sim.step(0.0)
	collected = sim.take_events()
	_check(sim.weapon_pickups.is_empty() and sim.nathaniel.owned_weapon_ids.size() == 2 and sim.resources == 30, "Duplicate pickup adds no slot or resource reward")
	_check(collected.size() == 1 and not collected[0].newly_owned, "Duplicate pickup is consumed once and identified as already owned")
	sim.step(0.0)
	_check(sim.take_events().is_empty(), "Collected pickup never emits twice")
	var config: Dictionary = sim.level.duplicate(true)
	config.weapon_pickups = [{"weapon_id": "heavy_rifle", "position": Vector2(700, 500)}]
	sim.configure(config)
	_check(sim.weapon_pickups.size() == 1 and sim.weapon_pickups[0].position == Vector2(700, 500), "Native level configuration spawns a logical weapon pickup")
	_check(sim.nathaniel.equipped_weapon_id == "rifle" and sim.nathaniel.owned_weapon_ids == ["rifle"], "New level resets the previous loadout")

func _test_equip_recovery() -> void:
	var sim: GameSimulation = _game()
	_unlock(sim)
	_ready(sim)
	_check(sim.fire_at(Vector2(600, 500)), "Ready aligned rifle fires immediately")
	var rifle_shot: Dictionary = sim.projectiles.back()
	var rifle_event: Dictionary = _shots(sim)[0]
	_check(sim.equip_weapon("heavy_rifle"), "Owned alternate gun equips")
	_check(sim.nathaniel.damage == 50 and sim.nathaniel.delay == 1.6 and sim.nathaniel.weapon == "gun", "Heavy rifle changes damage and cadence while retaining the gun mechanism")
	_check(sim.nathaniel.equip_ready_remaining == 0.35 and sim.nathaniel.cooldown == 0.0 and sim.nathaniel.recovery_delay == 0.8, "Equip adds readiness time without changing elapsed shot recovery")
	_check(not sim.fire_at(Vector2(600, 500)), "Manual fire is rejected during equip")
	sim.step(0.2)
	var equip_remaining: float = sim.nathaniel.equip_ready_remaining
	_check(sim.equip_weapon("heavy_rifle") and sim.nathaniel.equip_ready_remaining == equip_remaining, "Equipping the current gun does not restart its timer")
	sim.set_paused(true)
	sim.step(10.0)
	_check(not sim.equip_weapon("rifle") and sim.nathaniel.equip_ready_remaining == equip_remaining and sim.nathaniel.cooldown == 0.2, "Pause freezes equip and recovery and rejects swaps")
	sim.set_paused(false)
	sim.step(0.15)
	_check(is_zero_approx(sim.nathaniel.equip_ready_remaining) and not sim.fire_at(Vector2(600, 500)), "Completed equip still respects the new gun's firing interval")
	sim.step(1.25)
	_check(sim.fire_at(Vector2(600, 500)), "Heavy rifle fires after its full interval")
	var heavy_shot: Dictionary = sim.projectiles.back()
	var heavy_event: Dictionary = _shots(sim)[0]
	_check(rifle_shot.damage == 25 and rifle_shot.weapon_id == "rifle" and rifle_event.weapon_id == "rifle", "Swapping preserves the earlier bullet and queued event weapon identity")
	_check(heavy_shot.damage == 50 and heavy_shot.weapon_id == "heavy_rifle" and heavy_event.weapon_id == "heavy_rifle", "Heavy shot captures its own damage and weapon identity")
	_check(heavy_shot.speed == 450.0 and heavy_shot.remaining == 600.0 and heavy_shot.radius == 12.0, "Both guns retain projectile speed, travel distance and collision radius")
	_check(sim.equip_weapon("rifle"), "Can return to the default rifle")
	sim.step(0.8)
	_check(not sim.fire_at(Vector2(600, 500)), "Switching to the faster rifle cannot shorten heavy-shot recovery")
	_check(sim.equip_weapon("heavy_rifle") and sim.equip_weapon("rifle"), "Repeated swaps remain valid equipment requests")
	_check(sim.nathaniel.cooldown == 0.8 and sim.nathaniel.recovery_delay == 1.6, "Repeated swaps do not recharge or replace the last shot's recovery")
	sim.step(0.79)
	_check(not sim.fire_at(Vector2(600, 500)), "Recovery remains blocked immediately before its deadline")
	sim.step(0.01)
	_check(sim.fire_at(Vector2(600, 500)), "Faster rifle becomes ready at the preserved heavy-shot deadline")
	_check(heavy_shot.damage == 50 and heavy_shot.weapon_id == "heavy_rifle" and heavy_event.weapon_id == "heavy_rifle", "Subsequent swaps never mutate heavy-shot data")

func _test_aim_and_manual_fire() -> void:
	var sim: GameSimulation = _game()
	_ready(sim, Vector2(0, -1))
	_check(sim.fire_at(Vector2(600, 500)), "Manual fire accepts one valid intent while turning")
	_check(sim.projectiles.is_empty() and sim.nathaniel.manual_fire_target == Vector2(600, 500), "Turning does not fire through an unaligned barrel")
	sim.step(0.125)
	_check(Vector2(sim.nathaniel.aim_direction).is_equal_approx(Vector2(1, -1).normalized()) and sim.projectiles.is_empty(), "Aim turns 45 degrees in one eighth of a second")
	sim.step(0.125)
	var events: Array[Dictionary] = _shots(sim)
	_check(events.size() == 1 and events[0].direction == Vector2.RIGHT and sim.nathaniel.manual_fire_target == null, "Alignment emits the requested shot once and clears its intent")
	sim.step(1.0)
	_check(_shots(sim).is_empty(), "A point-fire intent does not become continuous fire")
	for fps: int in [30, 60, 120]:
		sim = _game()
		_ready(sim, Vector2.RIGHT)
		sim.fire_at(Vector2(400, 500))
		for frame: int in fps / 2:
			sim.step(1.0 / fps)
		events = _shots(sim)
		_check(events.size() == 1 and Vector2(sim.nathaniel.aim_direction).is_equal_approx(Vector2.LEFT), "Half-turn and shot are frame independent at %d FPS" % fps)
	sim = _game()
	sim.move_to(Vector2(700, 500))
	_ready(sim)
	sim.fire_at(Vector2(500, 600))
	sim.step(0.1)
	_check(sim.nathaniel.moving and sim.nathaniel.facing == Vector2.RIGHT and sim.projectiles.is_empty(), "Walking heading remains separate while the gun turns")
	sim.step(0.2)
	events = _shots(sim)
	_check(events.size() == 1 and sim.nathaniel.facing == Vector2.RIGHT and Vector2(sim.nathaniel.aim_direction).y > 0.9, "Firing while walking preserves locomotion and uses actual aim")
	sim = _game()
	_ready(sim, Vector2.LEFT)
	var enemy: Dictionary = sim.spawn_enemy("soldier", Vector2(600, 500))
	enemy.speed = 0.0
	enemy.delay = 100000.0
	sim.target_enemy(int(enemy.id))
	sim.step(0.25)
	_check(sim.projectiles.is_empty(), "Automatic fire also waits for aim alignment")
	sim.step(0.25)
	events = _shots(sim)
	_check(events.size() == 1 and events[0].direction == Vector2.RIGHT, "Automatic target fire resumes once aligned")
	enemy.position = Vector2(500, 600)
	sim.step(0.1)
	_check(Vector2(sim.nathaniel.aim_direction).angle() > 0.5 and _shots(sim).is_empty(), "Automatic aim tracks a moving target during cooldown")
	sim = _game()
	_ready(sim)
	_check(not sim.fire_at(Vector2(1000, 500)) and not sim.fire_at(Vector2(INF, 500)), "Invalid manual aim is rejected without storing an intent")
	_check(sim.nathaniel.manual_fire_target == null and sim.nathaniel.aim_direction == Vector2.RIGHT, "Rejected aim leaves weapon direction and intent unchanged")

func _test_manual_cancellation() -> void:
	for action: String in ["move", "target", "equip", "death"]:
		var sim: GameSimulation = _game()
		_unlock(sim)
		_ready(sim, Vector2.LEFT)
		sim.fire_at(Vector2(600, 500))
		match action:
			"move": sim.move_to(Vector2(500, 700))
			"target": sim.target_enemy(int(sim.spawn_enemy("soldier", Vector2(550, 500)).id))
			"equip": sim.equip_weapon("heavy_rifle")
			"death": sim.damage_entity(int(sim.nathaniel.id), 8000)
		_check(sim.nathaniel.manual_fire_target == null, "%s cancels the pending point-fire intent" % action)
	var sim: GameSimulation = _game()
	_ready(sim, Vector2.LEFT)
	sim.fire_at(Vector2(600, 500))
	sim.fire_at(Vector2(500, 600))
	sim.step(0.25)
	var events: Array[Dictionary] = _shots(sim)
	_check(events.size() == 1 and events[0].target_position == Vector2(500, 600), "Later point-fire replaces the single intent instead of queuing shots")

func _test_respawn() -> void:
	var sim: GameSimulation = _game()
	_unlock(sim)
	sim.equip_weapon("heavy_rifle")
	sim.step(0.1)
	var timer: float = sim.nathaniel.equip_ready_remaining
	sim.damage_entity(int(sim.nathaniel.id), 8000)
	_check(sim.lives == 2 and sim.nathaniel.equipped_weapon_id == "heavy_rifle" and sim.nathaniel.owned_weapon_ids == ["rifle", "heavy_rifle"], "Spare-life respawn retains the loadout")
	_check(sim.nathaniel.equip_ready_remaining == timer and sim.nathaniel.cooldown == 0.1, "Respawn does not bypass equip or shot recovery")
	_check(sim.nathaniel.aim_direction == Vector2(0, -1) and sim.nathaniel.manual_fire_target == null, "Respawn resets aim and pending fire at the new position")
	sim.lives = 0
	sim.damage_entity(int(sim.nathaniel.id), 8000)
	_check(not sim.equip_weapon("rifle") and not sim.fire_at(Vector2(600, 500)), "Defeat rejects equip and manual fire")

func _test_saves() -> void:
	var sim: GameSimulation = _game()
	_unlock(sim)
	sim.equip_weapon("heavy_rifle")
	_ready(sim)
	sim.fire_at(Vector2(600, 500))
	sim.equip_weapon("rifle")
	sim.step(0.1)
	var pickup: Dictionary = sim.spawn_weapon_pickup("heavy_rifle", Vector2(800, 500))
	var directory: String = "/tmp/nathaniel-weapons-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var store := SaveStore.new(directory)
	_check(store.save_slot(1, sim.snapshot()).success, "Weapon state saves through the existing native slot format")
	var saved: Dictionary = store.load_slot(1)
	var restored := GameSimulation.new()
	_check(saved.success and restored.restore(saved.state), "Weapon state restores after a JSON disk round trip")
	_check(restored.nathaniel.equipped_weapon_id == "rifle" and restored.nathaniel.owned_weapon_ids == ["rifle", "heavy_rifle"], "Both slots and selected gun survive reload")
	_check(is_equal_approx(restored.nathaniel.equip_ready_remaining, 0.25) and restored.nathaniel.cooldown == 0.1 and restored.nathaniel.recovery_delay == 1.6, "Partial equip and previous heavy-shot recovery survive reload")
	_check(restored.projectiles.size() == 1 and restored.projectiles[0].weapon_id == "heavy_rifle" and restored.projectiles[0].damage == 50, "In-flight shot keeps the old gun after saving with another gun equipped")
	_check(restored.weapon_pickups.size() == 1 and restored.weapon_pickups[0].id == pickup.id and restored.weapon_pickups[0].position == pickup.position, "Uncollected pickup retains its ID and logical position")
	_check(int(restored.spawn_weapon_pickup("rifle", Vector2(900, 500)).id) > int(pickup.id), "Restored pickup IDs advance the shared allocator")
	DirAccess.remove_absolute(store.slot_path(1))
	DirAccess.remove_absolute(directory)
	sim = _game()
	_ready(sim, Vector2.LEFT)
	sim.fire_at(Vector2(600, 500))
	sim.step(0.125)
	_check(restored.restore(sim.snapshot()) and restored.nathaniel.aim_direction.is_equal_approx(sim.nathaniel.aim_direction) and restored.nathaniel.manual_fire_target == Vector2(600, 500), "Mid-turn save restores actual aim and the one pending intent")
	restored.step(0.375)
	_check(_shots(restored).size() == 1, "Restored pending intent fires once after completing its turn")
	var config: Dictionary = sim.level.duplicate(true)
	config.weapon_pickups = [{"weapon_id": "heavy_rifle", "position": Vector2(500, 500)}]
	sim.configure(config)
	sim.step(0.0)
	_check(restored.restore(sim.snapshot()) and restored.weapon_pickups.is_empty(), "A consumed authored pickup does not respawn when loading")
	var legacy: Dictionary = sim.snapshot()
	for key: String in ["equipped_weapon_id", "owned_weapon_ids", "aim_direction", "manual_fire_target", "equip_ready_remaining", "recovery_delay"]:
		legacy.entities[0].erase(key)
	legacy.entities[0].cooldown = 0.35
	legacy.entities[0].delay = 1.2
	legacy.entities[0].facing = {"x": 1.0, "y": 0.0}
	legacy.erase("weapon_pickups")
	_check(SaveStore.validate_state(legacy).is_empty() and restored.restore(legacy), "Native saves without loadout fields remain compatible")
	_check(restored.nathaniel.equipped_weapon_id == "rifle" and restored.nathaniel.owned_weapon_ids == ["rifle"] and restored.weapon_pickups.is_empty(), "Old saves get the original gun without respawning authored pickups")
	_check(restored.nathaniel.cooldown == 0.35 and restored.nathaniel.delay == 1.2 and restored.nathaniel.recovery_delay == 1.2 and restored.nathaniel.aim_direction == Vector2.RIGHT, "Old saves preserve customized cadence, partial recovery and facing")

func _test_invalid_saves() -> void:
	var sim: GameSimulation = _game()
	var baseline: Dictionary = sim.snapshot()
	for patch: Dictionary in [{"owned_weapon_ids": []}, {"owned_weapon_ids": ["rifle", "rifle"]}, {"owned_weapon_ids": ["unknown"]}, {"equipped_weapon_id": "heavy_rifle"}, {"equip_ready_remaining": -0.1}, {"recovery_delay": "fast"}, {"aim_direction": {"x": 0, "y": 0}}, {"manual_fire_target": {"x": "bad", "y": 1}}]:
		var invalid: Dictionary = baseline.duplicate(true)
		invalid.entities[0].merge(patch, true)
		_check(not SaveStore.validate_state(invalid).is_empty() and not sim.restore(invalid), "Invalid loadout is rejected before restoration: %s" % patch.keys()[0])
		_check(sim.snapshot() == baseline, "Rejected loadout preserves the current session")
	for pickups: Variant in ["bad", [{"id": 3, "weapon_id": "unknown", "position": {"x": 700, "y": 500}}], [{"id": 1, "weapon_id": "rifle", "position": {"x": 700, "y": 500}}], [{"id": 3, "weapon_id": "rifle", "position": {"x": 700, "y": 500}}, {"id": 3, "weapon_id": "heavy_rifle", "position": {"x": 800, "y": 500}}]]:
		var invalid: Dictionary = baseline.duplicate(true)
		invalid.weapon_pickups = pickups
		_check(not SaveStore.validate_state(invalid).is_empty() and not sim.restore(invalid), "Malformed, unknown or duplicate pickup state is rejected")
		_check(sim.snapshot() == baseline, "Rejected pickup state preserves the current session")
