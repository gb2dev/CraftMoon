class_name PieMenu
extends Control

signal item_selected(index: int)
signal cancelled

const MAX_SLOTS: int = 8
const INNER_RADIUS: float = 128.0
const OUTER_RADIUS: float = 224.0
const RING_THICKNESS: float = OUTER_RADIUS - INNER_RADIUS
const ICON_RADIUS: float = INNER_RADIUS + RING_THICKNESS * 0.5
const AUTO_TRIGGER_DIST: float = OUTER_RADIUS + RING_THICKNESS * 0.25
const OFFSET: float = 2.0
const ARC_STEPS: int = 32
const STICK_DEADZONE: float = 0.5
const JOYPAD_DEVICE: int = 0
const ICON_SIZE: float = 64.0

class PieItem:
	var label: String
	var icon: Texture2D
	func _init(p_label: String, p_icon: Texture2D = null) -> void:
		label = p_label
		icon = p_icon

var _items: Array[PieItem] = []
var _slot_map: Array[int] = []
var _hovered_slot: int = -1
var _center: Vector2:
	get:
		return size * 0.5
var _visible_menu: bool = false
var _was_inside: bool = false
var _waiting: bool = false
var _joypad_active: bool = false
var _joypad_slot: int = -1
var _slice_polys: Array[PackedVector2Array] = []
var _shadow_poly: PackedVector2Array


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _visible_menu:
		_build_polygons()
		queue_redraw()


func _draw() -> void:
	if not _visible_menu:
		return
	_draw_shadow()
	_draw_slices()
	_draw_icons()


func set_items(items: Array[Variant]) -> void:
	_items.clear()
	for raw: Variant in items:
		if raw is PieItem:
			_items.append(raw)
		elif raw is Dictionary:
			_items.append(PieItem.new(raw.get("label", ""), raw.get("icon", null)))
	_assign_slots()


func open() -> void:
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
	_hovered_slot = -1
	_was_inside = false
	_waiting = false
	_joypad_active = false
	_joypad_slot = -1
	_visible_menu = true
	_build_polygons()
	show()
	grab_focus()
	queue_redraw()
	_on_mouse_moved(get_local_mouse_position())


func close() -> void:
	_visible_menu = false
	hide()
	_hovered_slot = -1
	cancelled.emit()


