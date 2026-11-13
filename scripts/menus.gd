extends CanvasLayer
## Inventory and crafting screens (touch friendly), plus an always-visible resource strip.
## While a screen is open the game is paused.

var state  # GameState node, set in setup()
var controls  # mobile controls node (cancels stuck touches when a screen opens)

var _root: Control
var _title: Label
var _list: VBoxContainer
var _status: Label
var _strip: Label
var _mode := "inventory"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	_build_strip()
	_build_panel()
	_root.visible = false


func setup(game_state, mobile_controls) -> void:
	state = game_state
	controls = mobile_controls
	state.inventory_changed.connect(_on_inventory_changed)
	state.message.connect(_on_state_message)
	_update_strip()


func open(mode: String) -> void:
	_mode = mode
	if controls:
		controls.reset_touches()
	get_tree().paused = true
	_root.visible = true
	_refresh()


func close() -> void:
	_root.visible = false
	get_tree().paused = false


# ---------- building the UI ----------

func _build_strip() -> void:
	_strip = Label.new()
	_strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_strip.custom_minimum_size = Vector2(360.0, 50.0)
	_strip.add_theme_font_size_override("font_size", 18)
	_strip.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_strip.add_theme_constant_override("outline_size", 4)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)
	# bottom centre, just above the hotbar
	_strip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	_strip.offset_top -= 92.0
	_strip.offset_bottom -= 92.0


func _build_panel() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780.0, 560.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.09, 0.96)
	style.border_color = Color(1.0, 1.0, 1.0, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(16.0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	vbox.add_child(top)
	top.add_child(_make_button("INVENTORY", 170.0, _show_mode.bind("inventory")))
	top.add_child(_make_button("CRAFTING", 170.0, _show_mode.bind("crafting")))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.add_child(_make_button("CLOSE", 130.0, close))

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0.0, 340.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
	_status.text = "USE near a tree = wood, near a rock = stone, near water = drink"
	vbox.add_child(_status)


func _make_button(text: String, min_width: float, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 52.0)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", _button_style(Color(0.20, 0.30, 0.22)))
	b.add_theme_stylebox_override("hover", _button_style(Color(0.26, 0.38, 0.28)))
	b.add_theme_stylebox_override("pressed", _button_style(Color(0.40, 0.58, 0.40)))
	b.add_theme_stylebox_override("disabled", _button_style(Color(0.13, 0.15, 0.14)))
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
	b.pressed.connect(callback)
	return b


func _button_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = Color(1.0, 1.0, 1.0, 0.35)
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(8.0)
	return s


func _add_row(text: String, buttons: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(300.0, 0.0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 20)
	row.add_child(label)

	for b in buttons:
		var btn := _make_button(str(b["text"]), 110.0, b["cb"])
		btn.disabled = not bool(b.get("enabled", true))
		row.add_child(btn)

	_list.add_child(row)
	_list.add_child(HSeparator.new())


# ---------- refreshing ----------

func _show_mode(mode: String) -> void:
	_mode = mode
	_refresh()


func _on_inventory_changed() -> void:
	_update_strip()
	if _root.visible:
		_refresh()


func _on_state_message(text: String) -> void:
	_status.text = text


func _update_strip() -> void:
	if state == null:
		return
	var food: int = state.count("berries") + state.count("cooked_meat") + state.count("raw_meat")
	_strip.text = "Wood %d   Stone %d   Food %d\n%.1f / %.0f kg" % [
		state.count("wood"), state.count("stone"), food, state.weight(), state.MAX_WEIGHT
	]


func _refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()

	if _mode == "inventory":
		_title.text = "INVENTORY     %.1f / %.0f kg" % [state.weight(), state.MAX_WEIGHT]
		var ids: Array = state.items.keys()
		ids.sort()
		if ids.is_empty():
			_add_row("Empty. Gather wood and stone with the USE button.", [])
		for id in ids:
			var n: int = state.items[id]
			var def: Dictionary = state.ITEMS[id]
			var buttons := []
			if def.has("food"):
				buttons.append({"text": "EAT", "cb": _on_use.bind(str(id))})
			elif def.has("place"):
				buttons.append({"text": "PLACE", "cb": _on_use.bind(str(id))})
			buttons.append({"text": "DROP", "cb": _on_drop.bind(str(id))})
			_add_row("%s  x%d    (%.1f kg)" % [str(def["name"]), n, float(def["weight"]) * float(n)], buttons)
	else:
		_title.text = "CRAFTING"
		for recipe in state.RECIPES:
			var rid := str(recipe["id"])
			var cost: Dictionary = recipe["cost"]
			var parts := PackedStringArray()
			for cid in cost:
				parts.append("%d %s (have %d)" % [int(cost[cid]), state.item_name(str(cid)), state.count(str(cid))])
			var text := "%s\n%s  -  %s" % [state.item_name(rid), ", ".join(parts), str(recipe["note"])]
			_add_row(text, [{"text": "CRAFT", "cb": _on_craft.bind(rid), "enabled": state.can_craft(recipe)}])


func _on_use(id: String) -> void:
	var is_placeable: bool = state.ITEMS[id].has("place")
	state.use_item(id)
	if is_placeable:
		close()


func _on_drop(id: String) -> void:
	state.drop(id)


func _on_craft(id: String) -> void:
	state.craft(id)
