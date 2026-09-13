class_name GameDebugBridge
extends RefCounted
## The same small MCP contract, implemented against Godot state and controls.

var app: GameApp


func _init(controller: GameApp) -> void:
	app = controller


func start(port: int) -> Node:
	var server := GameDebugServer.new()
	app.add_child(server)
	server.configure({"state": state, "nodes": nodes, "action": action, "tap": tap, "swipe": swipe, "screenshot": screenshot})
	var result := server.start_server(port)
	if not result.success:
		push_error(result.error)
	return server


func state() -> Dictionary:
	var size := app.get_viewport_rect().size
	var result: Dictionary = {"scene": "MainMenuScene", "engine": "Godot", "sceneSize": {"width": size.x, "height": size.y}, "menu": app.ui.menu}
	if app.sim == null or app.ui.menu in ["main", "levels", "credits"]:
		return result
	var sim := app.sim
	result.merge({"scene": "GameScene", "level": sim.level_number, "levelNumber": sim.level_number, "score": sim.score, "lives": sim.lives, "resources": sim.resources, "elapsedTime": sim.elapsed_time, "isPaused": sim.paused, "gameState": sim.result, "isGameOver": sim.result == "gameOver", "isVictory": sim.result == "victory", "hermesMode": sim.hermes_mode, "selectedCharacter": sim.focused_character, "enemyCount": 0, "towerCount": 0, "cameraZoom": app.camera_zoom, "corpses": sim.corpses.size(), "entities": []}, true)
	result.merge({"gameStatus": "paused" if sim.paused else sim.result,
		"playerPosition": {"x": sim.nathaniel.position.x, "y": sim.nathaniel.position.y},
		"hermesPosition": {"x": sim.hermes.position.x, "y": sim.hermes.position.y},
		"playerHealth": sim.nathaniel.hp, "hermesHealth": sim.hermes.hp,
		"hermesMode": "following" if sim.hermes_mode == "following" else "independent"}, true)
	for entity: Dictionary in sim.entities:
		if entity.hp <= 0:
			continue
		var point: Vector2 = entity.position
		var screen := app.world_to_screen(point)
		var item := {"id": entity.id, "type": entity.kind, "x": point.x, "y": point.y, "hp": entity.hp, "maxHP": entity.max_hp, "screenX": screen.x, "screenY": screen.y}
		result.entities.append(item)
		if entity.kind in ["nathaniel", "hermes"]:
			result[entity.kind] = item
		if entity.enemy:
			result.enemyCount += 1
		if entity.tower:
			result.towerCount += 1
	return result


func nodes() -> Array:
	var result: Array = []
	_collect_controls(app.ui, result)
	if app.sim != null and app.ui.menu.is_empty():
		for entity: Dictionary in app.sim.entities:
			if entity.hp <= 0:
				continue
			var view: ActorView = app.views.get(int(entity.id))
			if view == null or not view.is_visible_in_tree():
				continue
			var bounds: Rect2 = view.sprite.get_global_transform_with_canvas() * view.sprite.get_rect()
			var name: String = entity.kind if entity.kind in ["nathaniel", "hermes"] else ("tower_%d" if entity.tower else "enemy_%d") % int(entity.id)
			result.append({"name": name, "type": entity.kind, "frame": {"x": bounds.position.x, "y": bounds.position.y, "width": bounds.size.x, "height": bounds.size.y}, "interactive": true,
				"properties": {"health": "%d/%d" % [entity.hp, entity.max_hp], "coordinates": "viewport pixels, top-left origin"}})
	return result


func _collect_controls(node: Node, result: Array) -> void:
	if node is Button and node.is_visible_in_tree():
		if not app.ui.menu.is_empty() and not app.ui.get_node("Modal").is_ancestor_of(node):
			return
		var rect := _visible_rect(node)
		if not rect.has_area():
			return
		var properties: Dictionary = {}
		if node.toggle_mode:
			properties["checked"] = str(node.button_pressed)
		result.append({"name": node.text, "type": "CheckButton" if node.toggle_mode else "Button", "position": {"x": rect.get_center().x, "y": rect.get_center().y}, "frame": {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}, "interactive": not node.disabled, "properties": properties})
	for child in node.get_children():
		_collect_controls(child, result)


