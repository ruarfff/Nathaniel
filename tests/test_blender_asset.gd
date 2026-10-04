extends SceneTree
## Checks the imported sprite contract. --render also checks visible occlusion.

const PROP_PATH: String = "res://scenes/scenery/generated/placeholder_prop.tscn"
const PNG_PATH: String = "res://assets/generated/placeholder_prop.png"
const METADATA_PATH: String = "res://assets/generated/placeholder_prop.json"

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
	var image: Image = (load(PNG_PATH) as Texture2D).get_image()
	expect(image != null and not image.is_empty(), "Generated prop PNG loads")
	if image == null or image.is_empty():
		quit(1)
		return
	expect(image.get_size() == Vector2i(128, 128), "Shared render canvas stays 128 x 128")
	expect(image.detect_alpha() != Image.ALPHA_NONE, "Prop has transparent background")
	expect(image.get_pixel(0, 0).a == 0.0 and image.get_pixel(127, 127).a == 0.0, "Canvas corners remain transparent")
	var bounds: Rect2i = image.get_used_rect()
	expect(bounds.size.x >= 62 and bounds.size.x <= 66, "One-unit prop spans one 64-pixel ground diamond")
	expect(absi(bounds.end.y - 112) <= 2, "Ground contact includes the cell's front corner below its center anchor")
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string(METADATA_PATH))
	expect(metadata is Dictionary, "Export metadata loads")
	if metadata is Dictionary:
		expect(metadata.get("canvas") == [128.0, 128.0], "Metadata declares the source canvas")
		expect(metadata.get("anchor") == [64.0, 96.0], "Metadata declares the ground-center anchor")
	var import_config := ConfigFile.new()
	expect(import_config.load(PNG_PATH + ".import") == OK, "Import settings are recorded")
	for setting: String in ["compress/mode", "process/size_limit"]:
		expect(import_config.get_value("params", setting) == 0, "Lossless full-size import: " + setting)
	expect(import_config.get_value("params", "process/fix_alpha_border") == true, "Import fixes alpha borders")
	expect(import_config.get_value("params", "process/premult_alpha") == false, "Import retains straight alpha")
	var prop: Sprite2D = load(PROP_PATH).instantiate() as Sprite2D
	expect(prop != null, "Exported prop is a native Sprite2D")
	if prop == null:
		quit(1)
		return
	expect(prop.texture.get_size() == Vector2(128, 128), "Imported texture dimensions match export")
	expect(not prop.centered and prop.offset == Vector2(-64, -96), "Native sprite offset preserves the ground anchor")
	expect(prop.scale == Vector2.ONE and prop.z_index == 0, "Prop retains common scale and shared depth")
	expect(prop.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Prop uses the existing nearest sampling convention")
	expect(not prop.texture.get_image().has_mipmaps(), "Imported sprite has no mipmaps")
	expect(prop.get_child_count() == 0, "Artwork has no embedded collision or gameplay nodes")
	prop.free()
	var preview: BlenderAssetPreview = load("res://scenes/tests/blender_asset_preview.tscn").instantiate() as BlenderAssetPreview
	root.add_child(preview)
	expect((preview.get_node("World/Actors") as Node2D).y_sort_enabled and preview.scenery.y_sort_enabled, "Fixture uses the game's nested actor/scenery Y sort")
	expect(preview.behind.position.y < preview.scenery.get_child(1).position.y, "Behind actor feet sort before the prop anchor")
	expect(preview.in_front.position.y > preview.scenery.get_child(2).position.y, "Front actor feet sort after the prop anchor")
	expect(IsoProjection.project(Vector2(32, 0)) == Vector2(32, 16) and IsoProjection.project(Vector2(0, 32)) == Vector2(-32, 16), "Game basis matches Blender Y then X")
	if "--render" in OS.get_cmdline_user_args():
		if DisplayServer.get_name() == "headless":
			expect(false, "Pixel checks need a graphical display; omit --headless")
		else:
			await _check_rendered(preview)
	preview.free()
	print("Blender asset checks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _check_rendered(preview: BlenderAssetPreview) -> void:
	root.size = Vector2i(1280, 800)
	DisplayServer.window_set_title("Nathaniel - Blender asset validation")
	var combined: Image = await _capture()
	preview.behind.hide()
	preview.in_front.hide()
	var props: Image = await _capture()
	preview.scenery.hide()
	var background: Image = await _capture()
	preview.behind.show()
	preview.in_front.show()
	var actors: Image = await _capture()
	preview.scenery.show()
	var behind_pixels: int = _matching_overlap(combined, props, actors, background, Rect2i(570, 280, 140, 170))
	var front_pixels: int = _matching_overlap(combined, actors, props, background, Rect2i(990, 280, 140, 190))
	expect(behind_pixels > 40, "Rendered prop visibly covers the actor behind it (%d pixels)" % behind_pixels)
	expect(front_pixels > 40, "Rendered actor visibly covers the prop in front of it (%d pixels)" % front_pixels)
	var directory: String = ProjectSettings.globalize_path("res://test-artifacts")
	expect(DirAccess.make_dir_recursive_absolute(directory) == OK, "Screenshot directory exists")
	expect(combined.save_png(directory.path_join("blender-preview.png")) == OK, "Rendered fixture screenshot saves")
	print("Rendered overlap: behind=%d pixels, front=%d pixels" % [behind_pixels, front_pixels])


func _matching_overlap(combined: Image, expected: Image, other: Image, background: Image, area: Rect2i) -> int:
	var count: int = 0
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var first: Color = expected.get_pixel(x, y)
			var second: Color = other.get_pixel(x, y)
			var base: Color = background.get_pixel(x, y)
			if _difference(first, base) < 0.12 or _difference(second, base) < 0.12 or _difference(first, second) < 0.12:
				continue
			if _difference(combined.get_pixel(x, y), first) < 0.01:
				count += 1
	return count


func _difference(first: Color, second: Color) -> float:
	return maxf(absf(first.r - second.r), maxf(absf(first.g - second.g), absf(first.b - second.b)))
