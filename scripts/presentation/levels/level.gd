@tool
class_name GameLevel
extends Node2D
## Native TileMapLayer cells and marker positions are the runtime source of truth.

@export var definition: LevelDefinition


func _ready() -> void:
	if not Engine.is_editor_hint():
		_run_individual_level.call_deferred()


func data() -> Dictionary:
	var result: Dictionary = {
		"number": definition.number,
		"title": definition.title,
		"survival_map_id": (SurvivalMapCatalog.LEGACY_ID if definition.survival_map_id.is_empty() else definition.survival_map_id) if definition.number == 0 else "",
		"width": definition.width,
		"height": definition.height,
		"tile_size": definition.tile_size,
		"starting_lives": definition.starting_lives,
		"starting_resources": definition.starting_resources,
		"has_boss": definition.has_boss,
		"wave_based": definition.wave_based,
		"next_level": definition.next_level,
		"blocked": [],
		"player_start": Vector2(128, 128),
		"hermes_start": Vector2(192, 128),
		"enemies": [],
		"towers": [],
		"weapon_pickups": [],
		"entry_sectors": [],
	}
	var collision: TileMapLayer = get_node_or_null("Collision") as TileMapLayer
	if collision != null:
		result["blocked"] = collision.get_used_cells()
	var spawns: Node = get_node_or_null("Spawns")
	if spawns == null:
		return result
	for node: Node in spawns.get_children():
		if not node is SpawnMarker:
			continue
		var marker: SpawnMarker = node as SpawnMarker
		var projected_point: Vector2 = marker.position
		if spawns is Node2D:
			projected_point = (spawns as Node2D).transform * projected_point
		var point: Vector2 = IsoProjection.unproject(projected_point)
		if marker.kind == "enemyEntry":
			var sector: Dictionary = {}
			for existing: Dictionary in result.entry_sectors:
				if existing.id == marker.label:
					sector = existing
					break
			if sector.is_empty():
				sector = {"id": marker.label, "enabled": false, "positions": []}
				result.entry_sectors.append(sector)
			if marker.enabled:
				sector.enabled = true
				sector.positions.append(point)
			continue
		if not marker.enabled:
			continue
		if marker.kind == "nathaniel":
			result["player_start"] = point
		elif marker.kind == "hermes":
			result["hermes_start"] = point
		elif marker.kind == "weaponPickup":
			result["weapon_pickups"].append({"weapon_id": marker.weapon_id, "position": point})
		elif marker.kind in GameBalance.ENEMIES or marker.kind in GameBalance.TOWERS:
			var encounter: Dictionary = {"kind": marker.kind, "position": point}
			if marker.parameters != null:
				encounter.merge(marker.parameters.data())
			var collection: String = "towers" if marker.kind.ends_with("Tower") else "enemies"
			result[collection].append(encounter)
	return result


func _run_individual_level() -> void:
	if not is_inside_tree():
		return
	if get_tree().current_scene != self:
		return
	var main_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var app: Node = main_scene.instantiate()
	get_tree().root.add_child(app)
	get_tree().current_scene = app
	app.call_deferred("start_level_scene", self)
