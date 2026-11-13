extends CanvasLayer
## Basic survival HUD (Phase 1): status bars, compass + clock, notification text, empty hotbar, FPS.
## Hunger/thirst/health are shown but not yet changing - the survival system comes in Phase 3.

const DIRECTIONS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

var _player
var _rig
var _bars: Dictionary = {}
var _clock_label: Label
var _msg_label: Label
var _fps_label: Label
var _msg_tween: Tween
var _clock_minutes := 6.0 * 60.0
var _day := 1


func _ready() -> void:
	layer = 5
	_build_status_bars()
	_build_clock()
	_build_message()
	_build_hotbar()
	_ignore_mouse(self)


func bind(player, rig) -> void:
	_player = player
	_rig = rig


func show_message(text: String) -> void:
	_msg_label.text = text
	_msg_label.modulate.a = 1.0
	if _msg_tween and _msg_tween.is_valid():
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_interval(1.6)
	_msg_tween.tween_property(_msg_label, "modulate:a", 0.0, 0.6)


func on_menu_pressed(id: String) -> void:
	show_message("%s - coming in a later phase" % id.capitalize())


func _process(delta: float) -> void:
	_clock_minutes += delta * 2.0
	if _clock_minutes >= 1440.0:
		_clock_minutes -= 1440.0
		_day += 1

	var heading := ""
	if _rig:
		var deg := fposmod(-rad_to_deg(_rig.yaw), 360.0)
		heading = DIRECTIONS[int(round(deg / 45.0)) % 8]
	var hh := int(_clock_minutes / 60.0)
	var mm := int(_clock_minutes) % 60
	_clock_label.text = "%s    Day %d   %02d:%02d" % [heading, _day, hh, mm]

	if _player:
		_set_bar("health", _player.health)
		_set_bar("hunger", _player.hunger)
		_set_bar("thirst", _player.thirst)
		_set_bar("stamina", _player.stamina)

	_fps_label.text = "FPS %d" % Engine.get_frames_per_second()


func _set_bar(key: String, value: float) -> void:
	var bar := _bars[key] as ProgressBar
	bar.value = value


# ---------- builders ----------

func _build_status_bars() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	_add_bar(box, "health", "HEALTH", Color(0.85, 0.2, 0.2))
	_add_bar(box, "hunger", "HUNGER", Color(0.9, 0.55, 0.15))
	_add_bar(box, "thirst", "THIRST", Color(0.25, 0.55, 0.9))
	_add_bar(box, "stamina", "STAMINA", Color(0.4, 0.8, 0.3))

	_fps_label = Label.new()
	_fps_label.add_theme_font_size_override("font_size", 14)
	box.add_child(_fps_label)


func _add_bar(parent: Control, key: String, title: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(80.0, 0.0)
	label.add_theme_font_size_override("font_size", 14)
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(190.0, 16.0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false

	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(6)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	back.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	row.add_child(bar)

	_bars[key] = bar


func _build_clock() -> void:
	_clock_label = Label.new()
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.custom_minimum_size = Vector2(320.0, 0.0)
	_clock_label.add_theme_font_size_override("font_size", 20)
	_clock_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_clock_label.add_theme_constant_override("outline_size", 5)
	_clock_label.text = "N    Day 1   06:00"
	add_child(_clock_label)
	_clock_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	_clock_label.offset_top += 10.0
	_clock_label.offset_bottom += 10.0


func _build_message() -> void:
	_msg_label = Label.new()
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.custom_minimum_size = Vector2(420.0, 0.0)
	_msg_label.add_theme_font_size_override("font_size", 24)
	_msg_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_msg_label.add_theme_constant_override("outline_size", 8)
	_msg_label.modulate.a = 0.0
	add_child(_msg_label)
	_msg_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	_msg_label.offset_top += 48.0
	_msg_label.offset_bottom += 48.0


func _build_hotbar() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for i in 5:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(56.0, 56.0)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.0, 0.0, 0.0, 0.4)
		style.border_color = Color(1.0, 1.0, 1.0, 0.5)
		style.set_border_width_all(2)
		style.set_corner_radius_all(10)
		slot.add_theme_stylebox_override("panel", style)
		row.add_child(slot)
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	row.offset_top -= 16.0
	row.offset_bottom -= 16.0


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
