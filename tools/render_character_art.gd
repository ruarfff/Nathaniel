extends SceneTree
## Capture native animated actor scenes. --animate saves frames; --preview stays open.

const KINDS: Array[String] = ["nathaniel", "hermes", "grunt", "soldier", "boss"]
const TITLES: Array[String] = ["NATHANIEL", "HERMES", "GRUNT", "SOLDIER", "BOSS"]
const PAPER: Color = Color("e1dacb")
const MUTED: Color = Color("aaa79b")

var cast: Array[ActorView] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Character capture needs a graphical display; omit --headless")
		quit(1)
		return
	var directory: String = ProjectSettings.globalize_path("res://test-artifacts")
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("Cannot create character capture directory")
		quit(1)
		return
	var viewport: SubViewport = _board(false)
	if "--preview" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280, 720)
		root.content_scale_size = root.size
		DisplayServer.window_set_title("Nathaniel - Animated art preview")
		var display := TextureRect.new()
		display.texture = viewport.get_texture()
		display.size = Vector2(root.size)
		display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		root.add_child(display)
		_start_walking()
		return
	var result: Error = await _save(viewport, directory.path_join("character-studies.png"))
	if result == OK and "--animate" in OS.get_cmdline_user_args():
		var frames_directory: String = directory.path_join("character-animation")
		result = DirAccess.make_dir_recursive_absolute(frames_directory)
		if result == OK:
			_start_walking()
			for frame: int in range(48):
				if frame == 16 or frame == 36:
					for actor: ActorView in cast:
						actor.notify_attack()
				result = await _save(viewport, frames_directory.path_join("frame_%03d.png" % frame), false)
				if result != OK:
					break
			print("Character animation frames: ", frames_directory)
	viewport.free()
	cast.clear()
	if result == OK:
		viewport = _board(true)
		result = await _save(viewport, directory.path_join("character-4k.png"))
		viewport.free()
	quit(result)


func _board(native_4k: bool) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(3840, 2160) if native_4k else Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(viewport.size)
	background.color = Color("242421")
	viewport.add_child(background)
	var factor: Vector2 = Vector2(2.0, 2.0) if native_4k else Vector2.ONE
	var type_scale: int = 2 if native_4k else 1
	_label(viewport, "NATHANIEL   /   IRON & INK", Vector2(48, 28) * factor, 17 * type_scale, MUTED)
	_label(viewport, "Characters at native 4K" if native_4k else "Character studies", Vector2(46, 65) * factor, 44 * type_scale)
	_label(viewport, "Native SpriteFrames   /   idle · walk · fire   /   eight logical headings   /   8 pixels per world pixel", Vector2(48, 133) * factor, 18 * type_scale, MUTED)
	var magnification: float = 5.4 if native_4k else 3.8
	for index: int in range(5):
		var point: Vector2 = Vector2(200 + index * 365, 580) * factor
		_diamond(viewport, point, magnification)
		var actor: ActorView = _actor(viewport, KINDS[index], point, magnification, 0, false)
		cast.append(actor)
		_label(viewport, TITLES[index], Vector2(90 + index * 365, 706) * factor, 24 * type_scale)
	_label(viewport, "NATHANIEL  /  EIGHT WALK DIRECTIONS", Vector2(48, 751) * factor, 18 * type_scale, MUTED)
	for direction: int in range(8):
		var point: Vector2 = Vector2(120 + direction * 240, 949) * factor
		_diamond(viewport, point, 2.7 if native_4k else 1.8)
		var actor: ActorView = _actor(viewport, "nathaniel", point, 2.7 if native_4k else 1.8, direction, true)
		if actor.animation_sprite != null:
			actor.animation_sprite.set_frame_and_progress(1, 0.0)
		_label(viewport, "%d°" % (direction * 45), Vector2(103 + direction * 240, 1002) * factor, 17 * type_scale, MUTED)
	_label(viewport, "5.4 screen pixels per world pixel at maximum gameplay zoom. Gameplay footprints stay independent." if native_4k else "Actual Godot actor scenes. One shared art scale and ground anchor per actor across every frame and direction.", Vector2(48, 1042) * factor, 15 * type_scale, MUTED)
	return viewport


func _actor(parent: Node, kind: String, point: Vector2, magnification: float, direction: int, moving: bool) -> ActorView:
	var actor: ActorView = load("res://scenes/actors/%s.tscn" % kind).instantiate() as ActorView
	parent.add_child(actor)
	actor.scale = Vector2.ONE * magnification
	actor.apply_state({"id": 1, "position": IsoProjection.unproject(point), "facing": Vector2.RIGHT.rotated(float(direction) * PI / 4.0), "moving": moving, "hp": 100, "max_hp": 100}, false, false)
	return actor


func _start_walking() -> void:
	for actor: ActorView in cast:
		actor.apply_state({"position": IsoProjection.unproject(actor.position), "facing": Vector2.RIGHT, "moving": true}, false, true)


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


func _save(viewport: SubViewport, path: String, report: bool = true) -> Error:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var result: Error = image.save_png(path)
	if result != OK:
		push_error("Cannot save character capture: " + path)
	elif report:
		print("Character capture: %s (%d × %d)" % [path, image.get_width(), image.get_height()])
	return result
