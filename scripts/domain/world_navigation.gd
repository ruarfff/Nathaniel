class_name WorldNavigation
extends RefCounted
## Logical y-up terrain cells. AStarGrid2D owns the route search; this class
## owns circular tower clearance, exact endpoints and invalidation.

var width: int = 1
var height: int = 1
var tile_size: float = 32.0
var blocked: Dictionary = {}
var towers: Array[Vector2] = []
var revision: int = 0
var _grids: Dictionary = {}

func configure(config: Dictionary) -> void:
	width = maxi(1, int(config.get("width", 30)))
	height = maxi(1, int(config.get("height", 30)))
	tile_size = maxf(1.0, float(config.get("tile_size", 32.0)))
	blocked.clear()
	for item: Variant in config.get("blocked", []):
		var point: Vector2i
		if item is Vector2i or item is Vector2:
			point = Vector2i(item)
		elif item is Dictionary:
			point = Vector2i(int(item.x), int(item.y))
		else:
			point = Vector2i(int(item[0]), int(item[1]))
		blocked[point] = true
	towers.clear()
	invalidate()

func invalidate() -> void:
	revision += 1
	_grids.clear()

func update_towers(entities: Array[Dictionary]) -> void:
	towers.clear()
	for item: Dictionary in entities:
		if item.get("tower", false) and int(item.hp) > 0:
			towers.append(item.position)
	invalidate()

func cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / tile_size), floori(point.y / tile_size))

func center(point: Vector2i) -> Vector2:
	return (Vector2(point) + Vector2(0.5, 0.5)) * tile_size

func terrain_clear(point: Vector2) -> bool:
	var at: Vector2i = cell(point)
	return at.x >= 0 and at.y >= 0 and at.x < width and at.y < height and not blocked.has(at)

func walkable(point: Vector2, radius: float = 0.0) -> bool:
	if not terrain_clear(point):
		return false
	for tower: Vector2 in towers:
		if point.distance_to(tower) < 24.0 + radius:
			return false
	return true

func footprint_clear(point: Vector2) -> bool:
	var low: Vector2 = point - Vector2(24, 24)
	var high: Vector2 = point + Vector2(24, 24)
	if low.x < 0 or low.y < 0 or high.x > width * tile_size or high.y > height * tile_size:
		return false
	for y: int in range(floori(low.y / tile_size), ceili(high.y / tile_size)):
		for x: int in range(floori(low.x / tile_size), ceili(high.x / tile_size)):
			if blocked.has(Vector2i(x, y)):
				return false
	return true

func segment_clear(start: Vector2, goal: Vector2, radius: float) -> bool:
	var count: int = maxi(1, ceili(start.distance_to(goal) / minf(8.0, tile_size / 4.0)))
	var previous: Vector2i = cell(start)
	for index: int in range(1, count + 1):
		var point: Vector2 = start.lerp(goal, float(index) / count)
		if not walkable(point, radius):
			return false
		var current: Vector2i = cell(point)
		if current.x != previous.x and current.y != previous.y:
			if not terrain_clear(center(Vector2i(current.x, previous.y))) or not terrain_clear(center(Vector2i(previous.x, current.y))):
				return false
		previous = current
	return true

func route(start: Vector2, goal: Vector2, radius: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not walkable(goal, radius) or not terrain_clear(start):
		return result
	if segment_clear(start, goal, radius):
		result.append(goal)
		return result
	var grid: AStarGrid2D = _grid(radius)
	var from: Vector2i = cell(start)
	var to: Vector2i = cell(goal)
	# Exact endpoints can be clear while a conservative center is blocked.
	var from_solid: bool = grid.is_point_solid(from)
	var to_solid: bool = grid.is_point_solid(to)
	grid.set_point_solid(from, false)
	grid.set_point_solid(to, false)
	var ids: Array[Vector2i] = grid.get_id_path(from, to)
	grid.set_point_solid(from, from_solid)
	grid.set_point_solid(to, to_solid)
	if ids.is_empty():
		return result
	var current: Vector2 = start
	for index: int in range(1, ids.size()):
		var waypoint: Vector2 = goal if index == ids.size() - 1 else center(ids[index])
		if not segment_clear(current, waypoint, radius):
			return []
		result.append(waypoint)
		current = waypoint
	if result.is_empty():
		result.append(goal)
	return result

func route_to_range(start: Vector2, goal: Vector2, radius: float, attack_range: float) -> Array[Vector2]:
	# A tower's center is a dynamic obstacle. Enemies need a reachable attack
	# position, while their retained command still refers to the tower itself.
	var direction: Vector2 = (start - goal).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	for index: int in 16:
		var offset: int = (index + 1) / 2 * (1 if index % 2 else -1)
		var candidate: Vector2 = goal + direction.rotated(offset * TAU / 16.0) * attack_range * 0.9
		if not walkable(candidate, radius):
			continue
		var path: Array[Vector2] = route(start, candidate, radius)
		if not path.is_empty():
			return path
	return []

func _grid(radius: float) -> AStarGrid2D:
	if _grids.has(radius):
		return _grids[radius]
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, width, height)
	grid.cell_size = Vector2.ONE * tile_size
	grid.offset = Vector2.ONE * tile_size * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for y: int in height:
		for x: int in width:
			var point := Vector2i(x, y)
			# Slightly expand the circle so diagonal segments retain clearance.
			grid.set_point_solid(point, not walkable(center(point), radius + tile_size * 0.2))
	_grids[radius] = grid
	return grid
