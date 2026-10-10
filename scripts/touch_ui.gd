extends Control
## Touch controls for Blocky. Only visible on touchscreen devices.
##  - Left half drag  -> virtual joystick (move)
##  - Bottom-right circle -> jump button
##  - Right half drag (outside the button) -> camera look
## Plain Control drawing, no textures needed.

@export var player_path: NodePath

const JOY_RADIUS := 115.0
const KNOB_RADIUS := 46.0
const BTN_RADIUS := 80.0
const BTN_SMALL := 60.0
const BTN_DOM := 68.0

var _player: Node = null
var _touch := false
var _joy_id := -1
var _joy_center := Vector2.ZERO
var _cam_id := -1

func _ready() -> void:
	_touch = DisplayServer.is_touchscreen_available()
	visible = _touch
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if player_path != NodePath(""):
		_player = get_node_or_null(player_path)

func _btn_centers() -> Dictionary:
	var vp := get_viewport_rect().size
	return {
		"jump": Vector2(vp.x - 135.0, vp.y - 160.0),
		"atk": Vector2(vp.x - 135.0, vp.y - 345.0),
		"chi": Vector2(vp.x - 315.0, vp.y - 250.0),
		"dom": Vector2(vp.x - 315.0, vp.y - 430.0),
	}

func _input(event: InputEvent) -> void:
	if not _touch or _player == null:
		return
	var vp := get_viewport_rect().size
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if t.position.x < vp.x * 0.45 and t.position.y > vp.y * 0.35 and _joy_id == -1:
				_joy_id = t.index
				_joy_center = t.position
				queue_redraw()
			else:
				var bc := _btn_centers()
				if t.position.distance_to(bc["jump"]) <= BTN_RADIUS + 34.0:
					_player.try_touch_jump()
				elif t.position.distance_to(bc["atk"]) <= BTN_SMALL + 30.0:
					_player.try_attack()
				elif t.position.distance_to(bc["chi"]) <= BTN_SMALL + 30.0:
					_player.try_chidori()
				elif t.position.distance_to(bc["dom"]) <= BTN_DOM + 30.0:
					_player.try_domain()
				elif _cam_id == -1:
					_cam_id = t.index
		else:
			if t.index == _joy_id:
				_joy_id = -1
				_player.touch_move = Vector2.ZERO
				queue_redraw()
			elif t.index == _cam_id:
				_cam_id = -1
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _joy_id:
			var off := d.position - _joy_center
			if off.length() > JOY_RADIUS:
				_joy_center = d.position - off.normalized() * JOY_RADIUS
				off = d.position - _joy_center
			_player.touch_move = Vector2(off.x / JOY_RADIUS, off.y / JOY_RADIUS)
			queue_redraw()
		elif d.index == _cam_id:
			_player.add_camera_drag(d.relative)

func _draw() -> void:
	if not _touch:
		return
	# Joystick base + knob (knob follows only while touching).
	var base := _joy_center
	if _joy_id == -1:
		var vp := get_viewport_rect().size
		base = Vector2(155.0, vp.y - 175.0)
	draw_circle(base, JOY_RADIUS, Color(1, 1, 1, 0.14))
	draw_arc(base, JOY_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.4), 4.0, true)
	var knob := base
	if _player != null:
		knob = base + Vector2(_player.touch_move.x, _player.touch_move.y) * (JOY_RADIUS * 0.55)
	draw_circle(knob, KNOB_RADIUS, Color(1, 1, 1, 0.45))
	# Action buttons.
	var bc := _btn_centers()
	_draw_btn(bc["jump"], BTN_RADIUS, Color(0.35, 0.85, 0.4), "JMP")
	_draw_btn(bc["atk"], BTN_SMALL, Color(1.0, 0.6, 0.2), "ATK")
	_draw_btn(bc["chi"], BTN_SMALL, Color(0.35, 0.65, 1.0), "CHI")
	var mval: float = 0.0
	if _player != null:
		mval = _player.get("meter")
	var dom_ready := mval >= 100.0
	var dom_col := Color(1.0, 0.15, 0.2) if dom_ready else Color(0.45, 0.12, 0.15)
	_draw_btn(bc["dom"], BTN_DOM, dom_col, "DOM")

func _draw_btn(center: Vector2, radius: float, color: Color, label: String) -> void:
	draw_circle(center, radius, Color(color.r, color.g, color.b, 0.38))
	draw_arc(center, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 4.0, true)
	var font := ThemeDB.fallback_font
	var fs := 30
	var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string(font, center + Vector2(-ts.x * 0.5, ts.y * 0.35), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.92))
