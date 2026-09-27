class_name GameInput
extends Node
## Screen gestures issue logical commands through the same controller as UI.

var app: Node2D
var pointer_position := Vector2.ZERO
var touches: Dictionary = {}
var drag_kind := ""
var drag_start := Vector2.ZERO
var pinching := false
var _world_tap_pending := false
var _world_tap_start := Vector2.ZERO


func _input(event: InputEvent) -> void:
	if app == null:
		return
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag:
		pointer_position = event.position
	if event is InputEventKey:
		if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
			return
		if event.pressed and not event.echo and app.sim != null and app.sim.result in ["victory", "gameOver"]:
			get_viewport().set_input_as_handled()
			var level: int = app.sim.level_number
			if app.sim.result == "victory":
				level = app.level.definition.next_level
				if level < 0:
					app.command("main")
					return
			app.command("level", level)
			return
		var shortcuts := {KEY_ESCAPE: "escape", KEY_SPACE: "focus", KEY_B: "build", KEY_R: "toggle_hermes", KEY_S: "stop", KEY_F: "fire_at_pointer"}
		if shortcuts.has(event.keycode) and (event.keycode == KEY_ESCAPE or (app.sim != null and app.ui.menu.is_empty())):
			get_viewport().set_input_as_handled()
			if event.pressed and not event.echo:
				app.command(shortcuts[event.keycode], null)
	if event is InputEventScreenTouch:
		if event.canceled:
			cancel_tower_drag()
			touches.erase(event.index)
			pinching = not touches.is_empty()
			return
		if event.pressed:
			touches[event.index] = event.position
			if touches.size() >= 2:
				pinching = true
				cancel_tower_drag()
		else:
			touches.erase(event.index)
			if touches.is_empty():
				pinching = false
	if event is InputEventScreenDrag and touches.has(event.index):
		if _world_tap_pending and event.position.distance_to(_world_tap_start) > 12.0:
			_world_tap_pending = false
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
		_world_tap_pending = false
		app.change_zoom(event.factor)
	if event is InputEventMouseMotion and _world_tap_pending and event.position.distance_to(_world_tap_start) > 12.0:
		_world_tap_pending = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and pinching:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if not drag_kind.is_empty():
			# The button still needs its release to clear native GUI mouse capture.
			# Tower selection happens on button-down, so release cannot re-arm it.
			var kind := drag_kind
			drag_kind = ""
			if event.position.distance_to(drag_start) > 12.0:
				if app.ui.blocks_world_input(event.position):
					cancel_tower_drag()
				elif app.place_at(kind, event.position):
					app.ui.build_kind = ""
		elif _world_tap_pending:
			_world_tap_pending = false
			if not pinching and not app.ui.blocks_world_input(event.position) and event.position.distance_to(_world_tap_start) <= 12.0:
				app.world_click(event.position)
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if app == null or app.sim == null or not app.ui.menu.is_empty() or pinching:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_world_tap_start = event.position
				_world_tap_pending = true
			MOUSE_BUTTON_RIGHT:
				app.command("fire_at_pointer", null)
			MOUSE_BUTTON_WHEEL_UP:
				app.change_zoom(1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				app.change_zoom(1.0 / 1.1)


func begin_tower_drag(kind: String) -> void:
	if app == null or app.sim == null or not app.ui.menu.is_empty() or pinching or not app.ui.build_open or app.sim.paused:
		return
	_world_tap_pending = false
	drag_kind = kind
	drag_start = pointer_position
	app.ui.build_kind = kind


func cancel_tower_drag() -> void:
	drag_kind = ""
	_world_tap_pending = false
	if app != null:
		app.ui.build_kind = ""
