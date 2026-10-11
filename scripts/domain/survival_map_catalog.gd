class_name SurvivalMapCatalog
extends RefCounted
## Stable save identities. Scene loading belongs to the presentation adapter.

const LEGACY_ID := "legacy_survival"
const NEW_RUN_IDS: Array[String] = ["abandoned_crossroads", "dry_wash", "freight_yard", "open_countryside"]
const MAPS := {
	"abandoned_crossroads": {"title": "Abandoned Crossroads", "path": "res://levels/survival/abandoned_crossroads.tscn"},
	"dry_wash": {"title": "Dry Wash", "path": "res://levels/survival/dry_wash.tscn"},
	"freight_yard": {"title": "Freight Yard", "path": "res://levels/survival/freight_yard.tscn"},
	"open_countryside": {"title": "Open Countryside", "path": "res://levels/survival/open_countryside.tscn"},
	"legacy_survival": {"title": "Original Survival", "path": "res://levels/level_0.tscn"},
}


static func contains(map_id: String) -> bool:
	return MAPS.has(map_id)


static func scene_path(map_id: String) -> String:
	return MAPS.get(map_id, {}).get("path", "")


static func title(map_id: String) -> String:
	return MAPS.get(map_id, {}).get("title", "")


static func choose(rng: RandomNumberGenerator) -> String:
	return NEW_RUN_IDS[rng.randi_range(0, NEW_RUN_IDS.size() - 1)]
