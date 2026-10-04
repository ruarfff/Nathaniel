extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	_check_pulse()
	await _check_application()
	await _check_selection()
	if "--render" in OS.get_cmdline_user_args():
		if DisplayServer.get_name() == "headless":
			expect(false, "Rendered healing checks need a graphical display")
		else:
			await _check_rendered()
			await _check_range_rendered()
	print("Healing tower: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _actor(parent: Node) -> ActorView:
	var actor: ActorView = load("res://scenes/actors/heal_tower.tscn").instantiate()
	parent.add_child(actor)
	actor.apply_state({}, false, true)
	actor.healing_pulse.set_process(false)
	return actor


func _intensity(actor: ActorView) -> float:
	return actor.sprite.get_node("HealingLights").modulate.a


func _check_pulse() -> void:
	var actor: ActorView = _actor(root)
	var reference: ActorView = _actor(root)
	var transform: Transform2D = actor.sprite.transform
	var tint: Color = actor.sprite.modulate
	var dim: float = _intensity(actor)
	actor.healing_pulse._process(0.9)
	var middle: float = _intensity(actor)
	actor.healing_pulse._process(0.9)
	var bright: float = _intensity(actor)
	expect(dim > 0.0 and middle > dim and bright > middle, "Idle lights slowly brighten without turning off")
	actor.healing_pulse._process(1.8)
	expect(is_equal_approx(_intensity(actor), dim), "Idle lights return to their original dim level")
	actor.notify_heal()
	actor.healing_pulse._process(0.05)
	var rising: float = _intensity(actor)
	actor.healing_pulse._process(0.05)
	var peak: float = _intensity(actor)
	expect(rising > bright and peak > rising, "Successful healing rises quickly above the idle glow")
	actor.healing_pulse._process(0.3)
	expect(_intensity(actor) < peak and _intensity(actor) > bright, "Healing light fades smoothly after its peak")
	actor.healing_pulse._process(0.6)
	reference.healing_pulse._process(1.0)
	expect(is_equal_approx(_intensity(actor), _intensity(reference)), "Finished healing returns to the current idle breathing phase")
	expect(actor.sprite.transform == transform and actor.sprite.modulate == tint, "Breathing and healing leave the solid tower's transform and tint unchanged")
	actor.notify_heal()
	actor.healing_pulse._process(0.1)
	actor.apply_state({}, false, false)
	var frozen: float = _intensity(actor)
	actor.healing_pulse._process(2.0)
	expect(is_equal_approx(_intensity(actor), frozen), "Paused actor state freezes an active healing pulse")
	actor.apply_state({}, false, true)
	actor.healing_pulse._process(0.9)
	reference.healing_pulse._process(1.0)
	expect(is_equal_approx(_intensity(actor), _intensity(reference)), "Resume completes the pulse without advancing the paused idle phase")
	actor.free()
	reference.free()


func _check_application() -> void:
	var app: GameApp = load("res://scenes/main.tscn").instantiate()
	app.storage_root = "/private/tmp/nathaniel-healing-tower-%d/" % Time.get_ticks_usec()
	root.add_child(app)
	app.set_physics_process(false)
	expect(app.load_level(0), "Real application loads an isolated healing scenario")
	app.sim.configure({"number": 0, "width": 64, "height": 64, "tile_size": 32,
		"blocked": [], "player_start": Vector2(84, 242), "hermes_start": Vector2(1200, 1200),
		"enemies": [], "wave_based": false})
	app.sim.set_hermes_mode("building")
	var first: Dictionary = app.sim.place_map_tower("healTower", Vector2(200, 242))
	var second: Dictionary = app.sim.place_map_tower("healTower", Vector2(700, 242))
	app.sim.nathaniel.hp -= 5
	app.sim.hermes.position = first.position + Vector2(80, 0)
	app.sim.hermes.hp -= 5
	app.sim.take_events()
	CombatRules.update_unit(app.sim, first, 1.0)
	app._physics_process(0.0)
	var first_actor: ActorView = app.views[int(first.id)]
	var second_actor: ActorView = app.views[int(second.id)]
	first_actor.healing_pulse.set_process(false)
	second_actor.healing_pulse.set_process(false)
	first_actor.healing_pulse._process(0.1)
	second_actor.healing_pulse._process(0.1)
	expect(app.sim.nathaniel.hp == app.sim.nathaniel.max_hp and app.sim.hermes.hp == app.sim.hermes.max_hp, "One domain healing tick reaches both injured characters")
	var recipients: Array = app.effects.healing_flashes.map(func(flash: Dictionary) -> int: return int(flash.target_id))
	expect(recipients.size() == 2 and int(app.sim.nathaniel.id) in recipients and int(app.sim.hermes.id) in recipients, "GameApp gives each healed character one recipient flash")
	expect(_intensity(first_actor) > _intensity(second_actor) + 0.5, "GameApp routes a heal to its owner after creating both tower views")
	app.command("pause")
	app._physics_process(0.0)
	var frozen: float = _intensity(first_actor)
	first_actor.healing_pulse._process(1.0)
	expect(is_equal_approx(_intensity(first_actor), frozen), "The real pause command freezes tower feedback")
	app.command("resume")
	app._physics_process(0.0)
	first_actor.healing_pulse._process(0.9)
	second_actor.healing_pulse._process(0.9)
	expect(is_equal_approx(_intensity(first_actor), _intensity(second_actor)), "The real resume command lets healing recover to idle")
	CombatRules.update_unit(app.sim, first, 1.0)
	app._physics_process(0.0)
	first_actor.healing_pulse._process(0.1)
	second_actor.healing_pulse._process(0.1)
	expect(is_equal_approx(_intensity(first_actor), _intensity(second_actor)), "A full-health target does not retrigger the tower's pulse")
	app.sim.nathaniel.position = Vector2(600, 242)
	app.sim.nathaniel.hp -= 5
	CombatRules.update_unit(app.sim, second, 1.0)
	app._physics_process(0.0)
	first_actor.healing_pulse._process(0.1)
	second_actor.healing_pulse._process(0.1)
	expect(_intensity(second_actor) > _intensity(first_actor) + 0.5, "A later heal activates the second tower without activating the first")
	var removed_pulse: WeakRef = weakref(second_actor.healing_pulse)
	app.sim.damage_entity(int(second.id), int(second.hp))
	app._physics_process(0.0)
	expect(not app.views.has(int(second.id)), "Tower destruction removes its view during an active pulse")
	await process_frame
	expect(removed_pulse.get_ref() == null, "Tower destruction releases its pulse without a pending animation")
	app.sim.nathaniel.position = Vector2(84, 242)
	app.sim.nathaniel.hp -= 5
	CombatRules.update_unit(app.sim, first, 1.0)
	app._physics_process(0.0)
	var menu_pulse: WeakRef = weakref(first_actor.healing_pulse)
	app.show_main()
	await process_frame
	expect(app.views.is_empty() and menu_pulse.get_ref() == null, "Returning to the menu releases active healing views")
	expect(app.load_level(0), "The next game can start after an active healing pulse")
	var fresh: Dictionary = app.sim.place_map_tower("healTower", Vector2(900, 900))
	app._sync_views()
	var fresh_actor: ActorView = app.views[int(fresh.id)]
	fresh_actor.healing_pulse.set_process(false)
	var reference: ActorView = _actor(root)
	fresh_actor.healing_pulse._process(0.1)
	reference.healing_pulse._process(0.1)
	expect(is_equal_approx(_intensity(fresh_actor), _intensity(reference)), "A new game starts each healing tower at idle without a stale pulse")
	reference.free()
	app.queue_free()
	await process_frame


func _selection_app(parent: Node) -> GameApp:
	var app: GameApp = load("res://scenes/main.tscn").instantiate()
	app.storage_root = "/private/tmp/nathaniel-healing-selection-%d/" % Time.get_ticks_usec()
	parent.add_child(app)
	app.set_physics_process(false)
	app.load_level(0)
	app.sim.configure({"number": 0, "width": 64, "height": 64, "tile_size": 32,
		"blocked": [], "player_start": Vector2(450, 600), "hermes_start": Vector2(1200, 1200),
		"enemies": [], "wave_based": false})
	app.sim.set_hermes_mode("building")
	app.sim.fog.fill(2)
	app.fog.enabled = true
	app.effects.fog_enabled = true
	app.ui.update_game(app.sim, app.fog.enabled)
	return app


func _emitter_screen(actor: ActorView) -> Vector2:
	return actor.sprite.get_global_transform_with_canvas() * (Vector2(661, 375) - actor.sprite.region_rect.size * 0.5)


func _check_selection() -> void:
	var app: GameApp = _selection_app(root)
	var first: Dictionary = app.sim.place_map_tower("healTower", Vector2(600, 600))
	var second: Dictionary = app.sim.place_map_tower("healTower", Vector2(800, 600))
	app._sync_views()
	var first_actor: ActorView = app.views[int(first.id)]
	var second_actor: ActorView = app.views[int(second.id)]
	expect(first_actor.sprite.texture.get_image().get_pixel(661, 375).a > 0.99, "Selection fixture clicks the tower's opaque upper emitter")
	app.sim.move_to(Vector2(400, 1000))
	var destination: Vector2 = app.sim.nathaniel.destination
	app.sim.focused_character = "hermes"
	for zoom: float in [0.5, 1.0, 2.0]:
		app.camera_zoom = zoom
		app.camera.zoom = Vector2.ONE * zoom
		app.camera.position = IsoProjection.project(first.position)
		app.camera.force_update_scroll()
		app.world_click(_emitter_screen(first_actor))
		expect(app.effects.selected_healing_tower_id == int(first.id), "Clicking the upper emitter selects healing range at %.1fx zoom" % zoom)
		expect(app.sim.nathaniel.destination == destination and app.sim.focused_character == "hermes", "Tower selection preserves movement and camera focus at %.1fx zoom" % zoom)
	expect(not app.effects.healing_range_points().is_empty(), "Selecting the actual tower exposes its projected healing range")
	app.world_click(_emitter_screen(second_actor))
	expect(app.effects.selected_healing_tower_id == int(second.id), "Clicking another healing tower switches the range selection")
	app.world_click(app.world_to_screen(Vector2(1200, 500)))
	expect(app.effects.selected_healing_tower_id == -1 and app.effects.healing_range_points().is_empty(), "An empty-ground command clears the range")
	app.world_click(_emitter_screen(first_actor))
	app.world_click(app.world_to_screen(app.sim.nathaniel.position) - Vector2(0, 20 * app.camera_zoom))
	expect(app.effects.selected_healing_tower_id == -1, "Clicking another entity clears the tower selection")
	app.world_click(_emitter_screen(first_actor))
	app.command("escape")
	expect(app.effects.selected_healing_tower_id == -1 and not app.sim.paused and app.ui.menu.is_empty(), "Escape clears the range before opening pause")
	app.command("escape")
	expect(app.sim.paused and app.ui.menu == "pause", "A second Escape opens pause after selection is cleared")
	app.command("resume")
	app.world_click(_emitter_screen(first_actor))
	app.command("build")
	expect(app.ui.build_open and app.effects.selected_healing_tower_id == -1, "Opening Build clears healing range")
	app.command("build")
	app.world_click(_emitter_screen(first_actor))
	app.command("focus", "nathaniel")
	expect(app.effects.selected_healing_tower_id == -1, "The focus command clears healing range")
	app.world_click(_emitter_screen(first_actor))
	app.command("settings")
	expect(app.effects.selected_healing_tower_id == int(first.id) and app.sim.paused, "Settings preserves the selected tower while gameplay is paused")
	app.command("resume")
	app.world_click(_emitter_screen(first_actor))
	app.sim.fog.fill(1)
	app._sync_views()
	expect(app.effects.selected_healing_tower_id == -1 and app.effects.healing_range_points().is_empty(), "Fog hiding a selected tower clears its range during view synchronization")
	app.sim.fog.fill(2)
	app._sync_views()
	app.world_click(_emitter_screen(first_actor))
	app.sim.damage_entity(int(first.id), int(first.hp))
	app._sync_views()
	expect(app.effects.selected_healing_tower_id == -1, "A destroyed tower loses its range selection during view synchronization")
	app.world_click(_emitter_screen(second_actor))
	second.owned = true
	app.sim.set_hermes_mode("following")
	app._sync_views()
	expect(app.effects.selected_healing_tower_id == -1 and app.effects.healing_range_points().is_empty(), "Dismantling a live tower clears its selected range")
	var replacement: Dictionary = app.sim.place_map_tower("healTower", Vector2(600, 600))
	app._sync_views()
	app.world_click(_emitter_screen(app.views[int(replacement.id)]))
	app.show_main()
	expect(app.effects.selected_healing_tower_id == -1 and app.effects.healing_range_points().is_empty(), "Returning to the main menu clears the selected healing range")
	app.queue_free()
	await process_frame


func _capture(viewport: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _source_area(actor: ActorView, area: Rect2) -> Rect2i:
	var center: Vector2 = actor.sprite.region_rect.size * 0.5
	var start: Vector2 = actor.sprite.to_global(area.position - center)
	var end: Vector2 = actor.sprite.to_global(area.end - center)
	return Rect2i(Vector2i(start), Vector2i(end - start))


func _average_light(image: Image, area: Rect2i) -> float:
	var total: float = 0.0
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var color: Color = image.get_pixel(x, y)
			total += (color.g + color.b) * 0.5
	return total / float(area.get_area())


func _check_rendered() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(450, 390)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("28282a")
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	var actor: ActorView = _actor(viewport)
	actor.position = Vector2(225, 290)
	actor.scale = Vector2.ONE * 3.5
	var label := Label.new()
	label.position = Vector2(24, 350)
	label.add_theme_font_size_override("font_size", 20)
	viewport.add_child(label)
	label.text = "IDLE"
	var idle: Image = await _capture(viewport)
	actor.notify_heal()
	actor.healing_pulse._process(0.1)
	label.text = "HEALING / 0.10 s"
	var peak: Image = await _capture(viewport)
	actor.healing_pulse._process(0.8)
	label.text = "RECOVERED / 0.90 s"
	var recovered: Image = await _capture(viewport)
	for source: Rect2 in [Rect2(424, 346, 8, 22), Rect2(657, 355, 8, 48), Rect2(520, 465, 8, 45)]:
		var area: Rect2i = _source_area(actor, source)
		var idle_light: float = _average_light(idle, area)
		var peak_light: float = _average_light(peak, area)
		var recovered_light: float = _average_light(recovered, area)
		expect(peak_light > idle_light + 0.03, "Rendered emitter at %s brightens during healing (%.3f to %.3f)" % [source.position, idle_light, peak_light])
		expect(recovered_light < peak_light - 0.03, "Rendered emitter at %s returns to a soft glow (%.3f)" % [source.position, recovered_light])
	var pedestal: Rect2i = _source_area(actor, Rect2(550, 650, 85, 70))
	var changed: int = 0
	for y: int in range(pedestal.position.y, pedestal.end.y):
		for x: int in range(pedestal.position.x, pedestal.end.x):
			if idle.get_pixel(x, y) != peak.get_pixel(x, y) or idle.get_pixel(x, y) != recovered.get_pixel(x, y):
				changed += 1
	expect(changed == 0, "Rendered solid pedestal stays unchanged across the pulse (%d changed pixels)" % changed)
	var comparison := Image.create(viewport.size.x * 3, viewport.size.y, false, idle.get_format())
	comparison.blit_rect(idle, Rect2i(Vector2i.ZERO, viewport.size), Vector2i.ZERO)
	comparison.blit_rect(peak, Rect2i(Vector2i.ZERO, viewport.size), Vector2i(viewport.size.x, 0))
	comparison.blit_rect(recovered, Rect2i(Vector2i.ZERO, viewport.size), Vector2i(viewport.size.x * 2, 0))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-artifacts"))
	expect(comparison.save_png("res://test-artifacts/healing-tower-review.png") == OK, "Healing tower comparison capture is saved")
	viewport.free()


func _range_visible_samples(base: Image, selected: Image, points: PackedVector2Array, transform: Transform2D) -> int:
	var visible: int = 0
	for point: Vector2 in points:
		var screen := Vector2i(transform * point)
		var found: bool = false
		for y: int in range(maxi(0, screen.y - 2), mini(base.get_height(), screen.y + 3)):
			for x: int in range(maxi(0, screen.x - 2), mini(base.get_width(), screen.x + 3)):
				var before: Color = base.get_pixel(x, y)
				var after: Color = selected.get_pixel(x, y)
				if after.g > before.g + 0.04 and after.b > before.b + 0.04 and after.g > after.r + 0.08:
					found = true
		if found:
			visible += 1
	return visible


func _check_range_rendered() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1100, 700)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var app: GameApp = _selection_app(viewport)
	app.fog.enabled = false
	app.effects.fog_enabled = false
	app.effects.set_process(false)
	var tower: Dictionary = app.sim.place_map_tower("healTower", Vector2(600, 600))
	app._sync_views()
	var actor: ActorView = app.views[int(tower.id)]
	actor.healing_pulse.set_process(false)
	app.camera_zoom = 0.8
	app.camera.zoom = Vector2.ONE * app.camera_zoom
	app.camera.position = IsoProjection.project(tower.position)
	app.camera.force_update_scroll()
	var base: Image = await _capture(viewport)
	app.world_click(_emitter_screen(actor))
	var points: PackedVector2Array = app.effects.healing_range_points()
	var selected: Image = await _capture(viewport)
	var transform: Transform2D = app.effects.get_global_transform_with_canvas()
	var visible: int = _range_visible_samples(base, selected, points, transform)
	expect(not points.is_empty() and visible > points.size() / 2, "Selected tower visibly draws a cyan range on the actual level (%d boundary samples)" % visible)
	app.command("escape")
	var cleared: Image = await _capture(viewport)
	expect(_range_visible_samples(base, cleared, points, transform) == 0, "Clearing selection removes the rendered range boundary")
	expect(selected.save_png("res://test-artifacts/healing-range-review.png") == OK, "Selected healing range capture is saved")
	viewport.queue_free()
	await process_frame
