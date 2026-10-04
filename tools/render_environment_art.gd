extends SceneTree
## Render imported environment resources and authored level sections for review.

const BUILDINGS: Array[String] = ["house", "shop", "garage", "warehouse"]
const PROPS: Array[String] = ["tree", "dead_tree", "rocks", "windmill"]
const INK: Color = Color("242421")
const PAPER: Color = Color("e1dacb")
const MUTED: Color = Color("aaa79b")
const DIRECTORY: String = "res://test-artifacts"

var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Environment capture needs a graphical display; omit --headless")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY)) != OK:
		push_error("Cannot create environment capture directory")
		quit(1)
		return
	var viewport: SubViewport = _viewport(Vector2i(2304, 1536))
	_gallery(viewport)
	await _save(viewport, "environment-studies.png")
	viewport.free()
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/environment_terrain.json"))
	viewport = _viewport(Vector2i(1920, maxi(720, 170 + ceili(metadata.tiles.size() / 8.0) * 140)))
	_terrain_palette(viewport, metadata)
	await _save(viewport, "environment-terrain.png")
	viewport.free()
	for number: int in range(4):
		viewport = _viewport(Vector2i(1280, 800))
		_level_section(viewport, number, 1.35)
		await _save(viewport, "environment-level-%d.png" % number)
		viewport.free()
	viewport = _viewport(Vector2i(3840, 2160))
	_level_section(viewport, 2, 5.4)
	await _save(viewport, "environment-4k.png")
	viewport.free()
	quit(1 if failed else 0)


func _viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = INK
	background.size = Vector2(size)
	background.z_index = -100
	viewport.add_child(background)
	return viewport


func _gallery(viewport: SubViewport) -> void:
	_label(viewport, "NATHANIEL   /   IRON & INK", Vector2(64, 34), 18, MUTED)
	_label(viewport, "Earth settlement studies", Vector2(60, 70), 46)
	_label(viewport, "Editable Blender sources  /  8 pixels per world pixel  /  one shared 1.25× review scale", Vector2(64, 132), 20, MUTED)
	for index: int in range(4):
		var x: float = 306 + index * 560
		_label(viewport, BUILDINGS[index].to_upper(), Vector2(x - 210, 194), 23)
		_prop(viewport, BUILDINGS[index], Vector2(x, 594), 1.25)
		_prop(viewport, BUILDINGS[index] + "_ruin", Vector2(x, 1038), 1.25)
		_label(viewport, "RUIN", Vector2(x - 210, 1080), 18, MUTED)
	_label(viewport, "LANDMARKS & GROUND COVER", Vector2(64, 1156), 20, MUTED)
	for index: int in range(4):
		var x: float = 306 + index * 560
		_prop(viewport, PROPS[index], Vector2(x, 1440), 1.25)
		_label(viewport, PROPS[index].replace("_", " ").to_upper(), Vector2(x - 210, 1480), 18, MUTED)


func _prop(parent: Node, kind: String, point: Vector2, zoom: float) -> Sprite2D:
	var guide := Line2D.new()
	guide.position = point
	guide.scale = Vector2.ONE * zoom
	guide.points = PackedVector2Array([Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0), Vector2(0, -16)])
	guide.width = 0.75
	guide.default_color = Color("66624c")
	guide.antialiased = true
	parent.add_child(guide)
	var prop: Sprite2D = load("res://scenes/scenery/generated/environment_%s.tscn" % kind).instantiate() as Sprite2D
	prop.position = point
	prop.scale *= zoom
	parent.add_child(prop)
	return prop


func _terrain_palette(viewport: SubViewport, metadata: Dictionary) -> void:
	_label(viewport, "NATHANIEL   /   IRON & INK", Vector2(48, 28), 17, MUTED)
	_label(viewport, "Terrain palette", Vector2(44, 61), 40)
	_label(viewport, "Native TileMap cells  /  64 × 32 world pixels  /  full-resolution art with mipmaps and padded borders", Vector2(48, 117), 18, MUTED)
	var tiles: TileSet = load("res://resources/environment_tileset.tres") as TileSet
	for index: int in range(metadata.tiles.size()):
		var entry: Dictionary = metadata.tiles[index]
		var point := Vector2(134 + (index % 8) * 236, 221 + (index / 8) * 140)
		var layer := TileMapLayer.new()
		layer.tile_set = tiles
		layer.scale = Vector2.ONE * 2.6 / 8.0
		layer.position = point - Vector2(32, 16) * 2.6
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		viewport.add_child(layer)
		layer.set_cell(Vector2i.ZERO, entry.source_id, Vector2i(entry.atlas_coords[0], entry.atlas_coords[1]))
		_label(viewport, String(entry.name).replace("_", " "), point + Vector2(-86, 52), 15, MUTED)


func _level_section(viewport: SubViewport, number: int, zoom: float) -> void:
	var world := Node2D.new()
	world.scale = Vector2.ONE * zoom
	viewport.add_child(world)
	var level: GameLevel = load("res://levels/level_%d.tscn" % number).instantiate() as GameLevel
	world.add_child(level)
	var data: Dictionary = level.data()
	var actors := Node2D.new()
	actors.y_sort_enabled = true
	world.add_child(actors)
	var scenery: Node2D = level.get_node("Scenery") as Node2D
	scenery.reparent(actors)
	scenery.y_sort_enabled = true
	var focus: Vector2 = IsoProjection.project(data.player_start)
	for prop: Node2D in scenery.get_children():
		if not String(prop.name).begins_with("Scenery"):
			focus = prop.position + Vector2(0, -75)
			break
	world.position = Vector2(viewport.size) * Vector2(0.5, 0.56) - focus * zoom
	_actor(actors, "nathaniel", data.player_start)
	_actor(actors, "hermes", data.hermes_start)
	for enemy: Dictionary in data.enemies:
		_actor(actors, enemy.kind, enemy.position)
	var size_scale: float = viewport.size.x / 1280.0
	var panel := ColorRect.new()
	panel.color = Color(0.1, 0.1, 0.09, 0.91)
	panel.size = Vector2(viewport.size.x, 111 * size_scale)
	viewport.add_child(panel)
	_label(viewport, "IRON & INK / AUTHORED LEVEL %d" % number, Vector2(30, 19) * size_scale, roundi(23 * size_scale))
	var subtitle: String = "Original cell layout, blocked footprints and spawns / %.2f screen pixels per world pixel" % zoom
	if viewport.size.x == 3840:
		subtitle = "3840 × 2160 native capture / 2.7× canvas × 2× maximum camera zoom / original authored layout"
	_label(viewport, subtitle, Vector2(30, 61) * size_scale, roundi(16 * size_scale), MUTED)


func _actor(parent: Node, kind: String, point: Vector2) -> void:
	var path: String = "res://scenes/actors/%s.tscn" % kind
	if not ResourceLoader.exists(path):
		return
	var actor: ActorView = load(path).instantiate() as ActorView
	parent.add_child(actor)
	actor.apply_state({"position": point, "hp": 100, "max_hp": 100}, false, false)


func _label(parent: Node, text: String, point: Vector2, size: int, color: Color = PAPER) -> void:
	var label := Label.new()
	label.text = text
	label.position = point
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _save(viewport: SubViewport, filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var path: String = DIRECTORY.path_join(filename)
	if image.save_png(path) != OK:
		push_error("Cannot save environment capture: " + path)
		failed = true
	else:
		print("Environment art capture: %s (%d × %d)" % [path, image.get_width(), image.get_height()])
