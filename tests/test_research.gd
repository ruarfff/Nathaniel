extends SceneTree

var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_test_deaths_and_stacks()
	_test_collection_and_priority()
	_test_obstacles_and_approach()
	_test_build_and_removal()
	_test_ranks_and_pause()
	_test_restore_and_run_scope()
	_test_farming()
	for failure: String in failures:
		push_error(failure)
	print("Research domain: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _game(number: int = 0, blocked: Array = []) -> GameSimulation:
	var sim := GameSimulation.new()
	sim.configure({"number": number, "width": 40, "height": 40, "tile_size": 32,
		"blocked": blocked, "player_start": Vector2(300, 300), "hermes_start": Vector2(500, 300),
		"wave_based": false, "starting_resources": 100, "starting_lives": 0, "enemies": []})
	return sim

func _advance(sim: GameSimulation, seconds: float) -> void:
	for frame: int in ceili(seconds * 60.0):
		sim.step(1.0 / 60.0)

func _kill(sim: GameSimulation, kind: String, position: Vector2) -> Dictionary:
	var enemy: Dictionary = sim.spawn_enemy(kind, position)
	sim.damage_entity(enemy.id, enemy.hp)
	return enemy

func _center(sim: GameSimulation) -> Dictionary:
	_check(sim.place_tower("researchCenter", Vector2(600, 300)), "Research accepts normal build placement")
	return sim.research_center()

func _total(sim: GameSimulation) -> int:
	var total: int = sim.tech
	for pickup: Dictionary in sim.tech_pickups:
		total += int(pickup.amount)
	return total

func _test_deaths_and_stacks() -> void:
	var sim := _game()
	var grunt: Dictionary = _kill(sim, "grunt", Vector2(850, 500))
	_check(sim.tech_pickups.size() == 1 and sim.tech_pickups[0].amount == 1, "Grunt death creates one module")
	sim.damage_entity(grunt.id, 9000)
	_check(_total(sim) == 1, "Repeated death command cannot duplicate tech")
	_kill(sim, "spawner", Vector2(1000, 800))
	_check(sim.tech_pickups.size() == 2 and sim.tech_pickups[1].amount == 8 and sim.tech_pickups[1].kind == "core", "Spawner death creates one eight-tech core")
	_check(sim.corpses.is_empty(), "Tech enemies do not leave matter corpses")
	var deaths: int = 0
	for event: Dictionary in sim.take_events():
		if event.type == "death":
			deaths += 1
	_check(deaths == 2, "Both tech death effects retain their independent events")
	_advance(sim, 12.0)
	_check(_total(sim) == 9 and sim.tech_pickups.size() == 2, "Tech does not expire with corpse lifetime")
	for kind: String in ["soldier", "gunSoldier", "boss"]:
		_kill(sim, kind, Vector2(900, 600))
	_check(sim.corpses.size() == 3 and _total(sim) == 9, "Matter enemy outcomes remain unchanged")
	var stack: Dictionary = sim.spawn_tech(39, Vector2(851, 500))
	_check(stack.amount == 40 and _total(sim) == 48, "Local merging preserves unbounded stack quantity")
	var campaign := _game(1)
	_kill(campaign, "grunt", Vector2(850, 500))
	_kill(campaign, "spawner", Vector2(1000, 800))
	_check(campaign.tech_pickups.is_empty(), "Campaign does not acquire a new tech economy")
	var child_sim := _game()
	var spawner: Dictionary = child_sim.spawn_enemy("spawner", Vector2(850, 850))
	spawner.spawn_countdown = 0.0
	BattlefieldRules.update_spawner(child_sim, spawner, 0.01)
	var children: int = 0
	for unit: Dictionary in child_sim.entities.duplicate():
		if unit.kind == "grunt":
			children += 1
			child_sim.damage_entity(unit.id, unit.hp)
	_check(children > 0 and _total(child_sim) == children, "Each real spawner child earns the same grunt yield")

func _test_collection_and_priority() -> void:
	var sim := _game()
	sim.spawn_resource(10, sim.nathaniel.position, 0.0, true)
	var pickup: Dictionary = sim.spawn_tech(8, Vector2(325, 300), "core")
	sim.step(0.1)
	_check(pickup.phase == "collect" and pickup.owner_id == sim.nathaniel.id and sim.tech == 0, "Full matter rack can begin separate tech collection")
	_check(sim.hermes_mode == "following" and sim.research_center().is_empty(), "Collection needs no base or research center")
	var id: int = pickup.id
	var restored := GameSimulation.new()
	_check(restored.restore(sim.snapshot()), "An active collection snapshot restores")
	_advance(restored, 0.3)
	_check(restored.tech == 8 and restored.tech_pickup(id).is_empty(), "Saved collection consumes and credits once")
	_check(not restored.approach_tech(id), "A consumed drop cannot be claimed twice")
	_advance(restored, 1.0)
	_check(restored.tech == 8 and restored.carried_resource_count() == 1, "Tech does not consume cargo or re-award after acceptance")
	sim.nathaniel.position = Vector2(200, 300)
	sim.step(0.3)
	_check(pickup.phase == "loose" and pickup.owner_id == 0 and sim.tech == 0, "Leaving reach before acceptance releases the original drop")
	sim.nathaniel.position = Vector2(300, 300)
	sim.step(0.1)
	var unclaimed: Dictionary = sim.spawn_tech(3, Vector2(326, 300))
	_check(sim.tech_pickups.size() == 2 and pickup.amount == 8 and unclaimed.amount == 3, "Claimed tech is excluded from merging")
	var rescue := _game()
	var body: Dictionary = rescue.spawn_resource(10, Vector2(310, 300))
	var module: Dictionary = rescue.spawn_tech(1, Vector2(325, 300))
	rescue.step(0.1)
	_check(body.phase == "grab" and module.phase == "loose", "Urgent corpse grip takes priority over new tech")
	_check(not rescue.approach_tech(module.id), "Tech approach cannot interrupt a matter grip")
	_advance(rescue, 1.0)
	_check(rescue.tech == 1 and rescue.carried_resource_count() == 1, "Tech resumes when the body is safely carried")
	rescue.spawn_tech(2, rescue.nathaniel.position)
	_check(rescue.return_to_hermes(), "Cargo return can start while tech is nearby")
	rescue.step(0.1)
	_check(rescue.tech == 1 and rescue.tech_collection_state().is_empty(), "An active matter return retains priority")
	var moving := _game()
	moving.spawn_tech(1, Vector2(325, 300))
	moving.move_to(Vector2(800, 300))
	moving.step(0.1)
	_check(moving.nathaniel.destination == Vector2(800, 300) and moving.tech_target_id == 0, "Automatic collection never redirects movement")
	var boundary := _game()
	boundary.spawn_resource(10, Vector2(310, 300))
	boundary.spawn_tech(1, Vector2(325, 300))
	boundary.step(0.0)
	boundary.step(GameBalance.RESOURCE_GRAB_SECONDS + GameBalance.RESOURCE_CRUSH_SECONDS)
	_check(boundary.carried_resource_count() == 1 and boundary.tech == 0, "A large step does not reuse matter handling time as tech collection time")
	boundary.step(GameBalance.TECH_COLLECTION_SECONDS)
	_check(boundary.tech == 1, "Tech receives its own full collection interval after the matter grip")

func _test_obstacles_and_approach() -> void:
	var wall: Array = []
	for y: int in 40:
		wall.append(Vector2i(10, y))
	var sim := _game(0, wall)
	sim.nathaniel.position = Vector2(275, 300)
	var pickup: Dictionary = sim.spawn_tech(5, Vector2(400, 300))
	_check(pickup.phase == "deferred" and pickup.position.x == 400, "An unreachable death retains value without scattering through a wall")
	# Place both sides explicitly to exercise collection and merge barriers.
	var left: Dictionary = sim.spawn_tech(2, Vector2(280, 300))
	var right: Dictionary = {"id": sim.allocate_id(), "amount": 3, "position": Vector2(375, 300), "kind": "module", "phase": "loose", "phase_elapsed": 0.0, "owner_id": 0}
	sim.tech_pickups.append(right)
	sim.nathaniel.resource_reach = 140.0
	_check(not sim.approach_tech(right.id), "Tech approach rejects an unreachable route across a wall")
	_advance(sim, 0.4)
	_check(sim.tech_pickups.has(right) and right.amount == 3, "Extended pickup reach cannot collect through a wall")
	_check(not sim._tech_segment_clear(Vector2(310, 300), Vector2(360, 300)), "Merging cannot cross solid terrain")
	_check(left.amount >= 2, "Blocked merge does not discard existing quantities")
	var open := _game()
	var far: Dictionary = open.spawn_tech(4, Vector2(420, 300))
	_check(open.approach_tech(far.id), "Tech tap starts a valid approach")
	_check(open.approach_tech(far.id), "Repeated tap preserves the same approach")
	open.stop_player()
	_check(open.tech_target_id == 0 and open.nathaniel.destination == null and open.tech == 0, "Stop cancels approach without credit")
	_check(open.approach_tech(far.id), "A cancelled approach can be issued again")
	open.move_to(Vector2(300, 600))
	_check(open.tech_target_id == 0 and open.nathaniel.destination == Vector2(300, 600), "A new movement order replaces tech approach")
	open.stop_player()
	_check(open.approach_tech(far.id), "Approach restarts after replacement")
	_advance(open, 2.0)
	_check(open.tech == 4 and open.tech_pickups.is_empty(), "Approach stops within reach and completes collection")
	var deferred := _game()
	deferred.navigation.blocked.clear()
	for y: int in 40:
		for x: int in 40:
			deferred.navigation.blocked[Vector2i(x, y)] = true
	deferred.navigation.invalidate()
	var held: Dictionary = deferred.spawn_tech(9, Vector2(-50, 50))
	_check(held.phase == "deferred" and _total(deferred) == 9, "No valid ground defers placement without losing value")
	deferred.navigation.configure(deferred.level)
	deferred.step(0.01)
	_check(held.phase == "loose" and deferred.navigation.walkable(held.position, deferred.nathaniel.radius), "Deferred value appears on clear ground after obstruction is removed")
	var blocked_route := _game()
	var factory: Dictionary = blocked_route.spawn_enemy("spawner", Vector2(450, 300))
	factory.damage = 0
	var behind_factory: Dictionary = blocked_route.spawn_tech(5, Vector2(650, 300))
	_check(blocked_route.approach_tech(behind_factory.id), "Tech approach can find a route around a live spawner")
	var previous: Vector2 = blocked_route.nathaniel.position
	for waypoint: Vector2 in blocked_route.nathaniel.path:
		_check(blocked_route._tech_navigation().segment_clear(previous, waypoint, blocked_route.nathaniel.radius), "Every tech route segment retains live spawner clearance")
		previous = waypoint
	var priority := _game()
	var urgent: Dictionary = priority.spawn_resource(10, Vector2(300, 600))
	var tempting: Dictionary = priority.spawn_tech(5, Vector2(330, 300))
	_check(priority.approach_corpse(urgent.id), "Distant corpse rescue starts an explicit order")
	_check(not priority.approach_tech(tempting.id), "A tech tap cannot replace distant corpse rescue")
	priority.step(0.1)
	_check(tempting.phase == "loose" and priority.corpse_target_id == urgent.id, "Automatic tech waits during a distant corpse rescue")
	priority.stop_player()
	_check(priority.corpse_target_id == 0 and priority.approach_tech(tempting.id), "Cancelling corpse rescue releases collection priority")

func _test_build_and_removal() -> void:
	var sim := _game()
	var center: Dictionary = _center(sim)
	_check(not center.is_empty() and center.owned and center.weapon == "none", "Research center is an owned noncombatant structure")
	_check(sim.resources == 90 and sim.hermes_mode == "building", "Center pays ten matter and deploys Hermes")
	_check(not sim.place_tower("research_center", Vector2(600, 400)) and sim.resources == 90, "Duplicate accepted build input cannot create a second center or spend")
	_check(sim.place_map_tower("researchCenter", Vector2(600, 400)).is_empty(), "Map insertion also enforces research singleton")
	sim.tech = 50
	_check(sim.begin_research(center.id), "Connected owned center opens research")
	_check(sim.purchase_research("capacity", 0, sim.research_session_id), "Center grants a valid research purchase")
	sim.set_hermes_mode("following")
	_check(sim.research_center().is_empty() and sim.research_session_id == 0 and not sim.paused, "Recycling invalidates center and research session")
	_check(sim.resources == 92 and sim.tech == 40 and sim.research_ranks.capacity == 1, "Recycle refunds only floor quarter matter and retains learned research")
	center = _center(sim)
	var before: int = sim.resources
	sim.damage_entity(center.id, center.hp)
	_check(sim.research_center().is_empty() and sim.resources == before, "Center destruction gives no matter refund")
	_check(sim.tech == 40 and sim.research_ranks.capacity == 1, "Center destruction retains wallet and learned ranks")
	center = _center(sim)
	_check(sim.begin_research(center.id), "Rebuilding restores access without repurchasing learned rank")
	sim.set_paused(true)
	sim.damage_entity(sim.hermes.id, sim.hermes.hp)
	_check(sim.result == "gameOver" and sim.research_session_id == 0 and sim.paused, "Hermes death closes research without clearing an earlier pause")
	var placement := _game()
	_check(not placement.place_tower("researchCenter", Vector2(1000, 300)), "Center retains the normal build radius")
	_check(not placement.place_tower("researchCenter", placement.hermes.position), "Center rejects overlapping Hermes")
	var pickup: Dictionary = placement.spawn_tech(3, Vector2(600, 300))
	_check(placement.placement_error(pickup.position) == "overlapsResource" and not placement.place_tower("gunTower", pickup.position), "Building cannot cover tech or cut its collection clearance")
	_check(placement.research_center().is_empty(), "Rejected placements do not reserve the singleton")
	var campaign := _game(1)
	_check(not campaign.place_tower("researchCenter", Vector2(600, 300)), "Campaign keeps its existing building economy")

func _test_ranks_and_pause() -> void:
	var sim := _game()
	var center: Dictionary = _center(sim)
	sim.tech = 200
	var gun: Dictionary = sim.place_map_tower("gunTower", Vector2(500, 450))
	gun.hp = 300
	var laser: Dictionary = sim.place_map_tower("laserTower", Vector2(700, 400))
	laser.hp = 300
	var healer: Dictionary = sim.place_map_tower("healTower", Vector2(700, 500))
	healer.hp = 300
	sim.spawn_resource(10, Vector2(800, 500))
	sim.spawn_tech(1, Vector2(325, 300))
	var enemy: Dictionary = sim.spawn_enemy("grunt", Vector2(800, 800))
	sim.fire_at(enemy.position)
	_check(sim.begin_research(center.id) and sim.paused, "Opening research immediately owns pause")
	var session: int = sim.research_session_id
	var frozen: Dictionary = sim.snapshot()
	sim.step(60.0)
	_check(sim.snapshot() == frozen, "Research freezes the entire simulation including clocks, drops, corpses, shots, AI and waves")
	for track: String in GameBalance.RESEARCH:
		var catalog: Dictionary = GameBalance.RESEARCH[track]
		for rank: int in 2:
			var balance: int = sim.tech
			_check(sim.purchase_research(track, rank, session), "%s rank %d buys during research pause" % [track, rank + 1])
			_check(sim.tech == balance - int(catalog.costs[rank]) and sim.research_ranks[track] == rank + 1, "Purchase deducts exactly one catalog price and rank")
			balance = sim.tech
			_check(not sim.purchase_research(track, rank, session) and sim.tech == balance, "Duplicate rank input is stale and cannot spend twice")
		_check(not sim.purchase_research(track, 2, session), "Maximum rank rejects another purchase")
	_check(sim.nathaniel.resource_capacity == 3 and sim.nathaniel.resource_reach == 76.0, "Backpack retains exact existing maximum values")
	_check(gun.max_hp == 810 and gun.hp == 405, "Plating preserves existing tower health fraction at both ranks")
	_check(laser.max_hp == 810 and laser.hp == 405 and healer.max_hp == 810 and healer.hp == 405, "Plating applies equally to laser and heal tower health fractions")
	_check(center.max_hp == 600, "Defense plating does not upgrade the research center")
	_check(is_equal_approx(sim.hermes.delay, GameBalance.HERMES_ANCHORED_WEAPON.delay), "Cooling does not change deployed cannon cooldown")
	_check(not sim.upgrade_gathering("capacity"), "The replaced survival matter purchase is rejected while paused")
	sim.end_research()
	_check(not sim.paused and not sim.purchase_research("reach", 0), "Closing releases only research authority")
	_check(not sim.upgrade_gathering("reach"), "Survival matter upgrade is also rejected during play")
	var new_tower: Dictionary = sim.place_map_tower("laserTower", Vector2(650, 450))
	_check(new_tower.max_hp == 810 and new_tower.hp == 810, "New towers inherit plating from their baseline")
	sim.set_hermes_mode("following")
	_check(is_equal_approx(sim.hermes.delay, 2.25), "Mobile shoulder cooldown uses total 25 percent reduction")
	for repeat: int in 3:
		sim.set_hermes_mode("building")
		sim.set_hermes_mode("following")
	_check(is_equal_approx(sim.hermes.delay, 2.25), "Redeployment cannot compound cooling")
	var gated := _game()
	center = _center(gated)
	gated.tech = 9
	gated.set_paused(true)
	_check(gated.begin_research(center.id), "Research can open over an existing manual pause")
	_check(not gated.purchase_research("capacity", 0) and gated.tech == 9, "Unaffordable purchase changes nothing")
	var state: Dictionary = gated.research_state()
	_check(state.tracks[0].reason == "Need 1 more Tech" and not state.tracks[0].available, "Menu reports exact insufficient balance")
	session = gated.research_session_id
	gated.end_research()
	_check(gated.paused, "Research close preserves manual pause")
	gated.set_paused(false)
	gated.begin_research(center.id)
	gated.tech = 100
	_check(not gated.purchase_research("capacity", 0, session), "A previous menu session cannot authorize a new purchase")
	gated.set_application_suspended(true)
	_check(not gated.purchase_research("capacity", 0, gated.research_session_id), "Suspended application cannot accept a research purchase")
	gated.end_research()
	_check(gated.paused, "Closing research preserves application suspension")
	gated.set_application_suspended(false)
	_check(not gated.paused, "Returning to application releases its own pause")
	var fresh := _game()
	center = _center(fresh)
	fresh.tech = 100
	fresh.begin_research(center.id)
	_check(not fresh.purchase_research("capacity", 0, session), "A purchase token from another run cannot authorize a fresh run")

func _test_restore_and_run_scope() -> void:
	var sim := _game()
	var center: Dictionary = _center(sim)
	sim.tech = 100
	sim.begin_research(center.id)
	sim.purchase_research("plating", 0)
	sim.purchase_research("cooling", 0)
	sim.purchase_research("capacity", 0)
	sim.purchase_research("reach", 0)
	var saved: Dictionary = sim.snapshot()
	var plated: Dictionary = sim.place_map_tower("gunTower", Vector2(600, 450))
	plated.hp = 360
	saved = sim.snapshot()
	var restored := GameSimulation.new()
	_check(restored.restore(saved), "Research run state restores")
	_check(not restored.paused and restored.research_session_id == 0, "Restoring discards stale menu ownership")
	for repeat: int in 3:
		_check(restored.restore(restored.snapshot()), "Repeated native research restore remains valid")
	_check(restored.research_ranks == sim.research_ranks and restored.tech == sim.tech, "Repeated restore keeps learned ranks and wallet")
	_check(restored.entity(plated.id).max_hp == 720 and restored.entity(plated.id).hp == 360, "Repeated restore preserves a plated tower's baseline and damaged health fraction")
	restored.set_hermes_mode("following")
	_check(is_equal_approx(restored.hermes.delay, 2.55), "Restored cooling derives once from original baseline")
	var old := _game()
	old.nathaniel.resource_capacity = 3
	old.nathaniel.resource_reach = 60.0
	var legacy: Dictionary = old.snapshot()
	for key: String in ["tech", "tech_pickups", "research_ranks", "tech_target_id"]:
		legacy.erase(key)
	_check(restored.restore(legacy), "Legacy save without new fields restores")
	_check(restored.tech == 0 and restored.research_ranks.capacity == 2 and restored.research_ranks.reach == 1, "Legacy actor values migrate to their purchased ranks")
	_check(restored.nathaniel.resource_capacity == 3 and restored.nathaniel.resource_reach == 60.0, "Migration does not apply old backpack effects twice")
	var campaign := _game(1)
	_check(campaign.upgrade_gathering("capacity") and campaign.upgrade_gathering("reach"), "Campaign retains existing matter purchases")
	_check(restored.restore(campaign.snapshot()) and restored.nathaniel.resource_capacity == 2 and restored.nathaniel.resource_reach == 60.0, "Campaign save retains its original backpack path")
	var life := _game()
	life.tech = 25
	life.lives = 1
	center = _center(life)
	life.begin_research(center.id)
	life.purchase_research("capacity", 0)
	life.end_research()
	life.damage_entity(life.nathaniel.id, life.nathaniel.hp)
	_check(life.tech == 15 and life.research_ranks.capacity == 1, "Spare-life respawn retains run research")
	life.configure(life.level)
	_check(life.tech == 0 and life.tech_pickups.is_empty() and life.research_ranks.capacity == 0 and life.research_center().is_empty(), "New Run and Retry configuration reset the entire research economy")
	var invalid: Dictionary = saved.duplicate(true)
	for unit: Dictionary in invalid.entities:
		if unit.kind == "researchCenter":
			unit.owned = false
	_check(not restored.restore(invalid), "Direct restore rejects unowned research center")
	invalid = saved.duplicate(true)
	invalid.hermes_mode = "following"
	_check(not restored.restore(invalid), "Direct restore rejects center with an undeployed owner")
	invalid = saved.duplicate(true)
	for unit: Dictionary in invalid.entities:
		if unit.kind == "researchCenter":
			unit.weapon = "gun"
	_check(not restored.restore(invalid), "Direct restore rejects combat behavior on a research center")
	invalid = saved.duplicate(true)
	for unit: Dictionary in invalid.entities:
		if unit.kind == "gunTower":
			unit.max_hp = 864
	_check(not restored.restore(invalid), "Direct restore rejects compounded health inconsistent with the learned rank")
	for field: String in ["damage", "speed"]:
		invalid = saved.duplicate(true)
		for unit: Dictionary in invalid.entities:
			if unit.kind == "researchCenter":
				unit[field] = "invalid"
		_check(not restored.restore(invalid) and not GameSaveStore.validate_state(invalid).is_empty(), "Both validators reject nonnumeric center " + field)
	var starter := _game()
	var tower: Dictionary = starter.place_map_tower("gunTower", Vector2(600, 450))
	tower.hp = 300
	var baseline: Dictionary = starter.snapshot()
	invalid = baseline.duplicate(true)
	for unit: Dictionary in invalid.entities:
		if unit.kind == "gunTower":
			unit.research_base_max_hp = 1200
	_check(not restored.restore(invalid) and not GameSaveStore.validate_state(invalid).is_empty(), "Both validators reject a mismatched tower baseline at rank zero")
	for unit: Dictionary in baseline.entities:
		unit.erase("research_base_max_hp")
	_check(GameSaveStore.validate_state(baseline).is_empty() and restored.restore(baseline), "Older rank-zero tower without a saved baseline remains valid")
	_check(restored.entity(tower.id).max_hp == 600 and restored.entity(tower.id).hp == 300, "Missing baseline migration retains the old tower's maximum health and damage")

func _test_farming() -> void:
	var sim := _game()
	var start: int = Time.get_ticks_usec()
	for count: int in 1000:
		_kill(sim, "grunt", Vector2(850, 850))
	_check(_total(sim) == 1000 and sim.tech_pickups.size() == 1, "A thousand farmed grunts conserve rewards in one local stack")
	print("Tech farming: 1000 deaths, %d stacks, %d tech, %.1f ms" % [sim.tech_pickups.size(), _total(sim), (Time.get_ticks_usec() - start) / 1000.0])
	sim.nathaniel.position = Vector2(825, 850)
	_advance(sim, 0.4)
	_check(sim.tech == 1000 and sim.tech_pickups.is_empty(), "Collection cost does not grow with the value in a stack")
