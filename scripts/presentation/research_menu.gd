class_name ResearchMenu
extends Control
## Native paused upgrade surface. Only the simulation can accept a purchase.

signal purchase_requested(request: Dictionary)
signal resume_requested

const IVORY := Color("f0e8d6")
const OCHRE := Color("e6ad50")
const PETROL := Color("102b33")
const MUTED := Color("b6cbd0")

var state: Dictionary = {}
var category := "Nathaniel"
var selected_track := "capacity"
var narrow_detail := false
var narrow := false
var purchase_button: Button
var resume_button: Button
var back_button: Button
var category_buttons: Dictionary = {}
var track_buttons: Dictionary = {}
var _panel: PanelContainer
var _header: HBoxContainer
var _title: Label
var _balance: Label
var _categories: HBoxContainer
var _body: HBoxContainer
var _list_scroll: ScrollContainer
var _list: VBoxContainer
var _details: VBoxContainer
var _detail_scroll: ScrollContainer
var _detail_text: VBoxContainer
var _name: Label
var _rank: Label
var _effect: Label
var _description: Label
var _reason: Label
var _feedback: Label
var _armed_purchase: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = _theme()
	var dim := ColorRect.new()
	dim.color = Color(0.018, 0.032, 0.035, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_panel = PanelContainer.new()
	add_child(_panel)
	_panel.minimum_size_changed.connect(func() -> void: _layout.call_deferred())
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	_panel.add_child(rows)
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 16)
	rows.add_child(_header)
	_title = _label("RESEARCH", _header, 28)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label("PAUSED", _header, 18)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists("res://resources/actors/tech_icon.tres"):
		icon.texture = load("res://resources/actors/tech_icon.tres")
	_header.add_child(icon)
	_balance = _label("Tech 0", _header, 20)
	resume_button = _button("Resume", _header)
	_primary(resume_button)
	resume_button.custom_minimum_size.x = 116
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	_categories = HBoxContainer.new()
	_categories.add_theme_constant_override("separation", 10)
	rows.add_child(_categories)
	for name: String in ["Nathaniel", "Hermes", "Defenses"]:
		var button := _button(name, _categories)
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: select_category(name))
		category_buttons[name] = button
	_body = HBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 24)
	rows.add_child(_body)
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.size_flags_stretch_ratio = 0.92
	_body.add_child(_list_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	_list_scroll.add_child(_list)
	_details = VBoxContainer.new()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_constant_override("separation", 8)
	_body.add_child(_details)
	var detail_heading := HBoxContainer.new()
	detail_heading.add_theme_constant_override("separation", 16)
	_details.add_child(detail_heading)
	back_button = _button("Back", detail_heading)
	back_button.custom_minimum_size.x = 90
	back_button.pressed.connect(back)
	_name = _label("", detail_heading, 28)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.add_child(_detail_scroll)
	_detail_text = VBoxContainer.new()
	_detail_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_text.add_theme_constant_override("separation", 18)
	_detail_scroll.add_child(_detail_text)
	_rank = _label("", _detail_text, 18)
	_effect = _label("", _detail_text, 26)
	_description = _label("", _detail_text, 18)
	_description.add_theme_color_override("font_color", MUTED)
	_feedback = _label("", _details, 18)
	_feedback.add_theme_color_override("font_color", OCHRE)
	_feedback.hide()
	purchase_button = _button("Research", _details)
	_primary(purchase_button)
	purchase_button.custom_minimum_size.y = 56
	purchase_button.button_down.connect(_arm_purchase)
	purchase_button.pressed.connect(_purchase)
	_reason = _label("", _details, 16)
	_reason.add_theme_color_override("font_color", MUTED)
	get_parent().resized.connect(func() -> void: _layout.call_deferred())
	get_viewport().size_changed.connect(func() -> void: _layout.call_deferred())
	_layout()
	hide()


func open(research_state: Dictionary) -> void:
	category = "Nathaniel"
	selected_track = "capacity"
	narrow_detail = false
	_feedback.text = ""
	_feedback.hide()
	show()
	update_state(research_state)
	_layout()
	resume_button.grab_focus()


func update_state(research_state: Dictionary) -> void:
	if state == research_state:
		return
	state = research_state.duplicate(true)
	_balance.text = "Tech %d" % int(state.get("tech", 0))
	_refresh_tracks()
	_refresh_detail()


func select_category(value: String) -> void:
	category = value
	narrow_detail = false
	for track: Dictionary in state.get("tracks", []):
		if track.category == category:
			selected_track = track.id
			break
	_feedback.text = ""
	_feedback.hide()
	_refresh_tracks()
	_refresh_detail()
	_layout()


func select_track(id: String) -> void:
	selected_track = id
	narrow_detail = true
	_feedback.text = ""
	_feedback.hide()
	_refresh_detail()
	_refresh_tracks()
	_layout()
	if narrow:
		back_button.grab_focus()


func back() -> bool:
	if narrow and narrow_detail:
		narrow_detail = false
		_layout()
		if track_buttons.has(selected_track):
			track_buttons[selected_track].grab_focus()
		return true
	return false


func acknowledge(accepted: bool) -> void:
	_feedback.text = "Researched" if accepted else "Research changed. Check the current rank and Tech."
	_feedback.show()


func cancel_purchase_input() -> void:
	_armed_purchase.clear()


func _selected() -> Dictionary:
	for track: Dictionary in state.get("tracks", []):
		if track.id == selected_track:
			return track
	return {}


func _refresh_tracks() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	track_buttons.clear()
	for name: String in category_buttons:
		category_buttons[name].set_pressed_no_signal(name == category)
	for track: Dictionary in state.get("tracks", []):
		if track.category != category:
			continue
		var cost := "%d Tech" % int(track.cost) if int(track.rank) < int(track.max_rank) else "Fully researched"
		var button := _button("%s\nRank %d / %d  ·  %s" % [track.name, track.rank, track.max_rank, cost], _list)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 104
		button.toggle_mode = true
		button.set_pressed_no_signal(track.id == selected_track)
		button.pressed.connect(select_track.bind(String(track.id)))
		track_buttons[track.id] = button


func _refresh_detail() -> void:
	var track := _selected()
	_armed_purchase.clear()
	if track.is_empty():
		purchase_button.disabled = true
		_reason.text = "Select an upgrade."
		return
	_name.text = track.name
	_rank.text = "Rank %d of %d" % [track.rank, track.max_rank]
	var complete: bool = int(track.rank) >= int(track.max_rank)
	_effect.text = _effect_text(track, complete)
	_description.text = {
		"capacity": "Backpack cargo clamps. Carry more matter bodies in one trip. Tech uses a separate cassette.",
		"reach": "Longer reach for the matter arms and the short tech collector. Tech needs clear ground between Nathaniel and the drop.",
		"cooling": "Faster cooldown for Hermes's mobile shoulder laser. His deployed cannon keeps its normal cooldown.",
		"plating": "More maximum health for gun, laser, and heal towers. Existing damage keeps the same health fraction."
	}.get(selected_track, "")
	purchase_button.text = "Fully researched" if complete else "Research · %d Tech" % int(track.cost)
	purchase_button.disabled = not bool(track.get("available", false))
	_reason.text = str(track.get("reason", "")) if purchase_button.disabled else "Applies immediately · lasts for this run"
	if complete:
		_reason.text = "Maximum rank reached."


func _effect_text(track: Dictionary, complete: bool) -> String:
	var current := float(track.current)
	var next := float(track.next)
	match String(track.id):
		"capacity":
			return "Carry %d bodies" % int(current) if complete else "Carry %d %s to %d bodies" % [int(current), "body" if int(current) == 1 else "bodies", int(next)]
		"reach":
			return "Reach %d world units" % int(current) if complete else "Reach %d to %d world units" % [int(current), int(next)]
		"cooling":
			return "Mobile cooldown: %d%% of base" % roundi(current * 100) if complete else "Mobile cooldown: %d%% to %d%% of base" % [roundi(current * 100), roundi(next * 100)]
		"plating":
			return "Tower health: %d%% of base" % roundi(current * 100) if complete else "Tower health: %d%% to %d%% of base" % [roundi(current * 100), roundi(next * 100)]
	return ""


func _arm_purchase() -> void:
	var track := _selected()
	if not purchase_button.disabled and not track.is_empty():
		_armed_purchase = {"track": selected_track, "expected_rank": int(track.rank), "session_id": int(state.get("session_id", 0))}


func _purchase() -> void:
	if _armed_purchase.is_empty():
		return
	var request := _armed_purchase.duplicate()
	_armed_purchase.clear()
	purchase_requested.emit(request)


func _layout() -> void:
	if _panel == null:
		return
	var owner_ui := get_parent() as GameUI
	# The world keeps its virtual resolution. Research uses display UI points,
	# so stretching a 1280px world into a phone cannot shrink its touch targets.
	var output := get_viewport().get_final_transform() * owner_ui.get_global_transform_with_canvas()
	var density := 1.0
	if get_viewport() is Window and DisplayServer.get_name() != "headless":
		density = maxf(1.0, DisplayServer.screen_get_scale())
	var pixels_per_unit := Vector2(maxf(0.001, output.x.length()), maxf(0.001, output.y.length())) / density
	scale = Vector2.ONE / pixels_per_unit
	size = owner_ui.size * pixels_per_unit
	var source_safe := owner_ui.safe_rect().grow(16)
	var safe := Rect2(source_safe.position * pixels_per_unit, source_safe.size * pixels_per_unit).grow(-16)
	var desired := Vector2(minf(1100, safe.size.x), minf(600, safe.size.y))
	_panel.position = safe.get_center() - desired / 2
	_panel.size = desired
	narrow = safe.size.x < 1000
	_header.add_theme_constant_override("separation", 10 if narrow else 16)
	_title.add_theme_font_size_override("font_size", 22 if narrow else 28)
	back_button.visible = narrow and narrow_detail
	_categories.visible = not (narrow and narrow_detail)
	_list_scroll.visible = not narrow or not narrow_detail
	_details.visible = not narrow or narrow_detail
	_name.add_theme_font_size_override("font_size", 23 if narrow else 28)
	_effect.add_theme_font_size_override("font_size", 22 if narrow else 26)
	for button: Button in track_buttons.values():
		button.custom_minimum_size.y = 84 if narrow else 104


func _button(text: String, parent: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(64, 48)
	parent.add_child(button)
	return button


func _primary(button: Button) -> void:
	var face := StyleBoxFlat.new()
	face.bg_color = OCHRE
	face.border_color = IVORY
	face.set_border_width_all(1)
	face.set_content_margin_all(12)
	button.add_theme_stylebox_override("normal", face)
	var hover := face.duplicate() as StyleBoxFlat
	hover.bg_color = Color("f4c778")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(key, Color("102126"))


func _label(text: String, parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", IVORY)
	parent.add_child(label)
	if parent == _detail_text or parent == _details:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 20
	var panel := StyleBoxFlat.new()
	panel.bg_color = PETROL
	panel.border_color = Color("507781")
	panel.set_border_width_all(2)
	panel.set_content_margin_all(16)
	result.set_stylebox("panel", "PanelContainer", panel)
	var normal := panel.duplicate() as StyleBoxFlat
	normal.set_content_margin_all(12)
	normal.bg_color = Color("173b45")
	result.set_stylebox("normal", "Button", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("254d58")
	result.set_stylebox("hover", "Button", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.border_color = OCHRE
	pressed.bg_color = Color("20424a")
	result.set_stylebox("pressed", "Button", pressed)
	result.set_stylebox("hover_pressed", "Button", pressed)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = IVORY
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(3)
	result.set_stylebox("focus", "Button", focus)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("25383d")
	disabled.border_color = Color("50666b")
	result.set_stylebox("disabled", "Button", disabled)
	result.set_color("font_color", "Button", IVORY)
	result.set_color("font_hover_color", "Button", IVORY)
	result.set_color("font_pressed_color", "Button", IVORY)
	result.set_color("font_disabled_color", "Button", MUTED)
	return result
