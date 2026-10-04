extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	var sim := GameSimulation.new()
	sim.configure({"number": 0, "width": 64, "height": 64, "tile_size": 32,
		"blocked": [], "player_start": Vector2(200, 200),
		"hermes_start": Vector2(260, 200), "enemies": [], "wave_based": false})
	var target: Dictionary = sim.spawn_enemy("grunt", Vector2(400, 200))
	target.hp = 30
	sim.take_events()
	sim.damage_entity(int(target.id), 0, int(sim.hermes.id))
	sim.damage_entity(int(target.id), -3, int(sim.hermes.id))
	sim.damage_entity(-1, 10, int(sim.hermes.id))
	check(sim.take_events().is_empty(), "Rejected damage produces no hit effect")
	sim.damage_entity(int(target.id), 7, int(sim.hermes.id))
	var events: Array = sim.take_events()
	check(events.size() == 1 and events[0].type == "hit", "A valid hit emits one impact")
	if events.size() == 1:
		var hit: Dictionary = events[0]
		check(hit.amount == 7 and target.hp == 23, "Impact amount is applied damage")
		check(hit.target_id == target.id and hit.attacker_id == sim.hermes.id, "Impact identifies both actors")
		check(hit.position == Vector2(400, 200) and hit.target_kind == "grunt" and hit.target_enemy, "Impact retains logical contact and target art after removal")
	check(sim.take_events().is_empty(), "Impact events are consumed once")
	sim.damage_entity(int(target.id), 100, int(sim.nathaniel.id))
	events = sim.take_events()
	check(events.size() == 2 and events[0].type == "hit" and events[1].type == "death", "Lethal contact precedes death")
	if not events.is_empty():
		check(events[0].amount == 23, "Lethal impact is capped to remaining health")
	check(not target.active and target.hp == 0, "Damage still uses normal death handling")
	sim.damage_entity(int(target.id), 100, int(sim.nathaniel.id))
	check(sim.take_events().is_empty(), "A dead target cannot produce another impact")
	print("Combat impact checks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
