class_name IsoProjection
extends RefCounted
## Logical coordinates retain the Swift save/map coordinate system.


static func project(world: Vector2) -> Vector2:
	return Vector2(world.x - world.y, (world.x + world.y) * 0.5)


static func unproject(screen: Vector2) -> Vector2:
	return Vector2(screen.y + screen.x * 0.5, screen.y - screen.x * 0.5)


static func projected_bounds(world_size: Vector2) -> Rect2:
	return Rect2(-world_size.y, 0, world_size.x + world_size.y, (world_size.x + world_size.y) * 0.5)


static func clamp_camera(target: Vector2, world_size: Vector2, viewport: Vector2, zoom: float) -> Vector2:
	var bounds := projected_bounds(world_size)
	var half := viewport / (zoom * 2.0)
	var result := target
	for axis in range(2):
		if bounds.size[axis] <= half[axis] * 2.0:
			result[axis] = bounds.get_center()[axis]
		else:
			result[axis] = clampf(target[axis], bounds.position[axis] + half[axis], bounds.end[axis] - half[axis])
	return result
