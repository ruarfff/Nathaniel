extends SceneTree
## Environment art preserves the native level rules, grid, and ground anchors.

const KINDS: Array[String] = ["house", "house_ruin", "shop", "shop_ruin", "garage", "garage_ruin", "warehouse", "warehouse_ruin", "tree", "dead_tree", "rocks", "windmill"]
const LEVEL_HASHES: Array[String] = [
	"e1643ef1c6c992893868669a1555c004e95dfa5f9803f0dd64dd91e3f22c8612",
	"894c23e7fb99552448b9f0d284aeffc5c9c3c535e0ab13dff0b7e5313b403f1a",
	"225f333101a036a463557dd8ade46dabfb1f89908ad32b87c00cc77a6d6407db",
	"1fd99d5282a0f0268d6e070e1a26bfa58e79fee7f426e691653c9f02ad53a661",
	"2b3a4a6c0a6070e1ee615660a9d18161216f1f4f7dc01670f1db6748e88f20e3",
	"25b3ac95cb24e19cde8f532e19b4b87fa2d5f01801b13da6835f9e9ec6e97952",
]
const SCENERY_COUNTS: Array[int] = [6, 33, 30, 38, 6, 6]
const SCENERY_HASHES: Array[String] = [
	"0f5eb2d10505e3b8423719821809444d8c94b34c1e6cff8fff2ec48aaa0f7fe0",
	"7e9b4885b2f02354273b4821d6706fcfd6b7138161f98e85d6d491f6973b0838",
	"66993a212668d1e61698203365fbfaab984087f5fd06f1c7c01c369c0c4536fa",
	"edf9f545a763daf2fb157fc61f90f4b8696f58e02aa9684e9dc7f3ff28d8783c",
	"0f5eb2d10505e3b8423719821809444d8c94b34c1e6cff8fff2ec48aaa0f7fe0",
	"0f5eb2d10505e3b8423719821809444d8c94b34c1e6cff8fff2ec48aaa0f7fe0",
]

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	var tiles: TileSet = load("res://resources/environment_tileset.tres") as TileSet
	expect(tiles != null, "The shared environment TileSet loads")
	if tiles == null:
		quit(1)
		return
	_check_tiles(tiles)
	_check_levels(tiles)
	for kind: String in KINDS:
		_check_prop(kind)
	if "--render" in OS.get_cmdline_user_args():
		if DisplayServer.get_name() == "headless":
			expect(false, "Rendered environment checks need a graphical display")
		else:
			for zoom: float in [0.5, 0.65, 1.0, 1.35, 2.0, 5.4]:
				await _check_seams(tiles, zoom)
			for phase: float in [0.0, 0.25, 0.5, 0.75]:
				await _check_seams(tiles, 0.5, Vector2.ONE * phase)
			for zoom: float in [1.25, 1.35]:
				await _check_color_seams(tiles, zoom)
			for kind: String in ["house", "house_ruin", "tree", "windmill"]:
				await _check_sorting(kind)
	print("Environment art checks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _metadata(name: String) -> Dictionary:
	var path: String = "res://assets/generated/%s.json" % name
	expect(FileAccess.file_exists(path), name + " has export metadata")
	if not FileAccess.file_exists(path):
		return {}
	var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	expect(result is Dictionary, name + " metadata is valid JSON")
	return result if result is Dictionary else {}


func _check_tiles(tiles: TileSet) -> void:
	var metadata: Dictionary = _metadata("environment_terrain")
	expect(tiles.tile_shape == TileSet.TILE_SHAPE_ISOMETRIC and tiles.tile_layout == TileSet.TILE_LAYOUT_DIAMOND_DOWN, "Terrain retains the isometric Diamond Down layout")
	expect(tiles.tile_size == Vector2i(512, 256), "Native terrain cells contain eight source pixels per world pixel")
	var cell_size := Vector2i(metadata.tile_size[0], metadata.tile_size[1])
	var canvas := Vector2i(metadata.canvas[0], metadata.canvas[1])
	var gutter := Vector2i.ONE * int(metadata.gutter)
	expect(metadata.get("render_density") == 8 and cell_size == Vector2i(512, 256), "Terrain metadata records the shared density and cell size")
	expect(metadata.get("import_premultiplied_alpha", false), "Terrain metadata records premultiplied alpha for mipmaps")
	var shared_material: Material
	for index: int in range(tiles.get_source_count()):
		var source: TileSetAtlasSource = tiles.get_source(tiles.get_source_id(index)) as TileSetAtlasSource
		expect(source != null, "Terrain uses native atlas sources")
		if source == null:
			continue
		expect(not source.use_texture_padding, "Authored gutters preserve the imported mipmaps")
		expect(source.texture_region_size == canvas and canvas.x > cell_size.x and canvas.y > cell_size.y, "Tile art includes exported overlap around the logical diamond")
		expect(source.margins == gutter and source.separation == gutter * 2, "Atlas regions exclude the authored gutters")
		var image: Image = source.texture.get_image()
		expect(image.has_mipmaps(), "Terrain page imports mipmaps")
		var import_config := ConfigFile.new()
		expect(import_config.load(source.texture.resource_path + ".import") == OK and import_config.get_value("params", "process/premult_alpha", false), "Terrain page imports premultiplied alpha before mipmap generation")
		expect(image.get_width() <= 4096 and image.get_height() <= 4096, "Terrain pages stay within 4096 pixels")
		expect(source.get_runtime_texture() == source.texture, "Tile rendering uses the imported texture without rebuilding it")
		expect(not source.has_tiles_outside_texture(), "All declared terrain cells fit the atlas")
		var origins_valid: bool = true
		var materials_valid: bool = true
		for tile_index: int in range(source.get_tiles_count()):
			var coordinate: Vector2i = source.get_tile_id(tile_index)
			var data: TileData = source.get_tile_data(coordinate, 0)
			origins_valid = origins_valid and data.texture_origin == Vector2i.ZERO
			if shared_material == null:
				shared_material = data.material
			materials_valid = materials_valid and data.material == shared_material and data.material is CanvasItemMaterial and (data.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
		expect(origins_valid, "Terrain images remain centered on their logical cell")
		expect(materials_valid, "Every terrain tile carries the shared native premultiplied alpha material into new layers")


func _check_levels(tiles: TileSet) -> void:
	for number: int in range(6):
		var level: GameLevel = load("res://levels/level_%d.tscn" % number).instantiate() as GameLevel
		var data: Dictionary = level.data()
		var occupied: Array[String] = []
		for cell: Vector2i in data.blocked:
			occupied.append("%d,%d" % [cell.x, cell.y])
		occupied.sort()
		data.blocked = occupied
		# Weapon pickups were added after the terrain migration and have their own content checks.
		data.erase("weapon_pickups")
		# Soldier variant checks cover the weapon mix; this baseline protects placement and terrain.
		for spawn: Dictionary in data.enemies:
			if spawn.kind == "gunSoldier":
				spawn.kind = "soldier"
		expect(JSON.stringify(data).sha256_text() == LEVEL_HASHES[number], "Level %d preserves blocked cells, encounter positions, counts and level rules" % number)
		for layer_name: String in ["Ground", "NonCollision", "Collision"]:
			var layer: TileMapLayer = level.get_node(layer_name) as TileMapLayer
			expect(layer.tile_set == tiles and layer.scale == Vector2.ONE / 8.0 and layer.position == Vector2(-32, 0), "Level %d %s uses the shared art at the original grid scale" % [number, layer_name])
			expect(layer.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "Level %d %s uses smooth mipmap sampling" % [number, layer_name])
			expect(not layer.collision_enabled and not layer.navigation_enabled, "Level %d %s does not add engine collision or navigation" % [number, layer_name])
			for cell: Vector2i in [Vector2i.ZERO, Vector2i(7, 12), Vector2i(data.width - 1, data.height - 1)]:
				var point: Vector2 = layer.transform * layer.map_to_local(cell)
				expect(point.is_equal_approx(IsoProjection.project((Vector2(cell) + Vector2.ONE * 0.5) * 32.0)), "Scaled tile centers match logical gameplay centers")
				expect(layer.local_to_map(layer.transform.affine_inverse() * point) == cell, "Editor cell selection reverses the scaled projection")
			var valid_cells: bool = true
			for cell: Vector2i in layer.get_used_cells():
				valid_cells = valid_cells and layer.get_cell_tile_data(cell) != null
			expect(valid_cells, "Level %d %s has no missing tile references" % [number, layer_name])
		var scenery: Node2D = level.get_node("Scenery") as Node2D
		var origins: Array[String] = []
		var generated_only: bool = true
		for index: int in range(SCENERY_COUNTS[number]):
			var original: Node2D = scenery.get_node_or_null("Scenery%d" % index) as Node2D
			if original != null:
				origins.append("%s:%s" % [original.name, original.position])
		for prop: Node2D in scenery.get_children():
			if prop is Sprite2D:
				generated_only = generated_only and (prop as Sprite2D).texture.resource_path.begins_with("res://assets/generated/environment_")
		origins.sort()
		expect(origins.size() == SCENERY_COUNTS[number] and JSON.stringify(origins).sha256_text() == SCENERY_HASHES[number], "Level %d preserves the original scenery ground positions" % number)
		expect(generated_only and scenery.y_sort_enabled, "Level %d uses generated scenery with the existing depth sort" % number)
		level.free()


func _check_prop(kind: String) -> void:
	var name: String = "environment_" + kind
	var metadata: Dictionary = _metadata(name)
	if metadata.is_empty():
		return
	var prop: Sprite2D = load("res://scenes/scenery/generated/%s.tscn" % name).instantiate() as Sprite2D
	var anchor := Vector2(metadata.anchor[0], metadata.anchor[1])
	var image: Image = prop.texture.get_image()
	expect(image.get_size() == Vector2i(metadata.canvas[0], metadata.canvas[1]), kind + " canvas matches the exported metadata")
	expect(metadata.render_density == 8 and prop.scale == Vector2.ONE / 8.0, kind + " uses the shared world scale")
	expect(not prop.centered and prop.offset == -anchor, kind + " origin is the exported ground contact")
	expect((prop.transform * (anchor + prop.offset)).is_equal_approx(prop.position), kind + " ground anchor survives the node transform")
	expect(image.has_mipmaps() and prop.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, kind + " uses smooth imported mipmaps")
	expect(image.detect_alpha() != Image.ALPHA_NONE and image.get_pixel(0, 0).a == 0.0, kind + " retains a transparent background")
	expect(image.get_used_rect().has_area(), kind + " contains visible artwork")
	expect(prop.get_child_count() == 0, kind + " artwork adds no movement footprint")
	expect(FileAccess.file_exists("res://" + metadata.source), kind + " retains its editable Blender source")
	prop.free()


func _viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


func _capture(viewport: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _check_seams(tiles: TileSet, zoom: float, phase: Vector2 = Vector2(0.31, 0.27)) -> void:
	var viewport: SubViewport = _viewport(Vector2i(ceili(256.0 * zoom) + 64, ceili(128.0 * zoom) + 64))
	var world := Node2D.new()
	world.position = Vector2(viewport.size.x / 2.0, 32.0) + phase
	world.scale = Vector2.ONE * zoom
	viewport.add_child(world)
	var layer := TileMapLayer.new()
	layer.tile_set = tiles
	layer.scale = Vector2.ONE / 8.0
	layer.position = Vector2(-32, 0)
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	world.add_child(layer)
	for y: int in range(4):
		for x: int in range(4):
			layer.set_cell(Vector2i(x, y), 0, Vector2i((x + y) % 2, 0))
	var image: Image = await _capture(viewport)
	var holes: int = 0
	var inspected: int = 0
	var minimum_alpha: float = 1.0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var point: Vector2 = IsoProjection.unproject((Vector2(x + 0.5, y + 0.5) - world.position) / zoom)
			if point.x < 4.0 or point.y < 4.0 or point.x > 124.0 or point.y > 124.0:
				continue
			inspected += 1
			var alpha: float = image.get_pixel(x, y).a
			minimum_alpha = minf(minimum_alpha, alpha)
			if alpha < 0.98:
				holes += 1
	expect(inspected > 500 and holes == 0, "Terrain has no interior cracks at %.2f screen pixels per world pixel, phase %s (%d holes, minimum alpha %.3f)" % [zoom, phase, holes, minimum_alpha])
	viewport.free()


func _check_color_seams(tiles: TileSet, zoom: float) -> void:
	var viewport: SubViewport = _viewport(Vector2i(ceili(512.0 * zoom) + 80, ceili(256.0 * zoom) + 80))
	var world := Node2D.new()
	world.position = Vector2(viewport.size.x / 2.0, 40.0) + Vector2(0.31, 0.27)
	world.scale = Vector2.ONE * zoom
	viewport.add_child(world)
	var layer := TileMapLayer.new()
	layer.tile_set = tiles
	layer.scale = Vector2.ONE / 8.0
	layer.position = Vector2(-32, 0)
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	world.add_child(layer)
	for y: int in range(8):
		for x: int in range(8):
			layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	var mipmapped: Image = await _capture(viewport)
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var reference: Image = await _capture(viewport)
	var edge_loss: float = 0.0
	var interior_loss: float = 0.0
	var edge_count: int = 0
	var interior_count: int = 0
	for y: int in range(mipmapped.get_height()):
		for x: int in range(mipmapped.get_width()):
			var point: Vector2 = IsoProjection.unproject((Vector2(x + 0.5, y + 0.5) - world.position) / zoom)
			if point.x < 32.0 or point.y < 32.0 or point.x > 224.0 or point.y > 224.0:
				continue
			var dx: float = minf(fposmod(point.x, 32.0), 32.0 - fposmod(point.x, 32.0))
			var dy: float = minf(fposmod(point.y, 32.0), 32.0 - fposmod(point.y, 32.0))
			var distance: float = minf(dx, dy)
			var actual: Color = mipmapped.get_pixel(x, y)
			var expected: Color = reference.get_pixel(x, y)
			var loss: float = (expected.r + expected.g + expected.b - actual.r - actual.g - actual.b) / 3.0
			if distance >= 1.0 and distance < 3.0:
				edge_loss += loss
				edge_count += 1
			elif distance >= 5.0:
				interior_loss += loss
				interior_count += 1
	expect(edge_count > 1000 and interior_count > 1000, "Uniform scrub patch has enough tile edge and interior samples")
	var edge_bias: float = edge_loss / maxi(edge_count, 1) - interior_loss / maxi(interior_count, 1)
	expect(absf(edge_bias) < 0.0015, "Mipmaps preserve uniform terrain color at %.2f scale (edge brightness bias %.6f relative to unmipmapped sampling)" % [zoom, edge_bias])
	viewport.free()


func _check_sorting(kind: String) -> void:
	var viewport: SubViewport = _viewport(Vector2i(1000, 800))
	var actors := Node2D.new()
	actors.position = Vector2(500, 610)
	actors.scale = Vector2.ONE * 2.0
	actors.y_sort_enabled = true
	viewport.add_child(actors)
	var scenery := Node2D.new()
	scenery.y_sort_enabled = true
	actors.add_child(scenery)
	var prop: Sprite2D = load("res://scenes/scenery/generated/environment_%s.tscn" % kind).instantiate() as Sprite2D
	scenery.add_child(prop)
	var actor: ActorView = load("res://scenes/actors/nathaniel.tscn").instantiate() as ActorView
	actors.add_child(actor)
	actor.apply_state({}, false, false)
	actor.visible = false
	var prop_image: Image = await _capture(viewport)
	for in_front: bool in [false, true]:
		actor.position = Vector2(0, 8 if in_front else -8)
		actor.visible = true
		prop.visible = false
		var actor_image: Image = await _capture(viewport)
		prop.visible = true
		var combined: Image = await _capture(viewport)
		var overlap: int = 0
		var correct: int = 0
		for y: int in range(800):
			for x: int in range(1000):
				var a: Color = actor_image.get_pixel(x, y)
				var p: Color = prop_image.get_pixel(x, y)
				if a.a < 0.99 or p.a < 0.99 or _color_difference(a, p) < 0.08:
					continue
				overlap += 1
				if _color_difference(combined.get_pixel(x, y), a if in_front else p) < 0.025:
					correct += 1
		expect(overlap > 100, kind + " overlaps Nathaniel for a meaningful depth test")
		expect(correct >= overlap * 0.98, "%s sorts Nathaniel %s (%d/%d pixels)" % [kind, "in front" if in_front else "behind", correct, overlap])
	viewport.free()


func _color_difference(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) + absf(a.a - b.a)
