@tool
class_name LevelDefinition
extends Resource
## Gameplay dimensions stay in the original 32-point logical grid.

@export_range(0, 99) var number: int = 1
@export var title: String = "Campaign 1"
@export_group("Logical map")
@export_range(1, 512) var width: int = 30
@export_range(1, 512) var height: int = 30
@export_range(1, 256) var tile_size: int = 32
@export_group("Encounter")
## Spare lives after the current life. Zero allows one life.
@export_range(0, 99) var starting_lives: int = 3
@export_range(0, 99999) var starting_resources: int = 30
@export var has_boss: bool = true
@export var wave_based: bool = false
## -1 ends campaign progression; zero denotes survival.
@export_range(-1, 99) var next_level: int = -1
