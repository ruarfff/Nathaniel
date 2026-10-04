extends SceneTree
## Capture the imported actor scenes at review size and at native 4K maximum zoom.

const KINDS: Array[String] = ["gun_tower", "laser_tower", "heal_tower"]
const TITLES: Array[String] = ["GUN TOWER", "LASER TOWER", "HEAL TOWER"]
const ACCENTS: Array[Color] = [Color("b68a61"), Color("9fcbd0"), Color("bdca99")]
const INK: Color = Color("242421")
const PAPER: Color = Color("e1dacb")
const MUTED: Color = Color("aaa79b")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("HD art capture needs a graphical display; omit --headless")
		quit(1)
		return
	var directory: String = ProjectSettings.globalize_path("res://test-artifacts")
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("Cannot create screenshot directory")
		quit(1)
		return
	var viewport: SubViewport = _viewport(Vector2i(1280, 980))
	_gallery(viewport)
	var result: Error = await _save(viewport, directory.path_join("iron-ink-towers.png"))
	viewport.free()
	if result != OK:
		quit(result)
		return
	viewport = _viewport(Vector2i(3840, 2160))
	_native_4k(viewport)
	result = await _save(viewport, directory.path_join("iron-ink-4k.png"))
	viewport.free()
	quit(result)


func _viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = INK
	background.size = Vector2(size)
	viewport.add_child(background)
	return viewport


func _gallery(viewport: SubViewport) -> void:
	_label(viewport, "NATHANIEL   /   IRON & INK", Vector2(48, 28), 16, MUTED)
	_label(viewport, "Tower studies", Vector2(46, 59), 42)
	_label(viewport, "Blender sources  /  8 pixels per world pixel  /  shared 64 × 32 projection", Vector2(48, 119), 17, MUTED)
	for index: int in range(3):
		var point: Vector2 = Vector2(240 + index * 400, 540)
		_diamond(viewport, point, 6.0)
		_actor(viewport, KINDS[index], point, 6.0)
		_label(viewport, TITLES[index], Vector2(68 + index * 400, 641), 21, ACCENTS[index])
	_label(viewport, "IN GAME  /  2×", Vector2(48, 704), 16, MUTED)
	for index: int in range(3):
		var point: Vector2 = Vector2(140 + index * 175, 894)
		_diamond(viewport, point, 2.0)
		_actor(viewport, KINDS[index], point, 2.0)
	_label(viewport, "NATHANIEL  /  SHARED DEPTH SORT", Vector2(713, 704), 16, MUTED)
	_overlap(viewport, Vector2(839, 890), 2.0, false)
	_overlap(viewport, Vector2(1102, 890), 2.0, true)
	_label(viewport, "BEHIND", Vector2(805, 929), 14, MUTED)
	_label(viewport, "IN FRONT", Vector2(1068, 929), 14, MUTED)
	_label(viewport, "Actual Godot ActorView scenes. Ground diamonds are scale guides; collision stays in the simulation.", Vector2(48, 955), 13, MUTED)


func _native_4k(viewport: SubViewport) -> void:
	_label(viewport, "NATHANIEL   /   IRON & INK", Vector2(144, 100), 42, MUTED)
	_label(viewport, "Native 4K · maximum gameplay zoom", Vector2(140, 177), 90)
	_label(viewport, "3840 × 2160 viewport   /   2.7× canvas scale × 2× camera zoom = 5.4 screen pixels per world pixel", Vector2(144, 303), 36, MUTED)
	for index: int in range(3):
		var point: Vector2 = Vector2(720 + index * 1200, 986)
		_diamond(viewport, point, 5.4)
		_actor(viewport, KINDS[index], point, 5.4)
		_label(viewport, TITLES[index], point + Vector2(-174, 160), 42, ACCENTS[index])
	_label(viewport, "NORMAL GAMEPLAY ZOOM", Vector2(144, 1360), 38, MUTED)
	for index: int in range(3):
		var point: Vector2 = Vector2(340 + index * 470, 1820)
		_diamond(viewport, point, 2.7)
		_actor(viewport, KINDS[index], point, 2.7)
	_label(viewport, "NATHANIEL  /  MAXIMUM ZOOM", Vector2(1870, 1360), 38, MUTED)
	_overlap(viewport, Vector2(2270, 1900), 5.4, false)
	_overlap(viewport, Vector2(3240, 1900), 5.4, true)
	_label(viewport, "BEHIND", Vector2(2160, 2014), 32, MUTED)
	_label(viewport, "IN FRONT", Vector2(3130, 2014), 32, MUTED)
	_label(viewport, "Full-size GPU capture of the imported sprites. Shared ground anchors control front and behind sorting.", Vector2(144, 2080), 29, MUTED)


func _actor(parent: Node, kind: String, point: Vector2, magnification: float) -> ActorView:
	var actor: ActorView = load("res://scenes/actors/%s.tscn" % kind).instantiate() as ActorView
	parent.add_child(actor)
	actor.scale = Vector2.ONE * magnification
	actor.apply_state({"id": 1, "position": IsoProjection.unproject(point), "hp": 100, "max_hp": 100}, false, false)
	return actor


func _overlap(parent: Node, point: Vector2, magnification: float, in_front: bool) -> void:
	_diamond(parent, point, magnification)
	var actors := Node2D.new()
	actors.y_sort_enabled = true
	parent.add_child(actors)
	_actor(actors, "gun_tower", point, magnification)
	_actor(actors, "nathaniel", point + Vector2(4, 8 if in_front else -8) * magnification, magnification)


func _diamond(parent: Node, point: Vector2, magnification: float) -> void:
	var diamond := Polygon2D.new()
	diamond.position = point
	diamond.scale = Vector2.ONE * magnification
	diamond.polygon = PackedVector2Array([Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0)])
	diamond.color = Color("34352e")
	parent.add_child(diamond)
	var line := Line2D.new()
	line.points = PackedVector2Array([Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0), Vector2(0, -16)])
	line.width = 0.3
	line.default_color = Color("575749")
	line.antialiased = true
	diamond.add_child(line)


func _label(parent: Node, text: String, point: Vector2, size: int, color: Color = PAPER) -> void:
	var label := Label.new()
	label.text = text
	label.position = point
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _save(viewport: SubViewport, path: String) -> Error:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var result: Error = image.save_png(path)
	if result != OK:
		push_error("Cannot save HD art capture: " + path)
	else:
		print("HD art capture: %s (%d × %d)" % [path, image.get_width(), image.get_height()])
	return result
