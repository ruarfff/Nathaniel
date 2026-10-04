class_name WeaponPickupView
extends Node2D
## Resolution-independent crate art. The origin is its ground contact; no collision.


func _draw() -> void:
	var ink := Color("192528")
	var brass := Color("d3ab64")
	draw_colored_polygon(PackedVector2Array([Vector2(-20, -2), Vector2(0, -12), Vector2(20, -2), Vector2(0, 8)]), Color(0, 0, 0, 0.22))
	var lid := PackedVector2Array([Vector2(-18, -15), Vector2(0, -24), Vector2(18, -15), Vector2(0, -6)])
	var left := PackedVector2Array([Vector2(-18, -15), Vector2(0, -6), Vector2(0, 5), Vector2(-18, -4)])
	var right := PackedVector2Array([Vector2(0, -6), Vector2(18, -15), Vector2(18, -4), Vector2(0, 5)])
	for face: PackedVector2Array in [left, right, lid]:
		draw_colored_polygon(face, Color("59665a") if face == lid else (Color("35433e") if face == left else Color("293a36")))
		var outline := face.duplicate()
		outline.append(face[0])
		draw_polyline(outline, ink, 1.5, true)
	draw_line(Vector2(-12, -9), Vector2(-5, -5), brass, 2.0, true)
	draw_line(Vector2(5, -5), Vector2(12, -9), brass, 2.0, true)
	# Rifle emblem on the lid, with a distinct stock and long barrel.
	draw_line(Vector2(-10, -16), Vector2(11, -16), brass, 2.5, true)
	draw_line(Vector2(-10, -16), Vector2(-10, -12), brass, 3.0, true)
	draw_line(Vector2(-1, -16), Vector2(-3, -12), brass, 2.0, true)
	draw_line(Vector2(3, -18), Vector2(7, -18), brass, 1.5, true)
