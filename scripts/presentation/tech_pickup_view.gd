class_name TechPickupView
extends Node2D
## Uses one bounded sprite for each stack, regardless of its saved quantity.

const MODULE: Texture2D = preload("res://assets/generated/tech_module.png")
const CORE: Texture2D = preload("res://assets/generated/tech_core.png")

var _sprite: Sprite2D
var _quantity: Label
var _amount: int = -1


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.offset = Vector2(-512, -768)
	_sprite.scale = Vector2.ONE / 8.0
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)
	_quantity = Label.new()
	_quantity.position = Vector2(-24, 1)
	_quantity.size = Vector2(48, 18)
	_quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quantity.add_theme_font_size_override("font_size", 12)
	_quantity.add_theme_color_override("font_color", Color("d6fff6"))
	_quantity.add_theme_color_override("font_outline_color", Color("172125"))
	_quantity.add_theme_constant_override("outline_size", 4)
	add_child(_quantity)


func apply_state(pickup: Dictionary, _playback_enabled: bool = true) -> void:
	position = IsoProjection.project(Vector2(pickup.get("position", Vector2.ZERO)))
	visible = str(pickup.get("phase", "loose")) != "deferred"
	if _sprite == null:
		return
	_sprite.texture = CORE if pickup.get("kind", "module") == "core" else MODULE
	var amount: int = int(pickup.get("amount", 1))
	if amount != _amount:
		_amount = amount
		_quantity.text = str(amount)
		_quantity.visible = amount > 1
	# The attachment takes the intact module after its clamp reaches the ground.
	_sprite.visible = str(pickup.get("phase", "loose")) != "collect" or float(pickup.get("phase_elapsed", 0.0)) < GameBalance.TECH_COLLECTION_SECONDS * 0.4
	_quantity.visible = amount > 1 and _sprite.visible
