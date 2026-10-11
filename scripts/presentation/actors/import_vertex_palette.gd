@tool
extends EditorScenePostImport
## Restore the authored paint palette before Godot packs sRGB vertex colors.

const PALETTE_KEY: String = "rigid_vertex_palette"
const SOURCES: Array[String] = ["res://assets/generated/soldier.glb", "res://assets/generated/gun_soldier.glb", "res://assets/generated/boss.glb"]


func _post_import(scene: Node) -> Object:
	var error: String = convert_scene(scene, get_source_file())
	if not error.is_empty():
		push_error(error)
		return null
	return scene


static func convert_scene(scene: Node, source: String) -> String:
	if not SOURCES.has(source):
		return ""
	var pending: Array[Node] = [scene]
	var plans: Array[Dictionary] = []
	var palettes: Dictionary = {}
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		var extras: Dictionary = node.get_meta("extras", {})
		if not extras.has(PALETTE_KEY):
			continue
		if not node is MeshInstance3D or not node.mesh is ArrayMesh or node.skin != null or node.mesh.get_blend_shape_count() != 0:
			return "Vertex palette import requires an unskinned ArrayMesh without morphs."
		var palette: Variant = extras[PALETTE_KEY]
		if not palette is Dictionary or palette.is_empty():
			return "Vertex palette metadata is missing its colors."
		var mesh: ArrayMesh = node.mesh
		if node.material_override != null:
			return "Vertex palette import does not support material overrides."
		if palettes.has(mesh) and palettes[mesh] != palette:
			return "Shared vertex palette meshes have different palettes."
		palettes[mesh] = palette
		var colors: Dictionary = {}
		for key: Variant in palette:
			var value: Variant = palette[key]
			if not key is String or not value is Array or value.size() != 4:
				return "Vertex palette metadata has an invalid color."
			for component: Variant in value:
				if not (component is float or component is int) or not is_finite(float(component)) or component < 0.0 or component > 1.0:
					return "Vertex palette metadata has an invalid channel."
			if value[3] != 1.0:
				return "Vertex palette metadata must be opaque."
			var linear := Color(value[0], value[1], value[2], value[3])
			var srgb: Color = linear.linear_to_srgb()
			colors[key] = PackedByteArray([int(srgb.r * 255), int(srgb.g * 255), int(srgb.b * 255), 255])
		var surfaces: Array[Dictionary] = []
		for surface: int in mesh.get_surface_count():
			if node.get_surface_override_material(surface) != null:
				return "Vertex palette import does not support surface overrides."
			var format: int = mesh.surface_get_format(surface)
			if not format & Mesh.ARRAY_FORMAT_COLOR:
				continue
			var material: StandardMaterial3D = mesh.surface_get_material(surface) as StandardMaterial3D
			if material == null or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or material.emission_enabled or material.albedo_color != Color.WHITE:
				return "Vertex palette import requires opaque, non-emissive white paint."
			for texture: int in BaseMaterial3D.TEXTURE_MAX:
				if material.get_texture(texture) != null:
					return "Vertex palette import does not support textured paint."
			if format & (Mesh.ARRAY_FORMAT_BONES | Mesh.ARRAY_FORMAT_WEIGHTS):
				return "Vertex palette import does not support skinned attributes."
			var data: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), surface)
			var attributes: PackedByteArray = data.attribute_data.duplicate()
			var count: int = data.vertex_count
			var stride: int = RenderingServer.mesh_surface_get_format_attribute_stride(format, count)
			var offset: int = RenderingServer.mesh_surface_get_format_offset(format, count, Mesh.ARRAY_COLOR)
			for vertex: int in count:
				var start: int = offset + vertex * stride
				var key: String = "%d,%d,%d,%d" % [attributes[start], attributes[start + 1], attributes[start + 2], attributes[start + 3]]
				if not colors.has(key):
					return "Vertex palette import found an unknown packed color: " + key
				var replacement: PackedByteArray = colors[key]
				for channel: int in 4:
					attributes[start + channel] = replacement[channel]
			surfaces.append({"surface": surface, "attributes": attributes, "material": material})
		if surfaces.is_empty():
			return "Vertex palette metadata has no colored surfaces."
		plans.append({"node": node, "mesh": mesh, "surfaces": surfaces, "extras": extras})
	# Validate every marked mesh before changing the imported scene.
	var meshes: Dictionary = {}
	var materials: Dictionary = {}
	for plan: Dictionary in plans:
		if not meshes.has(plan.mesh):
			var rebuilt: ArrayMesh = plan.mesh.duplicate()
			var surface_data: Array = rebuilt.get("_surfaces")
			for entry: Dictionary in plan.surfaces:
				if not materials.has(entry.material):
					var paint: StandardMaterial3D = entry.material.duplicate()
					paint.vertex_color_use_as_albedo = true
					paint.vertex_color_is_srgb = true
					materials[entry.material] = paint
				# Use the saved surface data: GPU buffer updates are ignored in headless imports.
				surface_data[entry.surface].attribute_data = entry.attributes
				surface_data[entry.surface].material = materials[entry.material]
			rebuilt.set("_surfaces", surface_data)
			meshes[plan.mesh] = rebuilt
		plan.node.mesh = meshes[plan.mesh]
		var extras: Dictionary = plan.extras.duplicate()
		extras.erase(PALETTE_KEY)
		if extras.is_empty():
			plan.node.remove_meta("extras")
		else:
			plan.node.set_meta("extras", extras)
	return ""
