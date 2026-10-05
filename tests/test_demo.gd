extends SceneTree
## Demo checks use the real startup arguments and isolated storage.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	Engine.max_fps = 60
	_run.call_deferred()


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)


func _run() -> void:
	var app := load("res://scenes/main.tscn").instantiate() as GameApp
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	check(app.demo_mode and app.ui.demo_mode, "Demo startup configures the application and UI")
	check(app.ui.menu == "main" and app.sim == null, "Demo rejects campaign startup arguments and keeps the main menu")
	check(app.storage_root.ends_with("/demo-mode/demo/"), "Demo storage is separate under the explicit test root")
	app.progress.record_completion(2, 100, 10.0)
	app.show_main()
	check(_menu_text(app).contains("DEMO MODE · SURVIVAL ONLY"), "Main menu identifies the demo and its available mode")
	check(_menu_button(app, "New campaign") == null and _menu_button(app, "Select level") == null and not _menu_text(app).contains("Continue · Level"), "Demo menu omits all campaign entry points even with campaign records")
	check(_menu_button(app, "Survival") != null, "Demo offers Survival")
	app.command("levels")
	check(app.ui.menu == "main", "Demo rejects the campaign selector command")
	for number: int in range(1, 6):
		check(not app.load_level(number) and app.sim == null, "Demo rejects campaign level %d" % number)
	var campaign := load("res://levels/level_2.tscn").instantiate() as GameLevel
	var campaign_sim := GameSimulation.new()
	campaign_sim.configure(campaign.data())
	var campaign_snapshot := campaign_sim.snapshot()
	app.start_level_scene(campaign)
	check(app.sim == null and app.level == null, "Demo rejects direct campaign scene startup")
	_menu_button(app, "Survival").pressed.emit()
	await process_frame
	app.set_physics_process(false)
	check(app.sim != null and app.sim.level_number == 0 and app.ui.menu.is_empty(), "Survival menu button starts the authored survival level")
	app.ui.update_game(app.sim)
	check((app.ui.get_node("%Stats") as Label).text.contains("DEMO · SURVIVAL"), "Gameplay HUD identifies demo mode")
	var survival := app.sim
	app.command("level", 3)
	check(app.sim == survival and app.level.definition.number == 0, "Campaign commands preserve the current survival session")
	app.command("pause")
	check(_menu_text(app).contains("Demo mode · Survival only"), "Pause menu identifies demo mode")
	app.sim.resources = 123
	app.command("confirm_save", 1)
	check(app.save_store.load_slot(1).success, "Demo can save survival")
	app.command("main")
	app.command("load_slot", 1)
	check(app.sim != null and app.sim.level_number == 0 and app.sim.resources == 123 and not app.sim.paused, "Demo restores survival saves and resumes play")
	check(app.save_store.save_slot(2, campaign_snapshot, "Campaign fixture").success, "Campaign save fixture is valid")
	survival = app.sim
	app.command("load_slot", 2)
	check(app.sim == survival and app.sim.level_number == 0, "Demo rejects campaign saves without replacing survival")
	var imported := app.import_swift_save(app.storage_root.path_join("missing-swift.json"), 3)
	check(not imported.success and not FileAccess.file_exists(app.save_store.slot_path(3)), "Demo rejects Swift import without writing a slot")
	app.sim.result = "gameOver"
	app._physics_process(0.0)
	check(_menu_button(app, "Try again") != null, "Survival defeat offers retry")
	_menu_button(app, "Try again").pressed.emit()
	check(app.sim != survival and app.sim.level_number == 0 and app.sim.result == "playing", "Demo retry starts a fresh survival session")
	app.command("settings")
	app.command("back")
	check(app.ui.menu == "pause" and app.sim.paused, "Demo settings returns to paused survival")
	app.command("main")
	check(app.sim == null and _menu_text(app).contains("DEMO MODE"), "Returning to main keeps demo access rules")
	app.save_store.delete_slot(1)
	app.save_store.delete_slot(2)
	app.audio.music.stop()
	app.queue_free()
	await process_frame
	await create_timer(0.05).timeout
	print("Demo integration: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _menu_button(app: GameApp, text: String) -> Button:
	for child: Node in app.ui.get_node("%Content").get_children():
		if child is Button and child.text == text:
			return child
	return null


func _menu_text(app: GameApp) -> String:
	var text := ""
	for child: Node in app.ui.get_node("%Content").get_children():
		if child is Label:
			text += child.text + "\n"
	return text
