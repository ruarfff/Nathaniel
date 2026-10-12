extends SceneTree
## Checks the live research rigs and writes an isolated art review capture.


func _initialize() -> void:
	_run.call_deferred()


func _label(parent: Node, text: String, at: Vector2, font_size: int = 18) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e2e9e6"))
	parent.add_child(label)


func _panel(parent: Node, rect: Rect2, color: Color) -> void:
	var panel := ColorRect.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.color = color
	parent.add_child(panel)


func _actor(parent: Node, scene: String, point: Vector2, scale_value: float = 2.0) -> ActorView:
	var actor: ActorView = load("res://scenes/actors/" + scene + ".tscn").instantiate() as ActorView
	parent.add_child(actor)
	actor.apply_state({"id": 1, "position": IsoProjection.unproject(point), "hp": 100, "max_hp": 100, "facing": Vector2(-1, -1)}, false, false)
	actor.scale = Vector2.ONE * scale_value
	return actor


func _run() -> void:
	var surface := SubViewport.new()
	surface.size = Vector2i(1280, 800)
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	_panel(surface, Rect2(0, 0, 1280, 800), Color("14272f"))
	_label(surface, "TECH / RESEARCH — live game assets", Vector2(32, 20), 26)
	_label(surface, "Top: normal 1× world scale on sand / grass / rubble tones. Lower: 2× rig inspection.", Vector2(32, 58), 17)
	for index: int in 3:
		var x: float = 32 + index * 412
		_panel(surface, Rect2(x, 96, 392, 160), [Color("a99770"), Color("5d6942"), Color("75756b")][index])
		var tech := TechPickupView.new()
		surface.add_child(tech)
		tech.apply_state({"id": index, "amount": 1, "kind": "module", "position": IsoProjection.unproject(Vector2(x + 70, 184))})
		var core := TechPickupView.new()
		surface.add_child(core)
		core.apply_state({"id": index + 10, "amount": 8000, "kind": "core", "position": IsoProjection.unproject(Vector2(x + 155, 184))})
		var center: ResearchCenterView = _actor(surface, "research_center", Vector2(x + 290, 202), 1.0) as ResearchCenterView
		center._deployment = 1.0
		center._pose()
		assert(center.model_view.aim_pivot == null, "Research center must not have a weapon rig")
	_label(surface, "Ready beside gun / laser / healing towers", Vector2(32, 286))
	var center: ResearchCenterView = _actor(surface, "research_center", Vector2(160, 485)) as ResearchCenterView
	center._deployment = 1.0
	center._pose()
	_actor(surface, "gun_tower", Vector2(340, 485))
	_actor(surface, "laser_tower", Vector2(505, 485))
	_actor(surface, "heal_tower", Vector2(665, 485))
	center.notify_research()
	var scan: Node3D = center._parts.ResearchScan
	var frozen: Transform3D = scan.transform
	center._process(0.3)
	assert(scan.transform == frozen, "Research scan moved during pause")
	center._playback_enabled = true
	center._process(0.1)
	assert(scan.transform != frozen, "Research scan did not resume")
	center._playback_enabled = false
	_label(surface, "Folded", Vector2(845, 286))
	var folded: ResearchCenterView = _actor(surface, "research_center", Vector2(920, 485)) as ResearchCenterView
	folded._deployment = 0.0
	folded._pose()
	_label(surface, "Collector + full matter rack / clamp / cassette", Vector2(32, 550))
	for index: int in 3:
		var actor: ActorView = _actor(surface, "nathaniel", Vector2(165 + index * 350, 758), 2.3)
		var nathaniel: Dictionary = {"id": 1, "position": Vector2.ZERO, "hp": 100, "resource_capacity": 3}
		actor.sync_gathering([{"phase": "carry", "cargo_slot": 0}, {"phase": "carry", "cargo_slot": 1}, {"phase": "carry", "cargo_slot": 2}], nathaniel, {}, null)
		var collector := TechCollectionView.new()
		var pickups: Array = []
		if index > 0:
			pickups.append({"id": 100, "position": Vector2(12, 12), "phase": "collect", "phase_elapsed": GameBalance.TECH_COLLECTION_SECONDS * (0.45 if index == 1 else 0.88), "owner_id": 1})
		collector.sync(actor.model_view, pickups, nathaniel, false)
		assert(collector._parts.size() == 6, "Collector lost authored controls")
		assert(collector._parts.TechHeld.visible == (index > 0), "Collector ownership cue is incorrect")
	for frame: int in 4:
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://test-artifacts")
		surface.get_texture().get_image().save_png("res://test-artifacts/research-assets.png")
	surface.queue_free()
	await process_frame
	await _check_hit_inputs()
	print("Research visuals: noncombat rig, pause/resume, bounded stacks and collector with full cargo passed")
	quit()


func _check_hit_inputs() -> void:
	var app: GameApp = load("res://scenes/main.tscn").instantiate() as GameApp
	app.storage_root = "/private/tmp/nathaniel-research-art-input-%d/" % Time.get_ticks_usec()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app.load_level(0)
	app.fog.enabled = false
	app.sim.hermes.position = Vector2(480, 480)
	app.sim.nathaniel.position = Vector2(420, 400)
	var center: Dictionary = app.sim.place_map_tower("researchCenter", Vector2(590, 430))
	app._sync_views()
	app.camera.position = IsoProjection.project(center.position)
	app.camera.force_update_scroll()
	await process_frame
	var view: ResearchCenterView = app.views[int(center.id)]
	for point: Vector2 in [Vector2(-40, -1), Vector2(40, -1), Vector2(0, 18), Vector2(10, -58)]:
		var screen: Vector2 = view.get_global_transform_with_canvas() * point
		assert(app.world_entity_at(screen).get("id", -1) == center.id, "Research hit area omits a visible foot or arch")
	var foot: Vector2 = view.get_global_transform_with_canvas() * Vector2(0, 18)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = foot
	mouse.pressed = true
	root.push_input(mouse, true)
	mouse.pressed = false
	root.push_input(mouse, true)
	assert(app.ui.menu == "research" and app.sim.paused, "Mouse click on the outer foot did not open Research")
	app.command("research_resume")
	await process_frame
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = foot
	touch.pressed = true
	Input.parse_input_event(touch)
	await process_frame
	var release: InputEventScreenTouch = touch.duplicate() as InputEventScreenTouch
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
	assert(app.ui.menu == "research" and app.sim.paused, "Emulated touch on the outer foot did not open Research")
	app.audio.music.stop()
	app.queue_free()
	await process_frame
