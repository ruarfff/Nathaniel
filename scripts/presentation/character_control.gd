class_name CharacterControl
extends Button
## One hit target owns the friendly portrait and its visibility-filtered target.

const INK := Color("102b33")
const OCHRE := Color("e6ad50")
const PAPER := Color("f0e8d6")

var character := "nathaniel"
var target_texture: Texture2D
var target_name := "No target"
var target_color := OCHRE
var status := ""
var health := 1.0
var offscreen_direction := Vector2.ZERO
var _portrait: Texture2D
static var _textures: Dictionary = {}


func _ready() -> void:
	character = name.to_lower()
	custom_minimum_size = Vector2(224, 116)
	focus_mode = Control.FOCUS_NONE
	toggle_mode = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_portrait = portrait(character)


static func portrait(kind: String) -> Texture2D:
	if _textures.has(kind):
		return _textures[kind]
	var resource_name: String = {"gunSoldier": "gun_soldier", "gunTower": "gun_tower", "laserTower": "laser_tower", "healTower": "heal_tower"}.get(kind, kind)
	var path := "res://resources/actors/%s.tres" % resource_name
	if not ResourceLoader.exists(path):
		return null
	var visual := load(path) as ActorVisual
	var texture: Texture2D = visual.texture
	if visual.animations != null:
		texture = visual.animations.get_frame_texture(&"idle_0", 0)
	if texture != null:
		var crop := AtlasTexture.new()
		if texture is AtlasTexture:
			crop.atlas = texture.atlas
			crop.region = texture.region
		else:
			crop.atlas = texture
			var pixels := texture.get_image()
			crop.region = Rect2(pixels.get_used_rect()) if pixels != null else Rect2(Vector2.ZERO, texture.get_size())
		if kind in ["nathaniel", "hermes"]:
			crop.region.position.x += crop.region.size.x * 0.18
			crop.region.size *= Vector2(0.64, 0.48)
		crop.filter_clip = true
		texture = crop
	_textures[kind] = texture
	return texture


func update_unit(sim: GameSimulation, unit: Dictionary, fog_enabled: bool, active: bool) -> void:
	health = clampf(float(unit.get("hp", 0)) / maxf(1, unit.get("max_hp", 1)), 0, 1)
	set_pressed_no_signal(active)
	status = "Cargo %d/%d" % [sim.carried_resource_count(), sim.nathaniel.get("resource_capacity", 1)] if character == "nathaniel" else ("Mobile" if sim.hermes_mode == "following" else "Deployed")
	if not CombatRules.alive(unit):
		status = "Down"
	var target := sim.entity(int(unit.get("target_id", -1))) if CombatRules.alive(unit) else {}
	target_texture = null
	target_name = "No target"
	if CombatRules.alive(target):
		if fog_enabled and sim.visibility_at(target.position) < 2:
			target_name = "Out of sight"
		else:
			target_name = {"gunSoldier": "Gunner", "healTower": "Heal", "laserTower": "Laser", "gunTower": "Gun"}.get(target.kind, String(target.kind).capitalize())
			target_texture = portrait(target.kind)
	var action_hint := "Focus Hermes and open Build" if character == "hermes" else "Return to Nathaniel"
	tooltip_text = "%s · %d / %d HP\n%s\nTarget: %s\n%s" % [character.capitalize(), unit.get("hp", 0), unit.get("max_hp", 0), status, target_name, action_hint]
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var left := 86.0
	if _portrait != null:
		draw_texture_rect(_portrait, Rect2(8, 9, 70, size.y - 18), false)
	draw_string(font, Vector2(left, 23), character.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, PAPER)
	var bar := Rect2(left, 33, size.x - left - 14, 7)
	draw_rect(bar, Color("071b22"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * health, bar.size.y)), Color("8bc779"))
	draw_string(font, Vector2(left, 60), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, PAPER)
	var cross := Vector2(left + 8, 88)
	var color := target_color if target_texture != null else PAPER
	draw_arc(cross, 7, 0, TAU, 24, color, 1.5, true)
	draw_line(cross - Vector2(11, 0), cross + Vector2(11, 0), color, 1.5, true)
	draw_line(cross - Vector2(0, 11), cross + Vector2(0, 11), color, 1.5, true)
	var label_x := left + 25
	if target_texture != null:
		draw_texture_rect(target_texture, Rect2(label_x, 70, 34, 34), false)
		label_x += 37
	draw_string(font, Vector2(label_x, 93), target_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PAPER)
	if offscreen_direction != Vector2.ZERO:
		var tip := Vector2(size.x - 14, 14)
		var direction := offscreen_direction.normalized()
		var tail := tip - direction * 14
		draw_line(tail, tip, OCHRE, 3, true)
		draw_line(tip, tip - direction.rotated(0.65) * 8, OCHRE, 3, true)
		draw_line(tip, tip - direction.rotated(-0.65) * 8, OCHRE, 3, true)
