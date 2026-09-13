extends SceneTree
## Native content and editor-data round-trip checks. No user saves are touched.

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
	_check_atlas()
	var widths: Array[int] = [30, 120, 100, 100, 30, 30]
	var blocked_counts: Array[int] = [52, 450, 459, 165, 52, 52]
	var enemy_counts: Array[int] = [0, 16, 14, 10, 0, 0]
	var starts: Array[Vector2] = [Vector2(348, 605), Vector2(84, 242), Vector2(393, 469),
		Vector2(308, 661), Vector2(348, 605), Vector2(348, 605)]
	for number: int in range(6):
		var packed: PackedScene = load("res://levels/level_%d.tscn" % number) as PackedScene
		expect(packed != null, "Level %d loads" % number)
		if packed == null:
			continue
		var level: GameLevel = packed.instantiate() as GameLevel
		var data: Dictionary = level.data()
		expect(data.number == number, "Correct level number")
		expect(data.width == widths[number] and data.height == 30, "Correct map dimensions")
		expect(data.blocked.size() == blocked_counts[number], "Configured collision count is preserved")
		expect(data.enemies.size() == enemy_counts[number], "Configured enemy count is preserved")
		expect(data.player_start.is_equal_approx(starts[number]), "Configured player start is preserved")
		expect(data.starting_lives == (0 if number == 0 else 3), "Spare life configuration preserved")
		expect(data.starting_resources == (0 if number >= 4 else 30), "Resources preserved")
		expect(data.wave_based == (number == 0 or number >= 4), "Spawn mode preserved")
		var ground: TileMapLayer = level.get_node("Ground") as TileMapLayer
		for cell: Vector2i in [Vector2i(0, 0), Vector2i(7, 12), Vector2i(widths[number] - 1, 29)]:
			var logical: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * 32.0
			expect((ground.map_to_local(cell) + ground.position).is_equal_approx(IsoProjection.project(logical)),
				"Native isometric tile center equals projected gameplay cell center")
		var collision: TileMapLayer = level.get_node("Collision") as TileMapLayer
		var removed: Vector2i = data.blocked[0]
		collision.erase_cell(removed)
		expect(not level.data().blocked.has(removed), "Painting/erasing Collision changes runtime navigation data")
		var marker: SpawnMarker = level.get_node("Spawns").get_child(0) as SpawnMarker
		marker.position = IsoProjection.project(Vector2(321, 456))
		marker.kind = "nathaniel"
		# Disable any later Nathaniel start so only the edited marker applies.
		for other: Node in level.get_node("Spawns").get_children():
			if other != marker and other.kind == "nathaniel":
				other.enabled = false
		var design: EncounterParameters = EncounterParameters.new()
		design.max_hp = 321
		design.speed = 0.0
		var enemy_marker: SpawnMarker = SpawnMarker.new()
		enemy_marker.kind = "soldier"
		enemy_marker.parameters = design
		level.get_node("Spawns").add_child(enemy_marker)
		enemy_marker.owner = level
		expect(level.data().enemies.back().max_hp == 321, "Inspector parameters reach enemy setup")
		expect(level.data().enemies.back().speed == 0.0, "Zero is an explicit override")
		expect(not level.data().enemies.back().has("damage"), "Unset parameters preserve shared balance")
		var scenery: Node2D = level.get_node("Scenery") as Node2D
		expect(scenery.y_sort_enabled and scenery.get_child_count() > 0, "Native upright scenery has shared depth sorting")
		(level.get_node("Spawns") as Node2D).position = Vector2(10, 10)
		expect(level.data().player_start.is_equal_approx(Vector2(336, 461)), "Moving the native spawn group changes logical positions")
		var repacked: PackedScene = PackedScene.new()
		expect(repacked.pack(level) == OK, "Edited native scene packs")
		var roundtrip: GameLevel = repacked.instantiate() as GameLevel
		expect(roundtrip.data().player_start.is_equal_approx(Vector2(336, 461)), "Visual marker edits survive scene serialization")
		expect(not roundtrip.data().blocked.has(removed), "Painted collision edits survive scene serialization")
		roundtrip.free()
		level.free()
	for kind: String in ["nathaniel", "hermes", "grunt", "soldier", "boss", "spawner", "gun_tower", "laser_tower", "heal_tower", "corpse"]:
		var scene: PackedScene = load("res://scenes/actors/%s.tscn" % kind) as PackedScene
		expect(scene != null, "Reusable actor scene loads: " + kind)
		var actor: ActorView = scene.instantiate() as ActorView
		root.add_child(actor)
		actor.apply_state({"id": 1, "position": Vector2(100, 80), "hp": 50, "max_hp": 100}, true)
		expect(actor.position == Vector2(20, 90), "Actor projects logical position")
		expect(actor.sprite.texture != null, "Actor displays its configured texture")
		var foot: Vector2 = actor.sprite.position + Vector2(0, actor.visual.display_size.y / 2)
		expect(foot.is_equal_approx(actor.visual.feet_offset), "Actor bottom-center anchor is its world point")
		actor.free()
	print("Content checks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_atlas() -> void:
	var texture: Texture2D = load("res://assets/terrain/treestileset_iso.png") as Texture2D
	expect(texture != null, "Native terrain atlas loads")
	if texture == null:
		return
	var image: Image = texture.get_image()
	expect(image.get_size() == Vector2i(1024, 1024), "Terrain atlas dimensions are preserved")
	expect(image.get_pixel(0, 0).a == 0.0, "Diamond padding is transparent")
	image.convert(Image.FORMAT_RGBA8)
	var pixels: PackedByteArray = image.get_data()
	var has_opaque: bool = false
	var has_color_key: bool = false
	for offset: int in range(0, pixels.size(), 4):
		if pixels[offset + 3] == 255:
			has_opaque = true
			if pixels[offset] == 191 and pixels[offset + 1] == 123 and pixels[offset + 2] == 199:
				has_color_key = true
	expect(has_opaque, "Terrain artwork contains visible pixels")
	expect(not has_color_key, "Terrain transparency does not retain opaque color-key pixels")
