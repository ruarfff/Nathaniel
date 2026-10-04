@tool
class_name ActorVisual
extends Resource
## Reusable presentation parameters. Gameplay balance stays in GameSimulation.

@export var texture: Texture2D
@export_range(1, 16) var columns: int = 1
@export_range(1, 16) var rows: int = 1
@export var display_size: Vector2 = Vector2(48, 72)
## Zero uses the legacy display size. Positive values preserve a shared art scale.
@export_range(0, 32) var pixels_per_world_pixel: float = 0.0
## Ground contact within one source frame, measured from its top-left corner.
@export var ground_anchor: Vector2 = Vector2.ZERO
@export var feet_offset: Vector2 = Vector2.ZERO
@export_range(0, 200) var shadow_radius: float = 20.0
@export var tint: Color = Color.WHITE
@export var health_color: Color = Color("92d589")
## An optional live model; its generated scene owns projection and weapon markers.
@export var model_scene: PackedScene
## Optional weapon models attached to the live character's WeaponMount.
@export var weapons: Array[WeaponVisual] = []
@export var default_weapon_id: String = ""
## Optional continuous-beam appearance; absent keeps the existing beam treatment.
@export var laser: LaserVisual
## Contact height above the ground in logical world points (32 points per model unit).
@export_range(0.0, 128.0) var contact_height: float = 24.0
@export_group("Animation")
## Directional clips use logical headings: 0 is +X, then 45-degree steps.
@export var animations: SpriteFrames
@export var moving_texture: Texture2D
@export_range(1, 16) var moving_columns: int = 1
@export_range(0, 15) var idle_row: int = 0
@export_range(0, 15) var moving_row: int = 1
@export_range(0, 30) var animation_fps: float = 4.0


func frame_ground_anchor() -> Vector2:
	return animations.get_meta("ground_anchor", ground_anchor) if animations != null else ground_anchor


func frame_pixel_density() -> float:
	return float(animations.get_meta("pixels_per_world_pixel", pixels_per_world_pixel)) if animations != null else pixels_per_world_pixel
