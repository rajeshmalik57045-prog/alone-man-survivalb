extends Control
## Touch controls (survival-game style):
##  - Left half: floating joystick (push beyond the ring = sprint)
##  - Right half (empty area): drag to rotate the camera
##  - Buttons: USE (context action), JUMP, CROUCH (toggle), and menu icons INV/CRAFT/MAP/PAUSE
## Joystick and camera drag use separate finger indexes, so they work at the same time.

signal move_changed(vector: Vector2, sprint: bool)
signal look_delta(delta: Vector2)
signal jump_pressed
signal use_pressed
signal crouch_toggled(on: bool)
signal menu_pressed(id: String)

@export var button_opacity := 0.55:
	set(value):
		button_opacity = clampf(value, 0.15, 1.0)
		queue_redraw()
@export var button_scale := 1.0:
	set(value):
		button_scale = clampf(value, 0.6, 1.6)
		if is_inside_tree():
			_layout()
			queue_redraw()
@export var joystick_radius := 90.0
@export var look_multiplier := 1.0

var _buttons: Array[Dictionary] = []
var _idle_joy_center := Vector2(170.0, 570.0)
var _joy_finger := -1
var _look_finger := -1
var _joy_origin := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _joy_vec := Vector2.ZERO
var _sprinting := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_add_button("use", "USE")
	_add_button("jump", "JUMP")
	_add_button("crouch", "CROUCH")
	_add_button("inventory", "INV")
	_add_button("crafting", "CRAFT")
	_add_button("map", "MAP")
	_add_button("pause", "II")

	_layout()
	get_viewport().size_changed.connect(_on_viewport_resized)


func _add_button(id: String, label: String) -> void:
	_buttons.append({
		"id": id,
		"label": label,
		"pos": Vector2.ZERO,
		"r": 40.0,
		"finger": -1,
		"on": false,
	})


func _on_viewport_resized() -> void:
	_layout()
	queue_redraw()


func _layout() -> void:
	var vs := get_viewport_rect().size
	var s := button_scale
	_idle_joy_center = Vector2(170.0, vs.y - 150.0)
	var menu_index := 0
	for b in _buttons:
		match b["id"]:
			"use":
				b["pos"] = Vector2(vs.x - 150.0 * s, vs.y - 130.0 * s)
				b["r"] = 62.0 * s
			"jump":
				b["pos"] = Vector2(vs.x - 70.0 * s, vs.y - 260.0 * s)
				b["r"] = 44.0 * s
			"crouch":
				b["pos"] = Vector2(vs.x - 290.0 * s, vs.y - 70.0 * s)
				b["r"] = 36.0 * s
			_:
				b["pos"] = Vector2(vs.x - 44.0, 200.0 + 62.0 * float(menu_index))
				b["r"] = 26.0
				menu_index += 1


# ---------- input ----------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_on_press(touch.index, touch.position)
		else:
			_on_release(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_on_drag(drag.index, drag.position, drag.relative)


func _on_press(index: int, pos: Vector2) -> void:
	for b in _buttons:
		if b["finger"] == -1 and pos.distance_to(b["pos"]) <= float(b["r"]) * 1.15:
			b["finger"] = index
			_press_button(b)
			queue_redraw()
			return

	var vs := get_viewport_rect().size
	if pos.x < vs.x * 0.45:
		if _joy_finger == -1:
			_joy_finger = index
			_joy_origin = pos
			_joy_pos = pos
			_update_joystick()
	elif _look_finger == -1:
		_look_finger = index
	queue_redraw()


func _on_release(index: int) -> void:
	for b in _buttons:
		if b["finger"] == index:
			b["finger"] = -1
	if index == _joy_finger:
		_joy_finger = -1
		_joy_vec = Vector2.ZERO
		_sprinting = false
		move_changed.emit(Vector2.ZERO, false)
	if index == _look_finger:
		_look_finger = -1
	queue_redraw()


func _on_drag(index: int, pos: Vector2, relative: Vector2) -> void:
	if index == _joy_finger:
		_joy_pos = pos
		_update_joystick()
		queue_redraw()
	elif index == _look_finger:
		look_delta.emit(relative * look_multiplier)


func _update_joystick() -> void:
	var offset := _joy_pos - _joy_origin
	var v := offset / joystick_radius
	if v.length() > 1.0:
		v = v.normalized()
	if v.length() < 0.12:
		v = Vector2.ZERO
	_joy_vec = v
	_sprinting = offset.length() > joystick_radius * 1.3
	move_changed.emit(v, _sprinting)


func _press_button(b: Dictionary) -> void:
	match b["id"]:
		"jump":
			jump_pressed.emit()
		"use":
			use_pressed.emit()
		"crouch":
			b["on"] = not b["on"]
			crouch_toggled.emit(b["on"])
		_:
			menu_pressed.emit(b["id"])


## Forget all held fingers (called when a menu opens, so nothing stays "stuck").
func reset_touches() -> void:
	_joy_finger = -1
	_look_finger = -1
	_joy_vec = Vector2.ZERO
	_sprinting = false
	for b in _buttons:
		b["finger"] = -1
	move_changed.emit(Vector2.ZERO, false)
	queue_redraw()


# ---------- drawing ----------

func _draw() -> void:
	var a := button_opacity

	# Joystick
	var center := _joy_origin if _joy_finger != -1 else _idle_joy_center
	var ring_color := Color(1.0, 0.65, 0.2, a + 0.25) if _sprinting else Color(1.0, 1.0, 1.0, a)
	draw_circle(center, joystick_radius, Color(0.0, 0.0, 0.0, a * 0.35))
	draw_arc(center, joystick_radius, 0.0, TAU, 48, ring_color, 3.0, true)
	draw_circle(center + _joy_vec * joystick_radius, 34.0, Color(1.0, 1.0, 1.0, a * 0.85))

	# Buttons
	var font := ThemeDB.fallback_font
	for b in _buttons:
		var p: Vector2 = b["pos"]
		var r: float = b["r"]
		var down: bool = b["finger"] != -1 or b["on"]
		var fill := Color(0.0, 0.0, 0.0, a * 0.55)
		var ink := Color(1.0, 1.0, 1.0, minf(1.0, a + 0.4))
		if down:
			fill = Color(1.0, 1.0, 1.0, minf(1.0, a + 0.25))
			ink = Color(0.0, 0.0, 0.0, 0.9)
		draw_circle(p, r * (0.94 if down else 1.0), fill)
		draw_arc(p, r, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, minf(1.0, a + 0.2)), 2.5, true)

		match b["id"]:
			"jump":
				_draw_chevron(p, r, true, ink)
			"crouch":
				_draw_chevron(p, r, false, ink)
			_:
				var font_size := int(r * 0.45)
				var label: String = b["label"]
				draw_string(font, Vector2(p.x - r, p.y + font_size * 0.35), label,
						HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, font_size, ink)


func _draw_chevron(p: Vector2, r: float, up: bool, ink: Color) -> void:
	var d := -1.0 if up else 1.0
	var pts := PackedVector2Array([
		p + Vector2(-r * 0.38, -d * r * 0.15),
		p + Vector2(0.0, d * r * 0.25),
		p + Vector2(r * 0.38, -d * r * 0.15),
	])
	draw_polyline(pts, ink, maxf(3.0, r * 0.12), true)
