class_name GameInput
extends Node
## Screen gestures issue logical commands through the same controller as UI.

var app: Node2D
var touches: Dictionary = {}
var drag_kind := ""
var drag_start := Vector2.ZERO
var pinching := false


func _input(event: InputEvent) -> void:
	if app == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if app.sim != null and app.sim.result in ["victory", "gameOver"]:
			var level: int = app.sim.level_number
			if app.sim.result == "victory":
				level = app.level.definition.next_level
				if level < 0:
					app.command("main")
					return
			app.command("level", level)
			return
		match event.keycode:
			KEY_ESCAPE:
				app.command("escape", null)
			KEY_SPACE:
				app.command("switch_focus", null)
			KEY_R:
				app.command("toggle_hermes", null)
			KEY_S:
				app.command("stop", null)
			KEY_F:
				app.command("fire_at_pointer", null)
	if event is InputEventScreenTouch:
		if event.canceled:
			drag_kind = ""
			app.ui.build_kind = ""
			touches.erase(event.index)
			pinching = not touches.is_empty()
			return
		if event.pressed:
			touches[event.index] = event.position
			if touches.size() >= 2:
				pinching = true
				drag_kind = ""
				app.ui.build_kind = ""
		else:
			touches.erase(event.index)
			if touches.is_empty():
				pinching = false
	if event is InputEventScreenDrag and touches.has(event.index):
		if touches.size() == 2:
			var points := touches.values()
			var before: float = points[0].distance_to(points[1])
			touches[event.index] = event.position
			points = touches.values()
			var after: float = points[0].distance_to(points[1])
			if before > 1.0:
				app.change_zoom(after / before)
			pinching = true
		else:
			touches[event.index] = event.position
	if event is InputEventMagnifyGesture:
		app.change_zoom(event.factor)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and not drag_kind.is_empty():
		var kind := drag_kind
		drag_kind = ""
		if event.position.distance_to(drag_start) > 12 and not app.ui.get_node("Bottom").get_global_rect().has_point(event.position):
			app.place_at(kind, event.position)
			app.ui.build_kind = ""
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if app == null or app.sim == null or not app.ui.menu.is_empty() or pinching:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				app.world_click(event.position)
			MOUSE_BUTTON_RIGHT:
				app.command("fire_at_pointer", null)
			MOUSE_BUTTON_WHEEL_UP:
				app.change_zoom(1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				app.change_zoom(1.0 / 1.1)


func begin_tower_drag(kind: String) -> void:
	drag_kind = kind
	drag_start = get_viewport().get_mouse_position()
