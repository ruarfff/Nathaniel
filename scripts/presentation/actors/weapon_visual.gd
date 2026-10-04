@tool
class_name WeaponVisual
extends Resource
## A modular weapon's appearance and recoil. Combat values remain in the domain.

@export var weapon_id: String = ""
@export var model_scene: PackedScene
@export_range(0.0, 0.2) var recoil_distance: float = 0.025
@export_range(0.025, 0.5) var recoil_duration: float = 0.12
