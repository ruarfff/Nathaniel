class_name FogView
extends Node2D
## Draws logical visibility cells after projection, independently of game rules.

var simulation: GameSimulation
var enabled := true
var _timer := 0.0


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 0.1:
		_timer = 0
		queue_redraw()


func _draw() -> void:
	if simulation == null or not enabled:
		return
	var size: float = simulation.config.get("tile_size", 32)
	var viewport_rect := get_viewport_rect()
	var inverse := get_canvas_transform().affine_inverse()
	var corners: Array[Vector2] = []
	for point: Vector2 in [viewport_rect.position, Vector2(viewport_rect.end.x, 0), viewport_rect.end, Vector2(0, viewport_rect.end.y)]:
		corners.append(IsoProjection.unproject(inverse * point))
	var minimum := corners[0]
	var maximum := minimum
	for point: Vector2 in corners:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	for x in range(maxi(0, floori(minimum.x / size)), mini(simulation.config.get("width", 1), ceili(maximum.x / size) + 1)):
		for y in range(maxi(0, floori(minimum.y / size)), mini(simulation.config.get("height", 1), ceili(maximum.y / size) + 1)):
			var world := Vector2((x + 0.5) * size, (y + 0.5) * size)
			var visibility: int = simulation.visibility_at(world)
			if visibility == 2:
				continue
			var center := IsoProjection.project(world)
			var points := PackedVector2Array([center + Vector2(-size, 0), center + Vector2(0, -size * 0.5), center + Vector2(size, 0), center + Vector2(0, size * 0.5)])
			draw_colored_polygon(points, Color(0.015, 0.025, 0.03, 0.95 if visibility == 0 else 0.6))
