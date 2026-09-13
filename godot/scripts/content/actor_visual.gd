@tool
class_name ActorVisual
extends Resource
## Reusable presentation parameters. Gameplay balance stays in GameSimulation.

@export var texture: Texture2D
@export_range(1, 16) var columns: int = 1
@export_range(1, 16) var rows: int = 1
@export var display_size: Vector2 = Vector2(48, 72)
## The bottom center of each sprite sits on its logical world position.
@export var feet_offset: Vector2 = Vector2.ZERO
@export_range(0, 200) var shadow_radius: float = 20.0
@export var tint: Color = Color.WHITE
@export var health_color: Color = Color("92d589")
@export_group("Animation")
@export var moving_texture: Texture2D
@export_range(1, 16) var moving_columns: int = 1
@export_range(0, 15) var idle_row: int = 0
@export_range(0, 15) var moving_row: int = 1
@export_range(0, 30) var animation_fps: float = 4.0