func action(name: String, params: Dictionary) -> Dictionary:
	match name:
		"loadLevel":
			var level := str(params.get("level", ""))
			if not level.is_valid_int() or not app.load_level(int(level)):
				return {"success": false, "error": "Expected level 0–5"}
		"mainMenu":
			app.show_main()
		_:
			if app.sim == null:
				return {"success": false, "error": "No active game"}
			var sim := app.sim
			if sim.result != "playing":
				return {"success": false, "error": "Load a level before changing gameplay state"}
			match name:
				"pause":
					app.command("pause")
				"resume":
					app.command("resume")
				"addResources":
					var amount := str(params.get("amount", "0"))
					if not amount.is_valid_int() or int(amount) <= 0 or int(amount) > 9223372036854775807 - sim.resources:
						return {"success": false, "error": "Expected positive resource amount"}
					sim.resources += int(amount)
				"healPlayer":
					for unit: Dictionary in [sim.nathaniel, sim.hermes]:
						if unit.hp > 0:
							unit.hp = unit.max_hp
				"spawnEnemy":
					var x := str(params.get("x", ""))
					var y := str(params.get("y", ""))
					if not x.is_valid_float() or not y.is_valid_float() or not is_finite(float(x)) or not is_finite(float(y)):
						return {"success": false, "error": "Expected finite x,y"}
					if params.get("type", "") not in ["grunt", "soldier", "boss", "spawner"] or sim.spawn_enemy(params.type, Vector2(float(x), float(y))).is_empty():
						return {"success": false, "error": "Unknown enemy type"}
				"killAllEnemies":
					for entity: Dictionary in sim.entities.duplicate():
						if entity.enemy:
							sim.damage_entity(entity.id, entity.hp)
				"setHermesMode":
					var mode: String = params.get("mode", "")
					if mode not in ["following", "independent"] or sim.paused or sim.hermes.hp <= 0:
						return {"success": false, "error": "Expected following or independent while Hermes is alive and playing"}
					sim.set_hermes_mode(mode)
				_:
					return {"success": false, "error": "Unknown action"}
	return {"success": true}


func tap(point: Vector2) -> bool:
	return _tap_control(app.ui, point) or _tap_world(point)


func _tap_control(node: Node, point: Vector2) -> bool:
	if node is Button and node.is_visible_in_tree() and not node.disabled:
		if not app.ui.menu.is_empty() and not app.ui.get_node("Modal").is_ancestor_of(node):
			return false
		if _visible_rect(node).has_point(point):
			if node.toggle_mode:
				node.set_pressed_no_signal(not node.button_pressed)
				node.toggled.emit(node.button_pressed)
			node.pressed.emit()
			return true
	for child in node.get_children():
		if _tap_control(child, point):
			return true
	return false


func _visible_rect(control: Control) -> Rect2:
	var bounds := control.get_global_rect().intersection(control.get_viewport_rect())
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents:
			bounds = bounds.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	return bounds


func _tap_world(point: Vector2) -> bool:
	if app.sim == null or not app.ui.menu.is_empty():
		return false
	app.world_click(point)
	return true


func swipe(from: Vector2, to: Vector2, _duration: float) -> bool:
	for kind: String in ["gun_tower", "laser_tower", "heal_tower"]:
		if app.ui.buttons[kind].get_global_rect().has_point(from):
			return app.place_at(kind, to)
	return tap(to)


func screenshot() -> PackedByteArray:
	if DisplayServer.get_name() == "headless":
		return PackedByteArray()
	return app.get_viewport().get_texture().get_image().save_png_to_buffer()