func _input(event: InputEvent) -> void:
	if not _visible_menu:
		return

	if event is InputEventJoypadMotion:
		var axis: int = event.axis
		if axis == JOY_AXIS_LEFT_X or axis == JOY_AXIS_LEFT_Y or axis == JOY_AXIS_RIGHT_X or axis == JOY_AXIS_RIGHT_Y:
			var lx := Input.get_joy_axis(JOYPAD_DEVICE, JOY_AXIS_LEFT_X)
			var ly := Input.get_joy_axis(JOYPAD_DEVICE, JOY_AXIS_LEFT_Y)
			var rx := Input.get_joy_axis(JOYPAD_DEVICE, JOY_AXIS_RIGHT_X)
			var ry := Input.get_joy_axis(JOYPAD_DEVICE, JOY_AXIS_RIGHT_Y)

			var sv: Vector2
			if Vector2(lx, ly).length_squared() > Vector2(rx, ry).length_squared():
				sv = Vector2(lx, ly)
			else:
				sv = Vector2(rx, ry)

			var mag := sv.length()
			var prev := _hovered_slot
			if mag > STICK_DEADZONE:
				_joypad_active = true
				_joypad_slot = _angle_to_slot(atan2(sv.y, sv.x))
				_hovered_slot = _joypad_slot
				_was_inside = true
				if _hovered_slot != prev:
					queue_redraw()
			elif _joypad_active:
				_joypad_active = false
				if _joypad_slot >= 0 and _slot_map[_joypad_slot] >= 0:
					_hovered_slot = _joypad_slot
					_trigger_selected()
				_joypad_slot = -1

	elif event.is_action_pressed(&"ui_accept"):
		if _hovered_slot >= 0 and _slot_map[_hovered_slot] >= 0:
			_trigger_selected()
		else:
			close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not _visible_menu:
		return
	if event is InputEventMouseMotion:
		_on_mouse_moved(event.position)
	elif event is InputEventMouseButton:
		if event.is_action_pressed(&"action") or (event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
			_try_select()
			accept_event()


func _on_mouse_moved(mouse_pos: Vector2) -> void:
	var dx := mouse_pos.x - _center.x
	var dy := mouse_pos.y - _center.y
	var dist := sqrt(dx * dx + dy * dy)

	var prev := _hovered_slot
	if dist > INNER_RADIUS:
		_hovered_slot = _angle_to_slot(atan2(dy, dx))
		_was_inside = true
	else:
		_hovered_slot = -1

	if _hovered_slot != prev:
		queue_redraw()

	if not _waiting and _was_inside and dist >= AUTO_TRIGGER_DIST and _hovered_slot >= 0:
		if _slot_map[_hovered_slot] >= 0:
			_waiting = true
			_trigger_selected()


func _try_select() -> void:
	if _hovered_slot < 0 or _slot_map[_hovered_slot] < 0:
		close()
		return
	_trigger_selected()


func _trigger_selected() -> void:
	if _hovered_slot < 0 or _slot_map[_hovered_slot] < 0:
		return
	var idx := _slot_map[_hovered_slot]
	_visible_menu = false
	hide()
	_hovered_slot = -1
	_waiting = false
	item_selected.emit(idx)
	queue_redraw()


func _slot_to_angle(slot: int) -> float:
	return (TAU / MAX_SLOTS) * (float(slot) - OFFSET)


func _angle_to_slot(raw_angle: float) -> int:
	var slice := TAU / float(MAX_SLOTS)
	var f := raw_angle / slice + 0.5 + OFFSET
	var s := int(floor(f)) % MAX_SLOTS
	if s < 0:
		s += MAX_SLOTS
	return s


func _polar(radius: float, angle: float) -> Vector2:
	return _center + Vector2(cos(angle), sin(angle)) * radius


func _assign_slots() -> void:
	var _error := _slot_map.resize(MAX_SLOTS)
	_slot_map.fill(-1)
	for i in _items.size():
		if i < MAX_SLOTS:
			_slot_map[i] = i


func _draw_shadow() -> void:
	var shadow_color := get_theme_color("font_shadow_color", "Label")
	if shadow_color.a == 0.0:
		shadow_color = Color(0, 0, 0, 1.0)
	shadow_color.a = 0.55
	draw_colored_polygon(_shadow_poly, shadow_color)


func _draw_slices() -> void:
	var slice_angle := TAU / float(MAX_SLOTS)
	var sb_normal := get_theme_stylebox("normal", "Button") as StyleBoxFlat
	var sb_hover := get_theme_stylebox("hover", "Button") as StyleBoxFlat
	var base_color := sb_normal.bg_color
	var hover_color := sb_hover.bg_color
	var border_color := sb_normal.border_color

	for s in MAX_SLOTS:
		if _slot_map[s] < 0:
			continue

		var color := base_color if s != _hovered_slot else hover_color
		draw_colored_polygon(_slice_polys[s], color)

		var start_a := _slot_to_angle(s) - slice_angle * 0.5
		draw_line(
			_polar(INNER_RADIUS + 1.0, start_a),
			_polar(OUTER_RADIUS - 1.0, start_a),
			border_color, -1.0, false
		)
		var next_slot := (s + 1) % MAX_SLOTS
		if _slot_map[next_slot] < 0:
			var end_a := start_a + slice_angle
			draw_line(
				_polar(INNER_RADIUS + 1.0, end_a),
				_polar(OUTER_RADIUS - 1.0, end_a),
				border_color, -1.0, false
			)


func _draw_icons() -> void:
	var icon_half := ICON_SIZE * 0.5
	for s in MAX_SLOTS:
		var idx := _slot_map[s] if s < _slot_map.size() else -1
		if idx < 0 or idx >= _items.size():
			continue
		var tex := _items[idx].icon
		if tex == null:
			continue
		var angle := _slot_to_angle(s)
		var top_left := _polar(ICON_RADIUS, angle) - Vector2(icon_half, icon_half)
		draw_texture_rect(tex, Rect2(top_left, Vector2(ICON_SIZE, ICON_SIZE)), false)


func _build_polygons() -> void:
	_shadow_poly = _build_sector(0.0, TAU, INNER_RADIUS, OUTER_RADIUS, ARC_STEPS * 2)
	var slice_angle := TAU / float(MAX_SLOTS)
	var _error := _slice_polys.resize(MAX_SLOTS)
	for s in MAX_SLOTS:
		var center_a := _slot_to_angle(s)
		_slice_polys[s] = _build_sector(center_a - slice_angle * 0.5, slice_angle, INNER_RADIUS, OUTER_RADIUS, ARC_STEPS)


func _build_sector(start_angle: float, sweep: float, r_inner: float, r_outer: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var _error := pts.resize((steps + 1) * 2)
	for i in range(steps + 1):
		var a := start_angle + sweep * float(i) / float(steps)
		pts[i] = _center + Vector2(cos(a), sin(a)) * r_outer
	for i in range(steps + 1):
		var a := start_angle + sweep * float(steps - i) / float(steps)
		pts[steps + 1 + i] = _center + Vector2(cos(a), sin(a)) * r_inner
	return pts
