extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	_test_capacity_reach_and_expiry()
	_test_acceptance_and_interruption()
	_test_death_ownership()
	_test_upgrades_and_sequences()
	_test_spawn_invariants()
	_test_return_to_hermes()
	_test_save_phases_and_validation()
	_test_movement_and_weapon()
	_test_self_destruct_deadlines()
	_test_disarm_interruption_and_pause()
	_test_self_destruct_saves()
	if failures.is_empty():
		print("PASS resource gathering: %d assertions" % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("FAIL resource gathering: %d / %d assertions" % [failures.size(), checks])
		quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _game() -> GameSimulation:
	var sim := GameSimulation.new()
	sim.configure({"number": 1, "width": 64, "height": 64, "tile_size": 32,
		"blocked": [], "player_start": Vector2(300, 300),
		"hermes_start": Vector2(600, 300), "enemies": [], "wave_based": false})
	sim.set_hermes_mode("building")
	return sim

func _advance(sim: GameSimulation, seconds: float, fps: int = 60) -> void:
	for index: int in roundi(seconds * fps):
		sim.step(1.0 / fps)

func _test_capacity_reach_and_expiry() -> void:
	var sim: GameSimulation = _game()
	var corpse: Dictionary = sim.spawn_resource(10, sim.nathaniel.position + Vector2(45, 0), 10, false, "gunSoldier")
	sim.step(0)
	_check(corpse.phase == "loose" and not sim.nathaniel.has_corpse, "Starter arms do not reach beyond 44 points")
	corpse.position.x -= 1
	sim.step(0.1)
	_check(corpse.phase == "grab" and not corpse.carried and sim.resources == 30, "Grab begins at reach boundary without resource credit")
	sim.nathaniel.position.x -= 2
	sim.step(0)
	_check(corpse.phase == "loose" and corpse.cargo_slot == -1, "Moving beyond arm reach cancels an ungripped body")
	sim.nathaniel.position = corpse.position
	sim.step(GameBalance.RESOURCE_GRAB_SECONDS)
	_check(corpse.phase == "crush" and corpse.carried, "Grip transfers ground ownership to the arms")
	sim.step(GameBalance.RESOURCE_CRUSH_SECONDS)
	_check(corpse.phase == "carry" and corpse.source_kind == "gunSoldier" and corpse.amount == 10, "Crush stores one bundle with unchanged source and value")
	var next: Dictionary = sim.spawn_resource(10, sim.nathaniel.position)
	sim.step(9.9)
	_check(next.phase == "loose" and sim.carried_resource_count() == 1, "Full starter rack leaves another body on the ground")
	sim.step(0.1)
	_check(not sim.corpses.has(next), "Loose body expires at ten seconds")
	sim.step(20)
	_check(sim.corpses.size() == 1 and corpse.carried, "Held bundle never expires")
	corpse.expiration = 0
	sim.step(0)
	_check(sim.corpses.has(corpse), "An old zero-expiry carried bundle is preserved")

func _test_acceptance_and_interruption() -> void:
	for mode: String in ["following", "building"]:
		var sim: GameSimulation = _game()
		sim.set_hermes_mode(mode)
		sim.spawn_resource(10, sim.hermes.position)
		sim.step(0)
		_check(sim.resources == 30 and sim.corpses.size() == 1, "Living Hermes does not credit loose matter in " + mode)
		sim.nathaniel.position = sim.hermes.position + Vector2(44, 0)
		sim.step(0.6)
		_check(sim.resources == 30 and sim.carried_resource_count() == 1, "Collection itself creates no wallet resources in " + mode)
		sim.step(0.22)
		_check(sim.corpses[0].phase == "feed" and sim.resources == 30, "Presentation opens the intake before acceptance in " + mode)
		sim.nathaniel.position = sim.hermes.position + Vector2(49, 0)
		sim.step(0.1)
		_check(sim.corpses[0].phase == "carry" and sim.resources == 30, "Leaving intake reach cancels feed without credit in " + mode)
		sim.nathaniel.position = sim.hermes.position + Vector2(48, 0)
		sim.step(0.59)
		_check(sim.resources == 30 and sim.corpses.size() == 1, "Bundle remains owned until feed completion in " + mode)
		sim.step(0.01)
		_check(sim.resources == 40 and sim.corpses.is_empty() and not sim.nathaniel.has_corpse, "Accepted delivery transfers one bundle once in " + mode)
		_check(is_equal_approx(float(sim.hermes.furnace_remaining), GameBalance.RESOURCE_FURNACE_SECONDS), "Furnace pulse starts at accepted delivery in " + mode)
		sim.step(1)
		var deliveries: int = 0
		for event: Dictionary in sim.take_events():
			if event.type == "delivery":
				deliveries += 1
		_check(deliveries == 1 and sim.resources == 40 and sim.hermes.furnace_remaining == 0, "No repeated credit or furnace event in " + mode)
	for fps: int in [30, 60, 120]:
		var sim: GameSimulation = _game()
		sim.hermes.position = sim.nathaniel.position + Vector2(40, 0)
		sim.spawn_resource(10, sim.nathaniel.position)
		_advance(sim, 1.2, fps)
		_check(sim.resources == 40 and sim.corpses.is_empty(), "Gathering finishes after 1.2 seconds at %d FPS" % fps)

func _test_death_ownership() -> void:
	for time: float in [0.1, 0.4, 0.6, 0.8, 1.1]:
		var sim: GameSimulation = _game()
		sim.hermes.position = sim.nathaniel.position + Vector2(40, 0)
		var corpse: Dictionary = sim.spawn_resource(10, sim.nathaniel.position)
		sim.step(time)
		var location: Vector2 = sim.nathaniel.position
		sim.damage_entity(int(sim.nathaniel.id), 8000)
		_check(sim.corpses.size() == 1 and not corpse.carried and corpse.phase == "loose" and corpse.position == location and sim.resources == 30, "Death preserves one uncredited body at %.1fs" % time)
		_check(not sim.nathaniel.has_corpse and corpse.cargo_slot == -1, "Death releases cargo ownership at %.1fs" % time)
		if time >= GameBalance.RESOURCE_GRAB_SECONDS:
			_check(corpse.disarmed and corpse.expiration == 0.0, "Dropped held matter remains disarmed at %.1fs" % time)
		else:
			_check(not corpse.disarmed and is_equal_approx(float(corpse.expiration), 10.0 - time), "Death before grip preserves the armed deadline at %.1fs" % time)
	var sim: GameSimulation = _game()
	sim.hermes.position = sim.nathaniel.position + Vector2(40, 0)
	sim.spawn_resource(10, sim.nathaniel.position)
	sim.step(1.1)
	sim.damage_entity(int(sim.hermes.id), 2000)
	_check(sim.resources == 30 and sim.corpses[0].phase == "carry" and sim.corpses[0].carried, "Hermes death cancels an unaccepted feed and preserves cargo")

func _test_upgrades_and_sequences() -> void:
	var sim: GameSimulation = _game()
	sim.resources = 200
	_check(sim.gathering_upgrade_cost("capacity") == 20 and sim.gathering_upgrade_cost("reach") == 15, "Starter upgrades expose separate prices")
	sim.spawn_resource(10, sim.nathaniel.position)
	sim.step(0.1)
	_check(sim.upgrade_gathering("capacity") and sim.nathaniel.resource_capacity == 2 and sim.nathaniel.resource_reach == 44, "Capacity can increase during grab without changing reach")
	_check(sim.upgrade_gathering("capacity") and sim.upgrade_gathering("reach") and sim.upgrade_gathering("reach"), "Both upgrade paths reach their supported maximum")
	_check(sim.nathaniel.resource_capacity == 3 and sim.nathaniel.resource_reach == 76 and sim.resources == 95, "Upgrade prices are charged exactly once")
	_check(sim.gathering_upgrade_cost("capacity") == -1 and not sim.upgrade_gathering("capacity") and not sim.upgrade_gathering("other"), "Invalid and completed upgrade paths cannot charge resources")
	sim.spawn_resource(10, sim.nathaniel.position + Vector2(76, 0))
	sim.spawn_resource(20, sim.nathaniel.position + Vector2(74, 0), 10, false, "gunSoldier")
	sim.step(1.7)
	_check(sim.carried_resource_count() == 3 and sim.corpses[0].cargo_slot == 0 and sim.corpses[1].cargo_slot != sim.corpses[2].cargo_slot, "One arm pair fills each upgraded slot in sequence")
	sim.hermes.position = sim.nathaniel.position + Vector2(40, 0)
	sim.step(0.6)
	_check(sim.resources == 105 and sim.carried_resource_count() == 2, "First accepted bundle empties only one rack slot")
	sim.step(0.54)
	_check(sim.resources == 105 and sim.carried_resource_count() == 2, "Furnace completion separates accepted transfers")
	sim.step(2)
	_check(sim.resources == 135 and sim.corpses.is_empty(), "Larger rack feeds every distinct bundle once")
	var restored := GameSimulation.new()
	_check(restored.restore(sim.snapshot()) and restored.nathaniel.resource_capacity == 3 and restored.nathaniel.resource_reach == 76, "Upgrade values persist in native saves")
	sim.damage_entity(int(sim.nathaniel.id), 8000)
	_check(sim.nathaniel.resource_capacity == 3 and sim.nathaniel.resource_reach == 76, "A spare-life respawn preserves upgrades")
	sim.configure(sim.level)
	_check(sim.nathaniel.resource_capacity == 1 and sim.nathaniel.resource_reach == 44, "A fresh level resets the starter backpack")
	sim.resources = 0
	_check(not sim.upgrade_gathering("capacity"), "An unaffordable upgrade is rejected")
	sim.resources = 100
	sim.paused = true
	_check(not sim.upgrade_gathering("reach"), "Pause rejects upgrade mutations")

func _test_save_phases_and_validation() -> void:
	for time: float in [0.1, 0.4, 0.65, 0.9, 1.3]:
		var sim: GameSimulation = _game()
		sim.hermes.position = sim.nathaniel.position + Vector2(40, 0)
		sim.spawn_resource(10, sim.nathaniel.position, 10, false, "gunSoldier")
		sim.step(time)
		var restored := GameSimulation.new()
		var saved: Dictionary = JSON.parse_string(JSON.stringify(sim.snapshot()))
		_check(restored.restore(saved), "JSON restores in-flight gathering at %.2fs" % time)
		_check(restored.take_events().is_empty(), "Restore emits no delivery effect at %.2fs" % time)
		sim.step(2)
		restored.step(2)
		_check(restored.resources == 40 and restored.resources == sim.resources and restored.corpses.is_empty(), "Restored action completes with one credit at %.2fs" % time)
	var sim: GameSimulation = _game()
	sim.spawn_resource(10, sim.nathaniel.position, 10, true, "gunSoldier")
	var legacy: Dictionary = sim.snapshot()
	legacy.entities[0].erase("resource_capacity")
	legacy.entities[0].erase("resource_reach")
	legacy.entities[1].erase("furnace_remaining")
	for key: String in ["phase", "phase_elapsed", "cargo_slot", "pickup_position", "disarmed"]:
		legacy.corpses[0].erase(key)
	var extra: Dictionary = legacy.corpses[0].duplicate(true)
	extra.id = 99
	legacy.corpses.append(extra)
	var restored := GameSimulation.new()
	_check(restored.restore(legacy) and restored.carried_resource_count() == 1 and restored.corpses.size() == 2, "Legacy excess cargo drops without loss or credit")
	_check(restored.corpses[1].phase == "loose" and restored.corpses[1].disarmed and restored.corpses[1].expiration == 0 and restored.corpses[0].source_kind == "gunSoldier", "Legacy cargo migration preserves source type and leaves dropped matter safe")
	for field: String in ["phase", "phase_elapsed", "cargo_slot", "amount", "carried"]:
		var broken: Dictionary = sim.snapshot()
		match field:
			"phase": broken.corpses[0].phase = "magic"
			"phase_elapsed": broken.corpses[0].phase_elapsed = -1
			"cargo_slot": broken.corpses[0].cargo_slot = 9
			"amount": broken.corpses[0].amount = 0.5
			"carried": broken.corpses[0].carried = false
		var before: Dictionary = restored.snapshot()
		_check(not restored.restore(broken) and restored.snapshot() == before, "Invalid %s rejects restore without changing the running game" % field)
	var duplicate: Dictionary = sim.snapshot()
	duplicate.entities[0].resource_capacity = 2
	extra = duplicate.corpses[0].duplicate(true)
	extra.id = 99
	duplicate.corpses.append(extra)
	_check(not restored.restore(duplicate), "Two bundles cannot own one cargo slot")
	for field: String in ["resource_capacity", "resource_reach", "furnace_remaining", "missing_phase", "multiple_actions"]:
		var broken: Dictionary = sim.snapshot()
		match field:
			"resource_capacity": broken.entities[0].resource_capacity = 1.5
			"resource_reach": broken.entities[0].resource_reach = 0
			"furnace_remaining": broken.entities[1].furnace_remaining = 1.0
			"missing_phase": broken.corpses[0].erase("phase")
			"multiple_actions":
				broken.entities[0].resource_capacity = 2
				broken.corpses[0].phase = "feed"
				extra = broken.corpses[0].duplicate(true)
				extra.id = 99
				extra.cargo_slot = 1
				broken.corpses.append(extra)
		_check(not restored.restore(broken), "Invalid gathering %s fails state validation" % field)

func _test_spawn_invariants() -> void:
	var sim: GameSimulation = _game()
	sim.resources = 100
	sim.upgrade_gathering("capacity")
	sim.spawn_resource(10, sim.nathaniel.position, 10, true)
	var second: Dictionary = sim.spawn_resource(20, sim.nathaniel.position, 10, true)
	sim.hermes.position = sim.nathaniel.position + Vector2(40, 0)
	sim.step(0.6)
	var replacement: Dictionary = sim.spawn_resource(30, sim.nathaniel.position, 10, true)
	_check(second.cargo_slot == 1 and replacement.cargo_slot == 0, "Explicit carried setup fills the vacant slot after a delivery")
	var overflow: Dictionary = sim.spawn_resource(10, Vector2.ZERO, 0, true)
	_check(not overflow.carried and overflow.phase == "loose" and overflow.disarmed and overflow.expiration == 0 and overflow.position == sim.nathaniel.position, "Explicit carried overflow drops safely at Nathaniel without loss")
	var restored := GameSimulation.new()
	_check(restored.restore(sim.snapshot()), "Explicit resource setup always produces valid cargo ownership")
	var before: Dictionary = sim.snapshot()
	_check(sim.spawn_resource(0, sim.nathaniel.position).is_empty() and sim.spawn_resource(10, Vector2(INF, 0)).is_empty() and sim.spawn_resource(10, Vector2.ZERO, INF).is_empty() and sim.spawn_resource(10, Vector2.ZERO, 10, false, "unknown").is_empty() and sim.snapshot() == before, "Invalid resource setup leaves the allocator and game unchanged")
	sim.hermes.hp = 0
	_check(not sim.upgrade_gathering("reach"), "A dead Hermes cannot build a backpack upgrade")

func _test_movement_and_weapon() -> void:
	var sim: GameSimulation = _game()
	var corpse: Dictionary = sim.spawn_resource(10, sim.nathaniel.position)
	sim.step(0.1)
	sim.move_to(sim.nathaniel.position + Vector2(20, 0))
	sim.nathaniel.cooldown = 10
	_check(sim.fire_at(sim.nathaniel.position + Vector2(0, -100)), "Rifle accepts fire during a grab")
	var start: Vector2 = sim.nathaniel.position
	sim.step(0.1)
	_check(sim.nathaniel.position != start and corpse.phase == "grab" and not sim.projectiles.is_empty(), "Movement and rifle fire continue during backpack handling")

func _test_return_to_hermes() -> void:
	for mode: String in ["following", "building"]:
		var sim: GameSimulation = _game()
		sim.hermes.position = Vector2(1800, 300)
		sim.set_hermes_mode(mode)
		sim.resources = 200
		sim.upgrade_gathering("capacity")
		sim.upgrade_gathering("capacity")
		for index: int in 3:
			sim.spawn_resource(10, sim.nathaniel.position, 10, true)
		_check(sim.return_to_hermes() and sim.nathaniel.returning_cargo, "Return accepts a full rack while Hermes is " + mode)
		sim.step(0.1)
		sim.nathaniel.cooldown = 10
		_check(sim.fire_at(sim.nathaniel.position + Vector2(0, -100)) and sim.nathaniel.returning_cargo, "Manual fire preserves cargo return while Hermes is " + mode)
		var restored := GameSimulation.new()
		_check(restored.restore(sim.snapshot()) and restored.nathaniel.returning_cargo, "Save/load preserves cargo return while Hermes is " + mode)
		_advance(restored, 30)
		_check(restored.resources == 170 and restored.corpses.is_empty() and not restored.nathaniel.returning_cargo, "Long return feeds all three bundles while Hermes is " + mode)
		_check(Vector2(restored.nathaniel.position).distance_to(restored.hermes.position) <= GameBalance.RESOURCE_RETURN_DISTANCE and not restored.nathaniel.moving, "Return stops at the intake without walking past Hermes in " + mode)
	var sim: GameSimulation = _game()
	_check(not sim.return_to_hermes(), "An empty rack cannot start cargo return")
	sim.spawn_resource(10, sim.nathaniel.position, 10, true)
	sim.return_to_hermes()
	sim.stop_player()
	sim.step(0.1)
	_check(not sim.nathaniel.returning_cargo and not sim.nathaniel.moving, "Stop cancels cargo return without resuming it next frame")
	sim.return_to_hermes()
	var destination: Vector2 = sim.nathaniel.position + Vector2(0, 100)
	sim.move_to(destination)
	sim.step(0.1)
	_check(not sim.nathaniel.returning_cargo and sim.nathaniel.destination == destination, "Manual movement replaces cargo return")
	sim.return_to_hermes()
	sim.damage_entity(int(sim.nathaniel.id), 8000)
	_check(not sim.nathaniel.returning_cargo, "Death cancels cargo return before spare-life respawn")
	sim.spawn_resource(10, sim.nathaniel.position, 10, true)
	sim.return_to_hermes()
	sim.damage_entity(int(sim.hermes.id), 2000)
	_check(not sim.nathaniel.returning_cargo and not sim.nathaniel.moving, "Hermes death cancels cargo return immediately")
	var invalid: Dictionary = sim.snapshot()
	invalid.entities[0].returning_cargo = 1
	_check(not GameSimulation.gathering_state_error(invalid).is_empty(), "Saved cargo return must be a boolean")

func _test_self_destruct_deadlines() -> void:
	var sim: GameSimulation = _game()
	var corpse: Dictionary = sim.spawn_resource(10, Vector2(900, 900))
	sim.step(7)
	_check(not corpse.disarmed and corpse.expiration == GameBalance.RESOURCE_WARNING_SECONDS, "Warning begins inside the existing ten-second deadline")
	sim.nathaniel.position = corpse.position
	sim.step(GameBalance.RESOURCE_GRAB_SECONDS)
	_check(corpse.disarmed and corpse.carried and corpse.cargo_slot == 0 and corpse.expiration == 0, "Grip during warning atomically disarms and assigns a cargo slot")
	_check(sim.resources == 30, "Disarming a warning body does not credit resources")
	for lifetime: float in [0.1, GameBalance.RESOURCE_GRAB_SECONDS - 0.000000001, GameBalance.RESOURCE_GRAB_SECONDS]:
		sim = _game()
		corpse = sim.spawn_resource(10, sim.nathaniel.position, lifetime)
		sim.step(GameBalance.RESOURCE_GRAB_SECONDS)
		_check(sim.corpses.is_empty() and not sim.nathaniel.has_corpse and sim.resources == 30, "Expiry during grab or at grip boundary loses matter at %.10fs" % lifetime)
		var expired_count: int = 0
		for event: Dictionary in sim.take_events():
			if event.type == "corpse_expired":
				expired_count += 1
				_check(event.corpse_id == corpse.id and event.source_kind == corpse.source_kind and event.position == corpse.position, "Expiry event retains body identity and source for dissolution")
		_check(expired_count == 1, "Each expired body starts one dissolution")
		sim.step(1)
		_check(sim.take_events().is_empty(), "Expired matter cannot repeat effects or delivery")
	for lifetime: float in [GameBalance.RESOURCE_GRAB_SECONDS + 0.000000001, 0.29]:
		sim = _game()
		corpse = sim.spawn_resource(10, sim.nathaniel.position, lifetime)
		sim.step(GameBalance.RESOURCE_GRAB_SECONDS)
		_check(corpse.disarmed and corpse.carried and sim.corpses.size() == 1, "Grip just before expiry succeeds at %.10fs" % lifetime)
	for steps: Array in [[0.27, 0.01], [0.1, 0.1, 0.08], [1.0 / 60, 1.0 / 60, 1.0 / 60, 0.23]]:
		sim = _game()
		sim.spawn_resource(10, sim.nathaniel.position, GameBalance.RESOURCE_GRAB_SECONDS)
		for delta: float in steps:
			sim.step(delta)
		_check(sim.corpses.is_empty() and sim.resources == 30, "Expiry wins a split-step grip boundary: %s" % str(steps))
	sim = _game()
	corpse = sim.spawn_resource(10, Vector2(900, 900))
	sim.step(9.7)
	sim.step(0.02)
	sim.nathaniel.position = corpse.position
	sim.step(0.28)
	_check(sim.corpses.is_empty(), "Floating-point residue cannot rescue a body at its exact ten-second deadline")
	sim = _game()
	corpse = sim.spawn_resource(10, Vector2(900, 900), 0.1, false, "gunSoldier")
	var later: Dictionary = sim.spawn_resource(10, Vector2(950, 900), 0.4)
	sim.step(0.35)
	_check(sim.corpses.size() == 1 and sim.corpses[0] == later and is_equal_approx(float(later.expiration), 0.05), "Nearby bodies retain independent self-destruct deadlines")
	var expiry: Dictionary = {}
	for event: Dictionary in sim.take_events():
		if event.type == "corpse_expired":
			expiry = event
	_check(not expiry.is_empty() and expiry.corpse_id == corpse.id and is_equal_approx(float(expiry.elapsed_since_expiry), 0.25), "Dissolution starts with the elapsed part of a large step")
	_check(sim.nathaniel.hp == sim.nathaniel.max_hp and sim.hermes.hp == sim.hermes.max_hp and sim.resources == 30, "Internal breakdown causes no damage or resource reward")

func _test_disarm_interruption_and_pause() -> void:
	var sim: GameSimulation = _game()
	var corpse: Dictionary = sim.spawn_resource(10, sim.nathaniel.position, 1)
	sim.step(0.1)
	_check(corpse.cargo_slot == -1 and not corpse.disarmed, "Starting a grab reserves no slot and leaves the countdown armed")
	sim.nathaniel.position += Vector2(100, 0)
	sim.step(0)
	_check(corpse.phase == "loose" and is_equal_approx(float(corpse.expiration), 0.9), "Leaving reach before grip preserves the deadline")
	sim.paused = true
	sim.step(20)
	_check(is_equal_approx(float(corpse.expiration), 0.9) and sim.corpses.size() == 1, "Pause freezes armed self-destruct time")
	sim.paused = false
	sim.nathaniel.position = corpse.position
	sim.step(0.1)
	var elapsed: float = corpse.phase_elapsed
	sim.paused = true
	sim.step(20)
	_check(corpse.phase_elapsed == elapsed and not corpse.disarmed and is_equal_approx(float(corpse.expiration), 0.8), "Pause freezes a grab and its armed warning countdown")
	sim.paused = false
	sim.step(0.18)
	_check(corpse.disarmed and corpse.carried, "Resuming completes the remaining grip time")
	sim.damage_entity(int(sim.nathaniel.id), int(sim.nathaniel.max_hp))
	sim.nathaniel.position = Vector2(900, 900)
	sim.step(20)
	_check(sim.corpses.size() == 1 and corpse.disarmed and not corpse.carried and corpse.expiration == 0, "A death drop remains safe beyond the former lifetime")
	sim.nathaniel.position = corpse.position
	sim.step(0.6)
	_check(corpse.disarmed and corpse.carried and sim.resources == 30, "Safe dropped cargo can be collected again without credit")
	sim = _game()
	corpse = sim.spawn_resource(10, sim.nathaniel.position, 1)
	sim.step(0.1)
	var occupied: Dictionary = sim.spawn_resource(10, sim.nathaniel.position, 10, true)
	sim.step(0.18)
	_check(corpse.phase == "loose" and not corpse.disarmed and not corpse.carried and occupied.cargo_slot == 0, "Grip rechecks a slot occupied after the grab began")
	sim.step(0.72)
	_check(sim.corpses.size() == 1 and sim.corpses[0] == occupied, "Full cargo capacity cannot disarm nearby armed matter")

func _test_self_destruct_saves() -> void:
	for remaining: float in [7.5, 2.5]:
		var sim: GameSimulation = _game()
		sim.spawn_resource(10, Vector2(900, 900), remaining)
		var restored := GameSimulation.new()
		_check(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))), "Armed or warning state restores with %.1fs remaining" % remaining)
		_check(not restored.corpses[0].disarmed and restored.corpses[0].expiration == remaining, "Loading preserves the armed deadline with %.1fs remaining" % remaining)
		restored.step(remaining)
		_check(restored.corpses.is_empty() and restored.resources == 30, "Restored armed matter expires without reward")
		var after_expiry := GameSimulation.new()
		_check(after_expiry.restore(restored.snapshot()) and after_expiry.corpses.is_empty() and after_expiry.take_events().is_empty(), "Saving during dissolution cannot restore lost matter or repeat expiry")
	var sim: GameSimulation = _game()
	var corpse: Dictionary = sim.spawn_resource(10, sim.nathaniel.position, 10, true)
	sim.damage_entity(int(sim.nathaniel.id), int(sim.nathaniel.max_hp))
	var restored := GameSimulation.new()
	_check(restored.restore(sim.snapshot()) and restored.corpses[0].disarmed and not restored.corpses[0].carried, "Safe loose death drops retain permanent disarm through save/load")
	restored.nathaniel.position = Vector2(900, 900)
	restored.step(20)
	_check(restored.corpses.size() == 1, "Loaded safe loose matter never expires")
	sim = _game()
	corpse = sim.spawn_resource(10, Vector2(900, 900), 2.5)
	var legacy: Dictionary = sim.snapshot()
	legacy.corpses[0].erase("disarmed")
	_check(restored.restore(legacy) and not restored.corpses[0].disarmed and restored.corpses[0].expiration == 2.5, "Legacy loose matter keeps its remaining armed lifetime")
	legacy.corpses[0].expiration = 0
	_check(restored.restore(legacy) and restored.corpses.is_empty(), "A legacy expired body cannot return as collectible matter")
	legacy.corpses[0].expiration = 2.5
	legacy.corpses[0].phase = "grab"
	legacy.corpses[0].cargo_slot = 0
	legacy.corpses[0].phase_elapsed = 0.1
	_check(restored.restore(legacy) and not restored.corpses[0].disarmed and restored.corpses[0].cargo_slot == -1, "Legacy grab keeps its timer and defers slot assignment until grip")
	for invalid_value: Variant in [0, "false", null]:
		var broken: Dictionary = sim.snapshot()
		broken.corpses[0].disarmed = invalid_value
		var before: Dictionary = restored.snapshot()
		_check(not restored.restore(broken) and restored.snapshot() == before, "Invalid disarm values reject restoration without mutation")
	sim = _game()
	sim.spawn_resource(10, sim.nathaniel.position, 10, true)
	var broken: Dictionary = sim.snapshot()
	broken.corpses[0].disarmed = false
	_check(not restored.restore(broken), "Current held cargo cannot restore an armed mechanism")
