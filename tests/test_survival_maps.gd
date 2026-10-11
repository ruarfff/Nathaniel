extends SceneTree
## Authored survival terrain, deployment space, and large-unit route checks.

const MAPS: Array[String] = ["abandoned_crossroads", "dry_wash", "freight_yard", "open_countryside"]
const BLOCKED_COUNTS: Array[int] = [252, 270, 290, 101]
const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const SILHOUETTE_CLEARANCE: float = 40.0

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	for index: int in MAPS.size():
		_check_map(MAPS[index], BLOCKED_COUNTS[index])
	_check_new_assets()
	print("Survival map checks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_map(map_id: String, blocked_count: int) -> void:
	var packed: PackedScene = load("res://levels/survival/%s.tscn" % map_id) as PackedScene
	expect(packed != null, map_id + " native scene loads")
	if packed == null:
		return
	var level: GameLevel = packed.instantiate() as GameLevel
	var data: Dictionary = level.data()
	expect(data.get("survival_map_id") == map_id and data.number == 0, map_id + " preserves survival and authored map identity")
	expect(data.width == 52 and data.height == 52 and data.tile_size == 32, map_id + " has the full 1664 by 1664 world")
	expect(data.starting_lives == 0 and data.starting_resources == 30 and data.wave_based and not data.has_boss, map_id + " preserves survival balance")
	expect(data.enemies.is_empty() and data.towers.is_empty(), map_id + " leaves encounters to the survival wave rules")
	expect(data.blocked.size() == blocked_count, map_id + " explicit movement footprint remains authored")
	var ground: TileMapLayer = level.get_node("Ground") as TileMapLayer
	expect(ground.get_used_cells().size() == 2704, map_id + " ground covers every cell")
	var bounds_valid: bool = true
	var references_valid: bool = true
	var projection_valid: bool = true
	for layer_name: String in ["Ground", "NonCollision", "Collision"]:
		var layer: TileMapLayer = level.get_node(layer_name) as TileMapLayer
		expect(layer.scale == Vector2.ONE / 8.0 and layer.position == Vector2(-32, 0), map_id + " retains shared terrain scale")
		expect(not layer.collision_enabled and not layer.navigation_enabled, map_id + " keeps gameplay collision in the domain")
		for cell: Vector2i in layer.get_used_cells():
			bounds_valid = bounds_valid and Rect2i(0, 0, 52, 52).has_point(cell)
			references_valid = references_valid and layer.get_cell_tile_data(cell) != null
			projection_valid = projection_valid and (layer.transform * layer.map_to_local(cell)).is_equal_approx(IsoProjection.project((Vector2(cell) + Vector2.ONE * 0.5) * 32.0))
	expect(bounds_valid and references_valid and projection_valid, map_id + " painted cells remain in bounds and align with the world")
	var world_bounds: Rect2 = IsoProjection.projected_bounds(Vector2(1664, 1664))
	expect(world_bounds == Rect2(-1664, 0, 3328, 1664), map_id + " supplies correct projected camera bounds")
	var navigation := WorldNavigation.new()
	navigation.configure(data)
	expect(navigation.footprint_clear(data.player_start) and navigation.footprint_clear(data.hermes_start), map_id + " hero starts clear terrain")
	expect(data.player_start.distance_to(Vector2(832, 832)) < 128 and data.hermes_start.distance_to(data.player_start) < 128, map_id + " starts both heroes together near the central clearing")
	expect(data.weapon_pickups.size() == 1 and data.weapon_pickups[0].weapon_id == "heavy_rifle", map_id + " retains the heavy rifle opportunity")
	if not data.weapon_pickups.is_empty():
		var pickup: Vector2 = data.weapon_pickups[0].position
		expect(pickup.distance_to(data.player_start) <= 128 and not navigation.route(data.player_start, pickup, 19.2).is_empty(), map_id + " rifle is a short reachable walk")
	_check_routes(level, data, navigation, map_id)
	_check_scenery(level, data, map_id)
	level.free()


func _check_routes(level: GameLevel, data: Dictionary, navigation: WorldNavigation, map_id: String) -> void:
	# Inflate terrain by the visible boss half-width, above its 32-point body radius.
	# Cardinal steps then prove complete silhouette clearance along the whole route.
	var safe: Dictionary = {}
	for y: int in range(2, 50):
		for x: int in range(2, 50):
			var cell := Vector2i(x, y)
			var point: Vector2 = navigation.center(cell)
			var clear: bool = true
			for blocked: Vector2i in data.blocked:
				if Rect2(Vector2(blocked) * 32.0, Vector2.ONE * 32.0).grow(SILHOUETTE_CLEARANCE).has_point(point):
					clear = false
					break
			if clear:
				safe[cell] = true
	var reached: Dictionary = _reachable(safe, navigation.cell(data.player_start))
	var sectors: Array = data.get("entry_sectors", [])
	var simulation := GameSimulation.new()
	simulation.configure(data)
	expect(sectors.size() >= 4, map_id + " has four authored enemy entry sectors")
	var candidate_count: int = 0
	for sector: Dictionary in sectors:
		candidate_count += sector.positions.size()
		expect(sector.get("enabled", true) and sector.positions.size() >= 3, map_id + " sector has several enabled candidates")
		var legal_candidates: int = 0
		for point: Vector2 in sector.positions:
			if reached.has(navigation.cell(point)) and point.distance_to(data.player_start) >= 192 and point.distance_to(data.hermes_start) >= 192:
				legal_candidates += 1
		expect(legal_candidates >= 2, "%s %s admits bosses with silhouette clearance" % [map_id, sector.id])
		for kind: String in GameBalance.ENEMIES:
			var spawnable: int = 0
			for point: Vector2 in sector.positions:
				if BattlefieldRules.spawn_position_error(simulation, kind, point).is_empty():
					spawnable += 1
			expect(spawnable >= 2, "%s %s supplies multiple valid %s footprints" % [map_id, sector.id, kind])
		var occupied_sim := GameSimulation.new()
		occupied_sim.configure(data)
		occupied_sim.spawn_enemy("spawner", sector.positions[0])
		var remaining_large: int = 0
		var remaining_small: int = 0
		for point: Vector2 in sector.positions:
			if BattlefieldRules.spawn_position_error(occupied_sim, "spawner", point).is_empty():
				remaining_large += 1
			if BattlefieldRules.spawn_position_error(occupied_sim, "grunt", point).is_empty():
				remaining_small += 1
		expect(remaining_large >= 1 and remaining_small >= 2, "%s %s stays usable when a stationary spawner occupies its first site" % [map_id, sector.id])
	expect(candidate_count <= GameBalance.SURVIVAL_ENTRY_SEARCH_LIMIT, map_id + " candidate pool fits the bounded domain search")
	var clearings: Node = level.get_node("Clearings")
	expect(clearings.get_child_count() == 3, map_id + " authors three ordinary deployment clearings")
	for marker: Marker2D in clearings.get_children():
		var center: Vector2 = IsoProjection.unproject(marker.position)
		expect(navigation.footprint_clear(center) and reached.has(navigation.cell(center)), "%s clearing %s is reachable with the largest unit" % [map_id, marker.name])
		var exits: int = 0
		for direction: Vector2i in DIRECTIONS:
			var open: bool = true
			for step: int in range(1, 5):
				open = open and reached.has(navigation.cell(center) + direction * step)
			if open:
				exits += 1
		expect(exits >= 2, "%s clearing %s has at least two broad independent approaches" % [map_id, marker.name])
	# Every ordinary walkable cell connects to the fight, including spaces between props.
	var terrain: Dictionary = {}
	for y: int in 52:
		for x: int in 52:
			var cell := Vector2i(x, y)
			if not data.blocked.has(cell):
				terrain[cell] = true
	expect(_reachable(terrain, navigation.cell(data.player_start)).size() == terrain.size(), map_id + " has no enclosed walkable pockets")


func _reachable(cells: Dictionary, start: Vector2i) -> Dictionary:
	if not cells.has(start):
		return {}
	var result: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var index: int = 0
	while index < queue.size():
		var cell: Vector2i = queue[index]
		index += 1
		for direction: Vector2i in DIRECTIONS:
			var next: Vector2i = cell + direction
			if cells.has(next) and not result.has(next):
				result[next] = true
				queue.append(next)
	return result


func _check_scenery(level: GameLevel, data: Dictionary, map_id: String) -> void:
	var scenery: Node2D = level.get_node("Scenery") as Node2D
	expect(scenery.y_sort_enabled and scenery.scale == Vector2.ONE and scenery.get_child_count() >= 20, map_id + " has a complete upright scenery pass")
	var visible_art: bool = true
	var countryside_only: bool = true
	var canopy_gap: bool = false
	for prop: Sprite2D in scenery.get_children():
		visible_art = visible_art and prop.texture != null and prop.texture.resource_path.begins_with("res://assets/generated/environment_") and prop.get_child_count() == 0
		var path: String = prop.scene_file_path
		countryside_only = countryside_only and (path.ends_with("environment_tree.tscn") or path.ends_with("environment_dead_tree.tscn") or path.ends_with("environment_rocks.tscn"))
		if path.ends_with("environment_tree.tscn"):
			var cell := Vector2i(IsoProjection.unproject(prop.position) / 32.0)
			for direction: Vector2i in DIRECTIONS:
				canopy_gap = canopy_gap or (data.blocked.has(cell) and not data.blocked.has(cell + direction))
	expect(visible_art, map_id + " uses exported Iron and Ink scenery without art-derived collision")
	if map_id == "open_countryside":
		expect(countryside_only and canopy_gap, "Countryside contains only natural scenery; crowns do not fill adjacent collision cells")


func _check_new_assets() -> void:
	for kind: String in ["container", "rail", "rock_shelf"]:
		var stem: String = "environment_" + kind
		var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/%s.json" % stem))
		var source: String = "res://" + str(metadata.get("source", ""))
		expect(FileAccess.file_exists(source) and FileAccess.get_sha256(source) == metadata.get("source_sha256"), kind + " export matches its editable saved Blender source")
		var prop: Sprite2D = load("res://scenes/scenery/generated/%s.tscn" % stem).instantiate() as Sprite2D
		var anchor := Vector2(metadata.anchor[0], metadata.anchor[1])
		expect(prop.scale == Vector2.ONE / 8.0 and not prop.centered and prop.offset == -anchor, kind + " keeps the shared export scale and cropped ground anchor")
		expect(prop.texture.get_image().get_used_rect().has_area() and prop.get_child_count() == 0, kind + " contains visible artwork with no automatic collision")
		prop.free()
