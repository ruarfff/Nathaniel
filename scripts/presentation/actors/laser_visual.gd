@tool
class_name LaserVisual
extends Resource
## Appearance of a continuous beam. Combat timing and damage stay in the domain.

@export var edge_color := Color("e6ac4f")
@export var core_color := Color("fff4cd")
@export_range(0.1, 8.0) var edge_width: float = 2.6
@export_range(0.1, 8.0) var core_width: float = 0.9
@export_range(0.1, 8.0) var contact_radius: float = 2.4
@export_range(0.1, 16.0) var spark_length: float = 6.0
@export_range(0.01, 1.0) var spark_duration: float = 0.12
@export_range(0.1, 2.0) var spark_interval: float = 0.32
@export_range(0.01, 0.5) var muzzle_flash_duration: float = 0.09
