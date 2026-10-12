extends SceneTree
## Native UI integration with isolated storage; does not claim physical touch coverage.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)


func _run() -> void:
	var surface := SubViewport.new()
	surface.size = Vector2i(1280, 800)
	root.add_child(surface)
	var app := load("res://scenes/main.tscn").instantiate() as GameApp
	app.storage_root = "/private/tmp/nathaniel-research-ui-%d/" % Time.get_ticks_usec()
	surface.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app.load_level(0)
	app.fog.enabled = false
	app.sim.tech = 100
	app.sim.resources = 100
	app.sim.hermes.position = Vector2(480, 480)
	app.sim.nathaniel.position = Vector2(420, 400)
	var center := app.sim.place_map_tower("researchCenter", Vector2(590, 430))
	check(not center.is_empty(), "Research fixture creates one connected center")
	app._sync_views()
	app.ui.update_game(app.sim)
	check(app.views.has(int(center.id)), "Research center has a native actor view")
	check(app.ui.ring_buttons.research_center.disabled and app.ui.ring_buttons.research_center.text == "Research built", "Fourth build slot reports singleton state")
	check(not app.ui.buttons.upgrade_capacity.visible and not app.ui.buttons.upgrade_reach.visible, "Survival hides old matter purchase controls")
	app.camera.position = IsoProjection.project(center.position)
	app.camera.force_update_scroll()
	await process_frame
	var center_point := app.world_to_screen(center.position) - Vector2(0, 35)
	check(app.world_entity_at(center_point).get("id", -1) == center.id, "Center body hit testing selects its actor")
	var pickup := app.sim.spawn_tech(8, Vector2(center.position) + Vector2(95, 95), "core")
	app._sync_views()
	var pickup_point := app.world_to_screen(pickup.position)
	app.world_click(pickup_point)
	check(app.sim.tech_target_id == int(pickup.id) and app.tech_views.has(int(pickup.id)), "Visible tech tap selects a domain approach and native pickup view")
	app.command("stop")
	check(app.sim.tech_target_id == 0, "Stop cancels the tech approach through the same command path")
	app.open_context_ring()
	app.ui.build_kind = "gun_tower"
	app.ui.close_ring()
	var matter_before := app.sim.resources
	app.world_click(center_point)
	check(app.ui.menu.is_empty() and app.ui.build_kind == "gun_tower" and app.sim.resources == matter_before, "Active placement keeps priority over opening a center")
	app._set_build_open(false)
	app.open_context_ring()
	# Position the context ring away from the center body; its buttons keep priority.
	app.ui.ring_actor_position = Vector2(260, 300)
	app.ui._ring_layout_size = Vector2.ZERO
	app.ui._layout_ring()
	var destination: Variant = app.sim.nathaniel.destination
	app.world_click(center_point)
	check(app.ui.menu == "research" and app.sim.paused and app.ui.ring_character.is_empty(), "Center tap replaces open ring and pauses immediately")
	check(app.sim.nathaniel.destination == destination and not app.game_input._world_tap_pending, "Opening input is consumed without moving Nathaniel")
	await process_frame
	var menu := app.ui.research
	check(not menu.narrow and menu._list_scroll.visible and menu._details.visible, "Desktop shows list and details together")
	check(menu.purchase_button.size.y >= 48 and menu.resume_button.size.y >= 48, "Primary controls meet logical touch target minimum")
	var debug_nodes := GameDebugBridge.new(app).nodes()
	check(debug_nodes.any(func(node: Dictionary) -> bool: return str(node.name).begins_with("Research ·")), "Debug discovers the active Research purchase control")
	await process_frame
	check(menu.purchase_button.get_global_rect().end.y <= app.ui.safe_rect().end.y, "Desktop purchase remains inside the safe area after initial layout")
	var elapsed := app.sim.elapsed_time
	app.effects.delivery_pulse_time = 0.5
	var frozen_effect := {"position": Vector2.ZERO, "life": 0.4, "kind": "hit"}
	app.effects.transients.append(frozen_effect)
	var world_before := app.sim.snapshot()
	app._physics_process(2.0)
	app.effects._process(2.0)
	check(app.sim.elapsed_time == elapsed and app.sim.snapshot() == world_before, "Research freezes complete simulation snapshot")
	check(is_equal_approx(app.effects.delivery_pulse_time, 0.5) and is_equal_approx(frozen_effect.life, 0.4), "Research freezes delivery pulses and transient world effects")
	app.world_click(Vector2(15, 15))
	app.command("fire")
	app.command("follow")
	check(app.ui.menu == "research" and app.sim.nathaniel.destination == destination and app.sim.hermes_mode == "building", "Background input and gameplay commands cannot escape Research")
	menu.select_track("capacity")
	check(app.sim.tech == 100 and app.sim.research_ranks.capacity == 0, "Selecting a row does not buy a rank")
	menu.purchase_button.button_down.emit()
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	menu.purchase_button.pressed.emit()
	check(app.sim.tech == 100 and app.sim.research_ranks.capacity == 0, "A press interrupted by application suspension requires a fresh foreground input")
	menu.purchase_button.button_down.emit()
	menu.purchase_button.pressed.emit()
	check(app.sim.tech == 90 and app.sim.research_ranks.capacity == 1 and app.sim.paused, "Explicit button buys one rank while paused")
	menu.purchase_button.pressed.emit()
	check(app.sim.tech == 90 and app.sim.research_ranks.capacity == 1, "Repeated pressed signal needs fresh input before another purchase")
	app.command("research_purchase", {"track": "capacity", "expected_rank": 0, "session_id": app.sim.research_session_id})
	check(app.sim.tech == 90 and menu._feedback.text.begins_with("Research changed"), "Stale purchase preserves wallet and shows explanation")
	menu.purchase_button.button_down.emit()
	menu.purchase_button.pressed.emit()
	check(app.sim.research_ranks.capacity == 2 and menu.purchase_button.disabled and menu._reason.text == "Maximum rank reached.", "Maximum rank has disabled purchase and visible reason")
	app.sim.tech = 0
	menu.update_state(app.sim.research_state())
	menu.select_track("reach")
	check(menu.purchase_button.disabled and menu._reason.text == "Need 8 more Tech", "Insufficient Tech shows the exact shortage")
	surface.size = Vector2i(667, 375)
	await process_frame
	await process_frame
	menu._layout()
	menu.select_track("reach")
	await process_frame
	check(menu.narrow and menu.narrow_detail and menu.back_button.visible and not menu._list_scroll.visible, "Landscape phone uses full-width details with Back")
	check(menu._title.visible and menu._title.get_global_rect().end.x < menu._balance.get_global_rect().position.x, "Small-phone details preserve title and balance without overlap")
	check(menu.purchase_button.get_global_rect().end.y <= app.ui.safe_rect().end.y, "Short-screen purchase remains inside safe area")
	check(menu._detail_scroll.size.y > 0 and menu._detail_scroll.size.y < menu._detail_text.size.y, "Long details scroll above stable purchase control")
	# Production canvas_items stretching retains the 1280x800 virtual world on
	# a small physical viewport. An unscaled SubViewport alone cannot test it.
	surface.size_2d_override = Vector2i(1280, 800)
	surface.size_2d_override_stretch = true
	await process_frame
	await process_frame
	menu._layout()
	await process_frame
	check(app.ui.size.x >= 1280 and menu.narrow, "Research uses output width while the world retains its desktop virtual resolution")
	var rendered_purchase: Rect2 = surface.get_final_transform() * menu.purchase_button.get_global_rect()
	var rendered_resume: Rect2 = surface.get_final_transform() * menu.resume_button.get_global_rect()
	check(rendered_purchase.size.y >= 48 and rendered_resume.size.y >= 48, "Stretched desktop canvas retains 48px output targets")
	check(Rect2(Vector2(16, 16), Vector2(635, 343)).encloses(rendered_purchase), "Stretched phone purchase fits the physical safe area")
	check(app.ui.scale == Vector2.ONE and menu.scale.x > 1.0, "Only Research compensates for world scaling")
	surface.size_2d_override = Vector2i(960, 540)
	await process_frame
	await process_frame
	menu._layout()
	await process_frame
	rendered_resume = surface.get_final_transform() * menu.resume_button.get_global_rect()
	check(menu.narrow and rendered_resume.size.y >= 48, "Mobile 960x540 world scaling also retains touch targets")
	surface.size_2d_override = Vector2i.ZERO
	surface.size_2d_override_stretch = false
	await process_frame
	await process_frame
	menu._layout()
	app.command("escape")
	check(app.sim.paused and app.ui.menu == "research" and not menu.narrow_detail, "First phone Back returns to list without releasing pause")
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not app.sim.paused and app.ui.menu.is_empty(), "Second system Back closes Research")
	app.sim.set_paused(true)
	check(app._open_research(int(center.id)), "Research can acquire its own pause above an existing pause")
	app.command("research_resume")
	check(app.sim.paused and app.ui.menu == "pause", "Resume releases Research while preserving prior pause")
	app.command("resume")
	app._open_research(int(center.id))
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	app.command("research_resume")
	check(app.sim.paused, "Closing Research does not release application suspension")
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(not app.sim.paused and app.ui.menu.is_empty(), "Application resume releases only suspension without leaving a stale Pause menu")
	app.ui.show_menu("")
	app._open_research(int(center.id))
	app.sim.damage_entity(int(center.id), int(center.max_hp))
	app._physics_process(0.0)
	check(app.ui.menu != "research" and app.sim.research_session_id == 0, "Invalid center closes menu safely")
	check(app._retiring_centers.size() == 1 and app._retiring_centers[0]._removal == "destroyed", "Center destruction preserves its retirement cue when invalidating Research")
	app.load_level(1)
	app.ui.update_game(app.sim)
	check(app.ui.buttons.upgrade_capacity.visible and app.ui.buttons.upgrade_reach.visible and app.ui.ring_buttons.research_center.disabled, "Campaign keeps its original backpack path and no Research purchase")
	app.sim.damage_entity(int(app.sim.nathaniel.id), 1)
	app._sync_views()
	await create_timer(0.2).timeout
	app._sync_views()
	app._sync_views()
	var player_view: ActorView = app.views[int(app.sim.nathaniel.id)]
	check(not player_view._damage_tween_paused and not player_view._damage_tween.is_running(), "Repeated state updates do not restart a completed damage flash")
	app.audio.music.stop()
	surface.queue_free()
	await process_frame
	await create_timer(0.05).timeout
	print("Research presentation: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
