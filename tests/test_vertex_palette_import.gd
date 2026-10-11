extends SceneTree
## Check import-only color conversion and unchanged mesh buffers.

const Importer = preload("res://scripts/presentation/actors/import_vertex_palette.gd")
const SOURCE: String = "res://assets/generated/soldier.glb"
const PALETTE: Dictionary = {"0,1,1,255": [0.003, 0.004, 0.005, 1.0]}

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func fixture() -> Node3D:
	var scene := Node3D.new()
	scene.name = "Fixture"
	var node := MeshInstance3D.new()
	node.name = "Paint"
	scene.add_child(node)
	node.owner = scene
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.ONE])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.UP, Vector2.ONE])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color(0.003, 0.004, 0.005), Color(0.003, 0.004, 0.005), Color(0.003, 0.004, 0.005), Color(0.003, 0.004, 0.005)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 2, 1, 3])
	var mesh := ArrayMesh.new()
	mesh.resource_name = "Paint mesh"
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {10.0: PackedInt32Array([0, 1, 2])})
	var material := StandardMaterial3D.new()
	material.metallic = 0.12
	material.roughness = 0.78
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	mesh.surface_set_name(0, "Paint surface")
	arrays[Mesh.ARRAY_COLOR] = null
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(1, material)
	mesh.surface_set_name(1, "Plain surface")
	mesh.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(5, 5, 5))
	mesh.lightmap_size_hint = Vector2i(64, 64)
	mesh.shadow_mesh = ArrayMesh.new()
	mesh.shadow_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	node.mesh = mesh
	node.set_meta("extras", {"rigid_vertex_palette": PALETTE.duplicate(true), "keep": "authored"})
	return scene


func _run() -> void:
	_check_conversion()
	_check_guards()
	if not OS.get_cmdline_user_args().has("--skip-assets"):
		_check_assets()
	print("Vertex palette import: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_conversion() -> void:
	var importer: GDScript = Importer
	var scene: Node3D = fixture()
	var node: MeshInstance3D = scene.get_node("Paint")
	var original: ArrayMesh = node.mesh
	var original_data: Dictionary = RenderingServer.mesh_get_surface(original.get_rid(), 0)
	var original_plain: Dictionary = RenderingServer.mesh_get_surface(original.get_rid(), 1)
	var original_material: StandardMaterial3D = original.surface_get_material(0)
	expect(importer.convert_scene(scene, SOURCE).is_empty(), "Supported palette imports")
	var converted: ArrayMesh = node.mesh
	expect(converted != original and converted.get_rid() != original.get_rid(), "Conversion owns a separate mesh and RID")
	expect(RenderingServer.mesh_get_surface(original.get_rid(), 0) == original_data, "Original shared mesh bytes stay unchanged")
	var data: Dictionary = RenderingServer.mesh_get_surface(converted.get_rid(), 0)
	for key: String in original_data:
		if key not in ["attribute_data", "material"]:
			expect(data[key] == original_data[key], "Import preserves surface field " + key)
	expect(RenderingServer.mesh_get_surface(converted.get_rid(), 1) == original_plain, "Uncolored surface bytes and material stay exact")
	var stride: int = RenderingServer.mesh_surface_get_format_attribute_stride(data.format, data.vertex_count)
	var offset: int = RenderingServer.mesh_surface_get_format_offset(data.format, data.vertex_count, Mesh.ARRAY_COLOR)
	var attributes: PackedByteArray = data.attribute_data
	var prior: PackedByteArray = original_data.attribute_data
	var expected: Color = Color(0.003, 0.004, 0.005).linear_to_srgb()
	for vertex: int in data.vertex_count:
		for byte: int in stride:
			var index: int = vertex * stride + byte
			if byte >= offset and byte < offset + 4:
				var value: float = [expected.r, expected.g, expected.b, expected.a][byte - offset]
				expect(attributes[index] == int(value * 255), "Dark paint is restored before sRGB packing")
			else:
				expect(attributes[index] == prior[index], "All non-color attribute bytes stay exact")
	var material: StandardMaterial3D = converted.surface_get_material(0)
	expect(material != original_material and material.vertex_color_use_as_albedo and material.vertex_color_is_srgb, "Only colored material is cloned and enabled")
	expect(not original_material.vertex_color_use_as_albedo and not original_material.vertex_color_is_srgb, "Shared source material stays unchanged")
	expect(material.metallic == original_material.metallic and material.roughness == original_material.roughness and material.cull_mode == original_material.cull_mode, "Material lighting and sidedness stay unchanged")
	expect(converted.shadow_mesh == original.shadow_mesh, "Shadow mesh remains shared and exact")
	expect(converted.resource_name == original.resource_name and converted.custom_aabb == original.custom_aabb and converted.lightmap_size_hint == original.lightmap_size_hint, "Mesh identity and bounds survive")
	expect(converted.surface_get_name(0) == "Paint surface", "Surface name survives")
	expect(node.get_meta("extras") == {"keep": "authored"}, "Only the consumed palette marker is removed")
	expect(importer.convert_scene(scene, SOURCE).is_empty() and node.mesh == converted, "Repeated conversion is a no-op")
	var packed := PackedScene.new()
	packed.pack(scene)
	var path: String = "res://test-artifacts/vertex-palette-roundtrip.tscn"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-artifacts"))
	expect(ResourceSaver.save(packed, path) == OK, "Converted scene serializes")
	var reloaded: Node3D = (ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	var reloaded_mesh: ArrayMesh = reloaded.get_node("Paint").mesh
	var reloaded_data: Dictionary = RenderingServer.mesh_get_surface(reloaded_mesh.get_rid(), 0)
	expect(reloaded_data.attribute_data == data.attribute_data and reloaded_data.vertex_data == data.vertex_data and reloaded_data.lods == data.lods, "Saved resource preserves converted colors, geometry and LODs")
	expect(reloaded_mesh.shadow_mesh != null and reloaded_mesh.surface_get_material(0).vertex_color_is_srgb, "Saved resource preserves shadows and material flags")
	reloaded.free()
	scene.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	scene = fixture()
	expect(importer.convert_scene(scene, SOURCE).is_empty(), "A fresh import has no stale mesh cache")
	scene.free()


func _check_guards() -> void:
	var importer: GDScript = Importer
	for mode: String in ["source", "unknown", "invalid", "override", "surface_override", "shared_palette"]:
		var scene: Node3D = fixture()
		var node: MeshInstance3D = scene.get_node("Paint")
		var original: Mesh = node.mesh
		if mode == "unknown":
			node.set_meta("extras", {"rigid_vertex_palette": {"1,1,1,255": [0.01, 0.01, 0.01, 1]}})
		elif mode == "invalid":
			node.set_meta("extras", {"rigid_vertex_palette": {"0,1,1,255": [NAN, 0, 0, 1]}})
		elif mode == "override":
			node.material_override = StandardMaterial3D.new()
		elif mode == "surface_override":
			node.set_surface_override_material(0, StandardMaterial3D.new())
		elif mode == "shared_palette":
			var other: MeshInstance3D = node.duplicate()
			other.set_meta("extras", {"rigid_vertex_palette": {"0,1,1,255": [0.001, 0.004, 0.005, 1]}})
			scene.add_child(other)
		var error: String = importer.convert_scene(scene, "res://assets/generated/nathaniel.glb" if mode == "source" else SOURCE)
		expect(error.is_empty() == (mode == "source"), "Guard handles " + mode)
		expect(node.mesh == original and node.get_meta("extras").has("rigid_vertex_palette"), "Guard preserves the scene atomically: " + mode)
		node.material_override = null
		node.set_surface_override_material(0, null)
		scene.free()


func _check_assets() -> void:
	var expected: Dictionary = {"soldier": 15, "gun_soldier": 13, "boss": 22}
	for asset: String in expected:
		var scene: Node = load("res://assets/generated/%s.glb" % asset).instantiate()
		var pending: Array[Node] = [scene]
		var surfaces: int = 0
		while not pending.is_empty():
			var node: Node = pending.pop_back()
			pending.append_array(node.get_children())
			expect(not node.get_meta("extras", {}).has("rigid_vertex_palette"), "Normal import consumes palette metadata: " + asset)
			if node is MeshInstance3D:
				surfaces += node.mesh.get_surface_count()
				for surface: int in node.mesh.get_surface_count():
					if node.mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR:
						var material: StandardMaterial3D = node.get_active_material(surface)
						expect(material.vertex_color_use_as_albedo and material.vertex_color_is_srgb, "Normal imported material uses restored sRGB colors")
		expect(surfaces == expected[asset], "Normal imported surface count: " + asset)
		scene.free()
